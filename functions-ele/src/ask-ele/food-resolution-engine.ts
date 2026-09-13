import {AiProvider} from "../ai/ai-provider";
import {FoodSearchResult} from "../nutrition/types";
import {
  FoodResolutionDecision,
  FoodResolutionOption,
} from "./types";

/**
 * Normalizes a string using basic mechanical rules:
 * - lowercase
 * - trim
 * - collapse whitespace
 * - simple singular/plural removal ('s')
 * (No hardcoded synonym or equivalence dictionaries)
 *
 * @param {string} str - Input string.
 * @return {string} Mechanically normalized string.
 */
function normalizeMechanicalStr(str: string): string {
  let norm = str
    .toLowerCase()
    .trim()
    .replace(/[^\w\s]/g, "")
    .replace(/\s+/g, " ");

  if (norm.endsWith("s") && !norm.endsWith("ss")) {
    norm = norm.slice(0, -1);
  }
  return norm;
}

export interface FoodResolutionEngineOptions {
  highConfidenceThreshold?: number;
  macroDeltaThreshold?: number;
}

/**
 * Provider-independent Food Resolution Engine that evaluates search candidates
 * using mechanical fast-path matching or AI semantic reranking.
 */
export class FoodResolutionEngine {
  private readonly highConfidenceThreshold: number;
  private readonly macroDeltaThreshold: number;

  /**
   * Creates an instance of FoodResolutionEngine.
   *
   * @param {FoodResolutionEngineOptions} [options] - Configurable threshold parameters.
   */
  constructor(options?: FoodResolutionEngineOptions) {
    this.highConfidenceThreshold = options?.highConfidenceThreshold ?? 0.75;
    this.macroDeltaThreshold = options?.macroDeltaThreshold ?? 0.20;
  }

  /**
   * Resolves provider search candidates against a target user food concept.
   *
   * @param {string} foodName - User/LLM interpreted food concept name.
   * @param {FoodSearchResult[]} candidates - Candidate search results from provider.
   * @param {AiProvider} [aiProvider] - Active AI provider for semantic reranking.
   * @return {Promise<FoodResolutionDecision>} Resolution decision outcome.
   */
  public async resolveCandidates(
    foodName: string,
    candidates: FoodSearchResult[],
    aiProvider?: AiProvider
  ): Promise<FoodResolutionDecision> {
    if (!candidates || candidates.length === 0) {
      return {
        type: "ASK_CLARIFICATION",
        confidence: 0.0,
        options: [],
        question:
          `I couldn't find a database match for "${foodName}". ` +
          "Could you clarify what you had?",
      };
    }

    const normFood = normalizeMechanicalStr(foodName);

    // 1. FAST PATH: Mechanical Exact Match (Case / Punctuation / Plural Normalized)
    for (const c of candidates) {
      const normCand = normalizeMechanicalStr(c.name);
      if (normCand === normFood && !c.brandName) {
        console.log(
          `[FOOD_RESOLUTION_DIAGNOSTIC] Fast path exact generic match: "${c.name}"`
        );
        return {
          type: "AUTO_SELECT",
          selectedCandidate: c,
          confidence: 1.0,
        };
      }
    }

    for (const c of candidates) {
      const normCand = normalizeMechanicalStr(c.name);
      if (normCand === normFood) {
        console.log(
          `[FOOD_RESOLUTION_DIAGNOSTIC] Fast path exact match: "${c.name}"`
        );
        return {
          type: "AUTO_SELECT",
          selectedCandidate: c,
          confidence: 0.95,
        };
      }
    }

    // 2. AMBIGUOUS PATH: AI Semantic Reranking Layer
    let evaluations: Array<{
      candidate: FoodSearchResult;
      semanticScore: number;
      isGeneric: boolean;
      userLabel: string;
    }> = [];

    if (aiProvider && aiProvider.rerankFoodCandidates) {
      try {
        const rerankInputCandidates = candidates.map((c) => ({
          foodId: c.foodId,
          name: c.name,
          brandName: c.brandName,
          caloriesPer100g: c.caloriesPer100g,
        }));

        const rerankResult = await aiProvider.rerankFoodCandidates({
          foodName,
          candidates: rerankInputCandidates,
        });

        if (rerankResult && Array.isArray(rerankResult.evaluations)) {
          evaluations = candidates.map((cand) => {
            const ev = rerankResult.evaluations.find(
              (e) => e.foodId === cand.foodId
            );
            return {
              candidate: cand,
              semanticScore: ev?.semanticScore ?? 0.0,
              isGeneric: ev?.isGeneric ?? !cand.brandName,
              userLabel: ev?.userLabel || cand.name,
            };
          });
        }
      } catch (err) {
        console.warn("AI semantic candidate reranking error:", err);
      }
    }

    // Fallback if AI reranking was unavailable or failed
    if (evaluations.length === 0) {
      evaluations = candidates.map((c) => {
        const normC = normalizeMechanicalStr(c.name);
        let score = 0.0;
        if (normC === normFood) {
          score = c.brandName ? 0.90 : 1.0;
        } else if (normC.includes(normFood) || normFood.includes(normC)) {
          score = c.brandName ? 0.70 : 0.85;
        }
        return {
          candidate: c,
          semanticScore: score,
          isGeneric: !c.brandName,
          userLabel: c.name,
        };
      });
    }

    // Sort by semantic score descending, preferring generic candidates on tie
    evaluations.sort((a, b) => {
      if (Math.abs(b.semanticScore - a.semanticScore) > 0.05) {
        return b.semanticScore - a.semanticScore;
      }
      if (a.isGeneric && !b.isGeneric) return -1;
      if (!a.isGeneric && b.isGeneric) return 1;
      return 0;
    });

    // 3. NUTRITIONAL VARIANCE ASSESSMENT
    // Calculate macro delta ONLY among semantically plausible candidates (score >= 0.50)
    const plausibleEvaluations = evaluations.filter(
      (e) => e.semanticScore >= 0.50
    );
    const topCandidate = evaluations[0];
    const secondCandidate = plausibleEvaluations[1];

    let macroDeltaRatio = 0.0;
    if (
      topCandidate &&
      secondCandidate &&
      topCandidate.candidate.caloriesPer100g &&
      secondCandidate.candidate.caloriesPer100g
    ) {
      const c1 = topCandidate.candidate.caloriesPer100g;
      const c2 = secondCandidate.candidate.caloriesPer100g;
      const maxC = Math.max(c1, c2);
      if (maxC > 0) {
        macroDeltaRatio = Math.abs(c1 - c2) / maxC;
      }
    }

    // 4. DECISION POLICY
    const hasHighMacroVariance =
      secondCandidate !== undefined &&
      secondCandidate.semanticScore >= 0.60 &&
      macroDeltaRatio > this.macroDeltaThreshold;

    console.log(
      `[FOOD_RESOLUTION_DIAGNOSTIC] Engine evaluation summary for "${foodName}":`,
      JSON.stringify({
        topCandidateName: topCandidate?.candidate.name ?? null,
        topCandidateScore: topCandidate?.semanticScore ?? null,
        secondCandidateName: secondCandidate?.candidate.name ?? null,
        secondCandidateScore: secondCandidate?.semanticScore ?? null,
        macroDeltaRatio,
        hasHighMacroVariance,
      })
    );

    // A. AUTO_SELECT: High semantic confidence & no high macro variance between plausible alternatives
    if (
      topCandidate.semanticScore >= this.highConfidenceThreshold &&
      !hasHighMacroVariance
    ) {
      return {
        type: "AUTO_SELECT",
        selectedCandidate: topCandidate.candidate,
        confidence: topCandidate.semanticScore,
      };
    }

    // B. OFFER_OPTIONS: Plausible candidates (score >= 0.50) with nutritional delta
    const plausible = evaluations.filter((e) => e.semanticScore >= 0.50);
    if (plausible.length >= 2) {
      const options: FoodResolutionOption[] = plausible
        .slice(0, 3)
        .map((ev, idx) => ({
          optionId: `opt_${idx + 1}`,
          label: ev.userLabel,
          providerFoodId: ev.candidate.foodId,
          semanticFoodName: ev.candidate.name,
          brandName: ev.candidate.brandName,
        }));

      return {
        type: "OFFER_OPTIONS",
        confidence: topCandidate.semanticScore,
        options,
        question: `Which is closest to what you had for ${foodName}?`,
      };
    }

    // C. ASK_CLARIFICATION: Low semantic confidence / fundamentally different candidates
    const distinctOptions: FoodResolutionOption[] = evaluations
      .slice(0, 3)
      .map((ev, idx) => ({
        optionId: `opt_${idx + 1}`,
        label: ev.userLabel,
        providerFoodId: ev.candidate.foodId,
        semanticFoodName: ev.candidate.name,
        brandName: ev.candidate.brandName,
      }));

    return {
      type: "ASK_CLARIFICATION",
      confidence: topCandidate.semanticScore,
      options: distinctOptions,
      question:
        `I found a few different foods matching "${foodName}". ` +
        "Which one did you mean?",
    };
  }
}
