# Challenge Scoring — IMPLEMENTED Model (Weekly Accumulated Points)

_Implemented 2026-08-15. This is what the app now does, based on
`Challenge_Scoring_Recommended_Model.docx`._

## What was built
Points are **earned at every approved check-in** and **added to a running total**:

```
weekly = (bodyFat% × 0.5) + (weight% × 0.3) + (muscle% × 0.2)
week's points = max(0, weekly) × 10
Total = sum of every check-in's points  (+ admin bonus)
```

- Each measurement's **%** is the improvement **beyond the participant's best-so-far**
  for that measurement (lower weight/body-fat, higher muscle).
- **Never negative:** a poor week earns **0**, never subtracts.
- **×10 scale** for larger, motivating numbers.
- The **leaderboard and the winner ranking both use this total** (+ admin bonus).
- Eligibility unchanged: verified payment + approved baseline; once the challenge
  is completed, an approved **final** is required to be prize-eligible.

## Anti-farming — the one important clarification vs. the .docx
The document's hard requirement (§14) is that a participant must **not** be able to
yo-yo (lose → regain → re-lose the same kg) and get paid twice. To guarantee that,
improvement is measured **beyond the personal best**, not merely beyond the previous
check-in.

This means the Rahul example differs at **Week 4**:
- The doc's §9 compares Week 4 (75 kg) to Week 3 (78 kg) and awards **+50.3**.
- But Rahul was already credited for reaching 76 kg in Week 2; crediting 78→75
  again would double-count the 78→76 portion — exactly the farming §14 forbids.
- The implemented, farming-proof value credits only the **new** progress beyond his
  best (76 → 75), so **Week 4 = +22.5**, and Rahul's running total after Week 4 is
  **≈ 94.6** (not 122.4). Weeks 1–3 match the doc exactly (12.1, 60.0, 0).

If you specifically want the naive "compare to previous check-in" numbers (which are
farmable), that's a one-line change — but it contradicts §14, so we implemented the
protected version by default.

## Worked example (as implemented)
Baseline 80 kg / 30% / 32 kg muscle:

| Week | Measures | Points | Running total |
|---|---|---|---|
| 1 | 79 / 29.5% / 32 | +12.1 | 12.1 |
| 2 | 76 / 27% / 33 | +60.0 | 72.1 |
| 3 | 78 / 28% / 32.5 (worse) | +0 | 72.1 |
| 4 | 75 / 26% / 33 | +22.5 | **94.6** |

## What still needs a decision / follow-up
- **Admin bonus scale:** points are now ~10× bigger, so admin bonuses in "Adjust
  Standings" should be entered in the same range (e.g. +50, not +5).
- **Per-check-in "+X points" popup** (doc §16 — "CHECK-IN APPROVED / +60 POINTS"):
  the *total* is shown on the leaderboard; a per-check-in "you just earned +X" screen
  after approval is a nice follow-up we can add.
- Docs 01–03 describe the earlier peak model + the recommendation that led here; this
  doc (04) is the source of truth for what's live.

## Tests
See `test/challenge/challenge_flow_test.dart` → group **"Accumulated points"**:
Rahul accumulation, poor-week-adds-0, never-negative, anti-farming (yo-yo),
new-personal-best, missing-week-uses-latest, empty, String-drift, official =
points + completed-needs-final, eligibility gates, and a leaderboard integration
test (worse week adds nothing).
