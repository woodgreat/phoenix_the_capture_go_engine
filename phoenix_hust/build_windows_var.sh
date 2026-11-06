#!/bin/bash
# build_windows_var.sh - Phoenix Windows 单平台交叉编译脚本
# 用法: ./build_windows_var.sh
#
# 流程:
#   1. 检查 MinGW (x86_64-w64-mingw32-gcc)
#   2. hust build .     生成 Rust 工程
#   3. 覆盖 .cargo/config.toml 为 Windows target + MinGW 链接器
#   4. cargo build --release --target x86_64-pc-windows-gnu
#   5. 拷出 dist/windows/phoenix.exe
#
# 产物:
#   - dist/windows/phoenix.exe
#
# 注意（2026-11-06）:
#   `hust build .` 会把自己的产物写到 ./phoenix（宿主二进制）。若 dist/linux 下
#   已有发布件，脚本结束时会把 ./phoenix 恢复成它，避免宿主快捷文件变旧。
#
# 前置依赖: hust, cargo/rustc, mingw-w64
#   sudo apt-get install mingw-w64

set -e

cd "$(dirname "$0")"

DIST_DIR="dist"
mkdir -p "$DIST_DIR/windows" "$DIST_DIR/temp/windows"

# 查找 hust 生成的 Cargo 项目根目录
# 依次在以下目录中查找 Cargo.toml (限制深度避免误匹配):
#   1. $HOME/.local/bin/build     - 本机 hust 默认输出位置 (源码安装)
#   2. $HOME/.cargo/bin/build     - hust 通过 cargo 安装时的输出位置
#   3. /home/aaa/.cargo/bin/build - 历史/兼容路径
find_hust_cargo_project() {
    find $HOME/.local/bin/build $HOME/.cargo/bin/build /home/aaa/.cargo/bin/build \
        -maxdepth 2 -name "Cargo.toml" -type f 2>/dev/null | head -1 | xargs -r dirname
}

echo "=== 编译 Windows 版本 ==="
echo "注意: 需要安装 MinGW (sudo apt-get install mingw-w64)"

# 检查 MinGW
if ! which x86_64-w64-mingw32-gcc > /dev/null 2>&1; then
    echo "❌ 错误: 未找到 x86_64-w64-mingw32-gcc"
    echo "请先安装: sudo apt-get install mingw-w64"
    exit 1
fi

# 调用 hust 编译当前目录, 生成 Rust 项目
hust build .

HUST_TEMP=$(find_hust_cargo_project)
if [ -z "$HUST_TEMP" ]; then
    echo "❌ 找不到 Hust 生成的 Cargo 项目"
    exit 1
fi
echo "Hust 生成的 Cargo 项目: $HUST_TEMP"

# 复制 Windows 交叉编译配置 (MinGW 链接器设置) 到 Cargo 项目
mkdir -p "$HUST_TEMP/.cargo"
cp configs/config-windows.toml "$HUST_TEMP/.cargo/config.toml"

# 在 Hust 生成的 Cargo 项目内执行交叉编译
(cd "$HUST_TEMP" && cargo build --release --target x86_64-pc-windows-gnu)

# 从 target 目录拷出 Windows 可执行文件
WINDOWS_BIN="$HUST_TEMP/target/x86_64-pc-windows-gnu/release/phoenix.exe"
if [ -f "$WINDOWS_BIN" ]; then
    cp "$WINDOWS_BIN" "$DIST_DIR/windows/phoenix.exe"
    echo "✅ Windows 版本已放置到 $DIST_DIR/windows/phoenix.exe"
    # hust 刚把宿主产物写到 ./phoenix；若已有 Linux 发布件，恢复它。
    if [ -f "$DIST_DIR/linux/phoenix" ]; then
        rm -f ./phoenix
        cp "$DIST_DIR/linux/phoenix" ./phoenix
        chmod +x ./phoenix
    fi
else
    echo "❌ 找不到 Windows 编译产物: $WINDOWS_BIN"
    exit 1
fi
