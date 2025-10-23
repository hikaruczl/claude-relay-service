# 数据导入说明

## 📌 核心结论

**❌ 不能直接用现有备份在线上旧代码导入！**

**✅ 必须先更新 `scripts/data-transfer.js` 再导入！**

## 🔍 问题原因

1. **线上旧代码的bug**: 导入时使用错误的键前缀 `claude_account:*`
2. **实际系统使用**: `claude_console_account:*` 和 `openai_responses_account:*`
3. **新备份格式**: 包含旧代码不认识的字段

### 如果强行用旧代码导入会发生什么？

```
❌ 4个Claude Console账户 → 丢失（字段名不匹配）
❌ 2个OpenAI Responses账户 → 丢失（字段名不匹配）
✅ 2个API Keys → 正常导入
✅ 1个Gemini账户 → 正常导入

结果：丢失 6/7 的账户数据！
```

## ✅ 正确的操作流程

### 方案：先更新脚本，再导入数据

```bash
# 1. 上传修复后的脚本和备份到线上
scp scripts/data-transfer.js user@server:/path/to/project/scripts/
scp production-backup-final.json user@server:/path/to/project/

# 2. SSH登录执行导入
ssh user@server
cd /path/to/project
node scripts/data-transfer.js import \
  --input=production-backup-final.json \
  --skip-conflicts

# 3. 验证结果
# 应该看到：
# - API Keys: 2
# - Claude Console Accounts: 4
# - Gemini Accounts: 1
# - OpenAI Responses Accounts: 2
```

## 📁 文件清单

### 需要上传到线上的文件：

1. **scripts/data-transfer.js** （必须）
   - 修复后的导入脚本
   - 支持所有账户类型
   - 使用正确的键前缀

2. **production-backup-final.json** （必须）
   - 完整的备份数据
   - 包含所有7个账户

### 参考文档：

1. **DEPLOYMENT_GUIDE.md** - 详细部署步骤
2. **IMPORT_COMPATIBILITY_ANALYSIS.md** - 兼容性分析
3. **EXPORT_FIX_SUMMARY.md** - 导出脚本修复说明

## ⚠️ 风险提示

如果使用旧代码导入新备份：
- 数据不会报错，但会**静默失败**
- 只有 API Keys 和 Gemini 账户会被导入
- Claude 和 OpenAI 账户会**完全丢失**
- 系统会显示"没有可用账户"

## 🔧 技术细节

### 键前缀对照表

| 账户类型 | 旧代码使用 | 实际应该用 | 状态 |
|---------|-----------|-----------|------|
| Claude Console | `claude_account:*` ❌ | `claude_console_account:*` | 已修复 |
| OpenAI Responses | 不支持 ❌ | `openai_responses_account:*` | 已添加 |
| Gemini | `gemini_account:*` ✅ | `gemini_account:*` | 正常 |
| API Keys | `apikey:*` ✅ | `apikey:*` | 正常 |

## 📞 如有问题

查看详细文档：
- 部署步骤: `DEPLOYMENT_GUIDE.md`
- 兼容性分析: `IMPORT_COMPATIBILITY_ANALYSIS.md`
- 修复说明: `EXPORT_FIX_SUMMARY.md`
