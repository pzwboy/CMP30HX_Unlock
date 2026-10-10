# 解锁 NVIDIA CMP 30HX v3.0.0 (PCIe Gen2 x16)

专为 NVIDIA CMP 30HX（TU116 核心）显卡打造的 PCIe Gen2 x16 (~6.4 GB/s) 带宽解锁方案，支持 Windows 10/11 x64。

- **一键安装** — 脚本自动处理一切，只需双击并等待即可。
- **无需修改 BIOS** — 纯软件层拦截干预，无需刷写主板 BIOS 或显卡 VBIOS。

> [!TIP]
> - 用 DeepSeek 写的改进脚本，`README`自己稍微改了点，原仓库脚本的问题太多了，电脑简直无法日常使用……
>
> - 请优先下载`Release`的压缩包，直接下载仓库ZIP可能会有编码问题。
>
> - 如果出现`不是内部或外部命令，也不是可运行的程序`等报错，请转换BAT编码为`ANSI`。

## 1. 准备工作

**前置需求：**

- 已完成 PCIe x16 通道补阻改线的 CMP 30HX (TU116) 显卡，且插入与 CPU 直连的 PCIe x16 插槽。
- 已预先安装任意版本的 NVIDIA 驱动（显卡在设备管理器中能正常显示）。

**下载工具包：**

在 GitHub 页面点击`Code → Download ZIP`或下载最新的`Release`，解压到本地目录。

## 2. 在 Windows 上安装

> **仅需 1 步** — 右键点击 `Setup_CMP30HX.bat` → **以管理员身份运行**。

脚本会自动处理所有配置注册每次开机自启。

> [!IMPORTANT]
> 如果您的系统当前**开启了内存完整性（内核隔离 / HVCI）**，脚本会自动关闭它并提示您**重启一次电脑**。重新登录系统后，程序将自动切换至 Gen2 x16。

<details>
<summary>📋 详情：脚本执行了哪些操作？</summary>

1. **关闭 PCIe ASPM 和混合睡眠** — 防止 Windows 在 GPU 空闲时将 PCIe 链路降速。
2. **关闭快速启动（hiberboot）** — 防止重启后卡在 Gen1 速率。
3. **关闭微软易受攻击驱动程序阻止列表** — 允许加载 WinRing0 / ThrottleStop 内核驱动。
4. **关闭内存完整性（HVCI）** — 允许向 BAR0 MMIO 寄存器写入数据。
5. **注册开机自启维持机制** — 创建系统计划任务（开机 + 登录 + 睡眠唤醒）或注册表自启项，确保持久维持 Gen2 速率。
6. **解锁 Gen2 x16 + MRRS 512B** — 显卡即刻就绪，无需重启（关闭 HVCI 的情况除外）。

</details>


## 4. 验证结果

安装完成后，可通过以下两种方式之一进行验证：

| 工具 | 检查方式 | 正确结果 |
|---|---|---|
| **GPU-Z** 或 `40HXCheck.exe` | **Bus Interface（总线接口）** 项 | `PCIe x16 2.0 @ x16 2.0` |
| **AIDA64** → Tools → GPGPU Benchmark | **Memory Read / Memory Copy** 行 | **6.3 – 6.4 GB/s** |

> 若 AIDA64 仅达到约 2.5 GB/s → 说明 MRRS 仍处于默认的 128B 限制 → 重新运行 `40HXInstaller.exe -gen2-30hx`。

## 5. 常见故障排查 (Troubleshooting)

| 故障现象 | 产生原因 | 解决方案 |
|---|---|---|
| **卡在 Gen1 无法提升 (GPU TLS=Gen1, Root TLS=Gen2)** | - 双显卡系统（CMP 30HX + AMD/Intel 核显）或魔改驱动（RainCandy）重新初始化，自动将 GPU TLS 重置为 Gen1。<br>- 或 Windows 开启了内存完整性（HVCI），或显卡延长线接触不良 | 1. **自动解决**：新版 `Setup_CMP30HX_WindowsAIO.bat` 激活了**常驻守护（Resident Guard）**模式与登录任务（延迟 10 秒），自动补提 Gen2。<br>2. **手动解决**：在设备管理器中保持显卡处于**启用（Enable）**状态（**严禁**禁用设备，否则会切断 BAR0 MMIO 连接）→ 待桌面加载稳定后运行 `Setup_CMP30HX_WindowsAIO.bat` 或 `40HXInstaller.exe -gen2-30hx`。<br>3. 若开启了 HVCI：关闭内存完整性并**重启电脑**。 |
| **重启电脑后 Gen2 失效回退** | - NVIDIA / RainCandy 驱动在 APU 平台上加载较慢，或在开机后覆盖了 vBIOS 状态。<br>- 旧驱动残留配置冲突，或快速启动（Fast Startup）仍处于开启状态 | 1. `Setup_CMP30HX_WindowsAIO.bat` 已集成多层计划任务（登录延迟 10 秒 + 开机延迟 45 秒）与 **DriverStrategy=2 (Resident Guard)** 模式，每分钟自动检测并在失去 Gen2 时重新重训。<br>2. **DDU 建议**：在安全模式下使用 **DDU (Display Driver Uninstaller)** 彻底清除所有旧显卡驱动残留，再安装驱动，以防注册表冲突。 |
| **显卡空闲时自动掉速至 Gen1 x16** | Windows 系统的 PCIe ASPM 节能策略处于开启状态 | 重新运行 `Setup_CMP30HX_WindowsAIO.bat`（脚本会自动关闭 ASPM），或在电源选项 → PCI Express → 链接状态电源管理中设置为：**关闭**。 |
| **GPU-Z 显示 Gen2 x16 但 AIDA64 测速只有 ~2.5 GB/s** | 显卡的最大读取请求大小（MRRS）被限制在默认的 128 字节 | 运行命令 `40HXInstaller.exe -gen2-30hx`，将 MRRS 提升至 512 字节并刷新 DMA 队列。 |
| **无法识别显卡 / 报错代码 43** | 改焊 x16 通道电阻虚焊或接触不良，或者显卡未正确识别驱动 | 1. 重新检查显卡上的改电阻焊接点。<br>2. 重新安装 NVIDIA 驱动（建议使用 DDU 彻底清除后重装最新版）。 |
| **尝试了所有方法仍无法解决** | NVIDIA 驱动配置冲突、注册表配置文件损坏或驱动服务异常 | 在 Windows 安全模式下使用 **DDU (Display Driver Uninstaller)** 清除旧驱动后重新安装驱动。 |

## 6. 卸载与清理

| 操作系统 | 命令 |
|---|---|
| **Windows**（脚本） | `Setup_CMP30HX.bat -uninstall` |

工具将自动删除系统计划任务或注册表自启项、程序安装目录以及临时文件。

---

## 7. 技术说明

> [!NOTE]
> - **为什么只能达到 Gen2 而无法开启 Gen3？**
>   NVIDIA 在出厂时于 TU116 芯片上物理熔断了硬件电子熔丝（Silicon eFuse Bit 3 - 8.0 GT/s）。Gen2 x16 (5.0 GT/s) 是其绝对的硬件物理上限 — 本工具通过 BAR0 MMIO 安全解锁至该上限，绝不强行协商 Gen3，避免造成链路重训卡死。
> - **MRRS 512B 优化**：
>   将最大读取请求大小（Max Read Request Size）从 128B 提升至 512B，消除了 TLP 数据包分片瓶颈，跑满 ~6.4 GB/s 的 DMA 内存吞吐带宽。

---

## 致谢

> 本项目受 **CMP40HX-Unlock** 早期研究工作的启发。
> 
> 原仓库：[https://github.com/ngthaihoc/CMP30HXmodtoGEN2](https://github.com/ngthaihoc/CMP30HXmodtoGEN2)