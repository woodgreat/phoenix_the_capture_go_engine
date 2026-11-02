#!/usr/bin/env python3
"""
Phoenix AI 1-10 级同级对弈测试
每级一盘，共 10 盘
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
output_file = os.path.join(RECORD_DIR, f"selfplay_lv1-10_{timestamp}.txt")

def log(msg, f):
    print(msg)
    f.write(msg + "\n")
    f.flush()

def send_cmd(child, cmd, timeout=5):
    """发送命令并读取完整响应"""
    child.sendline(cmd)
    child.expect("\r?\n\r?\n", timeout=timeout)
    return child.before.decode()

def get_captures(child):
    """获取吃子数"""
    response = send_cmd(child, "sc")
    black_match = re.search(r'black=(\d+)', response)
    white_match = re.search(r'white=(\d+)', response)
    black = int(black_match.group(1)) if black_match else 0
    white = int(white_match.group(1)) if white_match else 0
    return black, white

def get_result(child):
    """获取游戏结果，使用 board_status 检测终局"""
    response = send_cmd(child, "board_status").strip()
    if "= 0" in response or "gaming" in response:
        return "gaming", None
    elif "= 1 B" in response or "1 B" in response:
        return "over", "B"
    elif "= 1 W" in response or "1 W" in response:
        return "over", "W"
    elif "= 2" in response or "white" in response.lower():
        return "over", "W"
    else:
        return "unknown", None

def play_one_game(level, game_num, f, max_moves=170):
    """进行一局对弈"""
    log(f"\n{'='*50}", f)
    log(f"第 {game_num} 局: LV{level} vs LV{level}", f)
    log(f"{'='*50}", f)
    
    child = pexpect.spawn(ENGINE_PATH, cwd=WORK_DIR, timeout=30)
    
    # 设置
    send_cmd(child, "boardsize 13")
    send_cmd(child, f"wood_ai_level {level}")
    send_cmd(child, "usb")
    
    move_num = 0
    game_over = False
    winner = None
    black_caps = 0
    white_caps = 0
    
    while not game_over and move_num < max_moves:
        # 黑棋走
        send_cmd(child, "gb")
        move_num += 1
        
        black_caps, white_caps = get_captures(child)
        status, winner = get_result(child)
        
        if status == "over":
            log(f"第 {move_num} 手后: 游戏结束!", f)
            game_over = True
            break
        
        # 白棋走
        send_cmd(child, "gw")
        move_num += 1
        
        black_caps, white_caps = get_captures(child)
        status, winner = get_result(child)
        
        if status == "over":
            log(f"第 {move_num} 手后: 游戏结束!", f)
            game_over = True
            break
        
        # 每 20 手记录
        if move_num % 20 == 0:
            log(f"  ... {move_num} 手, 黑 {black_caps} 子, 白 {white_caps} 子 ...", f)
    
    # 结果
    log(f"\n结果: {move_num} 手", f)
    log(f"黑吃 {black_caps} 子, 白吃 {white_caps} 子", f)
    
    if winner == "B":
        log(f"获胜: 黑棋", f)
    elif winner == "W":
        log(f"获胜: 白棋", f)
    else:
        # 棋盘满，吃子多者胜，相同白胜
        if black_caps > white_caps:
            log(f"棋盘满: 黑胜 ({black_caps} > {white_caps})", f)
            winner = "B"
        else:
            log(f"棋盘满: 白胜 ({white_caps} >= {black_caps})", f)
            winner = "W"
    
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
        log("Phoenix AI 1-10 级同级对弈测试", f)
        log("="*50, f)
        log("规则: 扭十字开局, 黑6子胜, 白5子胜, 棋盘满吃子多者胜", f)
        log("="*50, f)
        
        results = []
        
        # 测试 LV1 到 LV10
        for level in range(1, 11):
            result = play_one_game(level, level, f)
            results.append(result)
            log("", f)
        
        # 总结
        log("\n" + "="*50, f)
        log("测试总结", f)
        log("="*50, f)
        
        black_wins = 0
        white_wins = 0
        
        for r in results:
            level = r["level"]
            moves = r["moves"]
            winner = r["winner"]
            black_caps = r["black_caps"]
            white_caps = r["white_caps"]
            
            winner_str = "黑胜" if winner == "B" else "白胜"
            log(f"LV{level:2d}: {moves:3d}手, {winner_str}, 黑吃{black_caps}子, 白吃{white_caps}子", f)
            
            if winner == "B":
                black_wins += 1
            else:
                white_wins += 1
        
        log(f"\n总计: 黑胜 {black_wins} 盘, 白胜 {white_wins} 盘", f)
        
        if black_wins > white_wins:
            log("结论: 黑棋优势", f)
        elif white_wins > black_wins:
            log("结论: 白棋优势", f)
        else:
            log("结论: 黑白平衡", f)
        
        log(f"\n结果保存到: {output_file}", f)
    
    print(f"\n结果已保存到: {output_file}")

if __name__ == "__main__":
    main()
