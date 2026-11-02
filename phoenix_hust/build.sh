#!/bin/bash
# build.sh - Phoenix 双平台编译脚本
# 用法: ./build.sh [linux|windows|all]

cd "$(dirname "$0")"

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
        
        # Hust 编译生成 Rust 代码
        hust build .
        
        # 获取 Hust 生成的 Cargo 项目路径
        HUST_TEMP=$(find /home/aaa/.cargo/bin/build -name "Cargo.toml" -type f 2>/dev/null | head -1 | xargs dirname)
        
        if [ -z "$HUST_TEMP" ]; then
            echo "❌ 找不到 Hust 生成的 Cargo 项目"
            exit 1
        fi
        
        echo "Hust 生成的 Cargo 项目: $HUST_TEMP"
        
        # 复制配置文件到 Cargo 项目
        cp configs/config-windows.toml "$HUST_TEMP/.cargo/config.toml" 2>/dev/null || {
            mkdir -p "$HUST_TEMP/.cargo"
            cp configs/config-windows.toml "$HUST_TEMP/.cargo/config.toml"
        }
        
        # 用 Cargo 交叉编译 Windows
        cd "$HUST_TEMP"
        cargo build --release --target x86_64-pc-windows-gnu
        
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
