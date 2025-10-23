# 数据导入部署指南

## ⚠️ 重要提示

**不能直接用旧代码导入新备份！** 必须先更新导入脚本。

## 问题说明

- ❌ 旧代码使用错误的键前缀 `claude_account:*`
- ✅ 实际系统使用 `claude_console_account:*`
- ❌ 旧代码不支持 `openaiResponsesAccounts`

如果用旧代码导入，**4个Claude账户和2个OpenAI账户会丢失**！

## 推荐方案：更新脚本后导入

### 步骤 1: 上传文件到线上

```bash
# 上传修复后的导入脚本
scp scripts/data-transfer.js user@server:/path/to/claude-relay-service/scripts/

# 上传完整备份
scp production-backup-final.json user@server:/path/to/claude-relay-service/
```

### 步骤 2: 在线上执行导入

```bash
# SSH 登录到线上服务器
ssh user@server
cd /path/to/claude-relay-service

# 备份旧脚本（可选）
cp scripts/data-transfer.js scripts/data-transfer.js.backup-$(date +%Y%m%d)

# 执行导入（使用 --skip-conflicts 避免重复导入）
node scripts/data-transfer.js import \
  --input=production-backup-final.json \
  --skip-conflicts

# 如果需要强制覆盖
# node scripts/data-transfer.js import \
#   --input=production-backup-final.json \
#   --force
```

### 步骤 3: 验证导入结果

```bash
# 运行验证脚本
node -e "
const redis = require('./src/models/redis');
(async () => {
  await redis.connect();
  
  const apiKeys = await redis.client.keys('apikey:*');
  const consoleAccounts = await redis.client.keys('claude_console_account:*');
  const geminiAccounts = await redis.client.keys('gemini_account:*');
  const openaiAccounts = await redis.client.keys('openai_responses_account:*');
  
  console.log('导入验证结果:');
  console.log('- API Keys:', apiKeys.filter(k => !k.includes('hash_map')).length);
  console.log('- Claude Console Accounts:', consoleAccounts.length);
  console.log('- Gemini Accounts:', geminiAccounts.length);
  console.log('- OpenAI Responses Accounts:', openaiAccounts.length);
  console.log('');
  console.log('预期结果:');
  console.log('- API Keys: 2');
  console.log('- Claude Console Accounts: 4');
  console.log('- Gemini Accounts: 1');
  console.log('- OpenAI Responses Accounts: 2');
  
  await redis.disconnect();
})();
"
```

### 步骤 4: 测试功能

```bash
# 测试 API 调用
curl -X POST http://localhost:3000/api/v1/messages \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

## 导入的数据内容

```
production-backup-final.json 包含:
├── API Keys: 2
├── Claude Console Accounts: 4
│   ├── turn (7ca71dcd-aad6-47fd-8643-dae876790462)
│   ├── ... 其他3个账户
├── Gemini Accounts: 1
└── OpenAI Responses Accounts: 2
```

## 常见问题

### Q: 导入时提示账户已存在怎么办？

A: 使用 `--skip-conflicts` 跳过已存在的账户，或使用 `--force` 强制覆盖。

### Q: 导入后账户无法使用？

A: 检查以下几点：
1. 确认使用了新版 `data-transfer.js`
2. 检查 Redis 中的键是否正确（`claude_console_account:*`）
3. 查看应用日志是否有报错

### Q: 只想导入特定类型的账户？

A: 手动编辑备份文件，删除不需要的部分，或使用 `--types` 参数重新导出。

## 回滚方案

如果导入出现问题，可以：

```bash
# 1. 停止服务
npm run service:stop

# 2. 清除错误导入的数据
redis-cli
> DEL claude_console_account:*
> DEL openai_responses_account:*
> exit

# 3. 重新导入或恢复之前的备份
```

## 检查清单

导入前:
- [ ] 已上传新版 `data-transfer.js`
- [ ] 已上传 `production-backup-final.json`
- [ ] 已备份线上现有数据

导入后:
- [ ] 账户数量正确（4 + 1 + 2）
- [ ] API 调用正常工作
- [ ] 没有报错日志
