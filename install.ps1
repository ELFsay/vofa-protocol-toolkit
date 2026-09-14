<#
  VOFA+ 自定义协议工具箱 —— 一键安装脚本
  ------------------------------------------------------------------
  适用于普通用户，也适合直接交给 AI Agent 执行（无交互、幂等、带清晰输出）。

  用法：
    powershell -ExecutionPolicy Bypass -File install.ps1
    powershell -ExecutionPolicy Bypass -File install.ps1 -VofaDir "C:\Program Files\VOFA+"

  参数：
    -VofaDir       VOFA+ 安装目录（不填则自动探测注册表/常见路径）
    -ToolDir       配置工具安装目录（默认 %USERPROFILE%\vofa-protocol-tool）
    -SkipEngine    不下载/安装协议引擎 ConfigurableEngine.dll
    -SkipShortcut  不创建桌面快捷方式
    -EngineRepo    协议引擎仓库（默认 saltfishfly/vofa-configurable-engine）
#>
param(
    [string]$VofaDir = "",
    [string]$ToolDir = "",
    [switch]$SkipEngine,
    [switch]$SkipShortcut,
    [string]$EngineRepo = "saltfishfly/vofa-configurable-engine"
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrWhiteSpace($ToolDir)) { $ToolDir = Join-Path $env:USERPROFILE 'vofa-protocol-tool' }

function Say($msg) { Write-Host ("  " + $msg) }
function Step($msg) { Write-Host ""; Write-Host ("== " + $msg) }
function Warn($msg) { Write-Host ("  [!] " + $msg) -ForegroundColor Yellow }
function Ok($msg)   { Write-Host ("  [OK] " + $msg) -ForegroundColor Green }

# ---------- 1. 找 VOFA+ 安装目录 ----------
Step "1/6 定位 VOFA+ 安装目录"
if ($VofaDir -and (Test-Path (Join-Path $VofaDir 'vofa+.exe'))) {
    Ok "使用指定目录：$VofaDir"
} else {
    $cands = @()
    foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        $cands += (Get-ItemProperty $k -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like '*VOFA*' } |
                   ForEach-Object { $_.InstallLocation })
    }
    $cands += @("$env:ProgramFiles\VOFA+", "${env:ProgramFiles(x86)}\VOFA+", "C:\Program Files\VOFA+")
    $VofaDir = $cands | Where-Object { $_ -and (Test-Path (Join-Path $_ 'vofa+.exe')) } | Select-Object -First 1
    if (-not $VofaDir) {
        # 再扫一层：VOFA+ 有时装在 ...\Gutega\VOFA+\x64
        $hit = Get-ChildItem "$env:ProgramFiles","${env:ProgramFiles(x86)}" -Directory -ErrorAction SilentlyContinue |
               ForEach-Object { Get-ChildItem $_.FullName -Recurse -Depth 3 -Filter 'vofa+.exe' -ErrorAction SilentlyContinue } |
               Select-Object -First 1
        if ($hit) { $VofaDir = $hit.Directory.FullName }
    }
    if (-not $VofaDir) { throw "没找到 VOFA+ 安装目录，请用 -VofaDir 显式指定（含 vofa+.exe 的目录）" }
    Ok "自动探测到：$VofaDir"
}
$dirs = @{
    dataengines = Join-Path $VofaDir 'plugins\dataengines'
    widgets     = Join-Path $VofaDir 'plugins\widgets'
}

# ---------- 2. 安装配置工具 ----------
Step "2/6 安装配置工具到 $ToolDir"
New-Item -ItemType Directory -Force -Path $ToolDir | Out-Null
$toolSrc = Join-Path $scriptDir 'config-tool'
if (-not (Test-Path $toolSrc)) { throw "找不到 config-tool 目录（脚本要和 config-tool、qml-widget 同级）" }
Get-ChildItem $toolSrc -File | Where-Object { $_.Name -ne 'tool.cfg' } | ForEach-Object {
    Copy-Item $_.FullName -Destination $ToolDir -Force
}
$exe = Join-Path $ToolDir 'VofaProtocolTool.exe'
$cfg = Join-Path $ToolDir 'VofaProtocolTool.exe.config'
if (-not (Test-Path $exe)) { throw "复制失败：$exe 不存在" }
if (-not (Test-Path $cfg)) { Warn "缺少 VofaProtocolTool.exe.config（高 DPI 会不生效，但功能可用）" }
Ok "工具就位：$exe"

# ---------- 3. 安装只读控件 ----------
Step "3/6 安装只读控件到 plugins\widgets\VofaProtoView"
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $dirs.widgets 'VofaProtoView') | Out-Null
    Copy-Item (Join-Path $scriptDir 'qml-widget\VofaProtoView\*') (Join-Path $dirs.widgets 'VofaProtoView') -Recurse -Force
    Ok "控件就位（重启 VOFA+ 后在控件抽屉里，缩略图可点抽屉上方刷新按钮）"
} catch {
    Warn "复制控件失败（多半是写 Program Files 需要管理员权限）：$($_.Exception.Message)"
    Warn "请用“管理员身份运行 PowerShell”重跑本脚本，或手动把 qml-widget\VofaProtoView\ 拷到 $($dirs.widgets)\"
}

# ---------- 4. 安装协议引擎（可选） ----------
Step "4/6 安装协议解析引擎（来源：https://github.com/$EngineRepo）"
if ($SkipEngine) {
    Say "已按 -SkipEngine 跳过；请自行把 ConfigurableEngine.dll 等文件放进 $($dirs.dataengines)"
} else {
    try {
        New-Item -ItemType Directory -Force -Path $dirs.dataengines | Out-Null
        $tmp = Join-Path $env:TEMP ("vofa-engine-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $zip = Join-Path $tmp 'engine.zip'
        $done = $false
        foreach ($br in @('main', 'master')) {
            try {
                Invoke-WebRequest -Uri "https://codeload.github.com/$EngineRepo/zip/refs/heads/$br" -OutFile $zip -UseBasicParsing -ErrorAction Stop
                $done = $true; break
            } catch { }
        }
        if (-not $done) { throw "下载失败（网络或代理问题）" }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $root = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like 'vofa-configurable-engine*' } | Select-Object -First 1
        if (-not $root) { throw "解压后没找到仓库目录" }
        Copy-Item (Join-Path $root.FullName 'dist\ConfigurableEngine.dll') $dirs.dataengines -Force
        Copy-Item (Join-Path $root.FullName 'ConfigurableEngine.json') $dirs.dataengines -Force
        $cfgTarget = Join-Path $dirs.dataengines 'configurable_engine.json'
        if (Test-Path $cfgTarget) {
            Say "已存在 $cfgTarget —— 保留你现有的协议配置，未覆盖"
        } else {
            Copy-Item (Join-Path $root.FullName 'configurable_engine.json') $dirs.dataengines -Force
        }
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Ok "协议引擎已安装到 $($dirs.dataengines)"
    } catch {
        Warn "协议引擎安装失败：$($_.Exception.Message)"
        Warn "请手动到 https://github.com/$EngineRepo 下载，把 dist\ConfigurableEngine.dll、configurable_engine.json、ConfigurableEngine.json 放进 $($dirs.dataengines)"
    }
}

# ---------- 5. 桌面快捷方式 ----------
Step "5/6 创建桌面快捷方式"
if ($SkipShortcut) {
    Say "已按 -SkipShortcut 跳过"
} else {
    try {
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'VOFA+ 协议配置.lnk'
        $ws = New-Object -ComObject WScript.Shell
        $s = $ws.CreateShortcut($lnk)
        $s.TargetPath = $exe
        $s.WorkingDirectory = $ToolDir
        $s.IconLocation = "$exe,0"
        $s.Description = 'VOFA+ 自定义协议配置（configurable_engine.json）'
        $s.Save()
        Ok "桌面快捷方式：$lnk"
    } catch {
        Warn "创建快捷方式失败：$($_.Exception.Message)"
    }
}

# ---------- 6. 自检 ----------
Step "6/6 自检（不弹界面，结果写 selftest.log）"
$target = Join-Path $dirs.dataengines 'configurable_engine.json'
try {
    $log = Join-Path $ToolDir 'selftest.log'
    Remove-Item $log -Force -ErrorAction SilentlyContinue
    if (Test-Path $target) {
        Start-Process -FilePath $exe -ArgumentList @('--selftest', $target) -Wait -ErrorAction SilentlyContinue
    } else {
        Start-Process -FilePath $exe -ArgumentList @('--selftest') -Wait -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 800
    if (Test-Path $log) {
        Get-Content $log | Where-Object { $_ -match '往返|二次导出|读取结果|当前配置校验|RESULT' } | ForEach-Object { Say $_ }
        $t = Get-Content $log -Raw
        if ($t -match '非 JSON 内容') {
            Warn "配置文件读出来不是 JSON —— 请检查路径与文件内容。"
            Warn ""
            Warn ""
        } elseif ($t -match 'RESULT=OK') {
            Ok "自检通过"
        }
    } else {
        Warn "没有生成 selftest.log（可手动运行：`"$exe`" --selftest `"$target`"）"
    }
} catch {
    Warn "自检执行失败：$($_.Exception.Message)"
}

Write-Host ""
Write-Host "==================== 安装结果 ====================" -ForegroundColor Cyan
Say "VOFA+ 安装目录 : $VofaDir"
Say "协议引擎目录   : $($dirs.dataengines)"
Say "控件目录       : $($dirs.widgets)\VofaProtoView"
Say "配置工具       : $exe"
Write-Host ""
Write-Host "接下来请手动完成（脚本无法替你做）：" -ForegroundColor Cyan
Say "1) 完全退出并重新启动 VOFA+（控件/协议引擎都要重启才生效）；"
Say "2) 在数据接口的“数据格式”里选择 ConfigurableEngine；"
Say "3) 在左侧控件抽屉里找到 VofaProtoView，拖到画布上（缩略图可点抽屉上方刷新按钮）。"
Say "之后用桌面快捷方式打开配置工具改协议，点保存 → VOFA+ 约 1 秒内自动重载。"
