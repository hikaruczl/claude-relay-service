# ✅ 部署检查清单

使用此清单确保部署过程顺利完成。

---

## 📦 部署前准备

### 本地环境检查

- [ ] Node.js 已安装 (v14+)
- [ ] 本地服务正常运行
- [ ] Redis 数据库有数据
- [ ] 已配置至少一个 Claude/Gemini 账户
- [ ] 已创建至少一个 API Key
- [ ] Web 管理界面可以访问

### 数据导出

- [ ] 执行数据导出命令
  ```bash
  ./deploy.sh export
  # 或
  node scripts/data-transfer-enhanced.js export --output=production-backup.json
  ```
- [ ] 确认导出文件存在且大小合理 (>1KB)
- [ ] 备份文件已保存到安全位置
- [ ] (可选) 导出加密备份用于存档

### 文件准备

- [ ] `production-backup-*.json` - 数据备份文件
- [ ] `.env.production` - 生产环境配置模板
- [ ] `docker-compose.yml` - Docker 配置
- [ ] `deploy.sh` - 部署脚本 (已添加执行权限)

---

## 🖥️ 服务器环境准备

### 系统要求

- [ ] Linux 服务器 (Ubuntu 20.04+ / Debian 11+ / CentOS 8+)
- [ ] 最低配置: 2核 CPU, 2GB RAM, 20GB 磁盘
- [ ] 推荐配置: 4核 CPU, 4GB RAM, 50GB 磁盘
- [ ] 端口 3000 未被占用 (或修改配置)

### 软件安装

- [ ] Docker 已安装
  ```bash
  docker --version
  ```
- [ ] Docker Compose 已安装
  ```bash
  docker-compose --version
  ```
- [ ] (可选) Nginx/Caddy 反向代理已配置

### 网络配置

- [ ] 防火墙已配置 (允许必要端口)
- [ ] (可选) 域名已解析到服务器
- [ ] (可选) SSL 证书已配置

---

## 🚀 部署执行

### 上传文件

- [ ] 项目文件已上传到服务器
  ```bash
  scp -r /path/to/project user@server:/opt/claude-relay/
  ```
- [ ] 备份文件已上传
- [ ] 文件权限正确

### 环境配置

- [ ] 复制 `.env.production` 到 `.env`
- [ ] 修改 `JWT_SECRET` (必须修改!)
- [ ] 修改 `ENCRYPTION_KEY` (必须修改!)
  - ⚠️ 如果使用本地相同的密钥,可直接复制
  - ⚠️ 如果使用新密钥,导入时会自动重新加密
- [ ] 配置 Redis 连接信息
- [ ] 配置其他必要参数

### 服务启动

- [ ] 拉取 Docker 镜像
  ```bash
  docker-compose pull
  ```
- [ ] 启动服务
  ```bash
  docker-compose up -d
  ```
- [ ] 检查容器状态
  ```bash
  docker-compose ps
  ```
- [ ] 查看启动日志
  ```bash
  docker-compose logs claude-relay
  ```

---

## 📥 数据导入

### 导入准备

- [ ] 服务已成功启动
- [ ] 备份文件已上传到容器
  ```bash
  docker cp backup.json container_name:/app/backup.json
  ```

### 执行导入

- [ ] 运行导入命令
  ```bash
  docker-compose exec claude-relay node scripts/data-transfer-enhanced.js import \
    --input=/app/backup.json --force
  ```
- [ ] 确认导入成功 (无错误提示)
- [ ] 检查导入统计信息

### 导入验证

- [ ] 验证 API Keys 数量
  ```bash
  docker-compose exec claude-relay npm run cli keys list
  ```
- [ ] 验证账户数量
  ```bash
  docker-compose exec claude-relay npm run cli accounts list
  ```
- [ ] 验证管理员账户
  ```bash
  docker-compose exec claude-relay npm run cli status
  ```

---

## ✅ 功能测试

### 健康检查

- [ ] API 健康检查通过
  ```bash
  curl http://localhost:3000/health
  ```
- [ ] Redis 连接正常
  ```bash
  docker-compose exec redis redis-cli ping
  ```

### Web 界面测试

- [ ] 可以访问 `http://server-ip:3000/web`
- [ ] 管理员登录成功
- [ ] 仪表板数据显示正常
- [ ] API Keys 列表显示正确
- [ ] 账户列表显示正确

### API 功能测试

- [ ] 获取 API Key 信息成功
  ```bash
  curl http://localhost:3000/api/v1/key-info \
    -H "x-api-key: your-key"
  ```
- [ ] 测试对话接口成功
  ```bash
  curl -X POST http://localhost:3000/api/v1/messages \
    -H "x-api-key: your-key" \
    -H "Content-Type: application/json" \
    -d '{"model":"claude-sonnet-4-20250514","max_tokens":100,"messages":[{"role":"user","content":"Hello"}]}'
  ```
- [ ] 流式响应正常 (如果使用)

---

## 🔒 安全检查

### 配置安全

- [ ] `JWT_SECRET` 已设置为强随机值
- [ ] `ENCRYPTION_KEY` 已设置为 32 字符随机值
- [ ] (推荐) Redis 已设置密码
- [ ] 备份文件已从服务器删除或移到安全位置
- [ ] `.env` 文件权限设置为 600
  ```bash
  chmod 600 .env
  ```

### 网络安全

- [ ] (推荐) 使用 Nginx/Caddy 反向代理
- [ ] (推荐) 配置 HTTPS
- [ ] (推荐) 配置防火墙规则
- [ ] 不必要的端口已关闭

---

## 📊 监控和运维

### 日志配置

- [ ] 日志正常输出
  ```bash
  docker-compose logs -f claude-relay
  ```
- [ ] 日志文件正常创建 (`logs/` 目录)
- [ ] 日志轮转配置正确

### 备份计划

- [ ] 配置自动备份脚本
- [ ] 测试备份脚本执行成功
- [ ] 设置 crontab 定时任务
- [ ] (推荐) 备份到远程存储

### 监控工具 (可选)

- [ ] (可选) Redis Commander 可访问
  ```bash
  docker-compose --profile monitoring up -d redis-commander
  # 访问 http://server-ip:8081
  ```
- [ ] (可选) Prometheus 已配置
- [ ] (可选) Grafana 已配置

---

## 📝 文档和记录

### 部署记录

- [ ] 记录服务器 IP/域名: `_______________`
- [ ] 记录管理员账户: `_______________`
- [ ] 记录部署时间: `_______________`
- [ ] 记录服务版本: `_______________`

### 配置备份

- [ ] `.env` 文件已备份到安全位置
- [ ] `docker-compose.yml` 已备份
- [ ] 管理员密码已记录到密码管理器

### 运维文档

- [ ] 团队成员已了解服务地址
- [ ] 运维文档已分享给相关人员
- [ ] 故障联系人已确定

---

## 🎯 最终验证

### 端到端测试

- [ ] 从客户端 (SillyTavern/Claude Code 等) 连接成功
- [ ] 完整对话流程测试通过
- [ ] 使用统计正常记录
- [ ] 多个 API Key 可以正常使用
- [ ] 账户切换功能正常

### 性能测试

- [ ] 响应时间正常 (<2s)
- [ ] 内存使用正常 (<500MB)
- [ ] CPU 使用正常 (<50%)
- [ ] 并发请求测试通过

### 故障恢复测试

- [ ] 服务重启后正常运行
  ```bash
  docker-compose restart
  ```
- [ ] Redis 重启后数据完整
- [ ] 容器删除重建后服务正常
  ```bash
  docker-compose down && docker-compose up -d
  ```

---

## ✨ 部署完成

所有检查项通过后,部署即完成!

### 下一步建议

1. **性能优化**: 根据实际使用情况调整配置
2. **监控告警**: 配置监控和告警通知
3. **定期维护**: 设置定期备份和更新计划
4. **文档更新**: 记录任何自定义配置和变更

### 常用命令

```bash
# 查看服务状态
./deploy.sh status

# 查看日志
./deploy.sh logs

# 重启服务
./deploy.sh restart

# 备份数据
docker-compose exec claude-relay node scripts/data-transfer-enhanced.js export \
  --output=/app/data/backup-$(date +%Y%m%d).json
```

---

**部署日期**: _______________
**部署人员**: _______________
**审核人员**: _______________

🎉 **恭喜!服务已成功部署到生产环境!**
