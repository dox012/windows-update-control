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

---

## ⚠️ 注意事项

- 修改注册表和系统服务**需要管理员权限**。
- 长期关闭更新会**缺失安全补丁**，请自行权衡，定期手动更新。
- 方案二可能影响依赖 Windows Update 的功能（如 Defender 病毒库自动更新）。
- 本工具所有改动均可通过 `restore.ps1` 还原。

---

## 📄 License

[MIT](LICENSE)
