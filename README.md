I wanted to test if LLMs can actually be funny. So I built a benchmark for it.
Most AI evals test reasoning or coding. Nobody tests humor. But humor is hard. It needs timing, personality, context, and knowing where the line is. You can't memorize your way through comedy.

Here's what I built:
I created ComedyBench - a multi-agent comedy battle where two AI comedians riff off each other in real time.

Demo: https://drive.google.com/file/d/1_0B85GjBt7xw6mqklpSq_EvvbcCKRwN8/view?uuspdrive_link

## How It Works

1. You pick 2 comedians from 4 personas (Samay Raina, Abhishek Upmanyu, Trevor Noah, Jimmy O. Yang). Each has a distinct comedy style.
2. You pick a topic (dating, travel, tech life, etc.)
3. Two LLM comedians go back and forth, building on each other's jokes.
4. A third AI agent (ToxicityChecker) reviews every joke before delivery. If it crosses a line, the comedian has to revise. Not a regex filter. An actual agent that understands context, and it goes into a feedback loop.
5. A separate model (Gemini) judges the conversation on 5 comedy-specific metrics: setup/punchline, originality, timing, laugh factor, cringe penalty.
6. The whole thing runs on two models in parallel (8B vs 70B) using Harbor + Daytona sandboxes, so the comparison is fair.

## Tech Stack

| Component               | Tech                                   |
| ----------------------- | -------------------------------------- |
| Multi-agent framework   | AutoGen (pyautogen)                    |
| Comedy LLMs             | Groq API (Llama 3.1-8B, Llama 3.3-70B) |
| Judge                   | Google Gemini 2.5 Flash                |
| Container orchestration | Harbor                                 |
| Sandbox runtime         | Daytona                                |

## Characters & Topics

**Characters** (pick any 2):

| Key     | Comedian         | Style                       |
| ------- | ---------------- | --------------------------- |
| samay   | Samay Raina      | Dark humor, roast comedy    |
| upmanyu | Abhishek Upmanyu | Sarcastic, observational    |
| trevor  | Trevor Noah      | Political/social commentary |
| jimmy   | Jimmy O. Yang    | Deadpan, immigrant humor    |

**Topics:** indian-parents, dating, office-life, food, travel, tech-life

## Scoring Metrics

Each scored 0.0 to 1.0 by Gemini (temperature=0.1). Final score = average of all five.

| Metric          | What it measures                           |
| --------------- | ------------------------------------------ |
| SETUP_PUNCHLINE | Clear setup with satisfying payoff         |
| ORIGINALITY     | Fresh takes vs recycled jokes              |
| TIMING_FLOW     | Natural back-and-forth, callbacks, riffing |
| LAUGH_FACTOR    | Actually funny                             |
| CRINGE_PENALTY  | Inverted: higher = less cringe             |

## Prerequisites

- [Harbor CLI](https://github.com/harbor-ai/harbor) installed
- [Daytona](https://www.daytona.io/) account with API key
- [Groq](https://console.groq.com/) API key (free tier works)
- [Google AI](https://aistudio.google.com/) API key (for Gemini judge)

Create a `.env` file in the project root:

```
GROQ_API_KEY=gsk_...
GOOGLE_API_KEY=AIza...
DAYTONA_API_KEY=dtn_...
```

## Usage

```bash
./run-harbor.sh
```

Interactive menu lets you pick 2 comedians and a topic. Harbor launches both model containers in parallel on Daytona.

View results:

```bash
./show-results.sh
```

## Project Structure

```
comedy-bench/
├── comedy-8b/
│   ├── environment/
│   │   ├── comedy_exchange.py    # Agent logic + character/topic registries
│   │   ├── Dockerfile
│   │   └── .env.docker           # Baked into image at build time
│   ├── solution/solve.sh         # Container entry point
│   ├── tests/test.sh             # Gemini judge script
│   └── task.toml                 # Harbor task config
├── comedy-70b/                   # Same structure, llama-3.3-70b model
run-harbor.sh                     # Interactive launcher
show-results.sh                   # View scores + jokes from latest run
```

## Shortcomings & Future Improvements

### Code-Level

1. **Last joke bypasses ToxicityChecker** - Each joke cycle costs 2 rounds (Comedian -> ToxicityChecker), and rejections cost 2 more (revision -> re-check). When `max_round=12` is hit, the conversation cuts off mid-cycle. If the last message is a comedian's joke, there's no round left for the checker to review it. `extract_approved_jokes()` treats this as approved by default, so the final joke goes into output unmoderated. Rejections also eat into the round budget, meaning fewer total jokes make it through.
2. **Speaker routing silent fallback** - In `build_next_speaker_fn()`, if `comedian_before` is `None` (no prior comedian found in history), it defaults to `comedian1`. Can cause comedian1 to get consecutive turns.
3. **`solve.sh` env parsing is fragile** - `export $(cat /app/.env | xargs)` breaks on values with spaces, quotes, or special characters.
4. **Gemini `thinkingBudget: 0`** - `test.sh` disables Gemini's chain-of-thought, which could reduce judge quality.
5. **Duplicated `comedy_exchange.py`** - Identical file in both `comedy-8b/` and `comedy-70b/`. Should be a shared volume or build arg.

### Architecture-Level

9. **No retry/backoff for Groq API** - Free tier is rate-limited (8B: 6K TPM, 70B: 12K TPM). Back-to-back runs can timeout with no recovery.
10. **Single judge model** - Only Gemini 2.5 Flash. No cross-judge validation or ensemble scoring to reduce bias.
11. **Daytona network isolation** - Containers cannot make external calls beyond baked-in API keys. Tool-use agents (e.g. web search) are blocked at TLS level.
12. **No joke-level analytics** - Scores are conversation-level only. No per-joke scoring, rejection rate tracking, or revision quality metrics.
13. **No persistence** - No database or structured output for cross-run model comparison over time.

## Disclaimer

This project is for educational and research purposes only. The comedian characters are fictional representations used to explore different comedy styles in AI-generated content. They do not depict the actual views, personalities, or material of the real individuals referenced.
