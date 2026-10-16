<#
.SYNOPSIS
    从 git 备份恢复 ~/.pi（pi 用户级配置、技能、提示词、扩展声明）。

.DESCRIPTION
    幂等脚本：
      - 目标目录已是本仓库 -> git pull --ff-only
      - 目标目录不存在     -> git clone
      - 目标目录存在但非仓库 -> 仅在 -Force 下把旧目录改名为 .bak-<时间戳>（不删除）
    随后校验必需文件、提示重新登录、重装扩展、刷新模型目录。

.PARAMETER RepoUrl
    远程仓库地址，首次恢复（clone）时必填。

.PARAMETER TargetDir
    恢复目标，默认 $env:USERPROFILE\.pi。

.PARAMETER Pull
    只更新已有仓库。

.PARAMETER Force
    目标目录非空且非仓库时，改名旧目录后继续。

.EXAMPLE
    .\restore.ps1 -RepoUrl git@github.com:rLry/pi-config.git -Force

.EXAMPLE
    .\restore.ps1 -Pull
#>
[CmdletBinding()]
param(
    [string]$RepoUrl,
    [string]$TargetDir = (Join-Path $env:USERPROFILE ".pi"),
    [switch]$Pull,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$Message) Write-Host ("==> " + $Message) -ForegroundColor Cyan }
function Write-Note { param([string]$Message) Write-Host ("!!  " + $Message) -ForegroundColor Yellow }
function Write-Ok   { param([string]$Message) Write-Host ("    [OK] " + $Message) -ForegroundColor Green }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "未找到 git，请先安装：scoop install git"
}

$gitDir = Join-Path $TargetDir ".git"
$isRepo = Test-Path $gitDir

if ($Pull -and -not $isRepo) {
    throw ("-Pull 已指定，但 " + $TargetDir + " 不是 git 仓库。")
}

if ($isRepo) {
    Write-Step ("更新已有仓库：" + $TargetDir)
    git -C $TargetDir remote -v
    git -C $TargetDir pull --ff-only
} else {
    if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
        throw "首次恢复需要 -RepoUrl 参数，例如：.\restore.ps1 -RepoUrl git@github.com:rLry/pi-config.git"
    }
    if (Test-Path $TargetDir) {
        $existing = @(Get-ChildItem -Force $TargetDir)
        if ($existing.Count -gt 0) {
            if (-not $Force) {
                throw ($TargetDir + " 非空且不是仓库；确认后加 -Force，脚本只改名不删除。")
            }
            $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $bakName = (Split-Path $TargetDir -Leaf) + ".bak-" + $stamp
            Write-Note ("现有目录改名为 " + $bakName + "（未删除）")
            Rename-Item -Path $TargetDir -NewName $bakName
        }
    }
    Write-Step ("克隆 " + $RepoUrl + " -> " + $TargetDir)
    git clone $RepoUrl $TargetDir
}

$agentDir = Join-Path $TargetDir "agent"

Write-Step "校验必需文件"
$required = @("settings.json", "AGENTS.md", "mcp.json")
foreach ($name in $required) {
    $full = Join-Path $agentDir $name
    if (Test-Path $full) { Write-Ok $name } else { Write-Note ("缺少 " + $name) }
}
if (Test-Path (Join-Path $agentDir "skills")) {
    $n = @(Get-ChildItem (Join-Path $agentDir "skills") -Directory).Count
    Write-Ok ("skills 目录：" + $n + " 个技能")
}

Write-Step "凭据与本机数据（不随仓库同步）"
if (Test-Path (Join-Path $agentDir "auth.json")) {
    Write-Note "auth.json 已存在：请确认属于本机；该文件不应被提交。"
} else {
    Write-Note "尚未登录：启动 pi 后执行 /login 写入本机凭据。"
}
if ([string]::IsNullOrWhiteSpace($env:PADDLEOCR_MCP_AISTUDIO_ACCESS_TOKEN)) {
    Write-Note "PP-OCRv6 MCP 的令牌由环境变量提供（该 server 默认 disabled）。需要时执行："
    Write-Host "    [Environment]::SetEnvironmentVariable('PADDLEOCR_MCP_AISTUDIO_ACCESS_TOKEN','<你的令牌>','User')"
}

$pi = Get-Command pi -ErrorAction SilentlyContinue
if ($pi) {
    Write-Step "重装扩展（依据 settings.json 的 packages 声明）"
    & pi update --extensions
    Write-Step "刷新模型目录缓存"
    & pi update --models
} else {
    Write-Note "未找到 pi 命令；安装后手动执行：pi update --extensions 与 pi update --models"
}

Write-Step "完成"
Write-Host "未同步项（需各机器自行处理）：auth.json、mcp-auth.json、sessions/、npm/node_modules、日志、models-store.json"
Write-Host "详见 RESTORE.md"
