#!/bin/bash
# strength_test.sh - Run multiple games and count wins
# Usage: ./strength_test.sh <level_black> <level_white> <num_games> <max_moves>

BLACK_LEVEL=${1:-7}
WHITE_LEVEL=${2:-5}
NUM_GAMES=${3:-10}
MAX_MOVES=${4:-150}

echo "=== Phoenix Strength Test ==="
echo "Black: Level $BLACK_LEVEL"
echo "White: Level $WHITE_LEVEL"
echo "Games: $NUM_GAMES"
echo "Max moves per game: $MAX_MOVES"
echo ""

BLACK_WINS=0
WHITE_WINS=0
INCOMPLETE=0

for ((game=1; game<=NUM_GAMES; game++)); do
    echo -n "Game $game: "
    
    # Build GTP commands
    COMMANDS="clear_board"
    for ((i=1; i<=MAX_MOVES; i++)); do
        if [ $((i % 2)) -eq 1 ]; then
            COMMANDS="$COMMANDS
genmove black"
        else
            COMMANDS="$COMMANDS
genmove white"
        fi
    done
    COMMANDS="$COMMANDS
result
quit"
    
    # Run game and capture result (last "= gaming/black/white" line)
    RESULT=$(echo "$COMMANDS" | timeout 60 ./phoenix --level $BLACK_LEVEL 2>&1 | grep -E "^= (gaming|black|white)" | tail -1)
    
    # Count result
    if echo "$RESULT" | grep -q "black"; then
        BLACK_WINS=$((BLACK_WINS + 1))
        echo "Black (L$BLACK_LEVEL) wins"
    elif echo "$RESULT" | grep -q "white"; then
        WHITE_WINS=$((WHITE_WINS + 1))
        echo "White (L$WHITE_LEVEL) wins"
    else
        INCOMPLETE=$((INCOMPLETE + 1))
        echo "Incomplete"
    fi
done

echo ""
echo "=== Final Score ==="
echo "Black (L$BLACK_LEVEL): $BLACK_WINS/10 wins"
echo "White (L$WHITE_LEVEL): $WHITE_WINS/10 wins"
echo "Incomplete: $INCOMPLETE"

if [ $BLACK_WINS -gt $WHITE_WINS ]; then
    echo "Winner: Black (Level $BLACK_LEVEL)"
elif [ $WHITE_WINS -gt $BLACK_WINS ]; then
    echo "Winner: White (Level $WHITE_LEVEL)"
else
    echo "Result: Tie"
fi
