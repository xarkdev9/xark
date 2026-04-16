# Xark OS — Slot Machine Intro

## Concept
The tagline "redefining ___" cycles through words vertically like a slot machine reel.
Each word escalates from basic (text) to life-changing (memories).
Background flashes Xark signal colors between words. Final word holds with brand glow.

## Word Sequence

| # | Word | Duration | Color | Meaning |
|---|---|---|---|---|
| 1 | text. | 280ms | white 50% | Basic, everyone does this |
| 2 | chat. | 280ms | white 55% | Slightly better |
| 3 | plan. | 300ms | white 60% | Now it's useful |
| 4 | group chat. | 380ms | cyan #40E0FF | Social layer |
| 5 | group planning. | 400ms | amber #F5A623 | Intelligence layer |
| 6 | deciding. | 480ms | gold #FFD700 | Consensus layer |
| 7 | group execution. | 500ms | green #10B981 | Commitment layer |
| 8 | living. | 600ms | orange #FF6B35 | Real world |
| 9 | memories. | holds | orange + glow | The payoff |

**Total reel time: ~4.5 seconds**

## Choreography Timeline

```
0ms      spark         — screen appears
800ms    collision      — wordmark "xark" slides up
1800ms   reveal         — static taglines briefly visible
2800ms   slot starts    — "redefining" fades in, first word appears
3080ms   "chat."        — word scrolls up, replaces "text."
3360ms   "plan."
3660ms   "group chat."  — color shifts to cyan
4040ms   "group planning." — amber
4440ms   "deciding."    — gold
4920ms   "group execution." — green
5420ms   "living."      — Action Orange
6020ms   "memories."    — holds with glow
7520ms   idle           — "begin" button appears
```

## Mechanic

- Container: `overflow: hidden`, height = 1 line
- Each word: `translateY(110%) → 0% → -110%` with blur(8px) during transition
- Framer Motion `AnimatePresence mode="wait"` for clean enter/exit
- 80ms background flash (signal color at 15% opacity) between each word
- Final word "memories." gets `text-shadow` glow in Action Orange

## Color Flash

Between each word transition, the full screen flashes one of Xark's signal colors at 15% opacity for 80ms:
```
cyan → amber → gold → orange → green → cyan → amber → gold
```
Creates a rapid chromatic pulse. Subtle but energetic.

## Skip

Tap anywhere during the slot machine to jump to "memories." and idle phase.

## Where It Lives

- **WelcomeScreen.tsx** — plays on every app open (login page)
- **Ad video** — first 4-5 seconds of the 8-second blitz

## Ad Video Integration

```
[0:00-0:02]  Cinematic shot (woman at restaurant, phone glow)
[0:02-0:06]  Slot machine plays over dark background
             "redefining text. chat. plan. group chat..."
             Speed: real-time (the reel IS fast already)
[0:06]       "memories." lands with orange glow — HOLD
[0:06-0:08]  Hard cut to friends celebrating
```

The slot machine IS the hook. No need to speed-ramp it — it's already 4.5 seconds of rapid-fire energy.

## File Locations

| File | Purpose |
|---|---|
| `src/components/os/WelcomeScreen.tsx` | Production component |
| `promote/slot-machine-intro.md` | This design doc |
| `promote/ad-demos.md` | Full ad demo playbook |
