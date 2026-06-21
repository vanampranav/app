from groq import Groq
from dotenv import load_dotenv
import os
import json
from copy import deepcopy

def merge_profile(old, new):
    updated = deepcopy(old)
    for k, v in new.items():
        if v is not None:
            updated[k] = v
    return updated

def missing_fields(profile):
    return [k for k, v in profile.items() if v is None]

def known_fields(profile):
    return {k: v for k, v in profile.items() if v is not None}

load_dotenv()

USER_SCHEMA = {
    "name": None,
    "age": None,
    "gender": None,
    "current_weight_kg": None,
    "height_cm": None,
    "activity_level": None,
    "target_weight_kg": None,
    "timeline_weeks": None,
    "workout_days_per_week": None
}

# Track conversation context
conversation_context = {
    "consecutive_refusals": 0,
    "total_refusals": 0,
    "invalid_attempts": {},  # Track retries per field
}

def build_greeting(profile):
    """Build a personalized greeting with embedded name and first question"""
    known = known_fields(profile)
    missing = missing_fields(profile)
    
    name = known.get("name", "there")
    greeting = f"Hi {name}! I'm here to help you complete your fitness profile."
    
    if len(known) > 1:
        greeting += f" I see you've already provided: "
        known_items = [f"{k.replace('_', ' ')}" for k in known.keys() if k != "name"]
        greeting += ", ".join(known_items) + "."
    
    if missing:
        greeting += f" I'd love to gather a few more details to personalize your experience."
        first_missing = missing[0]
        question = get_question_for_field(first_missing)
        greeting += f" {question}"
    else:
        greeting += " It looks like your profile is complete!"
    
    return greeting

def get_question_for_field(field):
    """Return a humble, conversational question for each field"""
    questions = {
        "age": "Could you share your age with me?",
        "gender": "May I know your gender?",
        "current_weight_kg": "What's your current weight in kilograms?",
        "height_cm": "Could you tell me your height in centimeters?",
        "activity_level": "How would you describe your current activity level? (e.g., sedentary, lightly active, moderately active, very active)",
        "target_weight_kg": "What's your target weight goal in kilograms?",
        "timeline_weeks": "How many weeks would you like to reach your goal?",
        "workout_days_per_week": "How many days per week can you commit to working out?"
    }
    return questions.get(field, f"Could you provide your {field.replace('_', ' ')}?")

def build_system_prompt(profile, context):
    """Build dynamic system prompt with conversational awareness"""
    known = {k: v for k, v in profile.items() if v is not None}
    missing = [k for k, v in profile.items() if v is None]
    current_field = missing[0] if missing else None
    
    # Build context awareness
    context_notes = []
    if context["consecutive_refusals"] >= 1:
        context_notes.append(f"User has refused - ALL fields are essential, set next_question to NULL and exit!")
    
    if current_field and context["invalid_attempts"].get(current_field, 0) >= 2:
        context_notes.append(f"User has given {context['invalid_attempts'][current_field]} invalid answers for {current_field} - be extra patient and helpful")
    
    context_info = "\n".join(context_notes) if context_notes else "No special context."
    
    return f"""You are a warm, conversational fitness assistant. Your goal is to collect profile information while being genuinely helpful and human.

CURRENT STATE:
- Known fields: {json.dumps(known, indent=2)}
- **Currently asking for: {current_field}** ← This is the ONLY field you should try to extract
- Remaining fields: {missing[1:] if len(missing) > 1 else []}

CONTEXT AWARENESS:
{context_info}

EXTRACTION RULES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Only extract if response is relevant to current field
- Invalid/gibberish/off-topic = all null
- Never hallucinate values

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CORE PRINCIPLES (No rigid examples - use your judgment):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. HUMOR DEFUSES TENSION
   - Absurd answers (9000 kg, 200 years) = user joking
   - Respond with light humor, then ask for real info
   - Keep it brief and natural

2. CONFUSION IS REAL
   - Wrong field type (text for numbers) = confusion
   - Clarify what you need, don't just reject
   - Be helpful, not robotic

3. RESPECT BOUNDARIES (all fields essential)
   - **Any clear refusal** → Exit immediately with: "I understand. All these details are essential for your plan. Feel free to return when you're ready!"
   - Set next_question to null
   - Be empathetic but clear

4. KEEP IT NATURAL
   - Brief acknowledgments (2-4 words)
   - Clear, simple questions
   - Don't over-explain unless needed
   - Use empathy when things go wrong

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FIELD SPECIFICATIONS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

age (integer):
  - Range: 13-100
  - Round decimals
  - Reject if out of range

gender (string):
  - Normalize: male/man/guy/dude/boy → "Male"
  - Normalize: female/woman/girl/lady → "Female"
  - Normalize: other/non-binary/nb/prefer not to say → "Other"
  - Reject if offensive/unclear

current_weight_kg (float):
  - Range: 20-300 kg
  - Accept decimals
  - Convert pounds: lbs × 0.453592
  - Reject if unrealistic

height_cm (float):
  - Range: 100-250 cm
  - Accept decimals
  - Convert: (feet × 30.48) + (inches × 2.54)
  - Reject if unrealistic

activity_level (string):
  - EXACT values only: "Sedentary" / "Lightly Active" / "Moderately Active" / "Very Active" / "Extremely Active"
  - Interpret user's description and map to closest match

target_weight_kg (float):
  - Range: 20-300 kg
  - Should be within ±50kg of current weight (if known)
  - Same conversion as current_weight_kg

timeline_weeks (integer):
  - Range: 1-104 weeks
  - Convert: "3 months"→12, "half year"→26
  - Round decimals

workout_days_per_week (integer):
  - Range: 0-7 days
  - "every day"→7, "twice a week"→2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RESPONSE STRATEGY:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SITUATION → ACTION:

Valid answer:
  - Extract and normalize
  - Brief acknowledgment (2-4 words like "Got it!", "Thanks!")
  - Ask next question

Invalid but humorous (9000 kg, 200 years):
  - Light humor + redirect: "Haha! But seriously, what's your actual weight?"
  - Set extracted to null

Confused (wrong type or unclear):
  - Clarify: "I need your [field] - for example, [example]"
  - Set extracted to null

Clear refusal (nope, no, skip, I don't want to):
  - Exit immediately: "I understand. All these details are essential for your plan. Feel free to return when you're ready!"
  - Set next_question to null

Gibberish/typo (oo, asdf, random letters):
  - Simple: "I didn't catch that. [Repeat question]"
  - Set extracted to null

Off-topic questions:
  - Brief: "I can help with that later! First, [repeat question]"
  - Set extracted to null

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT FORMAT (JSON only):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{{
  "extracted": {{
    "name": null,
    "age": null,
    "gender": null,
    "current_weight_kg": null,
    "height_cm": null,
    "activity_level": null,
    "target_weight_kg": null,
    "timeline_weeks": null,
    "workout_days_per_week": null
  }},
  "situation_detected": "valid|invalid_humorous|confused|refusal|gibberish|off_topic",
  "acknowledgment": "brief natural response",
  "next_question": "question OR null if refusal"
}}

If refusal detected, set next_question to null.
Only extract the current field if response is actually relevant to it.
"""

# Initialize
client = Groq(api_key=os.getenv("GROQ_API_KEY"))
profile = USER_SCHEMA.copy()
messages = []

# Print initial greeting
print(build_greeting(profile))

# Main conversation loop
while True:
    user_input = input("\nYou: ").strip()
    if user_input.lower() in ["exit", "quit"]:
        print("\nAssistant: Thank you for your time! Feel free to come back anytime.")
        break

    if not user_input:
        print("\nAssistant: I didn't catch that. Could you please respond?")
        continue

    # Build system message with context
    system_message = {
        "role": "system",
        "content": build_system_prompt(profile, conversation_context)
    }

    # Update messages
    if messages and messages[0]["role"] == "system":
        messages[0] = system_message
    else:
        messages.insert(0, system_message)

    messages.append({"role": "user", "content": user_input})

    # Get response from LLM
    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=messages,
            temperature=0.5,  # Slightly higher for more natural responses
            response_format={"type": "json_object"}
        )
    except Exception as e:
        print(f"\nAssistant: I'm having trouble connecting. Please try again. (Error: {e})")
        messages.pop()
        continue

    assistant_raw = response.choices[0].message.content

    try:
        parsed = json.loads(assistant_raw)
    except json.JSONDecodeError:
        print("\nAssistant: I apologize, I didn't quite catch that. Could you please rephrase?")
        messages.pop()
        continue

    # Debug: Show what was extracted
    extracted_items = {k: v for k, v in parsed.get("extracted", {}).items() if v is not None}
    if extracted_items:
        print(f"\n[Extracted: {extracted_items}]")

    # Update conversation context based on situation
    situation = parsed.get("situation_detected", "")
    current_field = missing_fields(profile)[0] if missing_fields(profile) else None
    
    if situation == "refusal":
        conversation_context["consecutive_refusals"] += 1
        conversation_context["total_refusals"] += 1
    else:
        conversation_context["consecutive_refusals"] = 0
    
    if situation in ["invalid_humorous", "confused"] and current_field:
        conversation_context["invalid_attempts"][current_field] = \
            conversation_context["invalid_attempts"].get(current_field, 0) + 1

    # Update profile
    old_profile = profile.copy()
    profile = merge_profile(profile, parsed.get("extracted", {}))
    
    messages.append({"role": "assistant", "content": assistant_raw})

    # Build response
    response_text = ""
    if parsed.get("acknowledgment"):
        response_text += parsed["acknowledgment"]
    
    if parsed.get("next_question") is None:
        # Check if profile is complete or user wants to exit
        remaining = missing_fields(profile)
        
        if not remaining:
            # Profile complete - success!
            if not response_text:
                response_text = "Thank you so much!"
            response_text += " I have all the information I need. Your profile is now complete."
            print(f"\nAssistant: {response_text}")
            print("\n" + "="*50)
            print("FINAL PROFILE:")
            print("="*50)
            for k, v in profile.items():
                print(f"  {k.replace('_', ' ').title()}: {v}")
            print("="*50)
        else:
            # User refused too many times - graceful exit
            print(f"\nAssistant: {response_text}")
            print("\n" + "="*50)
            print("SESSION PAUSED")
            print("="*50)
            print(f"Collected so far:")
            for k, v in profile.items():
                if v is not None:
                    print(f"  ✓ {k.replace('_', ' ').title()}: {v}")
            print(f"\nStill needed:")
            for field in remaining:
                print(f"  ✗ {field.replace('_', ' ').title()}")
            print("="*50)
        break
    else:
        if response_text:
            response_text += " "
        response_text += parsed["next_question"]
        print(f"\nAssistant: {response_text}")

print("\nSession ended. Come back anytime you're ready to continue!")
