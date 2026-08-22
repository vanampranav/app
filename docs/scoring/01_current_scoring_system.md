# Challenge Scoring — The Current System (Peak vs. Baseline)

_Last updated: 2026-08-13_

This document explains **exactly** how points work in the app today, how weekly
check-ins feed the score, and what happens when a participant misses a week.

---

## 1. The one formula

Every approved measurement is scored **against the participant's baseline** using
three **relative % changes**, weighted:

```
Score (composite) = (Body-fat % change × 0.50)
                  + (Weight-loss %    × 0.30)
                  + (Muscle-gain %    × 0.20)
```

Where each component is a **relative** change from baseline:

| Component | Formula | Meaning |
|---|---|---|
| Body-fat % change | `(baseBF − nowBF) / baseBF × 100` | how much of your fat you've lost |
| Weight loss % | `(baseWt − nowWt) / baseWt × 100` | % of body weight lost |
| Muscle gain % | `(nowMuscle − baseMuscle) / baseMuscle × 100` | % of muscle gained |

Positive = good. If body fat / muscle isn't provided, that component counts as 0.

---

## 2. How weekly check-ins feed the score — **"PEAK"**

The participant checks in each week. For **each approved check-in** we compute the
composite above (that check-in vs. the baseline). The participant's **score is the
single BEST (peak) composite** they've reached across all approved submissions —
weekly check-ins **and** the final.

```
Your score = MAX( composite@week1, composite@week2, …, composite@final ) + admin bonus
```

- A **great week is never lost.** If you peak at Week 3 and slip by the end, you
  keep your Week 3 score.
- The **leaderboard ranks by this same peak**, so what people see = who's winning.
- **Consistency** (how many weeks you checked in) is **tracked and shown, but does
  NOT change the score.**
- To be **eligible for a prize** once the challenge ends, you additionally need an
  **approved final submission** and a **verified payment** — but the winning score
  can still come from an earlier peak week.

---

## 3. Worked example

**Baseline:** 80 kg · 30% body fat · 32 kg muscle

| Check-in | Weight | Body fat | Muscle | Composite (vs baseline) |
|---|---|---|---|---|
| Week 1 | 79 kg | 29.5% | 32 kg | **1.21** |
| Week 2 | 76 kg | 27% | 33 kg | **7.13** |
| Week 3 | _missed_ | — | — | — |
| Week 4 | 75 kg | 26% | 33 kg | **9.17** |
| Final | 73 kg | 25% | 33.5 kg | **11.90** |

**Score = the peak = 11.90** (the final was their best). Plus any admin bonus.

---

## 4. What happens when a user MISSES a check-in (e.g. Week 3)

Because the score is the **peak vs. baseline**, missing a week is handled very
simply:

- **No direct penalty.** Week 3 just isn't a data point. Your score stays at the
  best of the weeks you _did_ submit.
- **The only real cost:** you miss a **chance to set a new personal best.** If Week
  3 would have been your leanest moment, that peak isn't recorded — until your
  final submission (or a later week) captures it.
- **Missing every weekly** is fine for the score itself — as long as you submit an
  approved **baseline** and **final**, you're scored baseline→final. (Weeklies are
  for tracking + motivation, not required for the score.)
- Missing weeks does **not** make you ineligible. Only a missing **final** (after
  the challenge closes) or unverified **payment** does.

**Example:** if the same user's Week 3 (had they submitted) would have been their
best at a composite of 12.5, then skipping it means their recorded best is 11.90
(the final) instead of 12.5 — they lose the *peak they actually achieved but never
measured*. Nothing is subtracted; they just don't get credit for an un-submitted
result.

---

## 5. The known downside — **negative scores**

Because the composite is a straight transformation number, a participant who
**gets worse** (gains fat / loses muscle) at every check-in has a **negative peak
composite** → a **negative score**. Example: baseline 80 kg / 30% BF, best week is
82 kg / 31% BF → composite ≈ **−2.6**.

A negative number on the leaderboard is demotivating. This is the main reason we're
evaluating alternatives (see `02_alternative_incremental_scoring.md` and the
recommendation in `03_recommendation.md`).

---

## 6. Summary

| Question | Answer (current system) |
|---|---|
| What's my score? | Best (peak) composite from baseline to any approved check-in/final, + admin bonus |
| Do check-ins add points? | No — only your **best** one counts; extra check-ins don't add points |
| Do I lose points for missing a week? | No — you just miss a chance to set a new best |
| Can my score go negative? | **Yes** — if you never improve on baseline |
| What's needed to win a prize? | Verified payment + approved **final** submission (score can come from an earlier peak) |
| Is it gameable? | No — it's your single best net transformation; yo-yoing doesn't help |
