# Docker 导入故障排查

## 问题1: readline was closed 错误

### 原因
Docker 非交互模式下，readline 无法获取用户输入导致失败。

### 解决方案
使用 `--non-interactive` 或 `--force` 参数：

```bash
# 方法1: 非交互模式（自动确认所有操作）
docker exec claude-relay-service-claude-relay-1 \
  node /app/scripts/data-transfer.js import \
  --input=/app/production-backup-final.json \
  --non-interactive \
  --skip-conflicts

# 方法2: 强制覆盖模式
docker exec claude-relay-service-claude-relay-1 \
  node /app/scripts/data-transfer.js import \
  --input=/app/production-backup-final.json \
  --force
```

## 问题2: 导入数据不完整

### 症状
```
API Keys to import: 2
Claude Accounts to import: 0      ← 缺少 claudeConsoleAccounts
Gemini Accounts to import: 1
Admins to import: 0
```

### 原因
使用了旧版本的备份文件，缺少 `claudeConsoleAccounts` 和 `openaiResponsesAccounts` 字段。

### 解决方案

#### 方案A: 使用正确的备份文件（推荐）

确保使用 `production-backup-final.json`，它包含：
- ✅ claudeConsoleAccounts: 4
- ✅ openaiResponsesAccounts: 2
- ✅ geminiAccounts: 1
- ✅ apiKeys: 2

```bash
# 验证备份文件内容
cat production-backup-final.json | jq '.data | keys'

# 应该看到所有这些字段：
# - "admins"
# - "apiKeys"
# - "claudeAccounts"
# - "claudeConsoleAccounts"      ← 必须有
# - "geminiAccounts"
# - "openaiResponsesAccounts"    ← 必须有
```

#### 方案B: 重新导出数据

如果没有正确的备份文件，重新导出：

```bash
# 在有完整数据的环境中
node scripts/data-transfer.js export \
  --output=production-backup-final.json

# 上传到线上服务器
scp production-backup-final.json user@server:/path/to/project/
```

## 完整的正确操作流程

### 步骤1: 确认代码已更新

```bash
cd /path/to/claude-relay-service
git pull origin main
```

### 步骤2: 确认使用正确的备份文件

```bash
# 检查备份文件
cat production-backup-final.json | jq '.data | {
  apiKeys: (.apiKeys | length),
  claudeConsoleAccounts: (.claudeConsoleAccounts | length),
  geminiAccounts: (.geminiAccounts | length),
  openaiResponsesAccounts: (.openaiResponsesAccounts | length)
}'

# 应该看到：
# {
#   "apiKeys": 2,
#   "claudeConsoleAccounts": 4,
#   "geminiAccounts": 1,
#   "openaiResponsesAccounts": 2
# }
```

### 步骤3: 重启容器

```bash
docker-compose restart claude-relay
sleep 10  # 等待服务启动
```

### 步骤4: 执行导入（非交互模式）

```bash
# 使用 docker-compose（推荐）
docker-compose exec -T claude-relay \
  node /app/scripts/data-transfer.js import \
  --input=/app/production-backup-final.json \
  --skip-conflicts \
  --non-interactive

# 或使用 docker exec
docker exec claude-relay-service-claude-relay-1 \
  node /app/scripts/data-transfer.js import \
  --input=/app/production-backup-final.json \
  --skip-conflicts \
  --non-interactive
```

### 步骤5: 验证导入结果

```bash
docker-compose exec -T claude-relay node -e "
const redis = require('./src/models/redis');
(async () => {
  await redis.connect();
  
  const apiKeys = await redis.client.keys('apikey:*');
  const claudeConsole = await redis.client.keys('claude_console_account:*');
  const gemini = await redis.client.keys('gemini_account:*');
  const openai = await redis.client.keys('openai_responses_account:*');
  
  console.log('=== 导入验证结果 ===');
  console.log('API Keys:', apiKeys.filter(k => !k.includes('hash_map')).length);
  console.log('Claude Console Accounts:', claudeConsole.length);
  console.log('Gemini Accounts:', gemini.length);
  console.log('OpenAI Responses Accounts:', openai.length);
  
  console.log('\\n=== 预期结果 ===');
  console.log('API Keys: 2');
  console.log('Claude Console Accounts: 4');
  console.log('Gemini Accounts: 1');
  console.log('OpenAI Responses Accounts: 2');
  
  await redis.disconnect();
})();
"
```

## 参数说明

| 参数 | 说明 | 使用场景 |
|------|------|---------|
| `--non-interactive` | 非交互模式，自动确认 | Docker/CI环境（推荐） |
| `--skip-conflicts` | 跳过已存在的数据 | 增量导入 |
| `--force` | 强制覆盖已存在的数据 | 完全覆盖导入 |
| `--input=FILE` | 指定导入文件 | 必需参数 |

## 推荐命令组合

```bash
# 生产环境推荐（跳过已存在的数据）
--input=/app/production-backup-final.json --skip-conflicts --non-interactive

# 测试环境推荐（强制覆盖）
--input=/app/production-backup-final.json --force --non-interactive
```

## 常见错误对照表

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `readline was closed` | Docker非交互模式 | 添加 `--non-interactive` |
| `Claude Accounts to import: 0` | 使用了旧备份文件 | 使用 `production-backup-final.json` |
| `File not found` | 文件路径错误 | 检查容器内路径 `/app/...` |
| `Redis connection failed` | Redis未启动 | `docker-compose ps redis` |

## 一键修复脚本

```bash
#!/bin/bash
set -e

echo "=== Claude Relay Service 数据导入 ==="

# 1. 拉取最新代码
echo "▶ 步骤1: 拉取最新代码"
cd /path/to/claude-relay-service
git pull origin main

# 2. 检查备份文件
echo "▶ 步骤2: 检查备份文件"
if [ ! -f production-backup-final.json ]; then
  echo "❌ 错误: 找不到 production-backup-final.json"
  exit 1
fi

# 3. 验证备份文件内容
echo "▶ 步骤3: 验证备份文件"
CONSOLE_COUNT=$(cat production-backup-final.json | jq '.data.claudeConsoleAccounts | length')
if [ "$CONSOLE_COUNT" == "0" ]; then
  echo "❌ 错误: 备份文件缺少 Claude Console 账户数据"
  exit 1
fi
echo "✅ 备份文件验证通过: $CONSOLE_COUNT 个 Claude Console 账户"

# 4. 重启容器
echo "▶ 步骤4: 重启容器"
docker-compose restart claude-relay
sleep 10

# 5. 执行导入
echo "▶ 步骤5: 执行导入"
docker-compose exec -T claude-relay \
  node /app/scripts/data-transfer.js import \
  --input=/app/production-backup-final.json \
  --skip-conflicts \
  --non-interactive

# 6. 验证结果
echo "▶ 步骤6: 验证导入结果"
docker-compose exec -T claude-relay node -e "
const redis = require('./src/models/redis');
(async () => {
  await redis.connect();
  const keys = await redis.client.keys('claude_console_account:*');
  console.log('导入的 Claude Console 账户数量:', keys.length);
  await redis.disconnect();
})();
"

echo "✅ 导入完成！"
```

保存为 `import.sh` 并执行：
```bash
chmod +x import.sh
./import.sh
```
