# disable.ps1 —— 方案一：禁用自动更新（推荐，可逆，仍可手动更新）
. "$PSScriptRoot\lib.ps1"
Assert-Admin -ScriptPath $MyInvocation.MyCommand.Path
Disable-AutoUpdate
Read-Host "`n按回车退出"
