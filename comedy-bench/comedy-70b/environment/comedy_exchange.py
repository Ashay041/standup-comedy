#!/usr/bin/env python3
"""
Multi-agent comedy exchange using AutoGen + Groq API

Four available comedians (any 2 selected via env vars):
  Samay Raina, Abhishek Upmanyu, Trevor Noah, Jimmy O. Yang

ToxicityChecker moderator reviews every joke before delivery.

Flow: Comedian writes joke -> ToxicityChecker reviews ->
  APPROVED -> other comedian hears it and responds
  REJECTED -> same comedian revises with feedback

Env vars:
  COMEDY_MODEL   - Groq model to use (default: llama-3.1-8b-instant)
  GROQ_API_KEY   - Groq API key (required)
  COMEDY_CHAR1   - First comedian key (default: samay)
  COMEDY_CHAR2   - Second comedian key (default: upmanyu)
  COMEDY_TOPIC   - Topic key (default: indian-parents)
"""
import os
import sys
from autogen import ConversableAgent, GroupChat, GroupChatManager


# ---------------------------------------------------------------------------
# Character registry
# ---------------------------------------------------------------------------
CHARACTERS = {
    "samay": {
        "name": "Samay",
        "style": (
            "You are Samay Raina, a savage ENFP comedian from India. "
            "Your style is dark humor, rapid-fire wit, and observational comedy "
            "that pushes boundaries. You love roast comedy and your delivery is "
            "fearless and unapologetic."
        ),
        "avoid": (
            "No popsicle-stick puns. No recycled jokes. "
            "Be sharp, dark, and genuinely funny."
        ),
    },
    "upmanyu": {
        "name": "Upmanyu",
        "style": (
            "You are Abhishek Upmanyu, a sarcastic INTP comedian from India. "
            "Your style is fast-paced delivery, relatable observational humor, "
            "witty sarcasm, and self-deprecating moments. You are brutally honest "
            "and accidentally hilarious."
        ),
        "avoid": (
            "No dad jokes. No recycled jokes. "
            "Be sharp, sarcastic, and genuinely funny."
        ),
    },
    "trevor": {
        "name": "Trevor",
        "style": (
            "You are Trevor Noah, a South African comedian known worldwide. "
            "Your style is political and social commentary, cross-cultural humor, "
            "and vivid storytelling. You find humor in the absurdity of cultural "
            "differences. Your delivery is warm, intelligent, and builds to "
            "satisfying payoffs."
        ),
        "avoid": (
            "No cheap stereotypes. No recycled late-night monologue jokes. "
            "Be sharp, insightful, and genuinely funny."
        ),
    },
    "jimmy": {
        "name": "Jimmy",
        "style": (
            "You are Jimmy O. Yang, a Chinese-American comedian. "
            "Your style is deadpan delivery, immigrant experience humor, "
            "and self-deprecating comedy. You find humor in the clash between "
            "Asian and American cultures, family expectations, and the absurdity "
            "of everyday life. Your punchlines land because of your perfect timing "
            "and poker face."
        ),
        "avoid": (
            "No broad ethnic caricatures. No recycled jokes. "
            "Be sharp, deadpan, and genuinely funny."
        ),
    },
}

# ---------------------------------------------------------------------------
# Topic registry
# ---------------------------------------------------------------------------
TOPICS = {
    "indian-parents": {
        "description": "Indian parents, family expectations, and emotional warfare",
        "opener": (
            "{name} here. Indian parents are something else. "
            "My dad said 'I'm not angry, I'm disappointed.' "
            "That's the Indian version of a death sentence - "
            "no trial, no jury, just straight to emotional execution."
        ),
    },
    "dating": {
        "description": "Modern dating, apps, relationships, and rejection",
        "opener": (
            "{name} here. Dating apps have ruined us. "
            "I swiped right on someone and they unmatched so fast "
            "my phone asked if I wanted to file a missing person report."
        ),
    },
    "office-life": {
        "description": "Corporate life, meetings, WFH, and coworkers",
        "opener": (
            "{name} here. My boss said 'We need to talk' and I started "
            "updating my resume before he finished the sentence. Turns out "
            "he just wanted to discuss the team lunch. "
            "But my LinkedIn is looking fresh now."
        ),
    },
    "food": {
        "description": "Food culture, restaurants, cooking disasters, and diets",
        "opener": (
            "{name} here. I told my friend I'm on a diet. "
            "He said 'That's great, what kind?' I said 'The see-food diet - "
            "I see food and I eat it.' He stopped inviting me to buffets."
        ),
    },
    "travel": {
        "description": "Travel disasters, airports, tourists, and culture shock",
        "opener": (
            "{name} here. Airport security asked me to remove my shoes, "
            "my belt, my jacket. At that point I'm basically on a first date "
            "with TSA. At least buy me dinner before you scan my insides."
        ),
    },
    "tech-life": {
        "description": "Tech industry, coding, startups, and screen addiction",
        "opener": (
            "{name} here. My screen time report came in and my phone basically "
            "said 'Are you okay?' Seven hours of screen time and I still have "
            "zero unread messages. I'm not addicted, I'm just committed to "
            "being ignored efficiently."
        ),
    },
}

# ---------------------------------------------------------------------------
# Shared rules for all comedians (rule 5 uses per-character {avoid})
# ---------------------------------------------------------------------------
SHARED_COMEDIAN_RULES = (
    "RULES: "
    "1. LISTEN to what the other comedian said and RIFF OFF IT. "
    "   Build on their joke, twist it, or one-up it. "
    "2. Respond with ONLY your joke - one or two lines max. "
    "3. Every joke must have a clear setup and punchline. "
    "4. No explaining jokes. No 'here is my joke' or 'my turn'. Just say the joke. "
    "5. {avoid} "
    "6. If your joke was REJECTED by the moderator, revise it based on the feedback. "
    "   Keep the same theme but make it less offensive. "
    "7. Ignore messages from ToxicityChecker that say APPROVED - those aren't for you."
)


# ---------------------------------------------------------------------------
# Agent factory functions
# ---------------------------------------------------------------------------

def create_comedian_agent(char_key, llm_config):
    """Build a ConversableAgent from a CHARACTERS registry entry."""
    char = CHARACTERS[char_key]
    system_message = char["style"] + " " + SHARED_COMEDIAN_RULES.format(avoid=char["avoid"])
    return ConversableAgent(
        name=char["name"],
        system_message=system_message,
        llm_config=llm_config,
        human_input_mode="NEVER",
    )


def create_toxicity_checker(llm_config):
    """Build the ToxicityChecker moderator agent."""
    return ConversableAgent(
        name="ToxicityChecker",
        system_message=(
            "You are a content moderator for a live comedy show. "
            "Your job is to review each comedian's joke BEFORE it is delivered to the audience. "
            "Check for these 3 things: "
            "1. Overly political content (targeting specific political parties or leaders) "
            "2. Excessive vulgarity (explicit sexual or graphic content) "
            "3. Genuinely disrespectful content (racism, sexism, targeting disabilities) "
            "IMPORTANT: Dark humor, roasting, sarcasm, and edgy comedy are FINE. "
            "Comedy is supposed to push boundaries. Only flag content that is truly harmful. "
            "Be lenient - most jokes should pass. "
            "YOUR RESPONSE FORMAT (follow exactly): "
            "- If the joke is OK: respond with just the word APPROVED "
            "- If the joke crosses the line: respond with REJECTED: [one sentence explaining what was wrong]"
        ),
        llm_config=llm_config,
        human_input_mode="NEVER",
    )


# ---------------------------------------------------------------------------
# Speaker routing
# ---------------------------------------------------------------------------

def build_next_speaker_fn(comedian1, comedian2, toxicity_checker):
    """Return a speaker selection closure for the GroupChat."""
    comedian_names = {comedian1.name: comedian1, comedian2.name: comedian2}

    def next_speaker(last_speaker, groupchat):
        messages = groupchat.messages

        # After a comedian speaks -> ToxicityChecker reviews
        if last_speaker in (comedian1, comedian2):
            return toxicity_checker

        # After ToxicityChecker -> route based on approval/rejection
        if last_speaker == toxicity_checker:
            last_msg = messages[-1].get("content", "").strip()

            # Find which comedian spoke right before the checker
            comedian_before = None
            for msg in reversed(messages[:-1]):
                name = msg.get("name", "")
                if name in comedian_names:
                    comedian_before = comedian_names[name]
                    break

            if "REJECTED" in last_msg.upper():
                return comedian_before or comedian1
            else:
                if comedian_before == comedian1:
                    return comedian2
                else:
                    return comedian1

        return comedian1

    return next_speaker


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

def extract_approved_jokes(messages):
    """Filter group chat messages to only include approved comedian jokes."""
    conversation_lines = []
    i = 0
    while i < len(messages):
        msg = messages[i]
        speaker = msg.get("name", msg.get("role", "Unknown"))
        content = msg.get("content", "")
        if content is None:
            i += 1
            continue
        content = content.strip()

        # Skip empty, checker messages, and AutoGen markers
        if not content or speaker == "ToxicityChecker" or "***** " in content:
            i += 1
            continue

        # Check if this joke was approved by looking at the next message
        approved = False
        if i + 1 < len(messages):
            next_msg = messages[i + 1]
            if next_msg.get("name") == "ToxicityChecker":
                next_content = next_msg.get("content", "").strip().upper()
                if "APPROVED" in next_content:
                    approved = True
        else:
            # Last message with no checker after it — include it
            approved = True

        if approved:
            conversation_lines.append(f"{speaker}: {content}")

        i += 1

    return conversation_lines


def write_output(conversation_lines, comedy_model, char1_name, char2_name, topic_key):
    """Write the approved conversation to /output/ and print to stdout."""
    model_safe = comedy_model.replace("/", "_")
    output_path = f"/output/conversation_{model_safe}.txt"

    with open(output_path, "w") as f:
        f.write(f"COMEDY EXCHANGE - Model: {comedy_model}\n")
        f.write(f"Characters: {char1_name} vs {char2_name}\n")
        f.write(f"Topic: {topic_key}\n")
        f.write("=" * 50 + "\n\n")
        for line in conversation_lines:
            f.write(line + "\n\n")

    print(f"\nConversation saved to {output_path}")
    print(f"Total approved jokes: {len(conversation_lines)}")
    print("\n" + "=" * 50)
    for line in conversation_lines:
        print(line)
        print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    comedy_model = os.getenv("COMEDY_MODEL", "llama-3.1-8b-instant")
    groq_api_key = os.getenv("GROQ_API_KEY")
    char1_key = os.getenv("COMEDY_CHAR1", "samay").lower()
    char2_key = os.getenv("COMEDY_CHAR2", "upmanyu").lower()
    topic_key = os.getenv("COMEDY_TOPIC", "indian-parents").lower()

    if not groq_api_key:
        print("ERROR: GROQ_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    if char1_key not in CHARACTERS:
        print(f"ERROR: Unknown character '{char1_key}'. Available: {', '.join(CHARACTERS)}", file=sys.stderr)
        sys.exit(1)

    if char2_key not in CHARACTERS:
        print(f"ERROR: Unknown character '{char2_key}'. Available: {', '.join(CHARACTERS)}", file=sys.stderr)
        sys.exit(1)

    if char1_key == char2_key:
        print(f"ERROR: COMEDY_CHAR1 and COMEDY_CHAR2 must be different (both are '{char1_key}')", file=sys.stderr)
        sys.exit(1)

    if topic_key not in TOPICS:
        print(f"ERROR: Unknown topic '{topic_key}'. Available: {', '.join(TOPICS)}", file=sys.stderr)
        sys.exit(1)

    llm_config = {
        "model": comedy_model,
        "api_key": groq_api_key,
        "base_url": "https://api.groq.com/openai/v1",
        "temperature": 0.9,
        "max_tokens": 200,
    }

    comedian1 = create_comedian_agent(char1_key, llm_config)
    comedian2 = create_comedian_agent(char2_key, llm_config)
    checker = create_toxicity_checker(llm_config)

    next_speaker = build_next_speaker_fn(comedian1, comedian2, checker)

    group_chat = GroupChat(
        agents=[comedian1, comedian2, checker],
        messages=[],
        max_round=12,
        speaker_selection_method=next_speaker,
    )

    manager = GroupChatManager(
        groupchat=group_chat,
        llm_config=llm_config,
    )

    opening = TOPICS[topic_key]["opener"].format(name=comedian1.name)

    print(f"Starting comedy exchange with {comedy_model}")
    print(f"Characters: {comedian1.name} vs {comedian2.name}")
    print(f"Topic: {topic_key} - {TOPICS[topic_key]['description']}")
    print("=" * 50)

    comedian1.initiate_chat(manager, message=opening)

    conversation_lines = extract_approved_jokes(group_chat.messages)
    write_output(conversation_lines, comedy_model, comedian1.name, comedian2.name, topic_key)


if __name__ == "__main__":
    main()
