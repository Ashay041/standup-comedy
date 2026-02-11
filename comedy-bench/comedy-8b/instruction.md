# Pun Battle

Run a comedy exchange between two AutoGen agents (samay and upmanyu).

**Scenario:** samay and upmanyu have a pun competition. Each comedian must respond
with a pun. Keep it going for 2 turns each (4 jokes total).

**Requirements:**

- Save the full conversation transcript to `/output/conversation.txt`
- Each comedian gets exactly 2 turns
- Conversation must contain actual puns (wordplay)

**Environment Variables:**

- `COMEDY_MODEL`: Which model to use (gemma2-9b-it or llama-3.1-8b-instant)
- `GROQ_API_KEY`: API key for Groq (passed by Harbor)
- `GOOGLE_API_KEY`: API key for the judge LLM



# Code Flow

```
1. COMEDIANS (comedy_exchange.py)
   └─> Uses GROQ_API_KEY
   └─> Calls Groq API with Llama model
   └─> Generates conversation
   └─> Saves to /output/conversation.txt

2. JUDGE (test.sh)
   └─> Uses GOOGLE_API_KEY
   └─> Reads /output/conversation.txt
   └─> Calls Google API with Gemini model
   └─> Scores the conversation
   └─> Saves score to /logs/verifier/reward.txt
```
