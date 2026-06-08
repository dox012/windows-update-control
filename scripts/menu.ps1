# menu.ps1 —— 交互式菜单（由 disable-auto-update.bat 调用，也可直接运行）
. "$PSScriptRoot\lib.ps1"
Assert-Admin -ScriptPath $MyInvocation.MyCommand.Path

function Show-Menu {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "        Windows 自动更新控制工具" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] 禁用自动更新（推荐，可逆，仍可手动更新）"
    Write-Host "  [2] 彻底禁用（服务级，手动更新也会失效）" -ForegroundColor Yellow
    Write-Host "  [3] 恢复默认（还原正常更新）"
    Write-Host "  [4] 查看当前状态"
    Write-Host "  [0] 退出"
    Write-Host ""
}

# 注意：switch 内的 break 只会跳出 switch，无法退出 while，
# 因此给循环加标签，用 `break :menuLoop` 才能真正退出。
:menuLoop while ($true) {
    Show-Menu
    $choice = Read-Host "请输入选项编号"
    switch ($choice) {
        '1' { Disable-AutoUpdate;    Read-Host "`n按回车返回菜单" }
        '2' {
            Write-Host "`n警告：此操作会禁用更新服务，手动更新也将失效。" -ForegroundColor Red
            $c = Read-Host "确认继续？(y/N)"
            if ($c -eq 'y' -or $c -eq 'Y') { Disable-UpdateService }
            Read-Host "`n按回车返回菜单"
        }
        '3' { Restore-Updates;       Read-Host "`n按回车返回菜单" }
        '4' { Get-UpdateStatus;      Read-Host "`n按回车返回菜单" }
        '0' { Write-Host "已退出。" -ForegroundColor Gray; break menuLoop }
        default { Write-Host "无效选项，请重新输入。" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
