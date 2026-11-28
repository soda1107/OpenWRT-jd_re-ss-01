#!/usr/bin/env bash
# honk-core 交叉编译工具链，版本对齐 daeuniverse/honk 的 pins.env 与 rust-toolchain.toml

set -euo pipefail

BPF_LINKER_VERSION="0.11.0"
BPF_LINKER_SHA256="10f62ba9ab7e544d538370552660efcb4f1a19153d5752bbf0f6b51f3bada450"
ZIG_VERSION="0.17.1"
ZIG_SHA256="3581863e3cbcfd0fce0efc682ce7e9e93da96668a977791d356a26d2a7e9b17a"
RUST_CHANNEL="1.100.0"
EBPF_CHANNEL="nightly-2026-10-20"

# 装到全局路径，编译阶段以 runner 身份运行
CARGO_HOME="/usr/local/cargo"
RUSTUP_HOME="/usr/local/rustup"
export CARGO_HOME RUSTUP_HOME
export PATH="$CARGO_HOME/bin:$PATH"

CURL_OPTS=(-fsSL --retry 3 --retry-delay 5 --connect-timeout 15)

echo "[INFO] Installing honk-core toolchain..."
# file: build_honk_core.sh 用 file -b 校验产物是否为静态 ELF，无守卫
# binutils: 提供 readelf，build_honk_core.sh 用它检查 eBPF 对象的 .BTF 段
apt install -y libbpf-dev cmake libclang-dev zstd file binutils

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR"

curl "${CURL_OPTS[@]}" -o bpf-linker.tar.zst \
	"https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"
echo "$BPF_LINKER_SHA256  bpf-linker.tar.zst" | sha256sum -c -
tar --zstd -xf bpf-linker.tar.zst -C /usr/local/bin
chmod 0755 /usr/local/bin/bpf-linker

curl "${CURL_OPTS[@]}" -o zig.tar.xz \
	"https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz"
echo "$ZIG_SHA256  zig.tar.xz" | sha256sum -c -
tar -Jxf zig.tar.xz
# Zig 从可执行文件所在目录反推 lib/（含标准库与内置头文件），只拷二进制会报
# "unable to find zig installation directory from executable path"；必须整目录安装后做软链。
ZIG_PREFIX="/opt/zig-${ZIG_VERSION}"
rm -rf "$ZIG_PREFIX"
mv "zig-x86_64-linux-${ZIG_VERSION}" "$ZIG_PREFIX"
ln -svf "$ZIG_PREFIX/zig" /usr/local/bin/zig
# 冒烟测试：zig version 只证明二进制存在，zig cc 才能证明 lib/ 与目标工具链可用
zig version
printf 'int main(void) { return 0; }\n' > "$TMP_DIR/zig-smoke.c"
zig cc -target aarch64-linux-musl -c "$TMP_DIR/zig-smoke.c" -o "$TMP_DIR/zig-smoke.o"
echo "[INFO] zig cc cross-compile smoke test passed"

if [ ! -x "$CARGO_HOME/bin/cargo" ]; then
	# free-disk-space 可能清掉自带 rust，残留目录会让 rustup-init 拒绝安装
	rm -rf "${CARGO_HOME}" "${RUSTUP_HOME}"
	curl "${CURL_OPTS[@]}" -o rustup-init.sh "https://sh.rustup.rs"
	sh rustup-init.sh -y --profile minimal --default-toolchain none --no-modify-path
fi
rustup toolchain install "$RUST_CHANNEL" --profile minimal
rustup toolchain install "$EBPF_CHANNEL" --profile minimal --component rust-src,llvm-tools
rustup target add aarch64-unknown-linux-musl --toolchain "$RUST_CHANNEL"
rustup default "$RUST_CHANNEL" >/dev/null

cargo install --locked cargo-zigbuild

# 编译阶段要能写缓存
chmod -R a+rwX "$CARGO_HOME" "$RUSTUP_HOME"
ln -svf "$CARGO_HOME/bin/cargo-zigbuild" /usr/local/bin/cargo-zigbuild

echo "[SUCCESS] honk toolchain ready (bpf-linker $BPF_LINKER_VERSION, zig $ZIG_VERSION)."
