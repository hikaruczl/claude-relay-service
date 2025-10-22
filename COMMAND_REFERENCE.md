# ⚡ 部署命令速查表

快速查找常用命令,按使用场景分类。

---

## 📦 数据导出/导入

### 本地数据导出

```bash
# 导出所有数据(推荐 - 自动解密)
node scripts/data-transfer-enhanced.js export --output=production-backup.json

# 使用部署脚本导出
./deploy.sh export

# 导出加密备份(用于本地存档)
node scripts/data-transfer-enhanced.js export --output=encrypted-backup.json --decrypt=false

# 仅导出 API Keys
node scripts/data-transfer-enhanced.js export --types=apikeys --output=apikeys-only.json

# 仅导出账户
node scripts/data-transfer-enhanced.js export --types=accounts --output=accounts-only.json

# 导出脱敏数据(仅用于审计)
node scripts/data-transfer-enhanced.js export --sanitize --output=sanitized.json
```

### 服务器数据导入

```bash
# 上传备份到容器
docker cp production-backup.json claude-relay-claude-relay-1:/app/backup.json

# 导入数据(强制覆盖)
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js import \
  --input=/app/backup.json --force

# 导入数据(跳过冲突)
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js import \
  --input=/app/backup.json --skip-conflicts

# 导入数据(交互式确认)
docker-compose exec -it claude-relay node scripts/data-transfer-enhanced.js import \
  --input=/app/backup.json

# 使用部署脚本导入
./deploy.sh import production-backup.json
```

---

## 🐳 Docker 服务管理

### 基本操作

```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 重启服务
docker-compose restart

# 重启特定服务
docker-compose restart claude-relay
docker-compose restart redis

# 查看服务状态
docker-compose ps

# 查看资源使用
docker stats
```

### 镜像管理

```bash
# 拉取最新镜像
docker-compose pull

# 查看镜像
docker images | grep claude-relay

# 删除旧镜像
docker image prune -a

# 构建本地镜像
docker-compose build
```

### 容器操作

```bash
# 进入容器
docker-compose exec claude-relay sh
docker-compose exec redis sh

# 以 root 用户进入
docker-compose exec -u root claude-relay sh

# 在容器中执行命令
docker-compose exec claude-relay npm run cli status

# 查看容器详情
docker inspect claude-relay-claude-relay-1
```

---

## 📊 日志查看

### 实时日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f claude-relay
docker-compose logs -f redis

# 使用部署脚本查看
./deploy.sh logs

# 查看最近 100 行日志
docker-compose logs --tail=100 claude-relay

# 查看带时间戳的日志
docker-compose logs -f -t claude-relay
```

### 应用日志

```bash
# 主机上的日志文件
tail -f logs/claude-relay-combined.log
tail -f logs/claude-relay-error.log

# 容器内的日志
docker-compose exec claude-relay cat logs/claude-relay-combined.log

# 使用 less 浏览日志
docker-compose exec claude-relay less logs/claude-relay-combined.log
```

---

## 🔧 CLI 工具命令

### 系统状态

```bash
# 查看系统状态
docker-compose exec claude-relay npm run cli status

# 查看详细信息
docker-compose exec claude-relay npm run cli status -- --verbose
```

### API Key 管理

```bash
# 列出所有 API Keys
docker-compose exec claude-relay npm run cli keys list

# 创建新的 API Key
docker-compose exec claude-relay npm run cli keys create -- --name "MyApp" --limit 1000

# 查看 API Key 详情
docker-compose exec claude-relay npm run cli keys info -- --id <key-id>

# 删除 API Key
docker-compose exec claude-relay npm run cli keys delete -- --id <key-id>
```

### 账户管理

```bash
# 列出所有账户
docker-compose exec claude-relay npm run cli accounts list

# 刷新账户 Token
docker-compose exec claude-relay npm run cli accounts refresh <account-id>

# 查看账户详情
docker-compose exec claude-relay npm run cli accounts info <account-id>
```

### 管理员操作

```bash
# 创建新管理员
docker-compose exec claude-relay npm run cli admin create -- --username admin2

# 重置管理员密码
docker-compose exec claude-relay npm run cli admin reset-password -- --username admin

# 列出所有管理员
docker-compose exec claude-relay npm run cli admin list
```

---

## 🗄️ Redis 操作

### 连接和基本操作

```bash
# 进入 Redis CLI
docker-compose exec redis redis-cli

# 测试连接
docker-compose exec redis redis-cli ping

# 检查 Redis 信息
docker-compose exec redis redis-cli INFO

# 查看内存使用
docker-compose exec redis redis-cli INFO memory

# 查看客户端连接
docker-compose exec redis redis-cli CLIENT LIST
```

### 数据操作

```bash
# 查看所有键(慎用!)
docker-compose exec redis redis-cli KEYS "*"

# 查看特定类型的键
docker-compose exec redis redis-cli KEYS "apikey:*"
docker-compose exec redis redis-cli KEYS "claude:account:*"

# 查看键数量
docker-compose exec redis redis-cli DBSIZE

# 查看键的值
docker-compose exec redis redis-cli HGETALL "apikey:1234567890"

# 删除特定键
docker-compose exec redis redis-cli DEL "key-name"

# 清空数据库(危险!)
docker-compose exec redis redis-cli FLUSHDB
```

### 备份和恢复

```bash
# 手动触发 RDB 快照
docker-compose exec redis redis-cli SAVE
docker-compose exec redis redis-cli BGSAVE

# 导出 Redis 数据
docker cp claude-relay-redis-1:/data/dump.rdb ./redis-backup-$(date +%Y%m%d).rdb

# 恢复 Redis 数据
docker cp ./redis-backup.rdb claude-relay-redis-1:/data/dump.rdb
docker-compose restart redis
```

---

## 🌐 网络和健康检查

### 健康检查

```bash
# API 健康检查
curl http://localhost:3000/health

# 详细健康检查
curl http://localhost:3000/health | jq

# Redis 健康检查
docker-compose exec redis redis-cli ping

# 检查端口监听
sudo netstat -tlnp | grep 3000
sudo ss -tlnp | grep 3000
```

### API 测试

```bash
# 测试 API Key 信息
curl http://localhost:3000/api/v1/key-info \
  -H "x-api-key: your-api-key"

# 测试对话接口
curl -X POST http://localhost:3000/api/v1/messages \
  -H "x-api-key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# 测试流式响应
curl -N -X POST http://localhost:3000/api/v1/messages \
  -H "x-api-key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 100,
    "stream": true,
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# 获取模型列表
curl http://localhost:3000/api/v1/models \
  -H "x-api-key: your-api-key"
```

---

## 🔄 部署和更新

### 完整部署流程

```bash
# 方法一: 使用自动化脚本
./deploy.sh all

# 方法二: 手动执行
# 1. 导出数据
./deploy.sh export

# 2. 部署服务
./deploy.sh deploy

# 3. 导入数据
./deploy.sh import production-backup.json

# 4. 查看状态
./deploy.sh status
```

### 服务更新

```bash
# 拉取最新镜像
docker-compose pull

# 重新创建容器
docker-compose up -d

# 查看更新后的日志
docker-compose logs -f claude-relay

# 验证更新
curl http://localhost:3000/health
docker-compose exec claude-relay npm run cli status
```

### 配置更新

```bash
# 修改 .env 文件
nano .env

# 重启服务应用新配置
docker-compose restart

# 或完全重建
docker-compose down
docker-compose up -d

# 验证新配置
docker-compose exec claude-relay env | grep YOUR_VAR
```

---

## 🛡️ 备份和恢复

### 应用数据备份

```bash
# 导出完整数据
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js export \
  --output=/app/data/backup-$(date +%Y%m%d).json

# 从容器复制备份文件
docker cp claude-relay-claude-relay-1:/app/data/backup-*.json ./backups/

# 使用部署脚本
./deploy.sh export
```

### Redis 数据备份

```bash
# 触发 Redis 保存
docker-compose exec redis redis-cli BGSAVE

# 等待保存完成
docker-compose exec redis redis-cli LASTSAVE

# 导出 RDB 文件
docker cp claude-relay-redis-1:/data/dump.rdb ./redis-backup-$(date +%Y%m%d).rdb

# 备份 AOF 文件(如果启用)
docker cp claude-relay-redis-1:/data/appendonly.aof ./redis-aof-backup.aof
```

### 完整系统备份

```bash
# 创建备份目录
mkdir -p ~/claude-relay-backups/$(date +%Y%m%d)

# 备份应用数据
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js export \
  --output=/app/data/backup-$(date +%Y%m%d).json
docker cp claude-relay-claude-relay-1:/app/data/backup-*.json ~/claude-relay-backups/$(date +%Y%m%d)/

# 备份 Redis
docker-compose exec redis redis-cli BGSAVE
docker cp claude-relay-redis-1:/data/dump.rdb ~/claude-relay-backups/$(date +%Y%m%d)/

# 备份配置文件
cp .env ~/claude-relay-backups/$(date +%Y%m%d)/
cp docker-compose.yml ~/claude-relay-backups/$(date +%Y%m%d)/

# 备份日志
tar -czf ~/claude-relay-backups/$(date +%Y%m%d)/logs.tar.gz logs/
```

### 恢复操作

```bash
# 恢复应用数据
docker cp ~/claude-relay-backups/20250101/backup.json claude-relay-claude-relay-1:/app/
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js import \
  --input=/app/backup.json --force

# 恢复 Redis 数据
docker-compose down
docker cp ~/claude-relay-backups/20250101/dump.rdb claude-relay-redis-1:/data/
docker-compose up -d
```

---

## 🔍 故障排查

### 服务诊断

```bash
# 检查容器状态
docker-compose ps

# 查看容器详细信息
docker inspect claude-relay-claude-relay-1

# 检查容器资源使用
docker stats claude-relay-claude-relay-1

# 查看容器进程
docker-compose exec claude-relay ps aux

# 检查端口占用
sudo lsof -i :3000
sudo netstat -tlnp | grep 3000
```

### 日志分析

```bash
# 查找错误日志
docker-compose logs claude-relay | grep -i error

# 查找特定时间的日志
docker-compose logs --since="2025-10-21T10:00:00" claude-relay

# 统计错误数量
docker-compose logs claude-relay | grep -c "ERROR"

# 查看最近的崩溃日志
docker-compose logs --tail=500 claude-relay | grep -i "crash\|panic\|fatal"
```

### 网络诊断

```bash
# 从容器内测试外部连接
docker-compose exec claude-relay curl -I https://api.anthropic.com

# 测试 Redis 连接
docker-compose exec claude-relay nc -zv redis 6379

# 检查 DNS 解析
docker-compose exec claude-relay nslookup api.anthropic.com

# 测试代理连接(如果使用)
docker-compose exec claude-relay curl -x socks5://proxy:port https://api.anthropic.com
```

---

## 📊 监控命令

### 资源监控

```bash
# 实时资源使用
docker stats

# 特定容器资源
docker stats claude-relay-claude-relay-1

# 磁盘使用
docker-compose exec claude-relay df -h

# 内存使用
docker-compose exec claude-relay free -h

# CPU 信息
docker-compose exec claude-relay cat /proc/cpuinfo
```

### Redis 监控

```bash
# 实时监控 Redis 命令
docker-compose exec redis redis-cli MONITOR

# Redis 统计信息
docker-compose exec redis redis-cli INFO stats

# 慢查询日志
docker-compose exec redis redis-cli SLOWLOG GET 10

# 客户端连接列表
docker-compose exec redis redis-cli CLIENT LIST
```

### 启动监控工具

```bash
# 启动 Redis Commander
docker-compose --profile monitoring up -d redis-commander
# 访问: http://localhost:8081

# 启动完整监控栈
docker-compose --profile monitoring up -d
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3001
```

---

## 🧹 清理和维护

### 容器清理

```bash
# 停止所有服务
docker-compose down

# 停止并删除卷
docker-compose down -v

# 删除未使用的容器
docker container prune

# 删除未使用的镜像
docker image prune -a

# 系统清理(删除所有未使用资源)
docker system prune -a --volumes
```

### 日志清理

```bash
# 清理 Docker 容器日志
sudo sh -c "truncate -s 0 /var/lib/docker/containers/*/*-json.log"

# 清理应用日志(保留最近7天)
find logs/ -name "*.log" -mtime +7 -delete

# 清理备份文件(保留最近30天)
find ~/claude-relay-backups/ -mtime +30 -delete
```

### 数据库维护

```bash
# Redis 内存优化
docker-compose exec redis redis-cli MEMORY PURGE

# 清理过期键
docker-compose exec redis redis-cli --scan --pattern "expired:*" | xargs redis-cli DEL

# 优化 RDB 文件
docker-compose exec redis redis-cli BGSAVE
docker-compose exec redis redis-cli BGREWRITEAOF
```

---

## 🔐 安全操作

### 权限设置

```bash
# 设置 .env 文件权限
chmod 600 .env

# 设置数据目录权限
sudo chown -R 1000:1000 logs/ data/ redis_data/

# 检查文件权限
ls -la .env
ls -la logs/ data/
```

### 密钥生成

```bash
# 生成 JWT_SECRET
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"

# 生成 ENCRYPTION_KEY (必须32字节)
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# 生成随机密码
openssl rand -base64 32
```

---

## 📚 快速参考

### 部署脚本

```bash
./deploy.sh export          # 导出数据
./deploy.sh deploy          # 部署服务
./deploy.sh import [file]   # 导入数据
./deploy.sh all             # 完整部署
./deploy.sh status          # 查看状态
./deploy.sh logs            # 查看日志
./deploy.sh restart         # 重启服务
./deploy.sh stop            # 停止服务
```

### 最常用命令

```bash
# 启动
docker-compose up -d

# 停止
docker-compose down

# 日志
docker-compose logs -f claude-relay

# 进入容器
docker-compose exec claude-relay sh

# 健康检查
curl http://localhost:3000/health

# 系统状态
docker-compose exec claude-relay npm run cli status
```

---

**提示**: 将此文件加入书签,随时查阅!
