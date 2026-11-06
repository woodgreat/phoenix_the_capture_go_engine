#!/bin/bash
# build.sh - Phoenix 编译入口（转发到单平台脚本）
# 用法: ./build.sh [linux|windows|all]
#
#   linux   -> ./build_linux_var.sh     仅编译 Linux
#   windows -> ./build_windows_var.sh   仅编译 Windows（MinGW 交叉编译）
#   all     -> 依次执行上面两个脚本
#
# 单平台脚本也可以直接运行:
#   ./build_linux_var.sh
#   ./build_windows_var.sh
#
# 产物:
#   - dist/linux/phoenix
#   - dist/windows/phoenix.exe

set -e

cd "$(dirname "$0")"

PLATFORM=${1:-linux}

case "$PLATFORM" in
    linux)
        exec ./build_linux_var.sh
        ;;
    windows)
        exec ./build_windows_var.sh
        ;;
    all)
        echo "=== 编译所有平台 ==="
        ./build_linux_var.sh
        ./build_windows_var.sh
        ;;
    *)
        echo "用法: $0 [linux|windows|all]"
        exit 1
        ;;
esac
