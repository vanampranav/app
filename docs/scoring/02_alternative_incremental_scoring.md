# Challenge Scoring — Alternative: Incremental + Constant Check-in Points

_Last updated: 2026-08-13_

This document describes the **alternative** scoring model discussed: instead of
always comparing to the baseline, compare each check-in to the **previous
available check-in**, give a **constant number of points for every check-in**, and
**never show negative points.**

> This is written as a faithful spec of the idea **plus an honest analysis of its
> maths and pitfalls**, so we can compare it fairly against the current system.
> The final recommendation is in `03_recommendation.md`.

---

## 1. The idea, in plain words

1. **Constant participation points** — every approved weekly check-in earns a
   **fixed** number of points (say **+3**), no matter the result. This guarantees
   a growing, non-negative score and rewards *showing up*.
2. **Incremental progress** — each check-in's *progress* is measured against the
   **most recent available prior submission**:
   - Week 3 → compared to **Week 2** if it exists,
   - else **Week 1**,
   - else the **baseline**.
3. **No negatives** — a bad week never subtracts. A week where you regressed earns
   **0 progress** (but still keeps its participation points).

```
Total = Σ (participation points per approved check-in)
      + Σ (positive incremental progress, each week vs. the previous available check-in)
      + admin bonus
```

---

## 2. Worked example (same participant as Doc 01)

**Baseline:** 80 kg · 30% BF · 32 kg muscle. Participation = **+3 / check-in**.

| Check-in | vs. | Incremental composite | Progress counted | Participation |
|---|---|---|---|---|
| Week 1 | baseline | +1.21 | **+1.21** | +3 |
| Week 2 | Week 1 | +6.0 | **+6.0** | +3 |
| Week 3 | _missed_ | — | 0 | 0 |
| Week 4 | Week 2 | +2.25 | **+2.25** | +3 |
| Final | Week 4 | +3.02 | **+3.02** | +3 |

**Total ≈ (1.21 + 6.0 + 2.25 + 3.02) + (3×4) = 12.48 + 12 = 24.5**

### Missing Week 3 in this model
- You lose **Week 3's participation points** (you didn't check in).
- Week 4's progress is measured vs. **Week 2** (the last available), so the
  improvement you made across Weeks 2→4 is **still captured** — just credited to
  Week 4. **No progress is lost for missing a week**, only the participation points
  for that specific week.

---

## 3. Honest analysis — the three problems this model has

### Problem A — It is **gameable** (yo-yo farming)
Because each week is compared to the **previous** check-in and only positive change
counts, a participant can **oscillate** to farm the *same* progress twice:

- Week 1: 78 kg → earns progress for losing 2 kg.
- Week 2: 80 kg → regressed, earns **0** (no penalty).
- Week 3: 78 kg → compared to Week 2 (80 kg) → **earns progress for the same 2 kg again.**

The current "peak vs. baseline" model is immune to this (only your best net result
counts). To close this hole, "incremental" has to be redefined as *"improvement
beyond your previous **best**"* — but that is mathematically **identical to the
peak model**, just described week-by-week.

### Problem B — Relative %s **don't add up**
Percentage changes measured against *different* starting points do **not** sum to
the true change from baseline (they compound, not add). In the example, the
incremental progress summed to **12.48**, but the participant's actual baseline→final
transformation composite is **11.90**. So the incremental total is **inflated and
harder to interpret** — "24.5 points" no longer maps cleanly to a real
body-transformation number.

### Problem C — It changes what the score *means*
The current score answers *"how much did you transform?"* (a result). This model
answers *"how many points did you collect on the journey?"* (an XP total, heavily
influenced by attendance). That's a valid gamification choice — but it means the
**winner may be the most consistent check-in-er, not the biggest transformer**,
which may not be what a "Body Transformation Challenge" wants for its **prize**.

---

## 4. What this model is genuinely good at

- **Never negative** ✅ (the core goal).
- **Rewards consistency** ✅ (constant points pull people back each week).
- **Missing a week is gently handled** ✅ (only lose that week's participation).
- **Feels rewarding** ✅ (the number only ever goes up).

The problem is achieving all of that **without** the gaming hole (A), the inflated /
confusing maths (B), and without turning the prize into an attendance contest (C).

The next document shows how to keep every upside here while avoiding all three
downsides.
