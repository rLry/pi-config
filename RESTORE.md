# pi 配置备份仓库（`~/.pi`）

本仓库用 git 备份 pi 的用户级配置与知识资产，供在不同机器 / 不同用户目录下同步使用。

- 仓库根 = `~/.pi`，托管内容实际全部位于 `~/.pi/agent`
- 远程：`git@github.com:rLry/pi-config.git`（SSH，新机器需自备 `~/.ssh` 密钥）
- **凭据不随仓库同步**：`auth.json`、`mcp-auth.json` 已被 `.gitignore` 排除

## 一、同步范围

### 入库（手工维护，值得版本化）

| 路径 | 说明 |
|---|---|
| `agent/settings.json` | 偏好、默认模型、`packages` 声明、工具开关 |
| `agent/AGENTS.md` | 全局规则（跨目录生效） |
| `agent/mcp.json` | MCP 服务器定义（令牌已改为环境变量插值） |
| `agent/AGENTS.override.md` / `SYSTEM.md` / `APPEND_SYSTEM.md` / `keybindings.json` / `models.json` / `themes/` | 存在即入库 |
| `agent/skills/**` | 11 个技能及其脚本、schema、参考资料（约 3.6 MB） |
| `agent/prompts/**` | 4 个提示词模板 |
| `agent/extensions/pi-permission-system/config.json` | 安全边界的唯一事实源 |
| `RESTORE.md` / `restore.ps1` / `.gitignore` / `.gitattributes` | 恢复文档、恢复脚本、忽略规则 |

### 忽略（附理由）

| 路径 | 理由 |
|---|---|
| `agent/auth.json`、`agent/mcp-auth.json`、`agent/trust.json` | 凭据 / 本机路径信任记录，入库即泄露 |
| `agent/sessions/` | 目录名按工作目录路径编码（`--C--Users-denote--`），跨机器无意义；含会话正文且持续膨胀 |
| `agent/models-store.json` | pi.dev 模型目录缓存，含 `etag`/`checkedAt` 本机抓取元数据，跨机器同步会互相污染；用 `pi update --models` 重建 |
| `agent/npm/**`（仅保留其自带 `.gitignore`） | 依赖目录（32 MB），由 `pi update --extensions` 依据 `settings.json` 重建 |
| `agent/extensions/**/logs/`、`*.log`、`pi-debug.log` | 运行日志与调试输出 |
| `**/node_modules/`、`**/__pycache__/`、`*.py[cod]`、`**/.venv/` | 依赖与字节码 |
| `.DS_Store`、`Thumbs.db`、`desktop.ini`、`*.swp` | 系统 / 编辑器噪音 |

## 二、新机器恢复

前置：已安装 pi（`scoop install pi-coding-agent` 或 `npm i -g @earendil-works/pi`）与 git；若 `~/.pi` 已存在，`restore.ps1` 会先把旧目录改名为 `.bak-<时间戳>` 而**不删除**。

```powershell
# 1. 克隆（脚本同时校验必需文件、提示登录、重装扩展）
.\restore.ps1 -RepoUrl git@github.com:rLry/pi-config.git -Force

# 或手工执行等价步骤
git clone git@github.com:rLry/pi-config.git "$env:USERPROFILE\.pi"
```

```powershell
# 2. 凭据：auth.json 不在仓库中，需在本机重新登录
pi          # 进入交互后执行 /login，选择 provider 并完成认证

# 3. 重装扩展（依据 settings.json 的 packages 声明）
pi update --extensions

# 4. 刷新模型目录缓存（models-store.json 未同步）
pi update --models
```

```powershell
# 5. 可选：PP-OCRv6 MCP 的令牌以环境变量提供（该 server 默认 enabled=false）
[Environment]::SetEnvironmentVariable('PADDLEOCR_MCP_AISTUDIO_ACCESS_TOKEN', '<你的令牌>', 'User')
```

恢复后自检：

```powershell
Test-Path "$env:USERPROFILE\.pi\agent\settings.json"   # True
Test-Path "$env:USERPROFILE\.pi\agent\auth.json"       # 应为 True（本机新登录产生）
Test-Path "$env:USERPROFILE\.pi\agent\sessions"        # 应为 False（不同步，首次运行后自动生成）
pi list                                                # 三个扩展均应已安装
```

## 三、日常同步

```powershell
cd "$env:USERPROFILE\.pi"
git status
git add -A                 # 或 git add agent/skills 等具体路径
git commit -m "更新技能/设置"
git pull --rebase
git push
```

## 四、注意事项

1. **`settings.json` 中的 `shellPath`**：当前为 `~/scoop/apps/git/current/bin/bash.exe`，是唯一机器相关字段。另一台机器若 bash 位置不同，需本地修改；`~` 会展开为各机自己的家目录。
2. **SSH 密钥不在仓库内**（`~/.ssh` 属禁止读取区），新机器必须自行配置 GitHub SSH key，否则无法 `push` / `clone`。
3. **`mcp.json` 的令牌占位符**：值为 `$PADDLEOCR_MCP_AISTUDIO_ACCESS_TOKEN`，pi 支持 `$NAME` / `${NAME}` 环境变量插值。该 server 默认关闭，未设环境变量不影响使用。
4. **`models-store.json` 与 `sessions/` 不同步**：前者可重建，后者属本机过程数据。若确实需要跨机续聊历史，可单独放宽 `.gitignore`（须自行承担体积与路径不匹配问题）。
5. **切勿提交凭据**：提交前用 `git status` 复核；若误提交，需改写历史（`git filter-repo`）并在 provider 侧吊销密钥。
6. 仓库级 git 配置已设：`core.autocrlf=false`、`core.longpaths=true`、`core.quotepath=false`、`core.symlinks=false`；`.gitattributes` 用 `* -text` 禁止行尾转换，保证跨平台内容一致。
