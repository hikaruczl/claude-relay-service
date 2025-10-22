# 🚀 快速部署指南

## 一、本地准备 (5分钟)

### 1. 导出当前数据

```bash
# 方法一: 使用部署脚本 (推荐)
./deploy.sh export

# 方法二: 手动导出
node scripts/data-transfer-enhanced.js export --output=production-backup.json
```

导出的文件会包含:
- ✅ 所有 API Keys 及使用统计
- ✅ Claude 和 Gemini 账户配置
- ✅ 管理员账户
- ✅ 敏感数据已自动解密(方便迁移)

### 2. 准备文件清单

确认以下文件已准备好:
```bash
production-backup-YYYYMMDD-HHMMSS.json  # 数据备份
.env.production                         # 环境变量模板
docker-compose.yml                      # Docker 配置
deploy.sh                               # 部署脚本
```

---

## 二、服务器部署 (10分钟)

### 方法 A: 使用自动化脚本 (最简单)

```bash
# 1. 上传项目到服务器
scp -r /path/to/claude-relay-service user@your-server:/opt/

# 2. SSH 登录服务器
ssh user@your-server

# 3. 执行完整部署
cd /opt/claude-relay-service
./deploy.sh all
```

✅ 脚本会自动完成: 环境检查 → 服务部署 → 数据导入 → 健康检查

---

### 方法 B: 手动部署 (更可控)

#### 步骤 1: 上传文件到服务器

```bash
# 创建目录
ssh user@your-server "mkdir -p /opt/claude-relay"

# 上传必要文件
scp docker-compose.yml user@your-server:/opt/claude-relay/
scp .env.production user@your-server:/opt/claude-relay/.env
scp production-backup-*.json user@your-server:/opt/claude-relay/
```

#### 步骤 2: 配置环境变量

```bash
# SSH 登录服务器
ssh user@your-server
cd /opt/claude-relay

# 编辑 .env 文件
nano .env
```

**必须修改的配置:**
```bash
# 生成新的密钥
JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(64).toString('hex'))")
ENCRYPTION_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

# 如果使用相同的 ENCRYPTION_KEY,可以直接从本地复制
# 这样可以避免重新加密数据
```

⚠️ **重要提示:**
- 如果想保持数据加密兼容,请使用**相同的 ENCRYPTION_KEY**
- 或者导出时使用 `--decrypt=false` 保持加密状态

#### 步骤 3: 启动服务

```bash
# 拉取镜像并启动
docker-compose pull
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f claude-relay
```

#### 步骤 4: 导入数据

```bash
# 上传备份到容器
docker cp production-backup-*.json claude-relay-claude-relay-1:/app/backup.json

# 导入数据
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js import \
  --input=/app/backup.json \
  --force

# 验证导入
docker-compose exec claude-relay npm run cli status
```

---

## 三、验证和测试 (5分钟)

### 1. 健康检查

```bash
# 方法一: 使用脚本
./deploy.sh status

# 方法二: 手动检查
curl http://localhost:3000/health
```

预期返回:
```json
{
  "status": "ok",
  "timestamp": "2025-10-21T...",
  "uptime": 123
}
```

### 2. 访问 Web 界面

```bash
# 浏览器访问
http://your-server-ip:3000/web

# 使用导入的管理员账户登录
```

### 3. 测试 API 调用

```bash
# 获取 API Key 信息
curl http://your-server-ip:3000/api/v1/key-info \
  -H "x-api-key: your-imported-api-key"

# 测试对话
curl -X POST http://your-server-ip:3000/api/v1/messages \
  -H "x-api-key: your-imported-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### 4. 检查数据完整性

```bash
# 进入容器
docker-compose exec claude-relay sh

# 使用 CLI 工具验证
npm run cli status           # 系统状态
npm run cli keys list        # API Keys 列表
npm run cli accounts list    # 账户列表
```

---

## 四、常用运维命令

### 日常管理

```bash
# 查看日志
./deploy.sh logs
# 或
docker-compose logs -f claude-relay

# 查看状态
./deploy.sh status

# 重启服务
./deploy.sh restart

# 停止服务
./deploy.sh stop
```

### 数据备份

```bash
# 定期备份数据
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js export \
  --output=/app/data/backup-$(date +%Y%m%d).json

# 备份 Redis 数据
docker-compose exec redis redis-cli SAVE
docker cp claude-relay-redis-1:/data/dump.rdb ./redis-backup.rdb
```

### 更新服务

```bash
# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose up -d

# 查看更新日志
docker-compose logs -f claude-relay
```

---

## 五、故障排查

### 问题 1: 服务无法启动

```bash
# 检查端口占用
sudo netstat -tlnp | grep 3000

# 检查 Docker 状态
docker-compose ps
docker-compose logs claude-relay

# 重新启动
docker-compose down
docker-compose up -d
```

### 问题 2: 数据导入失败

```bash
# 检查 ENCRYPTION_KEY 是否一致
# 如果不一致,需要使用相同的密钥或导出时使用 --decrypt=false

# 查看详细错误
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js import \
  --input=/app/backup.json
```

### 问题 3: Redis 连接失败

```bash
# 检查 Redis 状态
docker-compose ps redis
docker-compose logs redis

# 测试连接
docker-compose exec redis redis-cli ping

# 检查环境变量
docker-compose exec claude-relay env | grep REDIS
```

### 问题 4: API 调用失败

```bash
# 检查 API Key 是否正确导入
docker-compose exec claude-relay npm run cli keys list

# 查看实时日志
docker-compose logs -f claude-relay

# 检查账户状态
docker-compose exec claude-relay npm run cli accounts list
```

---

## 六、安全建议

### 1. 使用反向代理

推荐使用 Nginx 或 Caddy:

```nginx
# /etc/nginx/sites-available/claude-relay
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

        # 流式响应支持
        proxy_buffering off;
        proxy_read_timeout 600s;
    }
}
```

### 2. 配置 HTTPS

```bash
# 使用 Certbot 申请免费证书
sudo certbot --nginx -d your-domain.com
```

### 3. 防火墙配置

```bash
# 只允许必要端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw enable
```

### 4. 定期备份

添加到 crontab:
```bash
# 每天凌晨 2 点备份
0 2 * * * cd /opt/claude-relay && docker-compose exec -T claude-relay node scripts/data-transfer-enhanced.js export --output=/app/data/auto-backup-$(date +\%Y\%m\%d).json
```

---

## 七、时间估算

| 步骤 | 预计时间 |
|------|---------|
| 本地数据导出 | 1-2 分钟 |
| 文件上传到服务器 | 1-3 分钟 |
| 服务器环境配置 | 3-5 分钟 |
| Docker 拉取镜像 | 2-5 分钟 |
| 服务启动 | 1-2 分钟 |
| 数据导入 | 1-3 分钟 |
| 验证测试 | 2-5 分钟 |
| **总计** | **15-25 分钟** |

---

## 八、快速命令速查表

```bash
# === 部署脚本 ===
./deploy.sh export          # 导出数据
./deploy.sh deploy          # 部署服务
./deploy.sh import          # 导入数据
./deploy.sh all             # 完整流程
./deploy.sh status          # 查看状态
./deploy.sh logs            # 查看日志

# === Docker Compose ===
docker-compose up -d        # 启动服务
docker-compose down         # 停止服务
docker-compose restart      # 重启服务
docker-compose ps           # 查看状态
docker-compose logs -f      # 查看日志

# === 数据操作 ===
node scripts/data-transfer-enhanced.js export   # 导出
node scripts/data-transfer-enhanced.js import   # 导入

# === 容器操作 ===
docker-compose exec claude-relay sh             # 进入容器
docker-compose exec claude-relay npm run cli status  # CLI 状态

# === 健康检查 ===
curl http://localhost:3000/health               # 服务健康
docker-compose exec redis redis-cli ping        # Redis 健康
```

---

## 🎉 完成!

部署完成后,你的服务应该已经:
- ✅ 在生产服务器上运行
- ✅ 所有数据已成功迁移
- ✅ API 服务正常响应
- ✅ Web 界面可以访问

如有问题,请查看:
- 📖 完整文档: `DEPLOYMENT.md`
- 🐛 故障排查: 本文档第五节
- 📝 项目文档: `README.md` 和 `CLAUDE.md`
