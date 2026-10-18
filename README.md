# OpenWRT-CI 
云编译OpenWRT固件，开启内核eBPF，支持DAED 内核级透明代理

官方版：
https://github.com/immortalwrt/immortalwrt.git

高通版：
https://github.com/VIKINGYFY/immortalwrt.git

LiBWrt：
https://github.com/LiBwrt/openwrt-6.x

京东云亚瑟 AX1800 Pro DAED 需要更换分区表和uboot,具体使用方法详见恩山帖子:
https://www.right.com.cn/forum/thread-8402269-1-1.html

# 固件简要说明：

固件每月自动编译一次（由 Auto-Clean 完成后触发）。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

当前工作流只构建 QUALCOMMAX 系列（ipq60xx / jdcloud_re-ss-01）；其余平台的 Config 仍保留，但不再自动构建。

# 目录简要说明：

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置

# 工具与 U-BOOT：

本地编译器（WSL/虚拟机里跑同一套脚本）：

https://github.com/VIKINGYFY/OWRT-Tools.git

自用修改版插件（Packages.sh 里的 viking 包即来自此仓库）：

https://github.com/VIKINGYFY/packages.git

高通版 U-BOOT——沉心：

https://github.com/chenxin527/uboot-qsdk12.5-build.git

高通版 U-BOOT——小猪：

https://github.com/1980490718/u-boot-2016.git

联发科 U-BOOT——全新版：

https://github.com/VIKINGYFY/UBOOT-CI/releases

联发科 U-BOOT——官方版：

https://drive.wrt.moe/uboot/mediatek
