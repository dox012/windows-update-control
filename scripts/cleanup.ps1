# cleanup.ps1 —— 清理已暂存/已下载的更新与功能升级文件（如等待重启的 Win11 升级包）
. "$PSScriptRoot\lib.ps1"
Assert-Admin -ScriptPath $MyInvocation.MyCommand.Path
Clear-StagedUpdates
Read-Host "`n按回车退出"
