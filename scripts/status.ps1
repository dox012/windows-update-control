# status.ps1 —— 查看当前更新策略与服务状态
. "$PSScriptRoot\lib.ps1"
Assert-Admin -ScriptPath $MyInvocation.MyCommand.Path
Get-UpdateStatus
Read-Host "`n按回车退出"
