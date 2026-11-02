#!/usr/bin/env python3
"""
Phoenix AI 逐级自对弈测试 - 修复版
遵循 Wood 吃子棋规则：
- 扭十字开局
- 无平局，吃子数相同判白胜
- 无 pass，必须落子
- 黑吃 6 子胜，白吃 5 子胜
"""

import pexpect
import time
import os
from datetime import datetime

WORK_DIR = "/home/aaa/workspace/phoenix_the_capture_go_engine/phoenix_the_capture_go_engine/phoenix_hust"
ENGINE_PATH = os.path.join(WORK_DIR, "phoenix")
RECORD_DIR = os.path.join(WORK_DIR, "record")

os.makedirs(RECORD_DIR, exist_ok=True)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_file = os.path.join(RECORD_DIR, f"selfplay_levels_test_{timestamp}.txt")

def log(msg, f):
    print(msg)
    f.write(msg + "\n")
    f.flush()

def setup_board(child):
    """设置扭十字开局 - 使用 usb 命令"""
    child.sendline("usb")
    child.expect("twist-cross")

def check_victory(black_caps, white_caps):
    """检查胜负：黑6子胜，白5子胜"""
    if black_caps >= 6:
        return "B"
    if white_caps >= 5:
        return "W"
    return None

def play_one_game(level, game_num, f):
    """进行一局对弈"""
    log(f"\n{'='*50}", f)
    log(f"第 {game_num} 局: LV{level} vs LV{level}", f)
    log(f"{'='*50}", f)
    
    child = pexpect.spawn(ENGINE_PATH, cwd=WORK_DIR, timeout=30)
    
    # 设置棋盘和等级
    child.sendline("boardsize 13")
    child.expect("=")
    child.sendline(f"wood_ai_level {level}")
    child.expect("=")
    setup_board(child)
    
    move_num = 0
    game_over = False
    winner = None
    black_caps = 0
    white_caps = 0
    
    log("\n扭十字开局已设置:", f)
    child.sendline("showboard")
    child.expect("=")
    time.sleep(0.3)
    
    while not game_over and move_num < 170:
        # 黑棋走
        child.sendline("genmove b")
        child.expect("=")
        move_num += 1
        
        # 获取吃子数
        child.sendline("wood_captures")
        child.expect("=")
        captures = child.before.decode()
        
        # 解析吃子数
        for part in captures.split():
            if part.startswith("black="):
                black_caps = int(part.split("=")[1])
            elif part.startswith("white="):
                white_caps = int(part.split("=")[1])
        
        # 检查胜负
        winner = check_victory(black_caps, white_caps)
        if winner:
            log(f"\n第 {move_num} 手后: 黑棋达到 {black_caps} 子，获胜!", f)
            game_over = True
            break
        
        # 白棋走
        child.sendline("genmove w")
        child.expect("=")
        move_num += 1
        
        # 获取吃子数
        child.sendline("wood_captures")
        child.expect("=")
        captures = child.before.decode()
        
        for part in captures.split():
            if part.startswith("black="):
                black_caps = int(part.split("=")[1])
            elif part.startswith("white="):
                white_caps = int(part.split("=")[1])
        
        # 检查胜负
        winner = check_victory(black_caps, white_caps)
        if winner:
            log(f"\n第 {move_num} 手后: 白棋达到 {white_caps} 子，获胜!", f)
            game_over = True
            break
        
        # 每 20 手记录一次
        if move_num % 20 == 0:
            log(f"\n... 已下 {move_num} 手, 黑吃 {black_caps} 子, 白吃 {white_caps} 子 ...", f)
    
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
        # 棋盘下满，吃子多者胜，相同判白胜
        if black_caps > white_caps:
            log(f"结果: 棋盘满，黑棋吃子多 ({black_caps} > {white_caps})，黑胜", f)
            winner = "B"
        else:
            log(f"结果: 棋盘满，白棋吃子多或相等 ({white_caps} >= {black_caps})，白胜", f)
            winner = "W"
    
    # 显示最终棋盘
    log("\n最终棋盘:", f)
    child.sendline("showboard")
    child.expect("=")
    time.sleep(0.5)
    
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
        log("Phoenix AI 逐级自对弈测试 (Wood 吃子棋规则)", f)
        log("="*50, f)
        log("规则: 扭十字开局, 黑6子胜, 白5子胜, 无平局", f)
        log("="*50, f)
        
        results = []
        
        # 测试 LV1, LV2, LV3
        for level in [1, 2, 3]:
            result = play_one_game(level, level, f)
            results.append(result)
        
        # 总结
        log("\n" + "="*50, f)
        log("测试总结", f)
        log("="*50, f)
        
        for r in results:
            level = r["level"]
            moves = r["moves"]
            winner = r["winner"]
            black_caps = r["black_caps"]
            white_caps = r["white_caps"]
            
            winner_str = "黑胜" if winner == "B" else "白胜"
            log(f"LV{level}: {moves}手, {winner_str}, 黑吃{black_caps}子, 白吃{white_caps}子", f)
        
        log(f"\n结果保存到: {output_file}", f)
    
    print(f"\n结果已保存到: {output_file}")

if __name__ == "__main__":
    main()
