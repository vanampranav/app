/**
 * Parser for the AI Coach meal and workout plans.
 */

export interface MealItem {
    name: string;
    quantity: string;
    calories: number;
    macro: string;
}

export type WeeklyMeals = Record<string, MealItem[]>[];

export interface WorkoutPlan {
    name: string;
    duration: string;
    exercises: string[];
    isRestDay: boolean;
}

export type WeeklyWorkouts = WorkoutPlan[];

export function convertFeetInchesToCm(feet: number, inches: number = 0): number {
    const totalInches = (feet * 12) + inches;
    return Math.round(totalInches * 2.54);
}

export function convertLbsToKg(lbs: number): number {
    return Math.round(lbs / 2.20462);
}

export function parseMealPlan(text: string): WeeklyMeals {
    const weeklyMeals: WeeklyMeals = [];
    // Split by Day X markers, keeping the marker in the segment
    const daySegments = text.split(/(?=Day\s*\d+[:\s\u2013\u2014-])/i)
        .filter(d => {
            const trimmed = d.trim();
            return trimmed && (/^Day\s*\d+/i.test(trimmed) || /Breakfast|Lunch|Dinner|Snack|Workout|Exercise/i.test(trimmed));
        });

    daySegments.forEach((dayText, index) => {
        if (index >= 7) return;
        const dayMeals: Record<string, MealItem[]> = {};

        const mealSections = dayText.split(/[—\-–\u2013\u2014]\s*(Breakfast|Lunch|Snack|Dinner|Snacks)\s*\((\d+)[^)]*\)\s*:/i);

        for (let i = 1; i < mealSections.length; i += 3) {
            let mealType = mealSections[i].trim();
            if (mealType.toLowerCase() === 'snack') mealType = 'Snacks';
            const itemsText = mealSections[i + 2] || '';
            const items: MealItem[] = [];

            const itemLines = itemsText.split('\n');
            itemLines.forEach(line => {
                const match = line.match(/^\s*\d+\.\s*(.*?)\s*[—\-–\u2013\u2014]+\s*(.*?)\s*[—\-–\u2013\u2014]+\s*(\d+(?:\.\d+)?)\s*kcal\s*[—\-–\u2013\u2014]+\s*(.*)$/i);
                if (match) {
                    items.push({
                        name: match[1].trim(),
                        quantity: match[2].trim(),
                        calories: parseInt(match[3]),
                        macro: match[4].trim().replace(/\//g, ' • ')
                    });
                } else {
                    const simpleMatch = line.match(/^\s*\d+\.\s*(.*?)\s*[—\-–\u2013\u2014]+\s*(.*?)\s*[—\-–\u2013\u2014]+\s*(\d+(?:\.\d+)?)\s*kcal/i);
                    if (simpleMatch) {
                        items.push({
                            name: simpleMatch[1].trim(),
                            quantity: simpleMatch[2].trim(),
                            calories: parseInt(simpleMatch[3]),
                            macro: 'Modified'
                        });
                    } else {
                        // Very simple match: "1. Food — 200 kcal" (no quantity)
                        const verySimpleMatch = line.match(/^\s*\d+\.\s*(.*?)\s*[—\-–\u2013\u2014]+\s*(\d+(?:\.\d+)?)\s*kcal/i);
                        if (verySimpleMatch) {
                            items.push({
                                name: verySimpleMatch[1].trim(),
                                quantity: 'As specified',
                                calories: parseInt(verySimpleMatch[2]),
                                macro: 'Modified'
                            });
                        }
                    }
                }
            });

            if (items.length > 0) {
                dayMeals[mealType] = items;
            }
        }
        weeklyMeals.push(dayMeals);
    });

    // Ensure we have 7 days
    while (weeklyMeals.length < 7) weeklyMeals.push({});
    return weeklyMeals;
}

export function parseWorkoutPlan(text: string): WeeklyWorkouts {
    const weeklyWorkouts: WeeklyWorkouts = [];
    // Split by Day X markers, keeping the marker in the segment
    const daySegments = text.split(/(?=Day\s*\d+[:\s\u2013\u2014-])/i)
        .filter(d => {
            const trimmed = d.trim();
            return trimmed && (/^Day\s*\d+/i.test(trimmed) || /Breakfast|Lunch|Dinner|Snack|Workout|Exercise/i.test(trimmed));
        });

    daySegments.forEach((dayText, index) => {
        if (index >= 7) return;

        // Backend format: "Day 1 – [Muscle Focus or Rest Day]:"
        // Regex to extract focus after the dash/marker
        const headerMatch = dayText.match(/Day\s*\d+.*?[—\-–\u2013\u2014]\s*(.*?):/i);
        let name = headerMatch ? headerMatch[1].trim() : '';

        // Fallback for "Workout: Name (Duration)"
        if (!name || name.toLowerCase().includes('day')) {
            const workoutMatch = dayText.match(/Workout:\s*(.*?)\s*(?:\((.*?)\))?\n/i);
            if (workoutMatch) {
                name = workoutMatch[1].trim();
            }
        }

        if (!name) name = 'Rest Day';

        const durationMatch = dayText.match(/\((.*?mins?)\)/i);
        const duration = durationMatch ? durationMatch[1].trim() : '0 mins';

        const exercises: string[] = [];
        const lines = dayText.split('\n');
        lines.forEach(line => {
            // Match numbered items but ignore header/summary lines
            const exMatch = line.match(/^\s*\d+\.\s*(.*?)(?:\s*[—\-–\u2013\u2014]\s*.*)?$/);
            if (exMatch && !line.toLowerCase().includes('day') && !line.toLowerCase().includes('workout:')) {
                exercises.push(exMatch[1].trim());
            }
        });

        const isRestDay = name.toLowerCase().includes('rest') || exercises.length === 0;

        weeklyWorkouts.push({
            name: isRestDay ? 'Rest Day' : name,
            duration: isRestDay ? '0 mins' : duration,
            exercises,
            isRestDay
        });
    });

    // Ensure we have 7 days
    while (weeklyWorkouts.length < 7) {
        weeklyWorkouts.push({
            name: 'Rest Day',
            duration: '0 mins',
            exercises: [],
            isRestDay: true
        });
    }

    return weeklyWorkouts;
}

export function extractSpecsFromPrompt(prompt: string) {
    let p = prompt.toLowerCase();
    const specs: any = {};

    // 1. HEIGHT: "175cm", "5 feet 3 inch", "5.7 feet", "5ft 3in"
    const heightRegex = /(\d{2,3})\s*(?:cm|cms|centimeters?)/i;
    const feetInchesRegex = /(\d+)\s*(?:feet|feets|ft|foot|')\s*(?:(\d+)\s*(?:inches|inch|in|"))?/i;
    const feetDecimalRegex = /(\d+\.\d+)\s*(?:feet|feets|ft|foot|')/i;

    const heightMatch = p.match(heightRegex);
    const feetInchesMatch = p.match(feetInchesRegex);
    const feetDecimalMatch = p.match(feetDecimalRegex);

    if (heightMatch) {
        specs.height = heightMatch[1];
        p = p.replace(heightMatch[0], '[HEIGHT]');
    } else if (feetInchesMatch) {
        const feet = parseInt(feetInchesMatch[1]);
        const inches = feetInchesMatch[2] ? parseInt(feetInchesMatch[2]) : 0;
        specs.height = convertFeetInchesToCm(feet, inches).toString();
        p = p.replace(feetInchesMatch[0], '[HEIGHT]');
    } else if (feetDecimalMatch) {
        const feet = parseFloat(feetDecimalMatch[1]);
        specs.height = convertFeetInchesToCm(feet, 0).toString();
        p = p.replace(feetDecimalMatch[0], '[HEIGHT]');
    } else {
        const mMatch = p.match(/(\d\.\d{1,2})\s*(?:m|meters?)/i);
        if (mMatch) {
            specs.height = Math.round(parseFloat(mMatch[1]) * 100).toString();
            p = p.replace(mMatch[0], '[HEIGHT]');
        }
    }

    // 2. WEIGHT (CURRENT): Handle kg/lbs and convert to kg
    const currentWeightRegex = /(?<!(?:lose|shed|drop|reduce|gain|add|put on|target|reach|to|goal)\s*)\b(?:i'm|i am|weight|i weigh|currently|at|is|over|around|about|above|below)\b\s*(\d+(?:\.\d+)?)\s*(kgs?|kilograms?|lbs?|pounds?)/i;
    const currentWeightAltRegex = /(\d+(?:\.\d+)?)\s*(kgs?|kilograms?|lbs?|pounds?)\b\s*(?:weight|currently|at|i am|i'm|is|above|below|over|around)/i;

    const parseWeight = (val: string, unit: string) => {
        const numeric = parseFloat(val);
        if (unit.toLowerCase().startsWith('l') || unit.toLowerCase().startsWith('p')) {
            return convertLbsToKg(numeric).toString();
        }
        return numeric.toString();
    };

    const weightMatch = p.match(currentWeightRegex);
    if (weightMatch) {
        specs.currentWeight = parseWeight(weightMatch[1], weightMatch[2]);
        p = p.replace(weightMatch[0], '[WEIGHT]');
    } else {
        const weightAltMatch = p.match(currentWeightAltRegex);
        if (weightAltMatch) {
            specs.currentWeight = parseWeight(weightAltMatch[1], weightAltMatch[2]);
            p = p.replace(weightAltMatch[0], '[WEIGHT]');
        }
    }

    // 3. WEIGHT CHANGE (Relative) & TARGET WEIGHT (Convert lbs to kg)
    const loseRegex = /(?:lose|shed|drop|reduce|decrease)\s*(\d+(?:\.\d+)?)\b(?!\s*(?:%|percent|percentage|body fat))\s*(kg|kgs|lbs|pounds?)?/i;
    const loseMatch = p.match(loseRegex);
    if (loseMatch) {
        const val = parseFloat(loseMatch[1]);
        const unit = loseMatch[2] || 'kg';
        specs.weightToLose = (unit.startsWith('l') || unit.startsWith('p')) ? convertLbsToKg(val) : val;
        p = p.replace(loseMatch[0], '[LOSE]');
    }

    const gainRegex = /(?:gain|add|put on|increase)\s*(\d+(?:\.\d+)?)\b(?!\s*(?:%|percent|percentage|body fat))\s*(kg|kgs|lbs|pounds?)?/i;
    const gainMatch = p.match(gainRegex);
    if (gainMatch) {
        const val = parseFloat(gainMatch[1]);
        const unit = gainMatch[2] || 'kg';
        specs.weightToGain = (unit.startsWith('l') || unit.startsWith('p')) ? convertLbsToKg(val) : val;
        p = p.replace(gainMatch[0], '[GAIN]');
    }

    const targetRegex = /(?:target|reach|to|goal|taget)\s*(?:weight\s*)?(?:is\s*|at\s*)?(\d+(?:\.\d+)?)\b(?!\s*(?:%|percent|percentage|body fat))\s*(kg|kgs|lbs|pounds?)?/i;
    const targetMatch = p.match(targetRegex);
    if (targetMatch) {
        specs.targetWeight = parseWeight(targetMatch[1], targetMatch[2] || 'kg');
        p = p.replace(targetMatch[0], '[TARGET]');
    }

    // 4. TIMELINE: "6 months", "12 weeks"
    const timelineRegex = /(\d+)\s*(weeks?|months?|wks?|mos?)/i;
    const timelineMatch = p.match(timelineRegex);
    if (timelineMatch) {
        specs.timelineValue = timelineMatch[1];
        const unit = timelineMatch[2].toLowerCase();
        specs.timelineUnit = (unit.startsWith('w')) ? 'weeks' : 'months';
        p = p.replace(timelineMatch[0], '[TIMELINE]');
    }

    // 5. AGE: "i am 25", "25 years old", "age 25", "25 y.o"
    // More rigid patterns to avoid false matches
    const explicitAgeRegex = /\b(?:i am|i'm|age is|at|is)\s*([1-9][0-9])\b/i;
    const yearsOldRegex = /\b([1-9][0-9])\b\s*(?:years? old|y\.o\.|yrs? old|years? of age)/i;

    const ageMatch = p.match(explicitAgeRegex) || p.match(yearsOldRegex);
    if (ageMatch) {
        specs.age = ageMatch[1];
    }

    // 6. GENDER
    if (/\b(male|man|boy|gentleman)\b/i.test(p)) specs.gender = 'male';
    else if (/\b(female|woman|girl|lady)\b/i.test(p)) specs.gender = 'female';

    return specs;
}
