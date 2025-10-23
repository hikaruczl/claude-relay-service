# Docker 部署数据导入指南

## 🐳 Docker 环境下的导入流程

### 关键区别

在Docker环境中：
- ❌ **不需要重新构建镜像**（scripts是代码的一部分，git pull后就有了）
- ✅ **直接在容器内��行导入命令**
- ⚠️ **备份文件需要放到宿主机可访问的位置**

## 📋 完整操作步骤

### 步骤 1: 拉取最新代码

```bash
# 在宿主机上
cd /path/to/claude-relay-service
git pull origin main
```

### 步骤 2: 上传备份文件

```bash
# 将备份文件放到项目根目录（或data目录）
# 如果是从开发机上传：
scp production-backup-final.json user@server:/path/to/claude-relay-service/

# 或者直接在服务器上创建
# 上传到项目根目录即可
```

### 步骤 3: 重启容器（让新代码生效）

```bash
# 方法1: 使用 docker-compose 重启（推荐）
docker-compose restart claude-relay

# 方法2: 完全重新创建容器
docker-compose down
docker-compose up -d

# 方法3: 如果需要重新构建（一般不需要）
# docker-compose build --no-cache claude-relay
# docker-compose up -d
```

### 步骤 4: 在容器内执行导入

```bash
# 进入容器
docker exec -it claude-relay-service-claude-relay-1 bash

# 或者如果容器名不同，先查看容器名
docker ps | grep claude-relay

# 在容器内执行导入
cd /app
node scripts/data-transfer.js import \
  --input=production-backup-final.json \
  --skip-conflicts

# 或者直接从宿主机执行（推荐）
docker exec -it claude-relay-service-claude-relay-1 \
  node /app/scripts/data-transfer.js import \
  --input=/app/production-backup-final.json \
  --skip-conflicts
```

### 步骤 5: 验证导入结果

```bash
# 在容器内验证
docker exec -it claude-relay-service-claude-relay-1 \
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
  
  await redis.disconnect();
})();
"
```

## 🎯 简化版本（一键执行）

```bash
# 在宿主机上执行以下命令

# 1. 拉取代码
cd /path/to/claude-relay-service
git pull origin main

# 2. 确保备份文件在项目目录
ls production-backup-final.json

# 3. 重启容器
docker-compose restart claude-relay

# 4. 等待10秒让服务完全启动
sleep 10

# 5. 执行导入
docker exec claude-relay-service-claude-relay-1 \
  node /app/scripts/data-transfer.js import \
  --input=/app/production-backup-final.json \
  --skip-conflicts

# 6. 验证结果
docker exec claude-relay-service-claude-relay-1 \
  node -e "
const redis = require('./src/models/redis');
(async () => {
  await redis.connect();
  const keys = await redis.client.keys('claude_console_account:*');
  console.log('Claude Console Accounts:', keys.length);
  await redis.disconnect();
})();
"
```

## 📂 文件路径映射

Docker Compose 配置中的卷映射：
```yaml
volumes:
  - ./logs:/app/logs        # 日志目录
  - ./data:/app/data        # 数据目录
```

建议放置备份文件的位置：
1. **项目根目录**: `/path/to/claude-relay-service/production-backup-final.json`
   - 容器内路径: `/app/production-backup-final.json`
   
2. **data目录**: `/path/to/claude-relay-service/data/production-backup-final.json`
   - 容器内路径: `/app/data/production-backup-final.json`
   - 导入时使用: `--input=/app/data/production-backup-final.json`

## ⚠️ 常见问题

### Q1: 容器名称不对？

```bash
# 查看实际的容器名
docker ps | grep claude-relay

# 或者使用 docker-compose 服务名
docker-compose exec claude-relay node /app/scripts/data-transfer.js import --input=/app/production-backup-final.json
```

### Q2: 文件找不到？

```bash
# 检查容器内文件
docker exec claude-relay-service-claude-relay-1 ls -la /app/production-backup-final.json

# 如果文件不存在，需要重新上传
# 或者使用 docker cp 复制到容器内
docker cp production-backup-final.json claude-relay-service-claude-relay-1:/app/
```

### Q3: 需要重新构建镜像吗？

**不需要！** 因为：
- `git pull` 后，代码已经更新
- `docker-compose restart` 会使用新代码
- scripts 目录是代码的一部分，会自动更新

**只有在以下情况才需要重新构建**：
- 修改了 `package.json` 依赖
- 修改了 `Dockerfile`
- 需要更新 Node.js 版本等基础环境

### Q4: Redis 数据会丢失吗？

**不会！** Redis 数据独立于应用容器：
- Redis 运行在独立的容器中
- 重启 claude-relay 容器不会影响 Redis 数据
- 导入操作直接操作 Redis，与容器重启无关

## 🔄 完整操作时间线

```
时间点           操作                          说明
---------------------------------------------------------------------
T0   ->  git pull origin main               拉取新代码（含修复的导入脚本）
T1   ->  上传 production-backup-final.json 备份文件到项目目录
T2   ->  docker-compose restart             重启容器（加载新代码）
T3   ->  等待10秒                           确保服务完全启动
T4   ->  docker exec ... 导入命令            执行导入
T5   ->  docker exec ... 验证命令            验证结果
```

**总耗时**: 约 1-2 分钟

## ✅ 预期结果

导入成功后应该看到：

```
============================================================
✅ Import Complete!
============================================================
Successfully imported: 9
Skipped: 0
Errors: 0
============================================================
```

验证命令输出：
```
导入验证结果:
- API Keys: 2
- Claude Console Accounts: 4
- Gemini Accounts: 1
- OpenAI Responses Accounts: 2
```

## 🚨 重要提示

1. **Redis 连接**: 确保 Docker Compose 中的 Redis 服务正常运行
   ```bash
   docker-compose ps redis
   ```

2. **网络连接**: 容器需要能访问 Redis 容器
   ```bash
   docker-compose exec claude-relay ping redis
   ```

3. **权限问题**: 确保备份文件在容器内可读
   ```bash
   docker exec claude-relay-service-claude-relay-1 cat /app/production-backup-final.json | head -5
   ```

## 📞 故障排查

如果导入失败，检查：
```bash
# 1. 查看容器日志
docker-compose logs claude-relay --tail=50

# 2. 检查 Redis 连接
docker-compose exec claude-relay node -e "
const redis = require('./src/models/redis');
redis.connect().then(() => console.log('Redis OK')).catch(e => console.error(e));
"

# 3. 检查文件内容
docker exec claude-relay-service-claude-relay-1 \
  node -e "console.log(JSON.parse(require('fs').readFileSync('/app/production-backup-final.json')).metadata)"
```
