#!/bin/bash
# self_play_test.sh - Phoenix AI vs AI strength test
# Usage: ./self_play_test.sh <level_black> <level_white> <num_moves>

BLACK_LEVEL=${1:-7}
WHITE_LEVEL=${2:-5}
NUM_MOVES=${3:-20}

echo "=== Phoenix Self-Play Test ==="
echo "Black: Level $BLACK_LEVEL"
echo "White: Level $WHITE_LEVEL"
echo "Max moves: $NUM_MOVES"
echo ""

# Generate GTP commands for a game
COMMANDS="clear_board"
for ((i=0; i<NUM_MOVES; i++)); do
    if [ $((i % 2)) -eq 0 ]; then
        COMMANDS="$COMMANDS
genmove black"
    else
        COMMANDS="$COMMANDS
genmove white"
    fi
done
COMMANDS="$COMMANDS
final_score
result
quit"

# Run game with black level
echo "--- Running game (Black L$BLACK_LEVEL vs White L$WHITE_LEVEL) ---"
RESULT=$(echo "$COMMANDS" | timeout 30 ./phoenix --level $BLACK_LEVEL 2>&1)

# Extract final score and result
FINAL_SCORE=$(echo "$RESULT" | grep -A1 "final_score" | tail -1)
GAME_RESULT=$(echo "$RESULT" | grep -A1 "^result" | tail -1)

echo "Final score: $FINAL_SCORE"
echo "Game result: $GAME_RESULT"
echo ""

# Determine winner from final_score (format: B+N or W+N)
if echo "$FINAL_SCORE" | grep -q "B+"; then
    echo "Winner: Black (Level $BLACK_LEVEL)"
elif echo "$FINAL_SCORE" | grep -q "W+"; then
    echo "Winner: White (Level $WHITE_LEVEL)"
else
    echo "Result: Game incomplete or draw"
fi
