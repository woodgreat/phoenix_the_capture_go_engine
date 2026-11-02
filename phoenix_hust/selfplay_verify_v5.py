#!/usr/bin/env python3
"""
Phoenix AI 自对弈测试 - 修复版 v5
正确解析引擎输出格式（= 开头，\n\n 结束）
"""

import pexpect
import time
import os
import re
from datetime import datetime

WORK_DIR = "/home/aaa/workspace/phoenix_the_capture_go_engine/phoenix_the_capture_go_engine/phoenix_hust"
ENGINE_PATH = os.path.join(WORK_DIR, "phoenix")
RECORD_DIR = os.path.join(WORK_DIR, "record")

os.makedirs(RECORD_DIR, exist_ok=True)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_file = os.path.join(RECORD_DIR, f"selfplay_test_{timestamp}.txt")

def log(msg, f):
    print(msg)
    f.write(msg + "\n")
    f.flush()

def send_cmd(child, cmd, timeout=5):
    """发送命令并读取完整响应（到 \n\n 结束）"""
    child.sendline(cmd)
    # 等待响应结束（空行）
    child.expect("\r?\n\r?\n", timeout=timeout)
    return child.before.decode()

def get_captures(child):
    """获取吃子数，返回 (black, white)"""
    response = send_cmd(child, "sc")
    # 从响应中解析 black=X white=Y
    black_match = re.search(r'black=(\d+)', response)
    white_match = re.search(r'white=(\d+)', response)
    
    black = int(black_match.group(1)) if black_match else 0
    white = int(white_match.group(1)) if white_match else 0
    return black, white

def get_result(child):
    """获取游戏结果，返回 (status, winner)"""
    response = send_cmd(child, "rw").strip()
    
    if "gaming" in response:
        return "gaming", None
    elif "black" in response.lower():
        return "over", "B"
    elif "white" in response.lower():
        return "over", "W"
    else:
        return "unknown", None

def play_one_game(level, game_num, f, max_moves=20):
    """进行一局对弈"""
    log(f"\n{'='*50}", f)
    log(f"第 {game_num} 局: LV{level} vs LV{level} (最多 {max_moves} 手)", f)
    log(f"{'='*50}", f)
    
    child = pexpect.spawn(ENGINE_PATH, cwd=WORK_DIR, timeout=30)
    
    # 设置棋盘和等级
    send_cmd(child, "boardsize 13")
    send_cmd(child, f"wood_ai_level {level}")
    send_cmd(child, "usb")
    
    log("\n扭十字开局已设置", f)
    
    move_num = 0
    game_over = False
    winner = None
    black_caps = 0
    white_caps = 0
    
    while not game_over and move_num < max_moves:
        # 黑棋走
        send_cmd(child, "gb")
        move_num += 1
        
        # 获取吃子数
        black_caps, white_caps = get_captures(child)
        
        # 检查结果
        status, winner = get_result(child)
        if status == "over":
            log(f"\n第 {move_num} 手后: 游戏结束!", f)
            game_over = True
            break
        
        # 白棋走
        send_cmd(child, "gw")
        move_num += 1
        
        # 获取吃子数
        black_caps, white_caps = get_captures(child)
        
        # 检查结果
        status, winner = get_result(child)
        if status == "over":
            log(f"\n第 {move_num} 手后: 游戏结束!", f)
            game_over = True
            break
        
        # 每 4 手记录一次
        if move_num % 4 == 0:
            log(f"  ... {move_num} 手, 黑吃 {black_caps} 子, 白吃 {white_caps} 子 ...", f)
    
    # 最终结果
    log(f"\n{'='*50}", f)
    log("对局结束:", f)
    log(f"{'='*50}", f)
    log(f"总手数: {move_num}", f)
    log(f"黑棋吃子: {black_caps}", f)
    log(f"白棋吃子: {white_caps}", f)
    
    if winner == "B":
        log(f"结果: 黑棋胜 (吃 {black_caps} 子)", f)
    elif winner == "W":
        log(f"结果: 白棋胜 (吃 {white_caps} 子)", f)
    else:
        log(f"结果: 达到 {max_moves} 手上限，游戏进行中", f)
    
    child.sendline("quit")
    child.close()
    
    return {
        "level": level,
        "moves": move_num,
        "winner": winner,
        "black_caps": black_caps,
        "white_caps": white_caps
    }

def main():
    with open(output_file, "w", encoding="utf-8") as f:
        log("Phoenix AI 自对弈测试 (20手验证)", f)
        log("="*50, f)
        log("规则: 扭十字开局, 黑6子胜, 白5子胜", f)
        log("="*50, f)
        
        # 测试 LV3，20 手
        result = play_one_game(3, 1, f, max_moves=20)
        
        log("\n" + "="*50, f)
        log("验证结果", f)
        log("="*50, f)
        log(f"LV{result['level']}: {result['moves']}手", f)
        log(f"黑吃 {result['black_caps']} 子, 白吃 {result['white_caps']} 子", f)
        if result['winner']:
            log(f"获胜方: {'黑棋' if result['winner'] == 'B' else '白棋'}", f)
        else:
            log("结果: 20手内未分胜负", f)
        
        log(f"\n结果保存到: {output_file}", f)
    
    print(f"\n结果已保存到: {output_file}")

if __name__ == "__main__":
    main()
