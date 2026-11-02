#!/bin/bash
# selfplay_lv5.sh - Run 10 games of Level 5 AI self-play
# Usage: ./selfplay_lv5.sh [num_games]

cd /home/aaa/workspace/phoenix_the_capture_go_engine/phoenix_the_capture_go_engine/phoenix_hust

NUM_GAMES=${1:-10}
RESULTS_FILE="/tmp/lv5_selfplay_results.txt"
echo "=== Level 5 Self-Play: $NUM_GAMES games ===" > "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

for game in $(seq 1 $NUM_GAMES); do
    echo "Starting game $game..."
    
    # Create FIFO pair
    IN=$(mktemp -u); OUT=$(mktemp -u)
    mkfifo "$IN" "$OUT"
    
    # Start engine
    ./phoenix < "$IN" > "$OUT" 2>/dev/null &
    PID=$!
    exec 3>"$IN"
    exec 4<"$OUT"
    
    # Helper functions
    send() { echo "$1" >&3; }
    reply() {
        while IFS= read -t 30 -u 4 rl; do
            case "$rl" in
                "= "*) echo "${rl#= }"; break ;;
                "=")   echo ""; break ;;
                "? "*) echo "ERR:${rl#? }"; break ;;
            esac
        done
    }
    
    # Setup
    send "boardsize 13"; reply > /dev/null
    send "clear_board"; reply > /dev/null
    send "wood_ai_level 5"; reply > /dev/null
    send "wood_ai_level"; LEVEL=$(reply)
    
    # Extract level number from response (format: "N" or "AI level: N")
    LEVEL_NUM=$(echo "$LEVEL" | grep -o '[0-9]\+' | head -1)
    
    if [ "$LEVEL_NUM" != "5" ]; then
        echo "Game $game: ERROR - Level not set (got '$LEVEL')" >> "$RESULTS_FILE"
        send "quit"; exec 3>&-; exec 4<&-; kill $PID 2>/dev/null
        rm -f "$IN" "$OUT"
        continue
    fi
    
    MOVES=0
    MAX_MOVES=200
    
    # Play game
    while [ $MOVES -lt $MAX_MOVES ]; do
        # Check board status
        send "board_status"
        STATUS=$(reply)
        
        # Check if game is over (not "0")
        if [ "$STATUS" != "0" ] && [ -n "$STATUS" ]; then
            break
        fi
        
        # Black move
        send "genmove b"
        BMOVE=$(reply)
        if [[ "$BMOVE" == ERR:* ]]; then
            echo "Game $game: Black error - $BMOVE" >> "$RESULTS_FILE"
            break
        fi
        MOVES=$((MOVES + 1))
        
        # Check status again
        send "board_status"
        STATUS=$(reply)
        if [ "$STATUS" != "0" ] && [ -n "$STATUS" ]; then
            break
        fi
        
        # White move
        send "genmove w"
        WMOVE=$(reply)
        if [[ "$WMOVE" == ERR:* ]]; then
            echo "Game $game: White error - $WMOVE" >> "$RESULTS_FILE"
            break
        fi
        MOVES=$((MOVES + 1))
    done
    
    # Get final results
    send "board_status"; FINAL_STATUS=$(reply)
    send "wood_captures"; CAPTURES=$(reply)
    send "result"; RESULT=$(reply)
    
    # Record results
    echo "Game $game:" >> "$RESULTS_FILE"
    echo "  Moves: $MOVES" >> "$RESULTS_FILE"
    echo "  Captures: $CAPTURES" >> "$RESULTS_FILE"
    echo "  Result: $RESULT (status: $FINAL_STATUS)" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    
    # Cleanup
    send "quit"
    exec 3>&-; exec 4<&-
    kill $PID 2>/dev/null
    rm -f "$IN" "$OUT"
    
    echo "Game $game complete: $RESULT ($MOVES moves)"
done

echo "=== Results ==="
cat "$RESULTS_FILE"
