
import re
import time
from logger_setup import mealplan_logger

# ============================================================
# PRE-COMPILED REGEX PATTERNS (compiled once at module load)
# ============================================================

# Day extraction pattern
DAY_PATTERN = re.compile(r"Day\s*(\d+):", re.IGNORECASE)

# Meal pattern - matches "- Breakfast (XXX kcal):" or "- Breakfast (XXX,...):"
MEAL_PATTERN = re.compile(
    r"[—\-–]?\s*(Breakfast|Lunch|Snack|Dinner)\s*\((\d+)[^)]*\)\s*:",
    re.IGNORECASE
)

# Item pattern: "1. Food - 150g - 200 kcal - 15p/8f/20c"
ITEM_PATTERN_MACROS = re.compile(
    r"^\s*\d+\.\s*(.*?)\s*[—\-–]+\s*([\d./]+\s*[a-zA-Z]*)\s*[—\-–]+\s*"
    r"(\d+(?:[.,]\d+)?)\s*kcal\s*[—\-–]+\s*"
    r"([\d.]+)p/([\d.]+)f/([\d.]+)c\s*$",
    re.MULTILINE | re.IGNORECASE
)

# Simple pattern: "1. Food - 150g - 200 kcal"
ITEM_PATTERN_SIMPLE = re.compile(
    r"^\s*\d+\.\s*(.*?)\s*[—\-–]+\s*([\d./]+\s*[a-zA-Z]*)\s*[—\-–]+\s*"
    r"(\d+(?:[.,]\d+)?)\s*kcal\s*$",
    re.MULTILINE | re.IGNORECASE
)

# FALLBACK pattern: More forgiving - catches "1. Food - qty - XXX kcal" with anything after
# This catches items where macros might be in a different format
ITEM_PATTERN_FALLBACK = re.compile(
    r"^\s*\d+\.\s*(.*?)\s*[—\-–]+\s*([\d./]+\s*[a-zA-Z]*)\s*[—\-–]+\s*"
    r"(\d+(?:[.,]\d+)?)\s*kcal",
    re.MULTILINE | re.IGNORECASE
)

# ULTRA FALLBACK: Catches ANY line with a number followed by "kcal"
# Format: "1. <anything> - <number> kcal" or similar
ITEM_PATTERN_ULTRA_FALLBACK = re.compile(
    r"^\s*(\d+)\.\s*(.+?)\s*[—\-–,|]\s*(\d+)\s*kcal",
    re.MULTILINE | re.IGNORECASE
)

# LAST RESORT: Just find "number kcal" pattern on any line starting with digit and period
ITEM_PATTERN_LAST_RESORT = re.compile(
    r"^\s*\d+\.\s*(.+)",  # Any line starting with "1. "
    re.MULTILINE
)

# Pattern to extract calories from a line
CALORIE_EXTRACT = re.compile(r"(\d+)\s*kcal", re.IGNORECASE)

# Pattern to extract macros from a line
MACRO_EXTRACT = re.compile(r"(\d+(?:\.\d+)?)\s*p[/,]\s*(\d+(?:\.\d+)?)\s*f[/,]\s*(\d+(?:\.\d+)?)\s*c", re.IGNORECASE)

# Pattern to extract quantity - look for number with unit before kcal
QUANTITY_EXTRACT = re.compile(r"[—\-–,|]\s*([\d./]+\s*(?:g|ml|cup|cups|tbsp|tsp|oz|slice|slices|piece|pieces|egg|eggs|serving|servings|medium|small|large|bunch|clove|cloves)?)\s*[—\-–,|]", re.IGNORECASE)

# Tuple pattern: "1. Food - 150g - (200, 10, 5, 30, 2)"
ITEM_PATTERN_TUPLE = re.compile(
    r"^\s*\d+\.\s*(.*?)\s*[—\-–]+\s*(.*?)\s*[—\-–]+\s*"
    r"\((\d+(?:[.,]\d+)?),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\)\s*$",
    re.MULTILINE | re.IGNORECASE
)

# Quantity parsing patterns
FRACTION_PATTERN = re.compile(r'(\d+)/(\d+)\s+([a-zA-Z]+)')
QUANTITY_PATTERN = re.compile(r'([\d.]+)\s*([a-zA-Z]*)')

# Quantity extraction pattern for output formatting
QTY_EXTRACT_PATTERN = re.compile(r'^([\d./]+)')

# Tuple to kcal conversion for fallback
TUPLE_TO_KCAL_PATTERN = re.compile(
    r'\((\d+(?:\.\d+)?),\s*[\d.]+,\s*[\d.]+,\s*[\d.]+,\s*[\d.]+\)'
)

# Goal classification patterns (pre-compiled)
GOAL_PATTERNS = {
    "weight_loss": [
        re.compile(r"(lose|shed|drop)\s+(weight|fat)", re.IGNORECASE),
        re.compile(r"fat\s+loss", re.IGNORECASE),
        re.compile(r"weight\s+loss", re.IGNORECASE),
        re.compile(r"slim\s+down", re.IGNORECASE),
    ],
    "muscle_gain": [
        re.compile(r"(gain|build|increase)\s+(muscle|mass)", re.IGNORECASE),
        re.compile(r"muscle\s+gain", re.IGNORECASE),
        re.compile(r"bulk", re.IGNORECASE),
    ],
    "get_stronger": [
        re.compile(r"(get|become|feel)\s+(stronger|strong)", re.IGNORECASE),
        re.compile(r"increase\s+strength", re.IGNORECASE),
        re.compile(r"lift\s+heavier", re.IGNORECASE),
    ],
    "get_flexible": [
        re.compile(r"(become|get|improve)\s+(flexible|mobility)", re.IGNORECASE),
        re.compile(r"(yoga|stretching|mobility\s+training)", re.IGNORECASE),
    ],
    "get_fit": [
        re.compile(r"get\s+fit", re.IGNORECASE),
        re.compile(r"(stay|keep)\s+(active|healthy)", re.IGNORECASE),
        re.compile(r"overall\s+fitness", re.IGNORECASE),
        re.compile(r"improve\s+fitness", re.IGNORECASE),
    ],
}

# ============================================================
# FUNCTIONS
# ============================================================

def calculate_bmi(weight_kg, height_cm):
    height_m = height_cm / 100
    return round(weight_kg / (height_m ** 2), 2)

def calculate_tdee(weight_kg, height_cm, age, gender, activity_level):
    height_m = height_cm / 100
    bmi = calculate_bmi(weight_kg, height_cm)
    
    # BMR: Mifflin-St Jeor Equation
    if gender == "male":
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age + 5
    else:
        bmr = 10 * weight_kg + 6.25 * height_cm - 5 * age - 161

    activity_factors = {
        "sedentary": 1.2,   
        "light": 1.375,
        "moderate": 1.55,
        "active": 1.725,
        "very active": 1.9
    }
    return int(bmr * activity_factors.get(activity_level, 1.55))

goal_config = {
    "weight_loss": {"calorie_offset": -500, "workout_focus": "Fat Burn & Cardio"},
    "muscle_gain": {"calorie_offset": +500, "workout_focus": "Strength & Hypertrophy"},
    "get_fit": {"calorie_offset": 0, "workout_focus": "Mixed Cardio and Strength"},
    "get_stronger": {"calorie_offset": +300, "workout_focus": "Progressive Overload & Compound Lifts"},
    "get_flexible": {"calorie_offset": 0, "workout_focus": "Mobility, Yoga, and Stretching"},
    "default": {"calorie_offset": 0, "workout_focus": "Mixed Cardio and Strength"}
}


def classify_goal_from_text(goal_text: str) -> str:
    """Classify goal using pre-compiled patterns."""
    goal_text_lower = goal_text.lower()

    for goal_name, patterns in GOAL_PATTERNS.items():
        for pattern in patterns:
            if pattern.search(goal_text_lower):
                return goal_name
    
    return "get_fit"


def parse_quantity(quantity_str):
    """Parse '150g', '2 eggs', '1/2 cup' into (value, unit)."""
    quantity_str = str(quantity_str).strip()
    
    fraction_match = FRACTION_PATTERN.match(quantity_str)
    if fraction_match:
        value = float(fraction_match.group(1)) / float(fraction_match.group(2))
        return str(value), fraction_match.group(3).lower()
    
    match = QUANTITY_PATTERN.match(quantity_str)
    if match:
        return match.group(1), match.group(2).lower() if match.group(2) else 'g'
    
    return quantity_str, 'g'


def round_to_5(value):
    """Round to nearest 5."""
    return max(5, round(value / 5) * 5)


def is_gram_based(unit):
    """Check if unit is gram-based (adjustable). Only 'g' and 'grams'."""
    unit_lower = str(unit).lower().strip()
    return unit_lower in ['g', 'grams', 'gram']


def is_ml_based(unit):
    """Check if unit is ml-based (adjustable volume measurement)."""
    unit_lower = str(unit).lower().strip()
    return unit_lower in ['ml', 'milliliter', 'milliliters']


def is_serving_based(unit):
    """Check if unit is serving-based (should NOT be adjusted, only gram/ml should be)."""
    unit_lower = str(unit).lower()
    serving_keywords = [
        "serving", "cup", "slice", "piece", "egg", "tbsp", "tsp",
        "medium", "small", "large", "whole", "half", 
        "bowl", "scoop", "handful", "portion", "unit", "item",
        "banana", "apple", "orange", "fruit"
    ]
    return any(k in unit_lower for k in serving_keywords)


def classify_item_macro_type(item):
    """Classify item as protein/fat/carbs/mixed based on dominant macro."""
    protein = item.get('protein', 0)
    fat = item.get('fat', 0)
    carbs = item.get('carbs', 0)
    
    total_macros = protein + fat + carbs
    if total_macros == 0:
        return 'mixed'
    
    protein_ratio = protein / total_macros
    fat_ratio = fat / total_macros
    carbs_ratio = carbs / total_macros
    
    if protein_ratio > 0.5:
        return 'protein'
    elif fat_ratio > 0.5:
        return 'fat'
    elif carbs_ratio > 0.5:
        return 'carbs'
    else:
        return 'mixed'


def adjust_item_quantity(item, target_ratio, max_ratio_change=0.5):
    """
    Adjust a gram-based or ml-based item's quantity by target_ratio, respecting limits.
    ONLY adjusts items with gram-based or ml-based units.
    Returns: actual ratio applied, or 1.0 if not adjusted
    """
    if not (is_gram_based(item['unit']) or is_ml_based(item['unit'])):
        return 1.0
    
    # Cap the adjustment to prevent extreme changes
    capped_ratio = max(1 - max_ratio_change, min(1 + max_ratio_change, target_ratio))
    
    new_quantity = item['quantity'] * capped_ratio
    
    # Apply minimum quantity rules (5g/ml minimum)
    new_quantity = max(5, round_to_5(new_quantity))
    
    # Update all values
    actual_ratio = new_quantity / item['quantity']
    item['quantity'] = new_quantity
    item['calories'] = new_quantity * item['cal_density']
    item['protein'] = new_quantity * item['protein_density']
    item['fat'] = new_quantity * item['fat_density']
    item['carbs'] = new_quantity * item['carbs_density']
    item['fiber'] = new_quantity * item['fiber_density']
    
    return actual_ratio

LOG_MODE = "B"  # Batch logs at end, not during streaming

def normalize_text_for_parsing(text):
    """
    Normalize Unicode characters that can vary between environments.
    This fixes parsing issues that occur on Linux but not Windows due to
    different Unicode representations of similar-looking characters.
    """
    original_text = text
    
    # Normalize all dash-like characters to standard hyphen-minus (U+002D)
    dash_chars = [
        '\u2014',  # — Em dash
        '\u2013',  # – En dash  
        '\u2212',  # − Minus sign
        '\u2010',  # ‐ Hyphen
        '\u2011',  # ‑ Non-breaking hyphen
        '\u2012',  # ‒ Figure dash
        '\u2015',  # ― Horizontal bar
        '\uFE58',  # ﹘ Small em dash
        '\uFE63',  # ﹣ Small hyphen-minus
        '\uFF0D',  # － Fullwidth hyphen-minus
    ]
    for dash in dash_chars:
        text = text.replace(dash, '-')
    
    # Normalize whitespace (non-breaking spaces, etc.)
    whitespace_chars = [
        '\u00A0',  # Non-breaking space
        '\u2000',  # En quad
        '\u2001',  # Em quad
        '\u2002',  # En space
        '\u2003',  # Em space
        '\u2004',  # Three-per-em space
        '\u2005',  # Four-per-em space
        '\u2006',  # Six-per-em space
        '\u2007',  # Figure space
        '\u2008',  # Punctuation space
        '\u2009',  # Thin space
        '\u200A',  # Hair space
        '\u202F',  # Narrow no-break space
        '\u205F',  # Medium mathematical space
        '\u3000',  # Ideographic space
    ]
    for ws in whitespace_chars:
        text = text.replace(ws, ' ')
    
    # Normalize line endings to Unix-style
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    
    # Log if we made changes (helps diagnose encoding issues)
    if text != original_text:
        mealplan_logger.info("[NORMALIZE] Text was normalized - found non-standard Unicode characters")
    
    return text

def process_single_day(day_string, target_calories, macros=None, min_qty=5, expected_day_number=None):
    """
    Parses and adjusts a single day's meal plan output from GPT with macro correction.
    
    CRITICAL: Ensures calories stay within ±100 kcal of target by doing adjustments
    BEFORE final rounding, then rounding smartly.
    
    Args:
        expected_day_number: If provided, used as fallback when day number can't be parsed from text.
    """
    # FIRST: Normalize the input text to handle encoding differences
    day_string = normalize_text_for_parsing(day_string)
    
    # DEBUG: Log the raw input to help diagnose parsing issues
    # Count items that look like food items (lines starting with "1.", "2.", etc.)
    potential_items = len(re.findall(r'^\s*\d+\.', day_string, re.MULTILINE))
    potential_kcal = len(re.findall(r'\d+\s*kcal', day_string, re.IGNORECASE))
    mealplan_logger.info(f"[RAW_INPUT] Length={len(day_string)}, PotentialItems={potential_items}, KcalMentions={potential_kcal}")
    
    # If very few items found, log the actual content for debugging
    if potential_items < 8:  # Expect at least 8 items in a full day
        # Log first 500 chars to see what's happening
        preview = day_string[:500].replace('\n', '\\n')
        mealplan_logger.warning(f"[RAW_INPUT_PREVIEW] Low item count! First 500 chars: {preview}")
    
    t_start = time.perf_counter()
    batch_logs = []
    
    def log_entry(label, inp, out):
        if LOG_MODE == "A":
            mealplan_logger.info(f"[{label}] {inp}  -->  {out}")
        elif LOG_MODE == "B":
            batch_logs.append((label, inp, out))

    macros = macros or {}
    target_protein = macros.get('protein_g', 0)
    target_fat = macros.get('fat_g', 0)
    target_carbs = macros.get('carbs_g', 0)
    
    # --- Extract day number (using pre-compiled pattern, with fallback to expected_day_number) ---
    day_match = DAY_PATTERN.search(day_string)
    if day_match:
        day_number = day_match.group(1)
        inp_day_title = day_match.group(0)
    elif expected_day_number is not None:
        # Use expected day number as fallback
        day_number = str(expected_day_number)
        inp_day_title = f"Day {expected_day_number}:"
        mealplan_logger.warning(f"[DAY_FALLBACK] Could not parse day number from text, using expected: {expected_day_number}")
    else:
        # Last resort: try more flexible pattern
        flexible_match = re.search(r'Day\s*(\d+)', day_string, re.IGNORECASE)
        if flexible_match:
            day_number = flexible_match.group(1)
            inp_day_title = flexible_match.group(0)
        else:
            day_number = "1"
            inp_day_title = "Day 1:"
            mealplan_logger.error(f"[DAY_PARSE_FAILED] Could not parse day number, defaulting to Day 1!")
    
    # Log day title transformation
    log_entry("DAY", inp_day_title, f"Day {day_number}:")

    meal_plan = {}

    # === MEAL PATTERN (using pre-compiled pattern) ===
    meals = MEAL_PATTERN.findall(day_string)
    
    # DIAGNOSTIC: Log meals found
    mealplan_logger.info(f"[MEALS_FOUND] Day {day_number}: {len(meals)} meals - {[m[0] for m in meals]}")
    
    # Log first 200 chars of each section for debugging format issues
    if len(meals) < 4:
        # Log the actual structure we're trying to parse
        for meal_type in ['Breakfast', 'Lunch', 'Snack', 'Dinner']:
            meal_pos = day_string.lower().find(meal_type.lower())
            if meal_pos >= 0:
                snippet = day_string[meal_pos:meal_pos+150].replace('\n', '\\n')
                mealplan_logger.info(f"[MEAL_DEBUG] {meal_type} starts at pos {meal_pos}: '{snippet}...'")
    
    # If no meals found, try a more forgiving pattern
    if len(meals) < 4:
        mealplan_logger.warning(f"[MEALS_MISSING] Expected 4 meals, found {len(meals)}. Trying fallback pattern.")
        # Fallback: look for meal names anywhere
        fallback_meals = []
        for meal_type in ['Breakfast', 'Lunch', 'Snack', 'Dinner']:
            # Try to find "Breakfast (XXX" pattern
            fallback_match = re.search(
                rf'{meal_type}\s*\((\d+)', 
                day_string, 
                re.IGNORECASE
            )
            if fallback_match and meal_type not in [m[0] for m in meals]:
                fallback_meals.append((meal_type, fallback_match.group(1)))
                mealplan_logger.info(f"[FALLBACK_MEAL] Found {meal_type} via fallback")
        meals = list(meals) + fallback_meals

    # --- Parse meals and items (NO ADJUSTMENTS YET) ---
    for meal_name, meal_kcal in meals:
        try:
            stated_total = int(meal_kcal)
        except Exception:
            stated_total = 0
        
        meal_plan[meal_name] = {
            "stated_total": stated_total,
            "items": [],
            "inp_meal_title": f"- {meal_name} ({meal_kcal} kcal):"
        }

    # =========================================================================
    # SIMPLE, ROBUST PARSING: Parse ALL lines with "kcal" in the entire day
    # =========================================================================
    # This approach doesn't rely on complex regex - just finds lines with calories
    # and assigns them to the correct meal based on position
    
    lines = day_string.split('\n')
    current_meal = None
    
    for line in lines:
        line_stripped = line.strip()
        if not line_stripped:
            continue
        
        # Check if this line indicates a meal header
        line_lower = line_stripped.lower()
        if 'breakfast' in line_lower and '(' in line_stripped:
            current_meal = 'Breakfast'
            continue
        elif 'lunch' in line_lower and '(' in line_stripped:
            current_meal = 'Lunch'
            continue
        elif 'snack' in line_lower and '(' in line_stripped:
            current_meal = 'Snack'
            continue
        elif 'dinner' in line_lower and '(' in line_stripped:
            current_meal = 'Dinner'
            continue
        
        # Skip if we haven't found a meal yet or if this line doesn't have calories
        if not current_meal:
                continue
        if current_meal not in meal_plan:
            continue
        if 'kcal' not in line_lower:
                continue

        # CRITICAL: Skip "Total" lines - these are summaries, not food items!
        if line_lower.startswith('total') or 'total:' in line_lower or 'total daily' in line_lower:
            continue
        
        # Check if line starts with a number (food items start with "1.", "2.", etc.)
        is_numbered_item = re.match(r'^\d+\.', line_stripped)
        
        # Also accept lines that have quantity patterns (fallback for non-numbered format)
        # e.g., "Greek yogurt - 150g - 100 kcal" or lines with separators
        has_quantity_pattern = re.search(r'\b\d+\s*(g|ml|oz|cup|egg|slice|piece|tbsp|tsp)\b', line_stripped, re.IGNORECASE)
        has_separator_format = re.search(r'\s+[-–—|]\s+', line_stripped)
        
        # Skip if it doesn't look like a food item at all
        if not is_numbered_item and not (has_quantity_pattern and has_separator_format):
            continue
        
        # This line has "kcal" - it's a food item. Parse it simply.
        # Look for: "1. Food name - quantity - XXX kcal" or similar
        
        # Extract calories (find number before "kcal")
        cal_match = re.search(r'(\d+)\s*kcal', line_stripped, re.IGNORECASE)
        if not cal_match:
            continue
        
        try:
            calories = float(cal_match.group(1))
        except:
                continue
        
        if calories <= 0:
                continue

        # Extract food name - everything from start (after number if present) to first separator
        # Remove the leading "1. " or "2. " etc (if present)
        food_part = re.sub(r'^\s*\d+\.\s*', '', line_stripped)
        
        # Also strip leading whitespace/indentation that might be left
        food_part = food_part.strip()
        
        # Split by common separators and take the first part as food name
        separators = [' - ', ' – ', ' — ', ' | ', ', ']
        food_name = food_part
        for sep in separators:
            if sep in food_name:
                food_name = food_name.split(sep)[0]
                break
        
        food_name = food_name.strip()
        if not food_name or len(food_name) < 2:
            continue
        
        # CRITICAL: Extract quantity ONLY from the portion BEFORE "kcal"
        # This prevents matching "2g" from macros like "2g/0.5g/20g"
        kcal_pos = line_stripped.lower().find('kcal')
        if kcal_pos > 0:
            qty_search_region = line_stripped[:kcal_pos]
        else:
            qty_search_region = line_stripped
        
        # Try to extract quantity (look for patterns like "150g", "1 cup", "2 eggs")
        # IMPORTANT: Check serving-based units FIRST (pieces, cups, eggs) before grams
        # This ensures "2 pieces" is found before any "2g" in macros
        qty_patterns = [
            (r'(\d+)\s*pieces?\b', 'piece'),      # 2 pieces - CHECK FIRST
            (r'(\d+)\s*cups?\b', 'cup'),          # 1 cup
            (r'(\d+)\s*eggs?\b', 'egg'),          # 2 eggs
            (r'(\d+)\s*slices?\b', 'slice'),      # 2 slices
            (r'(\d+)\s*servings?\b', 'serving'),  # 1 serving
            (r'(\d+)\s*tbsp\b', 'tbsp'),          # 2 tbsp
            (r'(\d+)\s*tsp\b', 'tsp'),            # 1 tsp
            (r'(\d+)\s*medium\b', 'medium'),      # 1 medium
            (r'(\d+)\s*small\b', 'small'),        # 1 small
            (r'(\d+)\s*large\b', 'large'),        # 1 large
            (r'(\d+)\s*g\b', 'g'),                # 150g - CHECK AFTER serving units
            (r'(\d+)\s*ml\b', 'ml'),              # 200ml
            (r'(\d+)\s*oz\b', 'oz'),              # 4oz
        ]
        
        qty_value = 100  # Default
        unit = 'g'
        gpt_qty_str = "100g"
        
        for pattern, unit_name in qty_patterns:
            qty_match = re.search(pattern, qty_search_region, re.IGNORECASE)
            if qty_match:
                try:
                    qty_value = float(qty_match.group(1))
                    unit = unit_name
                    gpt_qty_str = qty_match.group(0)
                    break
                except:
                    continue

        if qty_value <= 0:
            qty_value = 100
        
        # Try to extract macros (look for Xp/Xf/Xc pattern)
        macro_match = re.search(r'(\d+(?:\.\d+)?)\s*p[/,]\s*(\d+(?:\.\d+)?)\s*f[/,]\s*(\d+(?:\.\d+)?)\s*c', line_stripped, re.IGNORECASE)
        if macro_match:
            try:
                protein = float(macro_match.group(1))
                fat = float(macro_match.group(2))
                carbs = float(macro_match.group(3))
            except:
                protein = (calories * 0.35) / 4
                fat = (calories * 0.35) / 9
                carbs = (calories * 0.30) / 4
        else:
            # Estimate macros (35/35/30 split)
            protein = (calories * 0.35) / 4
            fat = (calories * 0.35) / 9
            carbs = (calories * 0.30) / 4
        
        cal_density = calories / qty_value if qty_value > 0 else 1

        meal_plan[current_meal]["items"].append({
            "name": food_name,
                "quantity": float(qty_value),
            "unit": unit,
                "calories": float(calories),
                "protein": protein,
                "fat": fat,
                "carbs": carbs,
            "fiber": 0,
                "cal_density": cal_density,
                "protein_density": protein / qty_value if qty_value > 0 else 0,
                "fat_density": fat / qty_value if qty_value > 0 else 0,
                "carbs_density": carbs / qty_value if qty_value > 0 else 0,
            "fiber_density": 0,
                "gpt_qty_str": gpt_qty_str,
                "gpt_calories": float(calories),
                "gpt_quantity": float(qty_value),
            "inp_item_str": line_stripped,
            })

    # =========================================================================
    # FALLBACK: For meals with no parsed items, try to extract from meal header line
    # =========================================================================
    # This handles cases where GPT outputs inline items like:
    # "- Breakfast (405 kcal): Greek yogurt with berries and honey"
    
    for meal_name, meal_data in meal_plan.items():
        if meal_data.get('items'):
            continue  # Already has items, skip
        
        stated_total = meal_data.get('stated_total', 0)
        if stated_total <= 0:
            continue
        
        # Try to find the meal header line and extract inline content
        meal_header_pattern = re.compile(
            rf'{meal_name}\s*\(\d+[^)]*\)\s*:\s*(.+)',
            re.IGNORECASE
        )
        
        header_match = meal_header_pattern.search(day_string)
        if header_match:
            inline_content = header_match.group(1).strip()
            
            # Skip if it looks like a numbered item (will be parsed normally)
            if re.match(r'^\s*\d+\.', inline_content):
                continue
            
            # Extract what looks like food content
            # Stop at newline or next meal marker
            inline_content = inline_content.split('\n')[0].strip()
            
            if inline_content and len(inline_content) > 3:
                mealplan_logger.info(f"[INLINE_FALLBACK] Creating item from inline content for {meal_name}: '{inline_content[:50]}...'")
                
                # Create a synthetic item using the stated calories
                # Estimate: 35% protein, 35% fat, 30% carbs
                calories = stated_total
                protein = (calories * 0.35) / 4
                fat = (calories * 0.35) / 9
                carbs = (calories * 0.30) / 4
                
                meal_data['items'].append({
                    'name': inline_content[:100],  # Truncate long names
                    'quantity': 1,
                    'unit': 'serving',
                    'calories': float(calories),
                    'protein': protein,
                    'fat': fat,
                    'carbs': carbs,
                    'fiber': 0,
                    'cal_density': float(calories),
                    'protein_density': protein,
                    'fat_density': fat,
                    'carbs_density': carbs,
                    'fiber_density': 0,
                    'gpt_qty_str': '1 serving',
                    'gpt_calories': float(calories),
                    'gpt_quantity': 1,
                    'inp_item_str': f"1. {inline_content[:100]} - 1 serving - {calories} kcal",
                })

    # =========================================================================
    # STEP 0: PER-MEAL SCALING - Fix when GPT's items don't match stated total
    # =========================================================================
    # This handles cases where GPT says "Lunch (471 kcal)" but only outputs 137 kcal of items
    # We scale up the items proportionally to get closer to the stated total
    
    for meal_name, meal_data in meal_plan.items():
        stated_total = meal_data.get('stated_total', 0)
        if stated_total <= 0:
            continue
        
        # Calculate actual total from items
        items = meal_data.get('items', [])
        if not items:
            continue
        
        actual_total = sum(item.get('calories', 0) for item in items)
        if actual_total <= 0:
            continue
        
        # If items are less than 70% of stated total, GPT probably forgot items
        # Scale up existing items to compensate (up to 2x each)
        ratio = stated_total / actual_total
        
        if ratio > 1.3:  # Items are significantly below stated total
            # Cap scaling at 2.5x per item (increased from 2x to handle larger gaps)
            scale_factor = min(ratio, 2.5)
            
            mealplan_logger.info(
                f"[MEAL_SCALE] {meal_name}: Items={actual_total:.0f}kcal, Stated={stated_total}kcal, "
                f"Scaling by {scale_factor:.2f}x"
            )
            
            for item in items:
                if is_gram_based(item.get('unit', '')) or is_ml_based(item.get('unit', '')):
                    old_qty = item['quantity']
                    new_qty = old_qty * scale_factor
                    item['quantity'] = new_qty
                    item['calories'] = new_qty * item.get('cal_density', 1)
                    item['protein'] = new_qty * item.get('protein_density', 0)
                    item['fat'] = new_qty * item.get('fat_density', 0)
                    item['carbs'] = new_qty * item.get('carbs_density', 0)
                    item['fiber'] = new_qty * item.get('fiber_density', 0)
                    # CRITICAL: Update gpt_quantity so fine-tuning phase can still adjust
                    # Without this, clamp_quantity uses old baseline and blocks further increases
                    item['gpt_quantity'] = new_qty
                else:
                    # For non-gram items (cups, eggs, etc.), just scale the calories
                    item['calories'] = item['calories'] * scale_factor
                    item['protein'] = item.get('protein', 0) * scale_factor
                    item['fat'] = item.get('fat', 0) * scale_factor
                    item['carbs'] = item.get('carbs', 0) * scale_factor

    # --- Helper functions ---
    def calculate_totals():
        totals = {'calories': 0, 'protein': 0, 'fat': 0, 'carbs': 0, 'fiber': 0}
        for meal_data in meal_plan.values():
            for item in meal_data['items']:
                totals['calories'] += item.get('calories', 0)
                totals['protein'] += item.get('protein', 0)
                totals['fat'] += item.get('fat', 0)
                totals['carbs'] += item.get('carbs', 0)
                totals['fiber'] += item.get('fiber', 0)
        return totals

    def get_max_quantity(item):
        """Max quantity - Allow reasonable scaling after per-meal adjustment."""
        original_qty = item.get('gpt_quantity', 100)
        
        # Allow up to 2.0x for daily fine-tuning (increased from 1.5x)
        # Combined with per-meal scaling (up to 2.5x), this allows up to 5x total if needed
        return original_qty * 2.0

    def is_main_protein_dish(item):
        """Detect main protein dish using nutritional data only. Never goes below 100g."""
        protein_density = item.get('protein_density', 0)
        protein = item.get('protein', 0)
        calories = item.get('gpt_calories', 1)
        original_qty = item.get('gpt_quantity', 0)
        
        protein_calorie_ratio = (protein * 4) / calories if calories > 0 else 0
        
        is_protein_dense = protein_density > 0.12
        is_protein_focused = protein_calorie_ratio > 0.25
        is_main_portion = original_qty >= 100
        
        return is_protein_dense and is_protein_focused and is_main_portion

    def get_min_quantity(item):
        """Min quantity - Allow reasonable reduction after per-meal adjustment."""
        original_qty = item.get('gpt_quantity', 100)
        
        # Allow down to 0.6x for daily fine-tuning
        return original_qty * 0.6

    def clamp_quantity(item, new_qty):
        """Clamp quantity within acceptable range"""
        min_qty = get_min_quantity(item)
        max_qty = get_max_quantity(item)
        return max(min_qty, min(max_qty, new_qty))

    def is_adjustable_for_macros(item):
        """Only adjust primary protein/carb/fat sources"""
        unit = item.get('unit', '').lower()
        
        # Never adjust serving-based items
        if is_serving_based(unit):
            return False
        
        # Only adjust gram/ml based
        if not (is_gram_based(unit) or is_ml_based(unit)):
            return False
        
        original_qty = item.get('gpt_quantity', item['quantity'])
        cal_density = item.get('cal_density', 0)
        
        # Don't adjust tiny portions (toppings/condiments)
        if original_qty < 20 and cal_density > 4:
            return False
        if original_qty < 15:
            return False
        
        return True

    # === CHECK PARSING COMPLETENESS ===
    initial_totals = calculate_totals()
    initial_calories = initial_totals['calories']
    
    # Log parsing result
    parsing_completeness = initial_calories / target_calories if target_calories > 0 else 1.0
    mealplan_logger.info(
        f"[PARSE_RESULT] Parsed {initial_calories:.0f} kcal ({parsing_completeness*100:.0f}% of target {target_calories})"
    )
    
    # Determine adjustment strategy based on parsing completeness
    if parsing_completeness < 0.5:
        # Critical: Less than 50% parsed - skip adjustments entirely
        mealplan_logger.warning(f"[PARSE_CRITICAL] Only {parsing_completeness*100:.0f}% parsed - skipping adjustments")
        goto_output = True
        parsing_seems_incomplete = True
    elif parsing_completeness < 0.85:
        # Warning: 50-85% parsed - do conservative adjustments
        mealplan_logger.warning(f"[PARSE_WARNING] Only {parsing_completeness*100:.0f}% parsed - conservative adjustments")
        goto_output = False
        parsing_seems_incomplete = True
    else:
        # Good: 85%+ parsed - normal adjustments
        goto_output = False
        parsing_seems_incomplete = False
    
    # If skipping adjustments, just calculate totals and go to output
    if goto_output:
        for meal_data in meal_plan.values():
            meal_data["total_cal"] = sum(float(i.get("calories", 0)) for i in meal_data["items"])
            meal_data["total_protein"] = sum(float(i.get("protein", 0)) for i in meal_data["items"])
            meal_data["total_fat"] = sum(float(i.get("fat", 0)) for i in meal_data["items"])
            meal_data["total_carbs"] = sum(float(i.get("carbs", 0)) for i in meal_data["items"])
            meal_data["total_fiber"] = sum(float(i.get("fiber", 0)) for i in meal_data["items"])

    # === STEP 2: Macro correction (on UNROUNDED gram/ml items) ===
    # If parsing is incomplete, reduce iterations; if critical, skip entirely
    if goto_output:
        MAX_ITERATIONS = 0
    elif parsing_seems_incomplete:
        MAX_ITERATIONS = 4  # Increased from 2
    else:
        MAX_ITERATIONS = 10  # Increased from 6
    
    for iteration in range(MAX_ITERATIONS):
        current = calculate_totals()
        
        # Check constraints
        calorie_deficit = target_calories - current['calories'] if target_calories > 0 else 0
        protein_deficit = target_protein - current['protein'] if target_protein > 0 else 0
        fat_deficit = target_fat - current['fat'] if target_fat > 0 else 0
        carbs_deficit = target_carbs - current['carbs'] if target_carbs > 0 else 0
        
        calories_ok = abs(calorie_deficit) <= 100
        protein_ok = abs(protein_deficit) <= max(5, target_protein * 0.05) if target_protein > 0 else True
        fat_ok = abs(fat_deficit) <= max(3, target_fat * 0.05) if target_fat > 0 else True
        carbs_ok = abs(carbs_deficit) <= max(5, target_carbs * 0.05) if target_carbs > 0 else True
        
        if calories_ok and protein_ok and fat_ok and carbs_ok:
            break
        
        # Get adjustable items
        adjustable_items = [
            (meal_name, idx, item)
            for meal_name, meal_data in meal_plan.items()
            for idx, item in enumerate(meal_data['items'])
            if is_adjustable_for_macros(item)
        ]
        
        if not adjustable_items:
            break
        
        # Priority: Calories > Protein > Fat > Carbs
        
        # Fix calories if needed - but with STRICT limits
        if not calories_ok and abs(calorie_deficit) > 20:
            num_adjustable = len(adjustable_items)
            
            if num_adjustable > 0:
                # Calculate per-item calorie change (even distribution)
                per_item_cal_change = calorie_deficit / num_adjustable
                
                # Limit per-item calorie change per iteration
                # Increased limits to allow reaching target more effectively
                max_cal_change = 30 if parsing_seems_incomplete else 60
                per_item_cal_change = max(-max_cal_change, min(max_cal_change, per_item_cal_change))
                
                for meal_name, idx, item in adjustable_items:
                    if item['cal_density'] > 0:
                        qty_change = per_item_cal_change / item['cal_density']
                        new_qty = item['quantity'] + qty_change
                        
                        # Use clamping to prevent drastic changes
                        new_qty = clamp_quantity(item, new_qty)
                        
                        item['quantity'] = new_qty
                        item['calories'] = new_qty * item['cal_density']
                        item['protein'] = new_qty * item['protein_density']
                        item['fat'] = new_qty * item['fat_density']
                        item['carbs'] = new_qty * item['carbs_density']
                        item['fiber'] = new_qty * item['fiber_density']
        
        # Recalculate and check if we should do macro adjustments
        # CRITICAL: Only do macro adjustments if calories are reasonably close to target
        # Otherwise, macro adjustments can blow up the calorie count
        current = calculate_totals()
        calorie_headroom = abs(target_calories - current['calories']) < 200  # Increased from 150
        
        if not calorie_headroom:
            # Calories are too far off - skip macro adjustments this iteration
            # Let the next iteration's calorie correction fix it first
            continue
        
        protein_deficit = target_protein - current['protein'] if target_protein > 0 else 0
        protein_ok = abs(protein_deficit) <= max(5, target_protein * 0.05) if target_protein > 0 else True
        
        # Fix protein if needed (only small adjustments to avoid breaking calories)
        if not protein_ok and abs(protein_deficit) > 2:
            protein_items = [x for x in adjustable_items if x[2]['protein_density'] > 0.05]
            if protein_items:
                protein_items.sort(key=lambda x: x[2]['protein_density'], reverse=(protein_deficit > 0))
                # Limit adjustment to avoid breaking calorie budget
                max_cal_change_per_item = 30  # Max 30 kcal change per item for macro fixes
                per_item = protein_deficit / len(protein_items)
                
                for meal_name, idx, item in protein_items:
                    qty_change = per_item / item['protein_density']
                    # Cap the calorie impact
                    cal_impact = abs(qty_change * item['cal_density'])
                    if cal_impact > max_cal_change_per_item:
                        qty_change = (max_cal_change_per_item / item['cal_density']) * (1 if qty_change > 0 else -1)
                    
                    new_qty = item['quantity'] + qty_change
                    new_qty = clamp_quantity(item, new_qty)
                    
                    item['quantity'] = new_qty
                    item['calories'] = new_qty * item['cal_density']
                    item['protein'] = new_qty * item['protein_density']
                    item['fat'] = new_qty * item['fat_density']
                    item['carbs'] = new_qty * item['carbs_density']
                    item['fiber'] = new_qty * item['fiber_density']
        
        # Check calories again after protein adjustment
        current = calculate_totals()
        if abs(target_calories - current['calories']) > 150:
            continue  # Skip remaining macro fixes, fix calories first
        
        fat_deficit = target_fat - current['fat'] if target_fat > 0 else 0
        fat_ok = abs(fat_deficit) <= max(3, target_fat * 0.05) if target_fat > 0 else True
        
        if not fat_ok and abs(fat_deficit) > 2:
            fat_items = [x for x in adjustable_items if x[2]['fat_density'] > 0.05]
            if fat_items:
                fat_items.sort(key=lambda x: x[2]['fat_density'], reverse=(fat_deficit > 0))
                max_cal_change_per_item = 25
                per_item = fat_deficit / len(fat_items)
                
                for meal_name, idx, item in fat_items:
                    qty_change = per_item / item['fat_density']
                    cal_impact = abs(qty_change * item['cal_density'])
                    if cal_impact > max_cal_change_per_item:
                        qty_change = (max_cal_change_per_item / item['cal_density']) * (1 if qty_change > 0 else -1)
                    
                    new_qty = item['quantity'] + qty_change
                    new_qty = clamp_quantity(item, new_qty)
                    
                    item['quantity'] = new_qty
                    item['calories'] = new_qty * item['cal_density']
                    item['protein'] = new_qty * item['protein_density']
                    item['fat'] = new_qty * item['fat_density']
                    item['carbs'] = new_qty * item['carbs_density']
                    item['fiber'] = new_qty * item['fiber_density']
        
        # Check calories again after fat adjustment
        current = calculate_totals()
        if abs(target_calories - current['calories']) > 150:
            continue
        
        carbs_deficit = target_carbs - current['carbs'] if target_carbs > 0 else 0
        carbs_ok = abs(carbs_deficit) <= max(5, target_carbs * 0.05) if target_carbs > 0 else True
        
        if not carbs_ok and abs(carbs_deficit) > 2:
            carb_items = [x for x in adjustable_items if x[2]['carbs_density'] > 0.05]
            if carb_items:
                carb_items.sort(key=lambda x: x[2]['carbs_density'], reverse=(carbs_deficit > 0))
                max_cal_change_per_item = 25
                per_item = carbs_deficit / len(carb_items)
                
                for meal_name, idx, item in carb_items:
                    qty_change = per_item / item['carbs_density']
                    cal_impact = abs(qty_change * item['cal_density'])
                    if cal_impact > max_cal_change_per_item:
                        qty_change = (max_cal_change_per_item / item['cal_density']) * (1 if qty_change > 0 else -1)
                    
                    new_qty = item['quantity'] + qty_change
                    new_qty = clamp_quantity(item, new_qty)
                    
                    item['quantity'] = new_qty
                    item['calories'] = new_qty * item['cal_density']
                    item['protein'] = new_qty * item['protein_density']
                    item['fat'] = new_qty * item['fat_density']
                    item['carbs'] = new_qty * item['carbs_density']
                    item['fiber'] = new_qty * item['fiber_density']

    # === STEP 3: SMART ROUNDING (while preserving calorie constraint) ===
    # Skip if we're bypassing all adjustments
    if not goto_output:
        # Now round to nearest 5, but check if it breaks calorie budget
        current_before_round = calculate_totals()
    
    for meal_data in meal_plan.values():
        for item in meal_data["items"]:
            unit = str(item.get("unit", "")).lower()
            
            if is_gram_based(unit) or is_ml_based(unit):
                original_qty = item['quantity']
                rounded_qty = round_to_5(original_qty)
                
                # Apply rounding
                item['quantity'] = rounded_qty
                item['calories'] = rounded_qty * item['cal_density']
                item['protein'] = rounded_qty * item['protein_density']
                item['fat'] = rounded_qty * item['fat_density']
                item['carbs'] = rounded_qty * item['carbs_density']
                item['fiber'] = rounded_qty * item['fiber_density']
    
    # Check if rounding broke the calorie constraint
    current_after_round = calculate_totals()
    calorie_diff = abs(current_after_round['calories'] - target_calories)
    
    if calorie_diff > 100:
        # Rounding broke it - need to fix
        # Distribute the adjustment across multiple items instead of just one
        adjustable = [
            (meal_name, item)
            for meal_name, meal_data in meal_plan.items()
            for item in meal_data['items']
            if is_adjustable_for_macros(item)
        ]
        
        if adjustable:
            cal_needed = target_calories - current_after_round['calories']
            num_items = len(adjustable)
            per_item_cal = cal_needed / num_items
            
            for meal_name, item in adjustable:
                if item['cal_density'] > 0:
                    qty_adjustment = per_item_cal / item['cal_density']
                    new_qty = item['quantity'] + qty_adjustment
                    new_qty = clamp_quantity(item, new_qty)
                    new_qty = round_to_5(new_qty)
                    
                    item['quantity'] = new_qty
                    item['calories'] = new_qty * item['cal_density']
                    item['protein'] = new_qty * item['protein_density']
                    item['fat'] = new_qty * item['fat_density']
                    item['carbs'] = new_qty * item['carbs_density']
                    item['fiber'] = new_qty * item['fiber_density']

    # === FINAL CHECK - Multiple aggressive passes ===
    # Keep adjusting until we hit target or can't improve
    for final_pass in range(8):  # Increased from 5
        final_totals = calculate_totals()
        final_diff = abs(final_totals['calories'] - target_calories)
        
        if final_diff <= 100:
            break  # Target met!
            
        cal_deficit = target_calories - final_totals['calories']
        
        adjustable = [
            item
            for meal_data in meal_plan.values()
            for item in meal_data['items']
            if is_adjustable_for_macros(item)
        ]
        
        if not adjustable:
            break
        
        # Track if we made any progress this pass
        old_total = final_totals['calories']
        
        # Calculate how much each item can contribute
        per_item_target = cal_deficit / len(adjustable)
        
        for item in adjustable:
            if item['cal_density'] > 0:
                qty_change = per_item_target / item['cal_density']
                new_qty = item['quantity'] + qty_change
                
                # Use clamping to prevent drastic changes
                new_qty = clamp_quantity(item, new_qty)
                new_qty = round_to_5(new_qty)
                
                item['quantity'] = new_qty
                item['calories'] = new_qty * item['cal_density']
                item['protein'] = new_qty * item['protein_density']
                item['fat'] = new_qty * item['fat_density']
                item['carbs'] = new_qty * item['carbs_density']
                item['fiber'] = new_qty * item['fiber_density']
        
        # Check if we made progress
        new_total = calculate_totals()['calories']
        if abs(new_total - old_total) < 10:
            break  # No more progress possible
    
    # Log final status
    final_check = calculate_totals()
    final_diff = abs(final_check['calories'] - target_calories)
    if final_diff > 100:
        mealplan_logger.warning(
            f"[POST-PROCESS] Could not meet calorie target within constraints. "
            f"Target: {target_calories}, Actual: {final_check['calories']:.0f}, Diff: {final_diff:.0f}. "
                f"Adjustable items: {len(adjustable) if 'adjustable' in dir() else 0}. "
            f"This preserves realistic portions over exact calories."
        )

        # --- Final meal totals (after adjustments) ---
        for meal_data in meal_plan.values():
            meal_data["total_cal"] = sum(float(i.get("calories", 0)) for i in meal_data["items"])
            meal_data["total_protein"] = sum(float(i.get("protein", 0)) for i in meal_data["items"])
            meal_data["total_fat"] = sum(float(i.get("fat", 0)) for i in meal_data["items"])
            meal_data["total_carbs"] = sum(float(i.get("carbs", 0)) for i in meal_data["items"])
            meal_data["total_fiber"] = sum(float(i.get("fiber", 0)) for i in meal_data["items"])

    # --- Final meal totals (always needed for output) ---
    for meal_data in meal_plan.values():
        meal_data["total_cal"] = sum(float(i.get("calories", 0)) for i in meal_data["items"])
        meal_data["total_protein"] = sum(float(i.get("protein", 0)) for i in meal_data["items"])
        meal_data["total_fat"] = sum(float(i.get("fat", 0)) for i in meal_data["items"])
        meal_data["total_carbs"] = sum(float(i.get("carbs", 0)) for i in meal_data["items"])
        meal_data["total_fiber"] = sum(float(i.get("fiber", 0)) for i in meal_data["items"])

    # --- Output formatting ---
    output_lines = [f"Day {day_number}:"]
    for meal_name, meal_data in meal_plan.items():
        meal_total_kcal = round_to_5(meal_data['total_cal'])
        
        meal_outp_str = f"- {meal_name} ({meal_total_kcal} kcal):"
        meal_inp_str = meal_data.get('inp_meal_title', f"- {meal_name} (??? kcal):")

        log_entry("MEAL", meal_inp_str, meal_outp_str)
        output_lines.append(meal_outp_str)

        for i, item in enumerate(meal_data["items"], 1):
            if is_gram_based(item['unit']) or is_ml_based(item['unit']):
                # Only gram/ml items get adjusted, so format as integer
                qty_str = f"{int(round(item['quantity']))}"
            else:
                # For ALL non-gram units (serving-based, medium, etc.), preserve original quantity
                # These items should NEVER be adjusted, so use original GPT quantity string
                gpt_qty_str = item.get('gpt_qty_str', '')
                if gpt_qty_str:
                    # Extract just the numeric/fraction part from original string like "1/2 medium"
                    qty_match = QTY_EXTRACT_PATTERN.match(gpt_qty_str)
                    if qty_match:
                        qty_str = qty_match.group(1)
                    else:
                        qty_str = gpt_qty_str.split()[0] if gpt_qty_str.split() else str(item["quantity"])
                else:
                    # Fallback: format the quantity value with fraction handling
                    qty_val = item["quantity"]
                    if abs(qty_val - 0.25) < 0.01:
                        qty_str = "1/4"
                    elif abs(qty_val - 0.5) < 0.01:
                        qty_str = "1/2"
                    elif abs(qty_val - 0.75) < 0.01:
                        qty_str = "3/4"
                    elif abs(qty_val - 0.33) < 0.02:
                        qty_str = "1/3"
                    elif abs(qty_val - 0.67) < 0.02:
                        qty_str = "2/3"
                    elif qty_val >= 1 and abs(qty_val - round(qty_val)) < 0.01:
                        qty_str = str(int(qty_val))
                    else:
                        qty_str = f"{qty_val:.2f}".rstrip('0').rstrip('.')
            
            unit = item["unit"]
            kcal = round_to_5(item["calories"])
            item_outp_str = f"  {i}. {item['name']} — {qty_str} {unit} — {kcal} kcal"
            
            item_inp_str = item.get('inp_item_str', f"{item['name']} — ??? — ???")
            log_entry("ITEM", item_inp_str, item_outp_str)

            output_lines.append(item_outp_str)

    daily_total_kcal = round_to_5(sum(m["total_cal"] for m in meal_plan.values()))
    total_items = sum(len(m["items"]) for m in meal_plan.values())
    
    # === FALLBACK: If parsing failed (0 calories or no items), return cleaned raw input ===
    if daily_total_kcal == 0 or total_items == 0:
        mealplan_logger.error(
            f"[PARSE_FAILURE] Day {day_number} - No items parsed. "
            f"Returning raw GPT output as fallback."
        )
        # Clean up the raw input and return it
        # Remove tuple format, keep readable format
        # Ensure fallback output still starts with "Day X:" so frontend can split segments
        fallback_output = day_string.strip()
        if not fallback_output.lower().startswith(f"day {day_number}"):
            fallback_output = f"Day {day_number}:\n{fallback_output}"
        # Try to convert tuple format to readable format (using pre-compiled pattern)
        fallback_output = TUPLE_TO_KCAL_PATTERN.sub(r'\1 kcal', fallback_output)
        # Return with anomaly indicating complete parse failure
        anomaly = {
            'type': 'parse_failure',
            'day_number': day_number,
            'target_calories': target_calories,
            'actual_calories': 0
        }
        return (fallback_output, anomaly)
    
    output_lines.append(f"Total Daily Calories: {daily_total_kcal} kcal")

    # === ANOMALY DETECTION ===
    # Trigger regeneration ONLY for calorie issues (strict: >100 kcal off)
    # Macros are logged as warnings but don't trigger regeneration
    anomaly_info = None
    
    # Calculate actual macros from all items
    actual_protein = sum(item.get('protein', 0) for meal in meal_plan.values() for item in meal.get('items', []))
    actual_fat = sum(item.get('fat', 0) for meal in meal_plan.values() for item in meal.get('items', []))
    actual_carbs = sum(item.get('carbs', 0) for meal in meal_plan.values() for item in meal.get('items', []))
    
    # Get target macros
    target_protein = macros.get('protein_g', 0) if macros else 0
    target_fat = macros.get('fat_g', 0) if macros else 0
    target_carbs = macros.get('carbs_g', 0) if macros else 0
    
    # Check conditions
    calorie_diff = abs(daily_total_kcal - target_calories)
    protein_diff = actual_protein - target_protein
    fat_diff = actual_fat - target_fat
    carbs_diff = actual_carbs - target_carbs
    protein_off = abs(protein_diff) / target_protein * 100 if target_protein > 0 else 0
    fat_off = abs(fat_diff) / target_fat * 100 if target_fat > 0 else 0
    carbs_off = abs(carbs_diff) / target_carbs * 100 if target_carbs > 0 else 0
    
    # ALWAYS log macro comparison (target vs actual vs difference)
    mealplan_logger.info(f"[MACRO_CHECK] Day {day_number}: Calories - Target: {target_calories} | Actual: {daily_total_kcal} | Diff: {daily_total_kcal - target_calories:+d} kcal")
    mealplan_logger.info(f"[MACRO_CHECK] Day {day_number}: Protein  - Target: {target_protein}g | Actual: {actual_protein:.0f}g | Diff: {protein_diff:+.0f}g ({protein_off:.0f}%)")
    mealplan_logger.info(f"[MACRO_CHECK] Day {day_number}: Fat      - Target: {target_fat}g | Actual: {actual_fat:.0f}g | Diff: {fat_diff:+.0f}g ({fat_off:.0f}%)")
    mealplan_logger.info(f"[MACRO_CHECK] Day {day_number}: Carbs    - Target: {target_carbs}g | Actual: {actual_carbs:.0f}g | Diff: {carbs_diff:+.0f}g ({carbs_off:.0f}%)")
    
    # Trigger regeneration for (ONLY if post-processing couldn't fix it):
    # 1. Calories off by > 100 kcal (strict)
    # 2. Protein off by > 25% (important for muscle/fitness goals - tighter threshold)
    problems = []
    if calorie_diff > 100:
        problems.append(f"Calories off by {calorie_diff} kcal (target: {target_calories}, actual: {daily_total_kcal})")
    if protein_off > 25:
        problems.append(f"Protein off by {protein_off:.0f}% (target: {target_protein}g, actual: {actual_protein:.0f}g)")
    
    if problems:
        mealplan_logger.info(f"[POST_PROCESS_FAILED] Day {day_number}: Even after quantity adjustments, still off - triggering regeneration")
        anomaly_info = {
            'type': 'calorie_deficit',
            'day_number': day_number,
            'target_calories': target_calories,
            'actual_calories': daily_total_kcal,
            'target_macros': {'protein': target_protein, 'fat': target_fat, 'carbs': target_carbs},
            'actual_macros': {'protein': round(actual_protein), 'fat': round(actual_fat), 'carbs': round(actual_carbs)},
            'problems': problems
        }
        mealplan_logger.warning(
            f"[ANOMALY_DETECTED] Day {day_number}: {'; '.join(problems)} - REGENERATING"
        )

    # END TIMING
    t_end = time.perf_counter()
    total_ms = (t_end - t_start) * 1000

    if LOG_MODE == "B":
        mealplan_logger.info("\n===== BATCH TRANSFORMATIONS START =====")
        for label, inp, out in batch_logs:
            mealplan_logger.info(f"[{label}] {inp}  -->  {out}")
        mealplan_logger.info("===== BATCH TRANSFORMATIONS END =====\n")

    mealplan_logger.info(f"[PROCESS_SINGLE_DAY TIME][MODE={LOG_MODE}] {total_ms:.2f} ms")

    # Return tuple: (output, anomaly_info) - anomaly_info is None if no issues
    return ("\n".join(output_lines), anomaly_info)


def calculate_macros(weight, target_calories):
    """35% protein, 35% fat, 30% carbs split. Fiber is part of carbs."""
    PROTEIN_PERCENT = 0.35
    FAT_PERCENT = 0.35
    CARBS_PERCENT = 0.30
    FIBER_PER_1000_KCAL = 14
    
    protein_g = round((target_calories * PROTEIN_PERCENT) / 4)
    fat_g = round((target_calories * FAT_PERCENT) / 9)
    carbs_g = round((target_calories * CARBS_PERCENT) / 4)
    fiber_g = round((target_calories / 1000) * FIBER_PER_1000_KCAL)

    return {
        'protein_g': protein_g,
        'fat_g': fat_g,
        'carbs_g': carbs_g,
        'fiber_g': fiber_g
    }