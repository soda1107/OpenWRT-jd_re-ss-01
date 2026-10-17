# 主线（VIKINGYFY/OpenWRT-CI）可合并项审查

- 本地仓库：`soda1107/OpenWRT-jd_re-ss-01`，分支 `main`，tip `b4a0a48`（2026-10-11）
- 上游：`VIKINGYFY/OpenWRT-CI`，`upstream/main` tip `4773a5d`（2026-08-08）
- 共同祖先 `85dc9f7`（2024-10-30「精简项目」）
- `git rev-list --left-right --count origin/main...upstream/main` = **630 / 202**

## 0. 判断前提：不能用 commit merge，只能按文件对比

本地领先 630 个提交、上游领先 202 个，且共同祖先停留在 2024-10。两边都对历史做过重写/强推（例如上游 `.github/workflows/QCA-ALL.yml` 在 diff 里显示为被本地改名成 `QCA-6.12-LiBwrt.yml`，上游的 `WRT-TEST.yml`、`OWRT-ONE.yml` 在本地被删）。

**结论：任何 `git merge upstream/main` / `git cherry-pick` 都会引入大范围回退。所有合并都应当做「按文件、按代码块的手工搬移」，并且能用 `workflow_dispatch` + `TEST=true` 只跑配置生成来验证的，就不要挂一次 3 小时全量编译。**

---

## 1. 结论速览

| # | 上游改动 | 建议 | 风险 | 收益 |
|---|---|---|---|---|
| A1 | `.gitattributes`（`*.txt`/`*.sh` → LF） | **合并（并扩展）** | 极低 | 消除 CRLF 造成的 YAML/shell 隐患 |
| A2 | `LICENSE`（MIT） | **合并** | 无 | 法务合规 |
| A3 | `Scripts/Packages.sh` 的 `Scripts/PRIVATE.sh` 钩子 | **合并** | 无（文件不存在即 no-op） | 私有扩展位 |
| A4 | `Settings.sh` 用 `$WRT_MARK` 替换硬编码 `DaeWRT` | **合并（补 diy.sh）** | 极低 | 版本串不再写死 |
| A5 | `Handles.sh` 的 TailScale Makefile 修补 | **合并** | 极低（`-f` 守卫） | 切到 tailscale 时少一个坑 |
| B1 | `gh cache delete` 陈旧缓存清理 | **合并（改 key 前缀）** | 低 | **最高**：防止 10GB 配额被挤爆导致全量重编 |
| B2 | `Clone Code` 剔除 `projectsmirrors.json` 里的国内源 | **合并** | 极低（`-f` 守卫） | 减少海外 runner 上的下载超时 |
| B3 | `Config/GENERAL.txt` 的增量包 | **选择性合并** | 中（逐条判断） | 功能补全 |
| B4 | `WRT-TEST.yml` 的 choice + TEST 交互 | **合并（做成 TEST 入口）** | 低 | 改配置后几十秒验证 |
| C1 | `make defconfig && make clean` | **不要合并** | 高 | 会清掉两级缓存 |
| C2 | `Cache-Clean.yml`（`gh cache delete --all` 每周） | **不要合并** | 高 | 会清掉 `.ccache`/toolchain |
| C3 | `/mnt/build_wrt` 软链 | **维持现状（不启用）** | 中 | 你已用 free-disk-space 替代 |
| C4 | 在线版 `init_build_environment.sh` | **不要合并** | 中 | 内置版更可复现 |
| C5 | `Packages.sh` 删除 daed/dae/honk + v2ray-geodata | **不要合并** | 高 | 这些包你在用 |
| C6 | `Settings.sh` 删除两条 source 修补 sed | **不要合并** | 中 | 你选的源码树需要它们 |
| C7 | `Handles.sh` 的 HomeProxy 资源预置 | **暂不合并** | 中 | homeproxy 未启用，纯增失败面 |
| C8 | 上游 workflow 结构（MTK/QCA/OWRT-ALL） | **不要合并** | 高 | 会改变构建成本与触发时机 |
| C9 | `Config/*-WIFI-NO/YES.txt` 改名与设备清单 | **不要合并** | 高 | workflow matrix 引用了现名 |
| C10 | 上游 README | **部分采纳** | 无 | 链接有参考价值 |

---

## 2. A 级：零风险 / 极低风险，可直接抄

### A1. 新增 `.gitattributes`

上游（`upstream/main:.gitattributes`）：
```
*.txt text eol=lf
*.sh text eol=lf
```

**建议扩展成**（关键是把 `*.yml` 也纳入 —— 你本地 WRT-CORE.yml 的 `Check Scripts` 步骤只对 `txt|sh` 做 `dos2unix`，`.yml` 是漏网的）：
```gitattributes
* text=auto eol=lf
*.sh  text eol=lf
*.txt text eol=lf
*.yml text eol=lf
```

落地后执行一次重归一化：
```bash
git add --renormalize .
git commit -m "chore: 统一行尾为 LF"
```

当前仓库里是 CRLF 的文件（实测）：

- `.github/workflows/Auto-Clean.yml`
- `.github/workflows/QCA-6.12-LiBwrt.yml`
- `.github/workflows/WRT-CORE.yml`
- `.github/workflows/WRT-CORE-TEST.yml`
- `Config/GENERAL.txt`
- `Config/IPQ60XX-NOWIFI.txt`
- `Config/IPQ60XX-WIFI.txt`

其余（`QCA-6.18-VIKINGYFY.yml`、全部 `Scripts/*.sh`、`diy.sh`、`Config/IPQ807X-*`、`Config/MEDIATEK.txt`、`Config/ROCKCHIP.txt`、`Config/X86.txt`）已是 LF。

风险：对固件功能零影响（`make defconfig` 前 `.config` 会被 `dos2unix`/kconfig 正常处理；这里主要是消除 workflow YAML 里 `run: |` 块被 CR 污染的隐患）。

### A2. 新增 `LICENSE`（MIT，`Copyright (c) 2026 VIKINGYFY`）

直接取上游文件。如果你想声明自己的版权，把 Copyright 行改成自己的名字即可（上游是 MIT，允许保留原作者声明 + 追加自己的）。

### A3. `Scripts/Packages.sh` 末尾加 `PRIVATE.sh` 钩子

上游在 `Packages.sh` 尾部替换掉你的 v2ray-geodata/passwall 清理段，新增了：
```sh
#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
```

**只加这 4 行，不要动你的 v2ray-geodata 段。** 理由：

- 本地已有同风格的 `Config/PRIVATE.txt` 钩子（`Scripts/Settings.sh:44-46`），`Scripts/PRIVATE.sh` 目前不存在 → 当前完全是 no-op；
- 给你一个「不改公共脚本就能加私有包/私有修补」的位置，对你这种 fork 场景正好。

### A4. `Scripts/Settings.sh` 用 `$WRT_MARK` 替换硬编码 `DaeWRT`

本地 `Scripts/Settings.sh:10` 现在是：
```sh
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ DaeWRT-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
```
上游改成（`Settings.sh:12`）：
```sh
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")
```

可用性核对：

- CI 路径 OK —— 本地 `.github/workflows/WRT-CORE.yml:127` 已经 `echo "WRT_MARK=${GITHUB_REPOSITORY%%/*}" >> $GITHUB_ENV`；
- **`diy.sh` 没有导出 `WRT_MARK`**，本地开发会显示成 `/ -<日期>`。所以合并时请同时给 `diy.sh` 加一行，例如：
  ```sh
  export WRT_MARK='DaeWRT'
  ```
- 纯展示字符串，对固件功能无影响。

### A5. `Scripts/Handles.sh` 加 TailScale 修补

上游 `Handles.sh` 里本地没有的一段（约 10 行）：
```sh
#修复TailScale配置文件冲突
FEEDS_PACKAGES="$PKG_PATH/../feeds/packages"
TS_FILE="$(find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/tailscale/Makefile' -print -quit 2>/dev/null)"
if [ -f "$TS_FILE" ]; then
	...
	if sed -i '/\/files/d' "$TS_FILE"; then
		echo "tailscale has been fixed!"
	else
		echo "tailscale fix failed; continuing!"
	fi
fi
```

有 `-f` 守卫 → 找不到文件直接跳过。本地 `Scripts/Packages.sh:65` 确实克隆 `asvow/luci-app-tailscale`，而 `Config/GENERAL.txt:16` 的 tailscale 目前是注释状态，所以现在是纯 no-op；等你哪天打开 tailscale 时才有意义。可按本地 `FIX()` 风格重写，保持一致：

```sh
#修复TailScale配置文件冲突
TS_FILE="$(find "$FEEDS_PATH/packages" -maxdepth 3 -type f -wholename '*/tailscale/Makefile' -print -quit 2>/dev/null)"
[ -n "$TS_FILE" ] && FIX "tailscale" "$(dirname "$TS_FILE")" sed -i '/\/files/d' "$TS_FILE"
```

---

## 3. B 级：收益明确，需要少量改造

### B1.（最推荐）陈旧缓存清理 —— 直接解决一个真实的稳定性隐患

**问题**：你本地是自研两级缓存（`.github/workflows/WRT-CORE.yml:174-208` 附近）：

- 工具链 key：`toolchain-$WRT_ARCH-$WRT_TARGET-$WRT_BRANCH-$WRT_HASH`，其中 `WRT_HASH` 是**上游 commit**（`:143`），每天上游一提交就变；
- 目标包 key：`...-$WRT_CONFIG-${{ hashFiles('Config/*.txt', 'Scripts/*.sh', 'package/**') }}`，改任何配置/脚本就变。

而本地**没有任何 cache 清理机制**（`Auto-Clean.yml` 只删 release 和 workflow run）。GitHub 单仓缓存配额只有 10 GB，超出后按 LRU 淘汰 —— 最坏情况是 `.ccache` + toolchain 被挤掉，于是下一次变成 3 小时全量编译。

**上游的做法**（`upstream/main:.github/workflows/WRT-CORE.yml:142-149`）：
```sh
if ${{steps.check-cache.outputs.cache-hit != 'true'}}; then
  CACHE_LIST=$(gh cache list --key "$WRT_CONFIG-$WRT_INFO" | cut -f 1)
  for CACHE_KEY in $CACHE_LIST; do
    gh cache delete $CACHE_KEY
  done
  echo "caches cleanup done!"
fi
```

**适配到你的 key**：先给两个缓存步骤加 `id`，再在其后追加清理步骤。

步骤一，给缓存步骤加 id：
```yaml
      - name: Cache Wrt Build - 工具链（...）
        id: cache-toolchain          # ← 新增
        uses: actions/cache@v4
        ...

      - name: Cache Wrt Build - 目标包（...）
        id: cache-target             # ← 新增
        uses: actions/cache@v4
        ...
```

步骤二，在「Refresh 工具链 stamp」之后追加：
```yaml
      - name: Clean Stale Caches（只清同前缀旧 key，保留本次最新的）
        run: |
          if [ "${{ steps.cache-toolchain.outputs.cache-hit }}" != "true" ]; then
            gh cache list --key "toolchain-$WRT_ARCH-$WRT_TARGET-$WRT_BRANCH-" --limit 100 \
              | cut -f 1 | while read -r ID; do gh cache delete "$ID" || true; done
            echo "toolchain caches cleanup done!"
          fi

          if [ "${{ steps.cache-target.outputs.cache-hit }}" != "true" ]; then
            gh cache list --key "$WRT_ARCH-$WRT_TARGET-$WRT_BRANCH-$WRT_CONFIG-" --limit 100 \
              | cut -f 1 | while read -r ID; do gh cache delete "$ID" || true; done
            echo "target caches cleanup done!"
          fi
```

要点：

- `gh cache list --key` 走的是 REST 的 key **前缀**过滤，所以传前缀即可（不要传完整 key）；
- **必须加 `--limit 100`**：`gh cache list` 默认只列 30 条，不加会漏；
- `GITHUB_TOKEN` 已经在 `.github/workflows/WRT-CORE.yml:50` 全局注入，`gh` 可直接用；
- 语义与上游一致：精确 key 命中 → 说明刚复用了最新的，不需要清；未命中 → 旧 key 已在失效途中，清掉。
- `actions/cache@v4` 的保存发生在 job 末尾（post 步骤），所以此刻删掉同前缀旧 key 不会误删本次新缓存。

验证方式：改一次 `Config/GENERAL.txt` 手动触发 `QCA-6.18-VIKINGYFY`，先看 `gh cache list` 的数量，跑完再看是否只剩最新的若干条。

### B2. `Clone Code` 步骤剔除国内镜像源

上游 `WRT-CORE.yml:105-109` 新增：
```sh
# GitHub Action 移除国内下载源
PROJECT_MIRRORS_FILE="./scripts/projectsmirrors.json"
if [ -f "$PROJECT_MIRRORS_FILE" ]; then
  sed -i '/.cn\//d; /tencent/d; /aliyun/d' "$PROJECT_MIRRORS_FILE"
fi
```

有 `-f` 守卫。GitHub Actions runner 在海外，`immortalwrt` 的 `projectsmirrors.json` 里的国内镜像常常超时。对 `LiBwrt/openwrt-6.x` 与 `VIKINGYFY/immortalwrt` 都适用（没有该文件就是 no-op）。建议接在本地 `WRT-CORE.yml:143` 的 `WRT_HASH` 之后。

### B3. `Config/GENERAL.txt` 的增量包：**逐条挑，不要整份覆盖**

上游 `Config/GENERAL.txt` 是 122 行，你的 132 行，两边差异很大。**整份覆盖会破坏你现在能编过的固件**，尤其：

- ⚠️ 上游无条件开启了 `CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y` / `-fibocom` / `-quectel`。而你本地 `Scripts/function.sh:77` 专门有
  ```sh
  if echo "$CI_NAME" | grep -v "6.12" > /dev/null; then
  ```
  的守卫，原因是 **LiBwrt 6.12 内核里没有这些 QMI 驱动**。抄过来会让 `QCA-6.12-LiBwrt` 这个 workflow 直接失败。
- ⚠️ 上游开启了 `CONFIG_PACKAGE_kmod-ovpn-backports=y`。这个包不是所有源码树都有，在你的 `LiBwrt 6.12` 上大概率不存在 → defconfig 阶段报未知符号。
- ⚠️ 上游把 `CONFIG_PACKAGE_kmod-nft-fullcone=y` 打开、同时删掉了你的 `CONFIG_PACKAGE_fullconenat-sonic=y`。这是**功能性替换**（fullcone 实现不同），会改变 NAT 行为，不要跟着改。
- ⚠️ 上游删掉了你所有的 `v2ray-geoip/geosite/geodata-updater`、`dae-geoip/dae-geosite`、`tcpdump`、`block-mount`、`btop`、`bash`、`bind-*`、`kmod-fs-ext4/f2fs` 行 —— 这些是你 dae/daed 路线要用的，不能删。
- ⚠️ 上游的 `CONFIG_PACKAGE_luci-app-homeproxy=y` 与你的 `luci-app-dae`/`luci-app-honk` 是两套科学上网方案，别混。
- 顺带一提：你 `Config/GENERAL.txt` 有一行笔误 `IG_PACKAGE_ucode-mod-math=y`（应为 `CONFIG_PACKAGE_ucode-mod-math=y`）。上游已经不再有这行。**建议直接删掉这行**（它本来就没被解析，等于没生效）。

**可以安全增量试的（纯新增、不冲突）**：

| 配置项 | 说明 |
|---|---|
| `CONFIG_PACKAGE_kmod-veth=y` | 虚拟以太网对，容器/网络实验常用 |
| `CONFIG_PACKAGE_kmod-wireguard=y` | WireGuard |
| `CONFIG_PACKAGE_kmod-fs-ksmbd=y` | 内核态 SMB 服务端；配合 samba4 一起用 |
| `CONFIG_PACKAGE_kmod-nvme=y`<br>`CONFIG_PACKAGE_libnvme=y`<br>`CONFIG_PACKAGE_nvme-cli=y` | NVMe 支持（亚瑟是 eMMC，无线程外设时是白装） |
| `CONFIG_PACKAGE_exfat-fsck=y`<br>`CONFIG_PACKAGE_exfat-mkfs=y` | exFAT 挂载/修复工具 |

**需要你按设备判断的（ipq60xx 无 SATA/USB3 主机口时基本是白装，且会撑大镜像）**：
`kmod-ata-ahci`、`kmod-ata-core`、`smartmontools`、`smartmontools-drivedb`、`kmod-usb3`、`kmod-usb-core`、`kmod-usb-dwc3`、`kmod-usb-xhci`、`kmod-usb-ohci`、`kmod-usb-uhci`、`kmod-usb-storage*`、`kmod-usb-net-asix*`、`kmod-usb-net-sierrawireless`。

`CONFIG_FEED_video=n` 是上游裁剪 video feed 的偏好，要不要看你是否需要该 feed。

**验证方式**：这些改动只影响 `.config`，用 B4 的 TEST 入口几十秒就能看到 `make defconfig` 是否报错。

### B4. 借用上游 `WRT-TEST.yml` 的交互形式，做一个真正的 TEST 入口

上游 `WRT-TEST.yml` 的 `workflow_dispatch` 有下拉选择：
```yaml
      CONFIG:
        default: 'MEDIATEK-WIFI-YES'
        required: true
        type: choice
        options:
          - IPQ60XX-WIFI-YES
          - ...
          - TEST
      SOURCE:
        default: 'VIKINGYFY/immortalwrt'
        type: choice
        options:
          - VIKINGYFY/immortalwrt
          - immortalwrt/immortalwrt
          - LiBwrt/openwrt-6.x
          - qosmio/openwrt-ipq
      BRANCH:
        default: 'main'
        type: string
      TEST:
        default: 'true'
        type: boolean
```

以及上游 `Custom Settings` 的 TEST 分支（`WRT-CORE.yml:169-173`）：
```sh
if [[ "${WRT_CONFIG,,}" == *"test"* ]]; then
  cat $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt >> .config
else
  cat $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt $GITHUB_WORKSPACE/Config/GENERAL.txt >> .config
fi
```

你这边的现状：已有 `.github/workflows/WRT-CORE-TEST.yml`（99 行，`ubuntu-22.04`，只做 Initialization Values + Clone Code + `generate_config`），但缺一个「带下拉选择」的入口，也缺 `WRT-CORE.yml` 里的 TEST 分支。

**建议**：新建 `.github/workflows/WRT-TEST.yml`，`workflow_dispatch` 用 `type: choice` 列出你现有的 Config 名（`IPQ60XX-NOWIFI`、`IPQ60XX-WIFI`、`IPQ807X-NOWIFI`、`IPQ807X-WIFI`、`MEDIATEK`、`ROCKCHIP`、`X86`）+ `SOURCE`/`BRANCH`，然后 `uses: ./.github/workflows/WRT-CORE-TEST.yml`，`TEST: true`。

配套在 `Scripts/function.sh` 的 `generate_config()` 里加 TEST 分支（当前是硬编码 cat 两个文件）：
```sh
if [[ "${WRT_CONFIG,,}" == *"test"* ]]; then
    cat $GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt > .config
else
    cat $GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt $GITHUB_WORKSPACE/Config/GENERAL.txt > .config
fi
```

**为什么值得做**：你现在改一个 `Config/*.txt` 要等 3 小时才知道有没有写错（比如 `kmod-ovpn-backports` 不存在）。有了这条路，几十秒就能在 `make defconfig` 阶段暴露未知符号。这也是 B3 的前置条件。

### B5. `Config/X86.txt` 补 3 行（来自上游）

```
CONFIG_PACKAGE_kmod-hwmon-w83627ehf=y
CONFIG_PACKAGE_kmod-hwmon-w83627hf=y
CONFIG_PACKAGE_kmod-w83627hf-wdt=y
```

纯增量。**但注意：你没有任何 workflow 在构建 X86**（matrix 里只有 IPQ60XX / IPQ807X，`QCA-6.12-LiBwrt.yml:35` 里的 `X86` 也没出现），所以合并后等于「未编译验证的配置」。同理 `Config/ROCKCHIP.txt`。

### B6. `Config/ROCKCHIP.txt` 上游新增的设备（如果你以后恢复 rockchip 构建）

上游比你多的设备条目：`ezpro_mrkaio-m68s`、`friendlyarm_nanopi-m5`、`friendlyarm_nanopi-r76s`、`linkease_easepi-r1`、`radxa_e20c`、`radxa_e25`、`radxa_e52c`。

---

## 4. C 级：不要合并 / 需要特别判断

### C1. ❌ 不要把 `make clean` 加进流程

上游 `WRT-CORE.yml:177` 是：
```sh
make defconfig -j$(nproc) && make clean -j$(nproc)
```
你本地 `WRT-CORE.yml:175` 只有 `make defconfig -j$(nproc)`。

我核对了 OpenWrt 官方顶层 `Makefile`（[openwrt/openwrt:Makefile](https://raw.githubusercontent.com/openwrt/openwrt/main/Makefile)）：
```make
_clean: FORCE
	rm -rf $(BUILD_DIR) $(STAGING_DIR) $(BIN_DIR) $(OUTPUT_DIR)/packages/$(ARCH_PACKAGES) $(TOPDIR)/staging_dir/packages

clean: _clean
	rm -rf $(BUILD_LOG_DIR)

targetclean: _clean
	rm -rf $(TOOLCHAIN_DIR) $(BUILD_DIR_BASE)/hostpkg $(BUILD_DIR_TOOLCHAIN)

dirclean: targetclean clean
	rm -rf $(STAGING_DIR_HOST) $(STAGING_DIR_HOSTPKG) $(BUILD_DIR_BASE)/host
	rm -rf $(TMP_DIR)
```
也就是 `make clean` 会删掉 `build_dir/` 和 `staging_dir/` —— **正是你两级缓存 restore 的两个路径**（工具链缓存的 `wrt/staging_dir/host/`、`wrt/staging_dir/toolchain-*/`，目标包缓存的 `wrt/staging_dir/target-*/`、`wrt/build_dir/`）。

上游能用是因为它的缓存策略与 `make clean` 配合方式不同。你靠增量复用，加 `make clean` 等于缓存白存、每次全量重编。**维持现状，不要合并。**

### C2. ❌ 不要用上游的 `Cache-Clean.yml`

上游新增，`cron: 0 20 * * 0` + `gh cache delete --all`。
这会把你的 `.ccache` 和 toolchain 缓存一起清掉 —— 表观上「清了空间」，实际让每周一之后的第一次构建退化成全量。要清就只清陈旧前缀（见 B1）。

### C3. ⚠️ `/mnt/build_wrt` 软链：维持你现在的注释状态

上游 `WRT-CORE.yml:85-87` 无条件执行：
```sh
sudo mkdir -p /mnt/build_wrt
sudo chown $USER:$USER /mnt/build_wrt
sudo ln -s /mnt/build_wrt $GITHUB_WORKSPACE/wrt
```
你本地 `WRT-CORE.yml:112-115` 把它整段注释掉了，而改用 `endersonmenezes/free-disk-space@v2` 腾空间。

**建议不变**。理由：一旦 `./wrt` 变成指向 `/mnt` 的符号链接，`git clone ... ./wrt/`、`actions/cache` 的 `wrt/dl/` 等 path 通配、`find ./ -maxdepth 3` 这些行为都会跟着变，属于「改了要重编一次才知道」的改动，和你「不影响功能与稳定」的前提相反。等你真的遇到磁盘不足（`df -h` 显示 `/` 剩余空间不够）再单独试。

### C4. ❌ 不要用在线版 `init_build_environment.sh` 替换内置版

上游 `WRT-CORE.yml:81` 是：
```sh
sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'
```
即不落盘、每次拉。

你的 `Scripts/init_build_environment.sh`（327 行，内含 `check_system` / `check_network` / `update_apt_source` / `install_dependencies`，支持 bionic…trixie、GCC 9–13、LLVM 18、`golang-1.26-go`）是自建内置版。

**保留内置版**：不依赖第三方站点可用性、可复现、版本可控。这是你相对上游的优势，属于「反向优化」。

唯一的维护动作：隔一段时间手动 diff 一次上游脚本，把「新系统支持」「toolchain 版本提升」这类更新手工搬回来。

### C5. ❌ 不要跟着上游删 `Packages.sh` 里的 daed/dae/honk 与 v2ray-geodata 段

上游删掉了这 3 行（你本地 `Scripts/Packages.sh:81-83`）：
```sh
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"
UPDATE_PACKAGE "luci-app-dae" "QiuSimons/luci-app-dae" "kix"
UPDATE_PACKAGE "luci-app-honk" "QiuSimons/luci-app-honk" "master"
```
并把你的收尾段整体换成了 PRIVATE.sh 钩子：
```sh
#删除官方的默认插件
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,bypass*}
rm -rf ../feeds/packages/net/v2ray-geodata
rm -rf ./feeds/packages/net/v2ray-geodata
rm -rf ./feeds/packages/v2ray-geodata
rm -rf ./v2ray-geodata
cp -r $GITHUB_WORKSPACE/package/v2ray-geodata ./
```
你的 `Config/GENERAL.txt` 开着 `luci-app-dae` / `luci-app-honk` / `dae-geoip` / `dae-geosite` / `v2ray-geodata-updater`，所以这些**都不能删**。

顺带：`Scripts/FixDaedInit.sh` 里唯一生效的 honk 版本号修补（去 `_beta63fix` 以符合 APK 规范）也是本地独有的，保留。

### C6. ❌ 不要跟着上游删 `Settings.sh` 的两条 source 修补 sed

本地 `Scripts/Settings.sh:34-35`：
```sh
sed -i 's/mirrors.vsean.net\/openwrt/mirror.nju.edu.cn\/immortalwrt/g' ./package/emortal/default-settings/files/99-default-settings-chinese
sed -i "s/DirectInterface/Interface/g" ./package/network/services/dropbear/files/dropbear.config
```
上游已经删掉了这两行（因为上游源码树里这两个文件的行为变了）。你选的源（LiBwrt 6.12 / VIKINGYFY/immortalwrt / davidtall）是否也需要这个修补，取决于你的源 —— 这是**最不该盲抄**的一类改动：删掉可能导致默认软件源或网口命名回退。

### C7. ⚠️ HomeProxy 资源预置：现在别搬

上游 `Scripts/Handles.sh` 里有约 180 行的 homeproxy 预置逻辑（`HP_DIR` 查找、从 `Loyalsoldier/surge-rules` 拉 `cncidr.txt`、从 `SagerNet/sing-geosite` 拉 `geosite-cn.srs`、下载 dashboard zip 并替换到包内，带 `hp_fetch_release_version` / `hp_download` / `hp_replace_file` 等函数）。

你的情况：`Scripts/Packages.sh:81` 的 `viking` 包组里**确实包含 `luci-app-homeproxy`**，但 `Config/GENERAL.txt:2` 是 `#CONFIG_PACKAGE_luci-app-homeproxy=y` —— **没有启用**，你实际用的是 dae/daed。

所以现在合并 = 每次构建多几个外网下载点、多一份失败面，收益为零。**等你真的启用 homeproxy 时再一并搬。** 上游那套代码的好处是每次下载失败只会 `echo "...; continuing!"` 不会中断构建，所以启用时可以放心用。

### C8. ❌ 不要照搬上游的 workflow 结构

上游是 `MTK-ALL` / `QCA-ALL` / `OWRT-ALL` 三个矩阵 + `WRT-TEST`，全部挂：
```yaml
on:
  workflow_run:
    workflows: ["Auto-Clean"]
    types: [completed]
```
（即「每周清完 release 就自动全平台编译」）。

你的现状是刻意收窄的：

- `QCA-6.18-VIKINGYFY.yml:36` 只留 `CONFIG: [IPQ60XX-NOWIFI]`（其余注释掉）；
- `QCA-6.12-LiBwrt.yml:7-10` 把 `workflow_run: Auto-Clean` 整段注释掉了（避免每周被自动触发的多平台矩阵拖垮额度）。

照搬会显著改变构建成本与触发时机 → **不要合并结构**。但 `WRT-TEST.yml` 的 choice 交互形式值得借鉴（见 B4）。

### C9. ❌ 不要跟着上游改 Config 文件名与设备清单

你是 `IPQ60XX-NOWIFI.txt` / `IPQ60XX-WIFI.txt`，上游是 `IPQ60XX-WIFI-NO.txt` / `IPQ60XX-WIFI-YES.txt`。**改名会直接断掉你 workflow matrix 的引用**，不要动。

设备清单同理：上游的 `IPQ60XX-WIFI-NO.txt` 是 19+ 个设备的「平台包」，你是围绕 `jdcloud_re-ss-01` 精选的。上游比你多的设备（仅作参考，不要覆盖）：`anysafe_e1`、`dptech_ap3000-2c`、`glinet_gl-ax1800`、`glinet_gl-axt1800`、`jdcloud_re-cs-07`、`link_nn6000-v1/v2`、`linksys_mr7500`、`philips_ly1800`、`sy_y6010`；IPQ807X 侧多 `arista_ap-c260/c360`、`dynalink_dl-wrx36`、`linksys_homewrk`、`mx4200v1/v2`、`mx4300`、`mx5300`、`mx8500`、`qnap_301w`、`tplink_tl-er2260t`、`xiaomi_ax9000-stock`。

**但有一点值得借鉴：上游 WIFI-NO 的实现机制。**
上游用 Kconfig 显式关闭：
```
CONFIG_PACKAGE_kmod-ath=n
CONFIG_PACKAGE_kmod-ath11k=n
CONFIG_PACKAGE_kmod-ath11k-ahb=n
CONFIG_PACKAGE_kmod-ath11k-pci=n
CONFIG_PACKAGE_ath11k-firmware-ipq6018=n
...
```
你（`IPQ807X-NOWIFI.txt` 里也有类似关闭项，但 `IPQ60XX-NOWIFI.txt` 只有 4 行设备选择）是主要靠 `Scripts/function.sh` 的 `remove_wifi()` 去 `sed` 源码树的 `target/linux/qualcommax/Makefile` / `target.mk` / `image/*.mk`，并 `rm -rf package/network/services/hostapd`、`package/firmware/ipq-wifi`。

`sed` 方式依赖源码树的具体写法，上游一改就可能失效；Kconfig 方式更「官方」。**建议：如果你哪天遇到 nowifi 构建里残漏了 wifi 驱动，把 `remove_wifi()` 改成「sed + 在 Config 里追加显式 `=n` 清单」双保险。**

上游 `MEDIATEK-WIFI-NO.txt` 用的是更新的官方机制（设备包做减法）：
```
CONFIG_TARGET_DEVICE_PACKAGES_mediatek_filogic_DEVICE_supergateway_s20l="-kmod-mt76 -kmod-mt76-connac ... -mt7986-wo-firmware"
```
你没有 MTK nowifi 变体，现在用不上；将来要加 MTK nowifi 时，优先用这个机制而不是再写 sed。

### C10. ⚠️ 上游 `README.md`：部分采纳

上游 README 是 64 行的「群/工具/uboot 链接 + starchart 徽章」，且把「每天 5 点自动编译」写死了。你本地 README 是围绕 **DAED + 京东云亚瑟 AX1800 Pro** 写的，信息密度更高、更贴合实际。

可以只挑这几条补充（都不影响构建）：

- 本地编译器 `https://github.com/VIKINGYFY/OWRT-Tools.git`
- 自用修改版插件 `https://github.com/VIKINGYFY/packages.git`
- U-Boot 相关链接（高通版沉心 / 小猪；联发科新版 / 官方版）

**不要**照抄「固件每天早上 5 点自动编译」（你把 `QCA-6.12-LiBwrt` 的自动触发注释掉了，实际是周更/手动），也不要抄 starchart 徽章（引用的是上游仓库的 star 曲线）。

### C11. `Auto-Clean.yml`：你的更强，不要倒退，但有一处建议

上游：`cron: 0 21 * * *`（每天）+ `releases_keep_latest: 0` 硬编码，无手动输入。
你本地：`cron: 0 20 * * 0`（每周）+ `workflow_dispatch.inputs.NUMBER`（默认 `'8'`）+ `releases_keep_latest: ${{inputs.NUMBER || '0'}}`。

**保留你的**。但注意 `${{ inputs.NUMBER || '0' }}` 在**定时触发**时 `inputs.NUMBER` 为空 → 落到 `'0'` → 每周把所有 release 都删光。如果这不是你想要的（比如想留最近几个），把兜底字面量改掉：
```yaml
          releases_keep_latest: ${{inputs.NUMBER || '3'}}
```

另外上游那套「Auto-Clean 完成后自动触发编译」的链式触发，你只在 `QCA-6.18-VIKINGYFY` 上保留着，是有意的；确认一下这符合你的预期即可。

### C12. 顺手清理死文件（反向：把上游的删除搬过来）

实测这些本地独有的文件**只在被注释掉的行里被引用**，属于死代码：

| 路径 | 引用处（均为注释） |
|---|---|
| `patches/001-fix_compile_with_ccache.patch` | `Scripts/Settings.sh:32-33`（vlmcsd patches 段已注释） |
| `patches/daed/Makefile` | `Scripts/Packages.sh:141`（daed Makefile 修补已注释） |
| `files/etc/config/argon` | 无任何引用（你 `Scripts/Handles.sh:28` 改的是 `package/luci-theme-argon/luci-app-argon-config/root/etc/config/argon`，即克隆下来的包内路径，不是这个 `files/`） |
| `package/dae/*`、`package/luci-app-dae/*` | 无任何引用（唯一 `$GITHUB_WORKSPACE/package/...` 的真引用是 `Scripts/Packages.sh:137` 的 `package/v2ray-geodata`） |

注意：CI 仓库的 `./package/` **不会**被整体拷进 OpenWrt 源码树（只有 `package/v2ray-geodata` 被显式 `cp -r`），所以 `package/dae` / `package/luci-app-dae` 是纯占位、根本不参与构建。

**建议**：确认你近期不打算恢复「daed Makefile 修补」和「vlmcsd ccache 补丁」后删掉，减少以后查引用时的干扰。`package/v2ray-geodata/*` 必须保留。

---

## 5. 建议的落地顺序

1. **A2 + A1**（`LICENSE` + `.gitattributes` + `git add --renormalize`）—— 纯文件层，一次提交。
2. **A3 + A4 + A5**（三个脚本的小改动）—— 可本地 `diy.sh` 跑一遍验证；`A4` 记得同步 `diy.sh` 的 `WRT_MARK`。
3. **B4**（TEST 入口 + `generate_config` 的 TEST 分支）—— **先做这一步**，它是后面所有 Config 改动的验证手段。
4. **B1 + B2**（缓存清理 + 镜像源裁剪）—— 在 `WRT-CORE.yml` 里，跑一次 `QCA-6.18-VIKINGYFY`（`IPQ60XX-NOWIFI`）看日志与 `gh cache list`。
5. **B3**（Config 增量包，逐条挑）—— 每次只加 2–3 项，用第 3 步的 TEST 入口验证 `make defconfig` 通过后再合并。
6. **C12**（删死文件）—— 独立提交，方便回滚。
7. **C10**（README 补充链接）—— 有空再说。

**全程避免**：`git merge upstream/main`、`git cherry-pick` 上游提交、整份覆盖 `Config/GENERAL.txt` 或 `WRT-CORE.yml`。

---

## 6. 落地记录（本次实际改动）

改动已全部应用在**工作区并已 `git add`**，可用 `git diff --cached` 复核，未提交。

### 已合并

| # | 改动 | 文件 |
|---|---|---|
| A1 | 新增 `.gitattributes`（`*.txt/*.sh/*.yml text eol=lf`）并对全仓做 `git add --renormalize` + 强制 LF 落盘；原先 7 个 CRLF 文件（`Auto-Clean.yml`、`QCA-6.12-LiBwrt.yml`、`WRT-CORE.yml`、`WRT-CORE-TEST.yml`、`Config/GENERAL.txt`、`Config/IPQ60XX-NOWIFI.txt`、`Config/IPQ60XX-WIFI.txt`）已全部转 LF | `.gitattributes` |
| A2 | 新增 MIT `LICENSE`（取自上游） | `LICENSE` |
| A3 | 末尾新增 `Scripts/PRIVATE.sh` 钩子（文件不存在即跳过） | `Scripts/Packages.sh` |
| A4 | `DaeWRT-$WRT_DATE` → `${WRT_MARK:-DaeWRT}-$WRT_DATE`；`diy.sh` 补 `export WRT_MARK='DaeWRT'` | `Scripts/Settings.sh`、`diy.sh` |
| A5 | 新增 TailScale Makefile 修补（`sed -i '/\/files/d'`） | `Scripts/Handles.sh` |
| B1 | 两个 `actions/cache@v4` 加 `id`；新增 `Prune Stale Caches` 步骤，在**编译成功且本次确定会写新缓存**后清理同前缀旧缓存 | `.github/workflows/WRT-CORE.yml` |
| B2 | `Clone Code` 增加剔除 `scripts/projectsmirrors.json` 中国内镜像源 | `.github/workflows/WRT-CORE.yml` |
| B4 | 新建 `WRT-TEST.yml` 手动入口（choice 下拉）；`generate_config` 增加 `*test*` 分支（不追加 GENERAL.txt）；`WRT-CORE-TEST.yml` 增加 `make defconfig` + `Verify Config Symbols` 符号校验（仅 warning） | `.github/workflows/WRT-TEST.yml`、`.github/workflows/WRT-CORE-TEST.yml`、`Scripts/function.sh` |
| B5/B6 | `Config/X86.txt` 补 3 个 W83627 hwmon kmod；`Config/ROCKCHIP.txt` 补 7 个设备（`ezpro_mrkaio-m68s`、`friendlyarm_nanopi-m5`、`friendlyarm_nanopi-r76s`、`linkease_easepi-r1`、`radxa_e20c/e25/e52c`，保留本地已有的 `nanopi-r6c/r6s`） | `Config/X86.txt`、`Config/ROCKCHIP.txt` |
| C10 | README 追加 OWRT-Tools、VIKINGYFY/packages 与 4 个 U-BOOT 链接（未采用上游的 QQ 群与付费中转站链接） | `README.md` |

### 顺带修掉的一个真 bug（`Scripts/Handles.sh`）

`b4a0a48`（本地 tip）把上游的 `PKG_PATH="$GITHUB_WORKSPACE/wrt/package"` 换成了
`FEEDS_PATH="./feeds"` + `PACKAGE_PATH="./package"`，但两个调用点
（`WRT-CORE.yml` 的 `cd ./wrt/package/`、`diy.sh:56` 的 `cd package/`）的 cwd 都是 `wrt/package/`，
于是 `"$PACKAGE_PATH/luci-theme-argon"` = `wrt/package/package/luci-theme-argon` —— **不存在**。
`FIX()` 的守卫是 `[ -d "$GUARD" ] || return 0`，所以 theme-argon / theme-aurora /
mini-diskmanager / natmapt **四个修补一直在静默跳过**（rust 那条因为
`wrt/package/feeds` 是指向 `wrt/feeds` 的符号链接而侥幸生效）。

现改为上游式绝对路径：

```bash
PKG_PATH="${GITHUB_WORKSPACE:+$GITHUB_WORKSPACE/wrt/package}"
[ -d "$PKG_PATH" ] || PKG_PATH="$(pwd)"
PACKAGE_PATH="$PKG_PATH"
FEEDS_PATH="$PKG_PATH/../feeds"
```

`FEEDS_PATH` 必须用 `../feeds` 而不是 `$PKG_PATH/feeds`：后者是符号链接，
而 `find` 默认（`-P`）**不跟随符号链接**，实测 `find <symlink> -type f` 输出为空。

> ⚠️ 副作用：修复后 argon 主题配色（`#31a1a1` / `0.5` / `bing` / `normal`）、
> aurora 菜单改 dropdown、mini-diskmanager 与 natmapt 菜单位置**会真正生效**，
> 固件外观与现在不同。不想要就删掉 `Scripts/Handles.sh` 里对应的 `FIX` 调用。

### 明确未合并

- **B3 整块**（`kmod-*` / `smartmontools` / `nvme` / `exfat` / `kmod-veth` / `kmod-wireguard` / `kmod-fs-ksmbd` 等 Config 增量）—— 按要求跳过，`Config/GENERAL.txt` 未做任何改动。
- 上游 `make defconfig && make clean`（会删 `BUILD_DIR`/`STAGING_DIR`，直接废掉两级缓存）。
- 上游 `Cache-Clean.yml`（`gh cache delete --all` 会连 ccache 一起清）。
- `/mnt/build_wrt` 软链（本地已注释，保持现状）。
- 在线版 `init_build_environment.sh`（保留本地 327 行内置版）。
- 上游 HomeProxy 资源预置（~180 行）。
- 上游 workflow 结构（MTK-ALL / QCA-ALL / OWRT-ALL）与 Config 改名。
- `Settings.sh` 删掉的两条 source 修补 sed（`mirrors.vsean.net` 默认源、dropbear `DirectInterface`）。

### 待你确认

- **C12 删死文件**：未执行。`patches/`、`files/etc/config/argon`、`package/dae`、`package/luci-app-dae` 确认无任何生效引用，但属于你自己的产物，删除不影响功能也不影响稳定性，因此留给你决定。要删执行：
  `git rm -r patches files package/dae package/luci-app-dae`
- **`README.md:18`** 写的「固件每天早上4点自动编译」与实际 cron 不符：`Auto-Clean.yml` 是 `0 20 * * 0`（每周一 04:00 +8），
野外触发链是 `workflow_run: Auto-Clean` → `QCA-6.18-VIKINGYFY.yml`，即**每周一次**；
且 `QCA-6.12-LiBwrt.yml` 的 `workflow_run` 段被注释，只能手动触发。未改动该句，等你确认实际调度方式。
- **`Auto-Clean.yml`** 的 `releases_keep_latest: ${{inputs.NUMBER || '0'}}` 兜底是 `0`，即无人值守时把 release 全删；若想保底留几个，把 `'0'` 改成 `'3'`。未改动。
