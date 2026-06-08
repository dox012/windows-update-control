# disable-aggressive.ps1 —— 方案二：彻底禁用（服务级，手动更新也会失效）
. "$PSScriptRoot\lib.ps1"
Assert-Admin -ScriptPath $MyInvocation.MyCommand.Path
Disable-UpdateService
Read-Host "`n按回车退出"
