#!/usr/bin/env python3
"""
批量修复 ai.hust 中所有等级的 pass 问题
"""

import re

# 读取文件
with open('/home/aaa/workspace/phoenix_the_capture_go_engine/phoenix_the_capture_go_engine/phoenix_hust/ai.hust', 'r') as f:
    content = f.read()

# 修复模板
fix_template = '''        if ({var} < 0) {{
            // Wood rules forbid passing: fill any empty point (random)
            i32[169] all_empty = {{0}};
            i32 n_all = 0;
            for (i32 x = 0; x < 13; x++) {{
                for (i32 y = 0; y < 13; y++) {{
                    if (b2.get(x, y) == 0) {{
                        all_empty[n_all] = x * 13 + y;
                        n_all = n_all + 1;
                    }}
                }}
            }}
            if (n_all > 0) {{
                {var} = all_empty[b2.rand_below(n_all)];
                debug_log_i32(1, "{level}", "filling random", {var});
            }} else {{
                this.last_x = -1;
                this.last_y = -1;
                return b2;
            }}
        }}'''

# 查找所有需要修复的位置
pattern = r'        if (best_enc < 0|mv < 0) \{\n            this\.last_x = -1;\n            this\.last_y = -1;\n            return b2;\n        \}'

# 统计修复数量
fixes = 0

def replace_match(match):
    global fixes
    fixes += 1
    
    # 确定变量名和等级
    var = 'mv' if 'mv < 0' in match.group(0) else 'best_enc'
    
    # 从上下文中确定等级
    # 查找前面的 debug_log 或类定义
    start = max(0, match.start() - 2000)
    context = content[start:match.start()]
    
    level_match = re.search(r'"L(\d+)"', context)
    if level_match:
        level = f"L{level_match.group(1)}"
    else:
        level = "AI"
    
    return fix_template.format(var=var, level=level)

# 执行修复
new_content = re.sub(pattern, replace_match, content)

# 写回文件
with open('/home/aaa/workspace/phoenix_the_capture_go_engine/phoenix_the_capture_go_engine/phoenix_hust/ai.hust', 'w') as f:
    f.write(new_content)

print(f"修复了 {fixes} 处 pass 问题")
