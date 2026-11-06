#!/bin/bash
# build.sh - Phoenix 双平台编译脚本
# 用法: ./build.sh [linux|windows|all]
#
# 功能说明:
#   - linux:   调用 hust 编译生成 Rust 代码, 用 cargo 产出 Linux 可执行文件 ./phoenix
#              (x86_64-unknown-linux-gnu, 默认 GNU 链接器 cc)
#   - windows: 调用 hust 生成 Rust 代码后, 用 MinGW (x86_64-pc-windows-gnu)
#              通过 cargo 交叉编译 Windows 可执行文件 phoenix.exe
#   - all:     依次编译 Linux 与 Windows 两个平台
#
# 产物路径:
#   - dist/linux/phoenix
#   - dist/windows/phoenix.exe
#
# 设计要点:
#   - hust build 仅生成 Rust 项目源码, 不直接产出可执行文件
#     实际 Cargo 项目位于 $HOME/.local/bin/build/temp/ (本机 hust 默认输出)
#   - hust 生成的 .cargo/config.toml 默认 target 是 Windows,
#     因此脚本必须显式用 --config 或先覆盖该文件, 否则 cargo build 默认产 Windows .exe
#   - Linux 分支不依赖项目根目录的 ./phoenix 软链接, 而是从 target/<triple>/release/ 直接拷出
#
# 前置依赖:
#   - hust (Hust 语言编译器)
#   - cargo / rustc
#   - mingw-w64 (Windows 交叉编译时需要: sudo apt-get install mingw-w64)

set -e

cd "$(dirname "$0")"

# 目标平台, 默认为 linux
PLATFORM=${1:-linux}
DIST_DIR="dist"
TEMP_DIR="$DIST_DIR/temp"

# 创建目录结构
mkdir -p "$DIST_DIR/linux" "$DIST_DIR/windows" "$TEMP_DIR/linux" "$TEMP_DIR/windows"

# 查找 hust 生成的 Cargo 项目根目录
# 依次在以下目录中查找 Cargo.toml (限制深度避免误匹配):
#   1. $HOME/.local/bin/build   - 本机 hust 默认输出位置 (源码安装)
#   2. $HOME/.cargo/bin/build   - hust 通过 cargo 安装时的输出位置
#   3. /home/aaa/.cargo/bin/build - 历史/兼容路径
# 取第一个匹配项的父目录作为 Cargo 项目根目录
# -maxdepth 2 限制搜索深度, -r 防止无匹配时 xargs 误执行
find_hust_cargo_project() {
    find $HOME/.local/bin/build $HOME/.cargo/bin/build /home/aaa/.cargo/bin/build \
        -maxdepth 2 -name "Cargo.toml" -type f 2>/dev/null | head -1 | xargs -r dirname
}

case "$PLATFORM" in
    linux)
        echo "=== 编译 Linux 版本 ==="

        # Hust 编译生成 Rust 代码 ( Cargo 项目位于 hust 输出目录, 不是当前目录 )
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
            # 2026-11-06 修复: 这里以前建的是指向 dist/linux/phoenix 的软链接,
            # 但 `hust build .` 会把自己的产物写到 ./phoenix, 顺着软链接把
            # dist/linux/phoenix 覆盖成旧二进制。`build.sh all` 时表现为
            # 编完 windows 后 Linux 发布件变回旧版本。改为普通文件副本。
            rm -f ./phoenix
            cp "$DIST_DIR/linux/phoenix" ./phoenix
            chmod +x ./phoenix
            echo "✅ Linux 版本已放置到 $DIST_DIR/linux/phoenix"
        else
            echo "❌ 找不到 Linux 编译产物: $LINUX_BIN"
            exit 1
        fi
        ;;

    windows)
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
        # 若 .cargo 目录不存在则先创建
        mkdir -p "$HUST_TEMP/.cargo"
        cp configs/config-windows.toml "$HUST_TEMP/.cargo/config.toml"

        # 在 Hust 生成的 Cargo 项目内执行交叉编译
        (cd "$HUST_TEMP" && cargo build --release --target x86_64-pc-windows-gnu)

        # 从 target 目录拷出 Windows 可执行文件
        WINDOWS_BIN="$HUST_TEMP/target/x86_64-pc-windows-gnu/release/phoenix.exe"
        if [ -f "$WINDOWS_BIN" ]; then
            cp "$WINDOWS_BIN" "$DIST_DIR/windows/phoenix.exe"
            echo "✅ Windows 版本已放置到 $DIST_DIR/windows/phoenix.exe"
            # `hust build .` 会把宿主产物写到 ./phoenix; 恢复了普通文件之后
            # 这里再同步一次 Linux 发布件, 保证 all 构建后两份产物都对。
            if [ -f "$DIST_DIR/linux/phoenix" ]; then
                rm -f ./phoenix
                cp "$DIST_DIR/linux/phoenix" ./phoenix
                chmod +x ./phoenix
            fi
        else
            echo "❌ 找不到 Windows 编译产物: $WINDOWS_BIN"
            exit 1
        fi
        ;;

    all)
        echo "=== 编译所有平台 ==="
        $0 linux
        $0 windows
        ;;
    *)
        echo "用法: $0 [linux|windows|all]"
        exit 1
        ;;
esac
