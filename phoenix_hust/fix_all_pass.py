#!/usr/bin/env python3
"""
批量修复 ai.hust 中所有等级的 pass 问题
"""

import re

# 读取文件
with open('/home/aaa/workspace/phoenix_the_capture_go_engine/phoenix_the_capture_go_engine/phoenix_hust/ai.hust', 'r') as f:
    lines = f.readlines()

# 修复计数
fixes = 0

# 遍历每一行
for i, line in enumerate(lines):
    if 'if (best_enc < 0) {' in line:
        # 检查下一行是否是 pass 逻辑
        if i + 1 < len(lines) and 'this.last_x = -1;' in lines[i + 1]:
            # 找到这个 if 块的结束位置
            j = i
            while j < len(lines) and '}' not in lines[j]:
                j += 1
            
            # 确定等级（向前查找 debug_log 或类定义）
            level = "AI"
            for k in range(max(0, i - 100), i):
                if '"L' in lines[k]:
                    match = re.search(r'"L(\d+)"', lines[k])
                    if match:
                        level = f"L{match.group(1)}"
                        break
            
            # 替换这个块
            indent = '        '
            new_block = [
                f'{indent}if (best_enc < 0) {{\n',
                f'{indent}    // Wood rules forbid passing: fill any empty point (random)\n',
                f'{indent}    i32[169] all_empty = {{0}};\n',
                f'{indent}    i32 n_all = 0;\n',
                f'{indent}    for (i32 x = 0; x < 13; x++) {{\n',
                f'{indent}        for (i32 y = 0; y < 13; y++) {{\n',
                f'{indent}            if (b2.get(x, y) == 0) {{\n',
                f'{indent}                all_empty[n_all] = x * 13 + y;\n',
                f'{indent}                n_all = n_all + 1;\n',
                f'{indent}            }}\n',
                f'{indent}        }}\n',
                f'{indent}    }}\n',
                f'{indent}    if (n_all > 0) {{\n',
                f'{indent}        best_enc = all_empty[b2.rand_below(n_all)];\n',
                f'{indent}        debug_log_i32(1, "{level}", "filling random", best_enc);\n',
                f'{indent}    }} else {{\n',
                f'{indent}        this.last_x = -1;\n',
                f'{indent}        this.last_y = -1;\n',
                f'{indent}        return b2;\n',
                f'{indent}    }}\n',
                f'{indent}}}\n'
            ]
            
            # 替换
            lines[i:j+1] = new_block
            fixes += 1
            print(f"修复了第 {i+1} 行 ({level})")

# 写回文件
with open('/home/aaa/workspace/phoenix_the_capture_go_engine/phoenix_the_capture_go_engine/phoenix_hust/ai.hust', 'w') as f:
    f.writelines(lines)

print(f"\n总共修复了 {fixes} 处 pass 问题")
