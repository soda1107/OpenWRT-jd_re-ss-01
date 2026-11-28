# OpenWRT-CI

云编译 OpenWrt 固件：内核开启 eBPF，透明代理使用 [luci-app-daeuniverse](https://github.com/QiuSimons/luci-app-daeuniverse)（honk / dae 双核心）。

## 固件

- 设备：京东云亚瑟 AX1800 Pro（`jdcloud_re-ss-01`，ipq60xx / qualcommax，eMMC）
- 源码：https://github.com/VIKINGYFY/immortalwrt （`main`）
- 流水线：`QCA-6.18-VIKINGYFY`（配置 `IPQ60XX-NOWIFI`）调用公用核心 `WRT-CORE`
- 触发：每月 1 号 `Auto-Clean` 完成后自动编译，也可手动运行（可选参数 `PACKAGE` 临时加插件、`TEST` 只生成配置不编译）
- 插件：daeuniverse（honk 为核心，编译期由 `honk/Makefile` 现场交叉编译）、argon 主题、`v2ray-geoip` / `v2ray-geosite`
- 本机需更换分区表与 U-Boot，方法见恩山帖子：https://www.right.com.cn/forum/thread-8402269-1-1.html

## 目录

| 路径 | 说明 |
| --- | --- |
| `.github/workflows/` | `WRT-CORE` 公用核心、`QCA-6.18-VIKINGYFY` 调用方、`Auto-Clean` 月度触发、`Lint` 静态检查 |
| `Config/` | `GENERAL.txt` 通用配置 + 设备配置 |
| `Scripts/` | `function.sh` 生成配置、`Packages.sh` 插件源、`Handles.sh` 上游修补、`Settings.sh` 固件细节、`AssertConfig.sh` 构建前断言、`InitHonkToolchain.sh` honk 工具链 |
| `package/` | 本地覆盖包（`v2ray-geodata`，固定 Loyalsoldier 规则集） |
| `diy.sh` | 本地编译入口 |

## 本地编译

```sh
sudo Scripts/InitHonkToolchain.sh    # honk-core 需要的 bpf-linker / zig / rust 工具链
./diy.sh                             # 默认 Config/IPQ60XX-NOWIFI.txt + VIKINGYFY/immortalwrt
```

`diy.sh` 只完成「拉源码 → 装插件 → 生成配置 → 断言」，`make download` / `make` 按需自行执行。

## 工具与 U-BOOT

- 本地编译器（WSL / 虚拟机跑同一套脚本）：https://github.com/VIKINGYFY/OWRT-Tools.git
- 自用修改版插件（`Packages.sh` 里的 viking 包来源）：https://github.com/VIKINGYFY/packages.git
- 高通版 U-BOOT（沉心）：https://github.com/chenxin527/uboot-qsdk12.5-build.git
- 高通版 U-BOOT（小猪）：https://github.com/1980490718/u-boot-2016.git
