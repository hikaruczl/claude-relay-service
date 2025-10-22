# 🚀 生产环境部署指南

## 📋 目录

1. [前期准备](#前期准备)
2. [导出本地数据](#导出本地数据)
3. [服务器环境配置](#服务器环境配置)
4. [部署服务](#部署服务)
5. [导入数据](#导入数据)
6. [验证和测试](#验证和测试)
7. [常见问题](#常见问题)

---

## 前期准备

### 1. 本地数据备份

在开始部署前,请先导出本地所有数据:

```bash
# 导出完整数据(包括账户、API Keys、使用统计、管理员)
node scripts/data-transfer-enhanced.js export --output=production-backup.json

# 导出的文件会包含:
# - 所有 API Keys 及其使用统计
# - Claude 和 Gemini 账户配置
# - 管理员账户
# - 全局统计数据
```

**重要提示:**
- 默认会自动解密敏感数据,方便跨环境迁移
- 备份文件包含明文密码和 token,请妥善保管
- 建议同时导出两份:一份解密(用于迁移),一份加密(用于备份)

```bash
# 导出加密备份(用于本地存档)
node scripts/data-transfer-enhanced.js export --output=encrypted-backup.json --decrypt=false
```

### 2. 检查必要文件

确保以下文件已准备好:
- `production-backup.json` - 数据备份文件
- `.env.example` - 环境变量模板
- `docker-compose.yml` - Docker 配置文件
- `Dockerfile` - Docker 镜像配置

---

## 导出本地数据

### 完整导出命令

```bash
# 进入项目目录
cd /mnt/vdb/dev/claude-relay-service

# 导出所有数据(默认自动解密,适合迁移)
node scripts/data-transfer-enhanced.js export --output=production-backup.json

# 查看导出结果
ls -lh production-backup.json
```

### 导出选项说明

```bash
# 仅导出 API Keys
node scripts/data-transfer-enhanced.js export --types=apikeys --output=apikeys-only.json

# 仅导出账户配置
node scripts/data-transfer-enhanced.js export --types=accounts --output=accounts-only.json

# 导出并脱敏(不推荐用于生产迁移)
node scripts/data-transfer-enhanced.js export --sanitize --output=sanitized.json
```

### 验证导出文件

```bash
# 检查文件大小
ls -lh production-backup.json

# 查看文件内容摘要
head -n 20 production-backup.json
```

---

## 服务器环境配置

### 方案一: Docker 部署 (推荐)

#### 1. 安装 Docker 和 Docker Compose

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker

# 安装 Docker Compose
sudo apt-get install docker-compose-plugin
```

#### 2. 上传文件到服务器

```bash
# 在本地执行,上传必要文件
scp production-backup.json user@your-server:/opt/claude-relay/
scp docker-compose.yml user@your-server:/opt/claude-relay/
scp .env.example user@your-server:/opt/claude-relay/.env

# 或使用 rsync 上传整个项目
rsync -avz --exclude 'node_modules' --exclude 'logs' \
  . user@your-server:/opt/claude-relay/
```

#### 3. 配置生产环境变量

```bash
# 登录服务器
ssh user@your-server
cd /opt/claude-relay

# 编辑 .env 文件
nano .env
```

**必须修改的配置项:**

```bash
# 🔐 安全配置 (必须更改!)
JWT_SECRET=your-production-jwt-secret-min-32-chars-long
ENCRYPTION_KEY=your-32-character-encryption-key

# 📊 Redis 配置
REDIS_HOST=redis  # Docker 内部使用 redis
REDIS_PORT=6379
REDIS_PASSWORD=  # 生产环境建议设置强密码
REDIS_DB=0

# 🌐 服务器配置
PORT=3000
HOST=0.0.0.0
NODE_ENV=production

# 🌐 代理配置(根据账户需要)
DEFAULT_PROXY_TIMEOUT=600000
MAX_PROXY_RETRIES=3

# 🎯 Claude API 配置
CLAUDE_API_URL=https://api.anthropic.com/v1/messages
CLAUDE_API_VERSION=2023-06-01
```

**重要安全建议:**
1. `JWT_SECRET` 和 `ENCRYPTION_KEY` 必须使用强随机字符串
2. 生产环境建议为 Redis 设置密码
3. 如果使用反向代理,设置 `TRUST_PROXY=true`

#### 4. 生成新的密钥 (可选)

```bash
# 如果需要生成新的密钥
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

---

## 部署服务

### Docker 部署步骤

#### 1. 启动服务

```bash
cd /opt/claude-relay

# 拉取最新镜像
docker-compose pull

# 启动服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f claude-relay
```

#### 2. 验证服务运行

```bash
# 检查健康状态
curl http://localhost:3000/health

# 预期返回:
# {"status":"ok","timestamp":"...","uptime":...}
```

#### 3. 查看容器日志

```bash
# 实时查看日志
docker-compose logs -f claude-relay

# 查看最近 100 行日志
docker-compose logs --tail=100 claude-relay

# 查看 Redis 日志
docker-compose logs -f redis
```

---

## 导入数据

### 1. 上传备份文件到容器

```bash
# 方法一: 使用 docker cp
docker cp production-backup.json claude-relay-claude-relay-1:/app/production-backup.json

# 方法二: 如果已经上传到主机,使用 volume 映射
# 确保 docker-compose.yml 中有 volume 映射:
# volumes:
#   - ./data:/app/data
cp production-backup.json ./data/
```

### 2. 进入容器执行导入

```bash
# 进入容器
docker-compose exec claude-relay sh

# 在容器内执行导入
node scripts/data-transfer-enhanced.js import --input=production-backup.json --force

# 或者直接在主机执行
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js import \
  --input=/app/production-backup.json --force
```

### 3. 导入选项说明

```bash
# 强制覆盖已存在的数据
--force

# 跳过冲突数据,只导入新数据
--skip-conflicts

# 交互式确认每个冲突(默认)
# 不加任何参数
```

### 4. 验证数据导入

```bash
# 进入容器
docker-compose exec claude-relay sh

# 使用 CLI 工具检查
npm run cli status

# 查看 API Keys
npm run cli keys list

# 查看 Claude 账户
npm run cli accounts list
```

---

## 验证和测试

### 1. 访问 Web 管理界面

```bash
# 浏览器访问
http://your-server-ip:3000/web

# 使用导入的管理员账户登录
```

### 2. 测试 API 端点

```bash
# 测试健康检查
curl http://your-server-ip:3000/health

# 测试 API Key 认证
curl -X POST http://your-server-ip:3000/api/v1/messages \
  -H "x-api-key: your-imported-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### 3. 检查日志

```bash
# 查看应用日志
docker-compose logs -f claude-relay

# 查看主机上的日志文件
tail -f logs/claude-relay-*.log
```

### 4. 监控 Redis 数据

```bash
# 启动 Redis Commander (可选)
docker-compose --profile monitoring up -d redis-commander

# 访问 http://your-server-ip:8081 查看 Redis 数据
```

---

## 常见问题

### 1. 导入数据时提示"已存在"

**解决方案:**

```bash
# 使用强制覆盖
node scripts/data-transfer-enhanced.js import --input=backup.json --force

# 或者跳过冲突
node scripts/data-transfer-enhanced.js import --input=backup.json --skip-conflicts
```

### 2. ENCRYPTION_KEY 不匹配导致解密失败

**原因:** 生产环境的 `ENCRYPTION_KEY` 与本地不同

**解决方案:**

```bash
# 选项 1: 使用相同的 ENCRYPTION_KEY
# 将本地的 ENCRYPTION_KEY 复制到生产环境的 .env 文件

# 选项 2: 导出时不解密,保持加密状态
node scripts/data-transfer-enhanced.js export --output=encrypted.json --decrypt=false
```

### 3. Redis 连接失败

**检查步骤:**

```bash
# 检查 Redis 容器状态
docker-compose ps redis

# 检查 Redis 日志
docker-compose logs redis

# 测试 Redis 连接
docker-compose exec redis redis-cli ping
# 应返回: PONG

# 检查环境变量
docker-compose exec claude-relay env | grep REDIS
```

### 4. 端口冲突

**解决方案:**

```bash
# 修改 docker-compose.yml 中的端口映射
ports:
  - "8080:3000"  # 使用 8080 端口

# 或修改 .env 文件
PORT=8080
```

### 5. 权限问题

```bash
# 确保数据目录权限正确
sudo chown -R 1000:1000 ./logs ./data ./redis_data

# 或使用当前用户
sudo chown -R $(id -u):$(id -g) ./logs ./data ./redis_data
```

### 6. 使用反向代理 (Nginx/Caddy)

**Nginx 配置示例:**

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # 支持流式响应
        proxy_buffering off;
        proxy_read_timeout 600s;
    }
}
```

**Caddy 配置示例:**

```caddy
your-domain.com {
    reverse_proxy localhost:3000
}
```

---

## 生产环境最佳实践

### 1. 定期备份

```bash
# 创建自动备份脚本
cat > /opt/claude-relay/backup.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/opt/claude-relay/backups"
mkdir -p $BACKUP_DIR

docker-compose exec -T claude-relay node scripts/data-transfer-enhanced.js export \
  --output=/app/data/backup-$DATE.json

# 保留最近 30 天的备份
find $BACKUP_DIR -name "backup-*.json" -mtime +30 -delete
EOF

chmod +x /opt/claude-relay/backup.sh

# 添加到 crontab (每天凌晨 2 点执行)
crontab -e
0 2 * * * /opt/claude-relay/backup.sh
```

### 2. 日志轮转

```bash
# Docker 已自动处理日志轮转,但可以配置主机上的日志
cat > /etc/logrotate.d/claude-relay <<EOF
/opt/claude-relay/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 1000 1000
}
EOF
```

### 3. 监控和告警

```bash
# 启动完整监控栈
docker-compose --profile monitoring up -d

# 访问:
# - Prometheus: http://your-server:9090
# - Grafana: http://your-server:3001 (admin/admin123)
# - Redis Commander: http://your-server:8081
```

### 4. 更新服务

```bash
# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose up -d

# 查看新版本日志
docker-compose logs -f claude-relay
```

---

## 快速命令参考

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f claude-relay

# 进入容器
docker-compose exec claude-relay sh

# 导出数据
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js export

# 导入数据
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js import --input=backup.json

# 查看状态
docker-compose exec claude-relay npm run cli status

# 备份 Redis 数据
docker-compose exec redis redis-cli SAVE
docker cp claude-relay-redis-1:/data/dump.rdb ./redis-backup-$(date +%Y%m%d).rdb
```

---

## 技术支持

如果遇到问题,请:
1. 查看日志: `docker-compose logs -f claude-relay`
2. 检查健康状态: `curl http://localhost:3000/health`
3. 查看项目 Issues: https://github.com/your-repo/issues
4. 参考项目文档: `README.md` 和 `CLAUDE.md`
