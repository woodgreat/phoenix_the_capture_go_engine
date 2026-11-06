#!/bin/bash
# build_linux_var.sh - Phoenix Linux 单平台编译脚本
# 用法: ./build_linux_var.sh
#
# 流程:
#   1. hust build .     生成 Rust 工程
#   2. 覆盖 .cargo/config.toml 为 Linux target
#   3. cargo build --release --target x86_64-unknown-linux-gnu
#   4. 拷出 dist/linux/phoenix 并刷新项目根目录 ./phoenix
#
# 产物:
#   - dist/linux/phoenix
#   - ./phoenix（普通文件副本，不是软链接）
#
# 注意（2026-11-06）:
#   `hust build .` 会把自己的产物写到 ./phoenix。因此 ./phoenix 必须是普通文件，
#   不能是指向 dist/linux/phoenix 的软链接，否则 hust 会顺着软链接把发布件
#   覆盖成旧二进制。
#
# 前置依赖: hust, cargo/rustc

set -e

cd "$(dirname "$0")"

DIST_DIR="dist"
mkdir -p "$DIST_DIR/linux" "$DIST_DIR/temp/linux"

# 查找 hust 生成的 Cargo 项目根目录
# 依次在以下目录中查找 Cargo.toml (限制深度避免误匹配):
#   1. $HOME/.local/bin/build     - 本机 hust 默认输出位置 (源码安装)
#   2. $HOME/.cargo/bin/build     - hust 通过 cargo 安装时的输出位置
#   3. /home/aaa/.cargo/bin/build - 历史/兼容路径
find_hust_cargo_project() {
    find $HOME/.local/bin/build $HOME/.cargo/bin/build /home/aaa/.cargo/bin/build \
        -maxdepth 2 -name "Cargo.toml" -type f 2>/dev/null | head -1 | xargs -r dirname
}

echo "=== 编译 Linux 版本 ==="

# Hust 编译生成 Rust 代码 (Cargo 项目位于 hust 输出目录, 不是当前目录)
hust build .

HUST_TEMP=$(find_hust_cargo_project)
if [ -z "$HUST_TEMP" ]; then
    echo "❌ 找不到 Hust 生成的 Cargo 项目"
    exit 1
fi
echo "Hust 生成的 Cargo 项目: $HUST_TEMP"

# 覆盖 hust 默认的 Windows config, 改为 Linux target
# 否则 cargo build 默认会产出 Windows .exe
mkdir -p "$HUST_TEMP/.cargo"
cp configs/config-linux.toml "$HUST_TEMP/.cargo/config.toml"

# 在 hust 生成的 Cargo 项目内显式编译 Linux target
(cd "$HUST_TEMP" && cargo build --release --target x86_64-unknown-linux-gnu)

# 从 target 目录拷出 Linux 可执行文件
LINUX_BIN="$HUST_TEMP/target/x86_64-unknown-linux-gnu/release/phoenix"
if [ -f "$LINUX_BIN" ]; then
    cp "$LINUX_BIN" "$DIST_DIR/linux/phoenix"
    chmod +x "$DIST_DIR/linux/phoenix"
    # 普通文件副本（原因见文件头注释）
    rm -f ./phoenix
    cp "$DIST_DIR/linux/phoenix" ./phoenix
    chmod +x ./phoenix
    echo "✅ Linux 版本已放置到 $DIST_DIR/linux/phoenix"
else
    echo "❌ 找不到 Linux 编译产物: $LINUX_BIN"
    exit 1
fi
