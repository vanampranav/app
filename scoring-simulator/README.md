# EleFit Challenge — Scoring Simulator

A single-page, **static** web tool that mirrors the app's live scoring engine
(`ChallengeScoringService.calculateAccumulatedPoints`). Enter a baseline + weekly
check-ins and see exactly how points are earned — for testing & sharing.

- Weekly, **accumulating** points (each approved check-in adds points)
- Weights: body fat **50%** / weight **30%** / muscle **20%**, `× 10` scale
- **Never negative** (a poor week earns 0)
- **Anti-farming**: improvement counts only **beyond your best-so-far**
- Built-in examples: "Rahul" and a yo-yo (anti-farming) case

## Run locally
Just open `index.html` in a browser — no build, no dependencies.

## Deploy to Vercel

**Option A — CLI (from this folder):**
```bash
npm i -g vercel        # once
cd scoring-simulator
vercel                 # follow prompts → preview URL
vercel --prod          # production URL to share
```

**Option B — Dashboard (no CLI):**
1. Go to https://vercel.com → **Add New… → Project**.
2. Import this repo (or drag-and-drop the `scoring-simulator` folder in **Add New → Project → Deploy**).
3. Set **Root Directory** = `scoring-simulator` if importing the whole repo.
4. Framework preset: **Other** (it's plain static HTML). Deploy.

No `vercel.json` is needed — a folder with `index.html` deploys as a static site
automatically.

## Keeping it in sync with the app
If the scoring model changes in `lib/features/challenge/domain/services/challenge_scoring_service.dart`,
update the `compute()` function + weights at the top of `index.html` to match.
