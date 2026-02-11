#!/bin/bash
set -e

echo "Running comedy exchange..."

# Load environment variables from .env file
if [ -f /app/.env ]; then
    export $(cat /app/.env | xargs)
fi

echo "Model: $COMEDY_MODEL"

# Run the comedy exchange
python /app/comedy_exchange.py

# Verify output was created
model_safe="${COMEDY_MODEL//\//_}"
output_file="/output/conversation_${model_safe}.txt"

if [ ! -f "$output_file" ] || [ ! -s "$output_file" ]; then
    echo "ERROR: output file missing or empty"
    exit 1
fi

echo "Done: $output_file"
