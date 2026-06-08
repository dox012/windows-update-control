# Windows 自动更新控制工具 (windows-update-control)

一套**可复用、可逆**的脚本，用来关掉 Windows 烦人的自动更新和自动重启。
在任何一台 Windows 电脑上 `git clone` 下来，**双击一个 `.bat` 就能用**。

> 适用于 Windows 10 / 11（专业版、教育版、企业版效果最佳；家庭版仅注册表方案有效）。

---

## ✨ 能做什么

| 操作 | 说明 |
|------|------|
| **① 禁用自动更新（推荐）** | 通过组策略/注册表关闭自动下载、安装、重启。**仍可手动更新**，副作用最小、可逆。 |
| **② 彻底禁用（服务级）** | 停掉并禁用 Windows Update 相关服务，最彻底。**手动更新也会失效**，谨慎使用。 |
| **③ 恢复默认** | 一键还原到系统默认，恢复正常更新。 |
| **④ 查看状态** | 显示当前的更新策略和服务状态。 |
| **⑤ 清理暂存的更新/升级包** | 删除已下载/已暂存的更新与功能升级文件（如等待重启的 Win11 升级包），**取消待装升级、腾出磁盘空间**。 |

---

## 🚀 快速开始

```powershell
git clone https://github.com/<你的用户名>/windows-update-control.git
cd windows-update-control
```

然后 **双击 `disable-auto-update.bat`**（会自动请求管理员权限），按菜单选择即可。

也可以单独运行某个脚本（需管理员 PowerShell）：

```powershell
# 在仓库目录下，右键“以管理员身份运行 PowerShell”
powershell -ExecutionPolicy Bypass -File .\scripts\disable.ps1            # 禁用（推荐）
powershell -ExecutionPolicy Bypass -File .\scripts\disable-aggressive.ps1 # 彻底禁用（服务级）
powershell -ExecutionPolicy Bypass -File .\scripts\restore.ps1            # 恢复
powershell -ExecutionPolicy Bypass -File .\scripts\status.ps1            # 查看状态
powershell -ExecutionPolicy Bypass -File .\scripts\cleanup.ps1           # 清理暂存的更新/升级包
```

> 脚本本身会在检测到非管理员时自动重新以管理员身份启动，所以直接双击 / 运行也行。

---

## 📊 两种禁用方案怎么选

| | 方案一：组策略/注册表 | 方案二：禁用服务 |
|---|---|---|
| 原理 | 告诉系统“不要自动更新” | 直接停掉更新引擎服务 |
| 彻底程度 | 中（停自动下载/安装/重启） | 高（更新引擎不转） |
| 还能手动更新吗 | ✅ 能 | ❌ 需先恢复服务 |
| 副作用 | 小，官方机制 | 较大，可能影响 Defender 病毒库、应用商店等 |
| 被系统改回的概率 | 低 | 中（新版 Windows 可能自动重启服务） |
| 推荐度 | ⭐ 主力方案 | 顽固机器再用 |

**建议**：先用方案一。压不住的机器再上方案二。

---

## 🔧 改了哪些东西（透明可审阅）

**方案一（注册表，路径 `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`）**
- `NoAutoUpdate = 1` — 关闭自动更新
- `AUOptions = 2` — 仅通知，不自动下载
- `NoAutoRebootWithLoggedOnUsers = 1` — 有用户登录时不自动重启

**方案二（服务，在方案一基础上）**
- `wuauserv`（Windows Update）→ 禁用
- `UsoSvc`（Update Orchestrator）→ 禁用
- `WaaSMedicSvc`（Update Medic，会偷偷把更新改回去）→ 尝试禁用

`restore.ps1` 会把以上全部还原成系统默认。

**清理（`cleanup.ps1` / 菜单 ⑤）会删除以下目录**
- `C:\Windows\SoftwareDistribution\Download` — 更新下载缓存
- `C:\$WINDOWS.~BT` — 功能升级暂存（Win11 等大版本升级包，常达 20–30 GB）
- `C:\$WINDOWS.~WS`、`C:\$GetCurrent` — 升级介质/升级助手残留

> 采用轻量的 `rd /s /q` 整体删除，仅对删不掉的受保护文件兜底取一次所有权（`takeown`/`icacls`），避免在超大目录上逐文件处理导致的资源耗尽崩溃。少量被进程占用的文件可能残留（通常几百 MB），**重启后再跑一次即可清净**。

---

## 🛑 关于 Windows 10 已停止支持

**Windows 10 已于 2025 年 10 月 14 日 结束官方支持**，之后不再提供免费安全更新。如果你用本工具关掉了自动更新、又拒绝升级到 Win11，系统设置里会出现：

> *“你的 Windows 版本已终止支持 / 你的设备中缺少重要的安全和质量修复”*

这条提示是**真实的系统状态，与本工具无关**（任何仍在用 Win10 的机器都会显示）。你有三条路：

| 选择 | 含义 |
|---|---|
| **继续用 Win10** | 系统照常可用，但**没有免费安全补丁**了。务必装好杀软、谨慎上网。 |
| **注册扩展安全更新（ESU）** | 微软为 Win10 22H2 提供**多一年**（至 2026-10-13）安全更新；消费者可通过开启 Windows 备份同步**免费**获得，或约 $30 付费。需登录微软账号。 |
| **升级到 Win11** | 回到被支持状态（但会恢复自动更新/重启那一套）。 |

> ESU 与本工具不冲突：ESU 只决定你**有没有资格收到**安全补丁，要不要装、自动还是手动，仍由本工具的策略控制。

---

## ⚠️ 注意事项

- 修改注册表和系统服务**需要管理员权限**。
- 长期关闭更新会**缺失安全补丁**，请自行权衡，定期手动更新。
- 方案二可能影响依赖 Windows Update 的功能（如 Defender 病毒库自动更新）。
- 方案一/二的策略改动均可通过 `restore.ps1` 还原。
- **清理（⑤）会真实删除文件，不可撤销**；但删除的只是更新缓存/升级暂存，需要时系统会重新下载，不影响当前系统运行。

---

## 📄 License

[MIT](LICENSE)
