# restore.ps1 —— 恢复 Windows 更新到默认状态
. "$PSScriptRoot\lib.ps1"
Assert-Admin -ScriptPath $MyInvocation.MyCommand.Path
Restore-Updates
Read-Host "`n按回车退出"
