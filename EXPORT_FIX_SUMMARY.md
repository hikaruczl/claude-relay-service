# 导出脚本修复说明

## 问题描述
运行导出脚本后，只导出了少数账号（1个Gemini账户），大部分Claude账户（4个）没有被导出。

## 根本原因
导出脚本 `scripts/data-transfer.js` 中使用了错误的Redis键前缀：
- 脚本使用 `claude:account:*` 来查找Claude账户
- 但实际系统中使用的是 `claude_console_account:*` 前缀

此外，系统中还存在其他账户类型未被导出：
- OpenAI Responses 账户 (`openai_responses_account:*`)

## 修复内容

### 1. 添加 Claude Console 账户导出支持
- 导出部分：添加对 `claude_console_account:*` 键的扫描和导出
- 导入部分：添加 Claude Console 账户的导入逻辑
- 更新导出/导入摘要显示

### 2. 添加 OpenAI Responses 账户导出支持
- 导出部分：添加对 `openai_responses_account:*` 键的扫描和导出
- 导入部分：添加 OpenAI Responses 账户的导入逻辑
- 更新导出/导入摘要显示

### 3. 修复导入部分的键前缀
- Claude OAuth 账户：使用 `claude:account:` 前缀（保持不变）
- Claude Console 账户：使用 `claude_console_account:` 前缀

## 修复后的导出结果

```
============================================================
✅ Export Complete!
============================================================
Output file: production-backup-final.json
File size: 11791 bytes
API Keys: 2
Claude OAuth Accounts: 0
Claude Console Accounts: 4      ← 修复前为 0
Gemini Accounts: 1
OpenAI Responses Accounts: 2     ← 新增支持
Admins: 0
============================================================
```

## 使用说明

### 导出所有数据
```bash
node scripts/data-transfer.js export --output=backup.json
```

### 导出特定类型数据
```bash
node scripts/data-transfer.js export --types=accounts --output=accounts-backup.json
```

### 导入数据
```bash
node scripts/data-transfer.js import --input=backup.json
```

## 系统中的账户类型

1. **Claude OAuth 账户** (`claude:account:*`)
   - 通过 OAuth 2.0 PKCE 流程创建
   - 存储加密的 access token 和 refresh token

2. **Claude Console 账户** (`claude_console_account:*`)
   - 通过 Claude Console API Key 创建
   - 包含配额管理和限流设置

3. **Gemini 账户** (`gemini_account:*`)
   - Google Gemini API 账户
   - 支持 OAuth token 刷新

4. **OpenAI Responses 账户** (`openai_responses_account:*`)
   - OpenAI API 账户
   - 用于 OpenAI 服务转发

## 文件变更
- `scripts/data-transfer.js` - 数据导出/导入脚本（已修复并格式化）
