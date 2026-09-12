# Implementation Plan — Ask Ele Regression A & B Architectural Correction (Approved with Adjustment)

## Goal Description
Fix Regression A (modifying an already resolved `readyToLog = true` meal) and Regression B (guidance question `"what is my dinner today?"` incorrectly triggering meal logging) using structural state guardrails and LLM semantic classification enhancements, incorporating the non-meal entity recovery adjustment.

## Proposed Changes

### [Meal Orchestrator]
#### [MODIFY] [meal-orchestrator.ts](file:///Users/nvanam/EleFitApp/app/functions-ele/src/ask-ele/meal-orchestrator.ts)
- Enforce structural invariant in `prepareMeal()`: zero foods cannot produce a `MealProposal`. Return a structured non-meal indicator (`NO_MEAL_ENTITIES`) instead of creating an empty proposal or throwing an unhandled exception.
- Never persist that result or overwrite existing `session.mealDraft`.

### [State Manager]
#### [MODIFY] [state-manager.ts](file:///Users/nvanam/EleFitApp/app/functions-ele/src/ask-ele/state-manager.ts)
- Update `validateTurnClassification()` so `CHANGE_MEAL_TYPE` does not require item entity ID resolution (proposal-level state).
- Ensure `applyMutationsToMealDraft()` handles `CHANGE_MEAL_TYPE` correctly even when `readyToLog = true` and `activeEntityId = null`.
- In `processTurn()`, if `NEW_MEAL_LOG` produces zero foods (`NO_MEAL_ENTITIES`), recover through the general/guidance semantic path (`aiProvider.getGuidance()`) using the original utterance, with a guard preventing infinite recursion and preserving any existing `mealDraft`.

### [OpenAI AI Provider]
#### [MODIFY] [openai-provider.ts](file:///Users/nvanam/EleFitApp/app/functions-ele/src/ai/providers/openai-provider.ts)
- Strengthen `classifyTurnAndMutations()` instructions to accurately distinguish recommendation/guidance questions (`NEW_INTENT`), consumed food statements (`NEW_MEAL_LOG`), and proposal corrections (`MODIFICATION_OF_PENDING_TASK`).

### [Tests]
#### [MODIFY] [orchestrator.test.ts](file:///Users/nvanam/EleFitApp/app/functions-ele/src/ask-ele/orchestrator.test.ts)
- Add explicit regression tests for Regression A (modifying `readyToLog` meal type) and Regression B (guidance question routing when fresh), plus negative/control cases.

## Verification Plan
### Automated Tests
- Run `npm run build && node lib/ask-ele/run-test.js` in `functions-ele`.
