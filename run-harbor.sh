#!/bin/bash
# Run ComedyBench - 2 models in parallel via Harbor + Daytona
# comedy-8b (llama-3.1-8b) vs comedy-70b (llama-3.3-70b)

# Load API keys from .env file
source .env

export GROQ_API_KEY
export GOOGLE_API_KEY
export DAYTONA_API_KEY

echo "========================================"
echo "  ComedyBench - Model Comparison"
echo "========================================"
echo ""

# ---------------------------------------------------------------------------
# Character selection
# ---------------------------------------------------------------------------
CHAR_KEYS=("samay" "upmanyu" "trevor" "jimmy")
CHAR_LABELS=(
    "Samay Raina      - dark humor, roast comedy"
    "Abhishek Upmanyu - sarcastic, observational"
    "Trevor Noah      - political/social commentary"
    "Jimmy O. Yang    - deadpan, immigrant humor"
)

echo "Pick two comedians:"
for i in "${!CHAR_LABELS[@]}"; do
    echo "  $((i+1))) ${CHAR_LABELS[$i]}"
done
echo ""

read -p "Comedian 1 [1]: " c1
c1=${c1:-1}
read -p "Comedian 2 [2]: " c2
c2=${c2:-2}

# Validate inputs
if [[ "$c1" -lt 1 || "$c1" -gt 4 || "$c2" -lt 1 || "$c2" -gt 4 ]]; then
    echo "ERROR: Pick a number between 1 and 4"
    exit 1
fi
if [[ "$c1" -eq "$c2" ]]; then
    echo "ERROR: Pick two different comedians"
    exit 1
fi

export COMEDY_CHAR1="${CHAR_KEYS[$((c1-1))]}"
export COMEDY_CHAR2="${CHAR_KEYS[$((c2-1))]}"

echo ""

# ---------------------------------------------------------------------------
# Topic selection
# ---------------------------------------------------------------------------
TOPIC_KEYS=("indian-parents" "dating" "office-life" "food" "travel" "tech-life")
TOPIC_LABELS=(
    "indian-parents - Family expectations and emotional warfare"
    "dating         - Modern dating, apps, and rejection"
    "office-life    - Corporate life, meetings, and WFH"
    "food           - Food culture, restaurants, and diets"
    "travel         - Airports, tourists, and culture shock"
    "tech-life      - Tech industry, coding, and screen addiction"
)

echo "Pick a topic:"
for i in "${!TOPIC_LABELS[@]}"; do
    echo "  $((i+1))) ${TOPIC_LABELS[$i]}"
done
echo ""

read -p "Topic [1]: " t
t=${t:-1}

if [[ "$t" -lt 1 || "$t" -gt 6 ]]; then
    echo "ERROR: Pick a number between 1 and 6"
    exit 1
fi

export COMEDY_TOPIC="${TOPIC_KEYS[$((t-1))]}"

# ---------------------------------------------------------------------------
# Summary and run
# ---------------------------------------------------------------------------
echo ""
echo "----------------------------------------"
echo "  Characters: $COMEDY_CHAR1 vs $COMEDY_CHAR2"
echo "  Topic:      $COMEDY_TOPIC"
echo "  Models:     llama-3.1-8b vs llama-3.3-70b"
echo "  Judge:      Gemini 2.5 Flash"
echo "  Env:        Daytona (2 sandboxes)"
echo "----------------------------------------"
echo ""

# Write selections into .env.docker so they get baked into the Docker image
# (Harbor doesn't pass arbitrary ${...} env vars to containers)
for env_file in comedy-bench/comedy-8b/environment/.env.docker \
                comedy-bench/comedy-70b/environment/.env.docker; do
    sed -i '' '/^COMEDY_CHAR1=/d;/^COMEDY_CHAR2=/d;/^COMEDY_TOPIC=/d' "$env_file"
    echo "COMEDY_CHAR1=$COMEDY_CHAR1" >> "$env_file"
    echo "COMEDY_CHAR2=$COMEDY_CHAR2" >> "$env_file"
    echo "COMEDY_TOPIC=$COMEDY_TOPIC" >> "$env_file"
done

# -p "comedy-bench" picks up comedy-8b and comedy-70b
# -n 2 runs both concurrently in separate Daytona sandboxes
# --force-build rebuilds images with the updated .env.docker
harbor run -p "comedy-bench" -n 2 --env daytona --force-build
