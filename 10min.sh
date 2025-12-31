#!/bin/bash

SCRIPT="/opt/cataised/playscript.sh"
DIR="/opt/cataised"
COUNT_FILE="/tmp/raewq-count.txt"
MAX=20
PLAY_LIMIT=10

# Initialize counter if missing or invalid
if [ ! -f "$COUNT_FILE" ] || ! [[ "$(cat "$COUNT_FILE")" =~ ^[0-9]+$ ]]; then
  echo 0 > "$COUNT_FILE"
fi

COUNT=$(cat "$COUNT_FILE")

# Increment count
COUNT=$((COUNT + 1))

# Reset if max reached
if [ "$COUNT" -gt "$MAX" ]; then
  COUNT=1
fi

echo "$COUNT" > "$COUNT_FILE"

# Only play during first PLAY_LIMIT runs
if [ "$COUNT" -le "$PLAY_LIMIT" ]; then
  NUM=$(( RANDOM % 10 + 1 ))
  FILE="cat${NUM}.wav"

  if [ -x "$SCRIPT" ] && [ -f "$DIR/$FILE" ]; then
    "$SCRIPT" "$DIR/$FILE"
  else
    echo "Missing script or file: $SCRIPT $DIR/$FILE"
  fi
fi
