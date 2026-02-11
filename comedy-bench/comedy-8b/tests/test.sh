#!/bin/bash
set -e

REWARD_FILE="/logs/verifier/reward.txt"

echo "Evaluating comedy exchange..."

# Load environment variables from .env file
if [ -f /app/.env ]; then
    export $(cat /app/.env | xargs)
fi

# Validate Google API key
GOOGLE_API_KEY="${GOOGLE_API_KEY:-}"
if [ -z "$GOOGLE_API_KEY" ]; then
    echo "ERROR: GOOGLE_API_KEY not set"
    echo "0.0" > "$REWARD_FILE"
    exit 0
fi

# Find the conversation file
CONVERSATION_FILE=$(ls /output/conversation_*.txt 2>/dev/null | head -1)

if [ -z "$CONVERSATION_FILE" ]; then
    echo "ERROR: No conversation file found"
    echo "0.0" > "$REWARD_FILE"
    exit 0
fi

echo "Judging: $CONVERSATION_FILE"

# Read conversation content
CONVERSATION=$(cat "$CONVERSATION_FILE")

CHAR_COUNT=$(echo -n "$CONVERSATION" | wc -c)
if [ "$CHAR_COUNT" -lt 100 ]; then
    echo "ERROR: Conversation too short (${CHAR_COUNT} chars)"
    echo "0.0" > "$REWARD_FILE"
    exit 0
fi

echo "Conversation length: ${CHAR_COUNT} chars"

# Judge prompt with 5 comedy criteria
JUDGE_PROMPT="You are a veteran stand-up comedy judge. You have seen thousands of sets.
Evaluate this comedy exchange between two AI comedians.

Score on these 5 criteria (each 0.0 to 1.0):

SETUP_PUNCHLINE (Does each joke have a clear setup and payoff?)
- 0.0 = no structure, just random statements
- 0.5 = some jokes land, others fall flat
- 1.0 = tight setups with satisfying punchlines every time

ORIGINALITY (Would a comedy audience groan or laugh?)
- 0.0 = recycled jokes everyone has heard (scarecrow, anti-gravity book)
- 0.5 = familiar premises with fresh angles
- 1.0 = genuinely original takes that surprise you

TIMING_FLOW (Does the back-and-forth feel natural?)
- 0.0 = robots reading joke books at each other
- 0.5 = decent flow but forced transitions
- 1.0 = natural riffing, callbacks, building on each other

LAUGH_FACTOR (Did it actually make you laugh or exhale sharply?)
- 0.0 = completely unfunny
- 0.5 = a few smile-worthy moments
- 1.0 = genuinely hilarious, multiple laugh-out-loud moments

CRINGE_PENALTY (How much cringe is present? INVERTED: higher = less cringe)
- 0.0 = painfully cringe, trying too hard
- 0.5 = some awkward moments but mostly fine
- 1.0 = zero cringe, smooth delivery throughout

IMPORTANT: Respond with ONLY a single-line JSON object. No markdown, no code blocks, no explanation before or after.
The JSON must be on ONE line in this exact format:
{\"setup_punchline\": 0.0, \"originality\": 0.0, \"timing_flow\": 0.0, \"laugh_factor\": 0.0, \"cringe_penalty\": 0.0, \"overall\": 0.0, \"reasoning\": \"brief analysis\"}

The overall score is the average of all five criteria scores. Keep reasoning under 100 words.

CONVERSATION:
$CONVERSATION"

# Build Gemini API request
REQUEST_JSON=$(jq -n \
  --arg text "$JUDGE_PROMPT" \
  '{
    "contents": [{"parts": [{"text": $text}]}],
    "generationConfig": {
      "temperature": 0.1,
      "maxOutputTokens": 2048,
      "thinkingConfig": {"thinkingBudget": 0}
    }
  }')

echo "Calling Gemini judge..."

# Call Gemini 2.5 Flash API
RESPONSE=$(curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GOOGLE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_JSON")

# Parse response
JUDGE_TEXT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null || echo "")

if [ -z "$JUDGE_TEXT" ] || [ "$JUDGE_TEXT" = "null" ]; then
    echo "ERROR: Failed to get judge response"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    echo "0.0" > "$REWARD_FILE"
    exit 0
fi

echo "Judge response:"
echo "$JUDGE_TEXT"

# Parse JSON score using Python (handles multi-line, code blocks, etc.)
echo "$JUDGE_TEXT" > /tmp/judge_response.txt

PARSE_RESULT=$(python3 << 'PYEOF'
import json, re

with open("/tmp/judge_response.txt") as f:
    text = f.read()

# Strip markdown code blocks if present
text = re.sub(r'```json\s*', '', text)
text = re.sub(r'```\s*', '', text)
text = text.strip()

# Find JSON object in the text
match = re.search(r'\{.*\}', text, re.DOTALL)
if not match:
    print("ERROR: No JSON found")
    print("SCORE:0.0")
    exit()

try:
    data = json.loads(match.group())
    score = float(data.get('overall', 0.0))
    score = max(0.0, min(1.0, score))

    for key in ['setup_punchline', 'originality', 'timing_flow', 'laugh_factor', 'cringe_penalty']:
        if key in data:
            print(f"  {key}: {data[key]}")

    reasoning = data.get('reasoning', 'No reasoning provided')
    print(f"REASONING: {reasoning}")
    print(f"SCORE:{score}")
except (json.JSONDecodeError, ValueError) as e:
    print(f"ERROR: JSON parse failed: {e}")
    print("SCORE:0.0")
PYEOF
)

echo ""
echo "$PARSE_RESULT"

# Extract the score
SCORE=$(echo "$PARSE_RESULT" | grep "^SCORE:" | cut -d: -f2)

if [ -z "$SCORE" ]; then
    echo "ERROR: Could not extract score"
    echo "0.0" > "$REWARD_FILE"
    exit 0
fi

echo ""
echo "Final score: $SCORE"
echo "$SCORE" > "$REWARD_FILE"
