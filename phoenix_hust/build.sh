#!/bin/bash
# build.sh - Phoenix 双平台编译脚本
# 用法: ./build.sh [linux|windows|all]
#
# 功能说明:
#   - linux:  调用 hust 编译生成 Rust 代码并产出 Linux 可执行文件 ./phoenix
#   - windows: 调用 hust 生成 Rust 代码后, 用 MinGW (x86_64-pc-windows-gnu)
#              通过 cargo 交叉编译 Windows 可执行文件 phoenix.exe
#   - all:    依次编译 Linux 与 Windows 两个平台
#
# 产物路径:
#   - dist/linux/phoenix
#   - dist/windows/phoenix.exe
#
# 前置依赖:
#   - hust (Hust 语言编译器)
#   - cargo / rustc (Windows 交叉编译时需要)
#   - mingw-w64 (Windows 交叉编译时需要: sudo apt-get install mingw-w64)

cd "$(dirname "$0")"

# 目标平台, 默认为 linux
PLATFORM=${1:-linux}
DIST_DIR="dist"
TEMP_DIR="$DIST_DIR/temp"

# 创建目录结构
mkdir -p "$DIST_DIR/linux" "$DIST_DIR/windows" "$TEMP_DIR/linux" "$TEMP_DIR/windows"

case "$PLATFORM" in
    linux)
        echo "=== 编译 Linux 版本 ==="
        
        # Hust 编译生成 Rust 代码
        hust build .
        
        # 复制编译产物
        if [ -f "./phoenix" ]; then
            cp "./phoenix" "$DIST_DIR/linux/phoenix"
            chmod +x "$DIST_DIR/linux/phoenix"
            echo "✅ Linux 版本已放置到 $DIST_DIR/linux/phoenix"
        else
            echo "❌ 找不到编译产物 ./phoenix"
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
        
        # 获取 Hust 生成的 Cargo 项目路径
        # 依次在以下目录中查找 Cargo.toml (限制深度避免误匹配):
        #   1. $HOME/.local/bin/build   - 本机 hust 默认输出位置 (源码安装)
        #   2. $HOME/.cargo/bin/build   - hust 通过 cargo 安装时的输出位置
        #   3. /home/aaa/.cargo/bin/build - 历史/兼容路径
        # 取第一个匹配项的父目录作为 Cargo 项目根目录
        # -maxdepth 2 限制搜索深度, -r 防止无匹配时 xargs 误执行
        HUST_TEMP=$(find $HOME/.local/bin/build $HOME/.cargo/bin/build /home/aaa/.cargo/bin/build -maxdepth 2 -name "Cargo.toml" -type f 2>/dev/null | head -1 | xargs -r dirname)
        
        if [ -z "$HUST_TEMP" ]; then
            echo "❌ 找不到 Hust 生成的 Cargo 项目"
            exit 1
        fi
        
        echo "Hust 生成的 Cargo 项目: $HUST_TEMP"
        
        # 复制 Windows 交叉编译配置 (MinGW 链接器设置) 到 Cargo 项目
        # 若 .cargo 目录不存在则先创建
        cp configs/config-windows.toml "$HUST_TEMP/.cargo/config.toml" 2>/dev/null || {
            mkdir -p "$HUST_TEMP/.cargo"
            cp configs/config-windows.toml "$HUST_TEMP/.cargo/config.toml"
        }
        
        # 在 Hust 生成的 Cargo 项目内执行交叉编译
        cd "$HUST_TEMP"
        cargo build --release --target x86_64-pc-windows-gnu
        
        # 将编译出的 Windows 可执行文件拷回 dist 目录
        # $OLDPWD 是脚本原始工作目录 (phoenix_hust 根目录)
        if [ -f "target/x86_64-pc-windows-gnu/release/phoenix.exe" ]; then
            cp "target/x86_64-pc-windows-gnu/release/phoenix.exe" "$OLDPWD/$DIST_DIR/windows/phoenix.exe"
            echo "✅ Windows 版本已放置到 $DIST_DIR/windows/phoenix.exe"
        else
            echo "❌ 找不到 Windows 编译产物"
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
