# lib.ps1 —— 共享函数库，被 menu.ps1 和各独立脚本 dot-source 调用
# 统一管理：管理员检测/自我提权、注册表与服务的禁用/恢复/状态

# 让中文在控制台正常显示
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Script:AUPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

# 受影响的服务及其“恢复时”的默认启动类型
$Script:Services = @(
    @{ Name = 'wuauserv';     Display = 'Windows Update';            DefaultStart = 'Manual' }
    @{ Name = 'UsoSvc';       Display = 'Update Orchestrator';       DefaultStart = 'Automatic' }
    @{ Name = 'WaaSMedicSvc'; Display = 'Update Medic Service';      DefaultStart = 'Manual' }
)

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 若当前不是管理员，则以管理员身份重新启动调用脚本并退出当前进程
function Assert-Admin {
    param([string]$ScriptPath)
    if (Test-Admin) { return }
    Write-Host "需要管理员权限，正在重新以管理员身份启动..." -ForegroundColor Yellow
    if (-not $ScriptPath) { $ScriptPath = $MyInvocation.PSCommandPath }
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$ScriptPath`"") `
        -Verb RunAs
    exit
}

# 方案一：注册表/组策略禁用自动更新
function Disable-AutoUpdate {
    Write-Host "`n[方案一] 通过注册表禁用自动更新..." -ForegroundColor Cyan
    if (-not (Test-Path $Script:AUPath)) {
        New-Item -Path $Script:AUPath -Force | Out-Null
    }
    New-ItemProperty -Path $Script:AUPath -Name 'NoAutoUpdate'                -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $Script:AUPath -Name 'AUOptions'                   -Value 2 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $Script:AUPath -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Host "  ✓ NoAutoUpdate = 1（关闭自动更新）" -ForegroundColor Green
    Write-Host "  ✓ AUOptions = 2（仅通知，不自动下载）" -ForegroundColor Green
    Write-Host "  ✓ NoAutoRebootWithLoggedOnUsers = 1（不自动重启）" -ForegroundColor Green
    Write-Host "完成。仍可在“设置”中手动检查更新。" -ForegroundColor Green
}

# 方案二：在方案一基础上，停用并禁用更新相关服务
function Disable-UpdateService {
    Disable-AutoUpdate
    Write-Host "`n[方案二] 停用并禁用 Windows Update 相关服务..." -ForegroundColor Cyan
    foreach ($svc in $Script:Services) {
        $name = $svc.Name
        try {
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
            Set-Service  -Name $name -StartupType Disabled -ErrorAction Stop
            Write-Host "  ✓ $($svc.Display) ($name) 已停止并禁用" -ForegroundColor Green
        } catch {
            # 部分受保护服务（如 WaaSMedicSvc）无法用 Set-Service 修改，改写注册表 Start=4
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"
            try {
                Set-ItemProperty -Path $regPath -Name 'Start' -Value 4 -ErrorAction Stop
                Write-Host "  ✓ $($svc.Display) ($name) 已通过注册表禁用（重启后生效）" -ForegroundColor Green
            } catch {
                Write-Host "  ! $($svc.Display) ($name) 禁用失败：$($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    Write-Host "完成。注意：此模式下手动更新也会失效，需先运行 restore 恢复。" -ForegroundColor Yellow
}

# 恢复：删除策略项 + 还原服务启动类型
function Restore-Updates {
    Write-Host "`n[恢复] 还原 Windows 更新到默认状态..." -ForegroundColor Cyan

    # 仅删除本工具写入的策略项，不动 AU 键里可能存在的其他设置
    if (Test-Path $Script:AUPath) {
        foreach ($n in @('NoAutoUpdate','AUOptions','NoAutoRebootWithLoggedOnUsers')) {
            Remove-ItemProperty -Path $Script:AUPath -Name $n -ErrorAction SilentlyContinue
        }
        # 若 AU 键已无任何值和子项，则连空壳一并清理
        $au = Get-Item -Path $Script:AUPath
        if ($au.ValueCount -eq 0 -and $au.SubKeyCount -eq 0) {
            Remove-Item -Path $Script:AUPath -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  ✓ 已清除自动更新策略项" -ForegroundColor Green

    # 还原服务
    foreach ($svc in $Script:Services) {
        $name = $svc.Name
        try {
            Set-Service -Name $name -StartupType $svc.DefaultStart -ErrorAction Stop
            Write-Host "  ✓ $($svc.Display) ($name) 启动类型还原为 $($svc.DefaultStart)" -ForegroundColor Green
        } catch {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"
            $startVal = if ($svc.DefaultStart -eq 'Automatic') { 2 } else { 3 }
            try {
                Set-ItemProperty -Path $regPath -Name 'Start' -Value $startVal -ErrorAction Stop
                Write-Host "  ✓ $($svc.Display) ($name) 已通过注册表还原（重启后生效）" -ForegroundColor Green
            } catch {
                Write-Host "  ! $($svc.Display) ($name) 还原失败：$($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    Write-Host "完成。建议重启后到“设置”手动检查一次更新。" -ForegroundColor Green
}

# 清理已暂存/已下载的更新与功能升级文件（如等待重启的 Win11 升级包）
function Clear-StagedUpdates {
    Write-Host "`n[清理] 删除已暂存的更新/升级文件..." -ForegroundColor Cyan

    # 1. 先停掉占用这些文件的服务
    foreach ($s in @('wuauserv','UsoSvc','BITS','dosvc')) {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  已暂停更新相关服务" -ForegroundColor Gray

    $freeBefore = (Get-PSDrive C).Free / 1GB

    # 2. 逐个清理目标目录
    $targets = @(
        'C:\Windows\SoftwareDistribution\Download',  # 更新下载缓存
        'C:\$WINDOWS.~BT',                            # 功能升级暂存（Win11 升级包）
        'C:\$WINDOWS.~WS',                            # 升级介质
        'C:\$GetCurrent'                              # 升级助手残留
    )
    foreach ($t in $targets) {
        if (-not (Test-Path $t)) { Write-Host "  跳过(不存在): $t" -ForegroundColor Gray; continue }
        Write-Host "  正在删除: $t ..." -ForegroundColor Gray
        # 轻量直删：单个原生进程整体递归删除（避免 takeown 逐文件导致的 R6016 资源耗尽）
        cmd /c "rd /s /q `"$t`"" 2>$null
        # 仍有残留（被保护文件）才兜底取一次所有权后再删
        if (Test-Path $t) {
            cmd /c "takeown /f `"$t`" /r /d y >nul 2>&1 & icacls `"$t`" /grant *S-1-5-32-544:F /t /c >nul 2>&1 & rd /s /q `"$t`"" 2>$null
        }
        Write-Host ("    -> {0}" -f $(if (Test-Path $t) {'仍有残留(可重启后再试一次)'} else {'已删除'})) -ForegroundColor Green
    }

    # 3. 把 Windows Update 服务恢复到“手动”（保持方案一：仍可手动更新）
    Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue

    $freeAfter = (Get-PSDrive C).Free / 1GB
    Write-Host ("完成。C 盘剩余 {0:N2} GB -> {1:N2} GB（腾出约 {2:N2} GB），自动更新策略保持不变。" -f $freeBefore, $freeAfter, ($freeAfter - $freeBefore)) -ForegroundColor Green
}

# 查看当前状态
function Get-UpdateStatus {
    Write-Host "`n===== 当前 Windows 更新状态 =====" -ForegroundColor Cyan

    Write-Host "`n[注册表策略] $Script:AUPath" -ForegroundColor White
    if (Test-Path $Script:AUPath) {
        foreach ($n in @('NoAutoUpdate','AUOptions','NoAutoRebootWithLoggedOnUsers')) {
            $v = (Get-ItemProperty -Path $Script:AUPath -Name $n -ErrorAction SilentlyContinue).$n
            $shown = if ($null -ne $v) { $v } else { '(未设置)' }
            Write-Host ("  {0,-30} = {1}" -f $n, $shown)
        }
    } else {
        Write-Host "  (无策略项 —— 自动更新为系统默认/开启)" -ForegroundColor Gray
    }

    Write-Host "`n[服务状态]" -ForegroundColor White
    foreach ($svc in $Script:Services) {
        $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        if ($s) {
            Write-Host ("  {0,-20} 状态={1,-8} 启动类型={2}" -f $svc.Name, $s.Status, $s.StartType)
        } else {
            Write-Host ("  {0,-20} (未找到该服务)" -f $svc.Name) -ForegroundColor Gray
        }
    }
    Write-Host ""
}
