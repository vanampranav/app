# Challenge Scoring — Research & Recommendation

_Last updated: 2026-08-13_

Goal, in your words: **(1) never show negative points** (demotivating), and
**(2) reward weekly check-ins** with a constant amount — while keeping the
challenge fair and the winner meaningful.

This document compares the options and gives a concrete recommendation.

---

## 1. The two real problems, separated

The alternative model in Doc 02 tried to solve two things at once, which made it
gameable and confusing. They're cleaner solved **separately**:

| Problem | Simplest correct fix |
|---|---|
| Scores can go **negative** | **Floor the score at 0.** A regressing user sits at 0, never below. |
| Check-ins should **earn points** | **Add a fixed participation bonus per approved check-in.** |

Neither fix requires the incremental week-vs-week comparison — which is where all
the gaming (yo-yo farming) and confusing maths came from.

---

## 2. Recommended formula

```
Final Score = max(0, PEAK) + (checkInPoints × approvedCheckIns) + adminBonus
```

- **PEAK** = the current system: your best baseline→submission composite
  (body-fat 50% / weight 30% / muscle 20%). Fair, not gameable, matches the prize.
- **`max(0, …)`** = **no negatives.** A user who never beats their baseline scores
  0 from transformation (not a negative).
- **`checkInPoints × approvedCheckIns`** = a **constant reward per check-in**
  (e.g. **+1 or +2** each). Guarantees a positive, growing score for anyone who
  shows up, and directly rewards consistency.
- **`adminBonus`** = unchanged manual admin adjustment.

### Why this is the right shape
- ✅ **Never negative** — solved by the floor *and* the participation points.
- ✅ **Rewards every check-in** — constant, transparent, exactly what you asked for.
- ✅ **Not gameable** — the transformation part is a single best net result;
  yo-yoing does nothing. Participation is capped by the number of weeks.
- ✅ **Still a transformation challenge** — the biggest transformer still wins, as
  long as participation points are kept **modest** (see §3).
- ✅ **Minimal change** — it's the system we already built, plus a floor and a
  per-check-in bonus. Low risk, fully testable.

---

## 3. The one dial to set: how much should check-ins matter?

`checkInPoints` decides whether the prize is about **results** or **attendance**.
With a ~12-week challenge and typical transformation composites of **~5–15**:

| checkInPoints | Max participation (12 wks) | Effect | Use when |
|---|---|---|---|
| **0** | 0 | Pure transformation, just floored at 0 (no negatives). Check-ins shown as a stat only. | Prize must be purely about results |
| **+1** _(recommended)_ | +12 | Consistency is a meaningful edge but transformation still decides most placements. | **Balanced — recommended** |
| **+2** | +24 | Attendance rivals transformation; a diligent average-result person can beat a big transformer who skipped weeks. | You want to heavily reward engagement |
| **+3 or more** | +36+ | Effectively an attendance contest. | Not recommended for a transformation prize |

**Recommendation: `checkInPoints = +1`.** It makes showing up every week a real,
visible advantage (up to +12) without letting attendance overtake the actual body
transformation. If engagement is your #1 goal for this specific challenge, +2 is
defensible.

> Tip: you can make `checkInPoints` a **per-challenge setting** so each challenge
> can dial results-vs-engagement independently.

---

## 4. What happens to "missing Week 3" under the recommendation

- **Transformation:** unchanged from today — you simply miss a chance to set a new
  peak. Nothing is subtracted.
- **Participation:** you miss **that week's** `checkInPoints` (e.g. −1 vs. someone
  who checked in). Small, fair, and it never pushes you negative.
- **Net effect:** missing a week costs you a little (one check-in's points + a
  possible peak), but your score **only ever goes up or stays flat** — it never
  drops. That's the motivating property you wanted.

### Worked example (recommendation, checkInPoints = +1)
Same participant, checked in Weeks 1, 2, 4, Final (missed Week 3):
- Peak transformation = **11.90**
- Participation = 4 check-ins × 1 = **+4**
- **Final Score = max(0, 11.90) + 4 = 15.90**

A struggling participant (best composite −2.6, but checked in all 4 weeks):
- Peak transformation floored = **max(0, −2.6) = 0**
- Participation = **+4**
- **Final Score = 4** — positive and motivating, not a demoralising −2.6.

---

## 5. Why NOT the incremental (week-vs-week) model

Recapping Doc 02's findings, the incremental model:
- is **gameable** by oscillating (farms the same kg twice) unless redefined as
  "beat your previous best" — which is just the peak model again;
- produces **inflated, hard-to-explain totals** (relative %s don't sum to the true
  baseline→now change);
- quietly turns the prize into an **attendance contest**.

The recommended model gets **all** of Doc 02's upsides (no negatives, rewards
check-ins, gentle on missed weeks, only-goes-up) **without** any of these
downsides.

---

## 6. Recommendation summary

> **Keep the peak transformation score, floor it at 0 so nobody goes negative, and
> add a small constant `+1` per approved check-in. Make the per-check-in value a
> per-challenge setting.**

```
Final Score = max(0, PEAK transformation) + (1 × approvedCheckIns) + adminBonus
```

This is a small, safe, fully-testable change to the system already in place. If you
approve, the implementation is:
1. `max(0, …)` on the composite in the scoring service.
2. Add `checkInPoints × approvedCheckIns` in the leaderboard + winner scoring.
3. (Optional) expose `checkInPoints` on the challenge model as an admin setting.
4. Update the leaderboard "How to score" card + this doc set.
5. Add tests: floor-at-0, participation adds up, missing week costs one check-in,
   yo-yo doesn't inflate.
