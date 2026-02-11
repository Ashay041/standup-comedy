#!/bin/bash
# Show ComedyBench results from the latest (or specified) job run

JOBS_DIR="jobs"

# Use provided job folder or find the latest one
if [ -n "$1" ]; then
    JOB_DIR="$JOBS_DIR/$1"
else
    LATEST=$(ls -1 "$JOBS_DIR" 2>/dev/null | sort | tail -1)
    if [ -z "$LATEST" ]; then
        echo "No jobs found in $JOBS_DIR/"
        exit 1
    fi
    JOB_DIR="$JOBS_DIR/$LATEST"
fi

echo "======================================================"
echo "  COMEDYBENCH RESULTS"
echo "  Job: $(basename $JOB_DIR)"
echo "======================================================"

# Find all task trial directories (skip config/log files)
for trial_dir in "$JOB_DIR"/*/; do
    # Skip if not a directory
    [ -d "$trial_dir" ] || continue
    # Skip if no agent output
    [ -f "$trial_dir/agent/oracle.txt" ] || continue

    trial_name=$(basename "$trial_dir")
    # Extract task name (before the __ random suffix)
    task_name="${trial_name%%__*}"

    echo ""
    echo "------------------------------------------------------"
    echo "  $task_name"
    echo "------------------------------------------------------"

    # Show the model used
    model=$(grep "^Model:" "$trial_dir/agent/oracle.txt" 2>/dev/null | head -1 | sed 's/Model: //')
    if [ -n "$model" ]; then
        echo "  Model: $model"
    fi

    # Show the score
    reward="N/A"
    if [ -f "$trial_dir/verifier/reward.txt" ]; then
        reward=$(cat "$trial_dir/verifier/reward.txt" | tr -d '[:space:]')
    fi
    echo "  Score: $reward"

    # Show detailed scores from verifier output
    if [ -f "$trial_dir/verifier/test-stdout.txt" ]; then
        grep -E "^\s+(setup_punchline|originality|timing_flow|laugh_factor|cringe_penalty):" \
            "$trial_dir/verifier/test-stdout.txt" 2>/dev/null
        reasoning=$(grep "^REASONING:" "$trial_dir/verifier/test-stdout.txt" 2>/dev/null | head -1)
        if [ -n "$reasoning" ]; then
            echo "  $reasoning"
        fi
    fi

    # Print the jokes (clean lines from oracle.txt after the == separator)
    echo ""
    # Find the last block of clean conversation (after the final ==== line)
    awk '/^=+$/{found=NR} found && NR>found && /^[A-Z][a-z]+:/' \
        "$trial_dir/agent/oracle.txt" 2>/dev/null | while read -r line; do
        echo "  $line"
    done
done

# Print leaderboard
echo ""
echo "======================================================"
echo "  LEADERBOARD"
echo "======================================================"
echo ""
printf "  %-25s %s\n" "TASK" "SCORE"
printf "  %-25s %s\n" "----" "-----"

# Collect and sort scores
for trial_dir in "$JOB_DIR"/*/; do
    [ -d "$trial_dir" ] || continue
    [ -f "$trial_dir/verifier/reward.txt" ] || continue
    trial_name=$(basename "$trial_dir")
    task_name="${trial_name%%__*}"
    reward=$(cat "$trial_dir/verifier/reward.txt" | tr -d '[:space:]')
    echo "$task_name $reward"
done | sort -k2 -rn | while read -r name score; do
    printf "  %-25s %s\n" "$name" "$score"
done

echo ""
echo "======================================================"
