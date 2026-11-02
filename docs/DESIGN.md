# LedgerLock design brief

Goal (owner, 2026-11-01): not a generic app. It should feel **alive**. For a money app, that means calm and
trustworthy, not bouncy. Life comes from four things, each grounded in established principles:

| Source of life | What it means here | Principles |
|---|---|---|
| **Responsiveness** | Everything you touch answers within ~100 ms: cards press in, buttons give a haptic tick | Doherty threshold (< 400 ms), Saffer's microinteractions (trigger → feedback) |
| **Continuity** | Numbers count to their new value; lists and bars grow in; screens hand off instead of cutting | Material motion (purposeful, spring-based), object constancy |
| **Warmth** | A soft serif voice for headings, warm paper neutrals, plain friendly copy | Aesthetic-usability effect, brand voice |
| **Awareness** | The app reflects your situation: greeting by time of day, "on track" lines, celebrating done things | Peak-end rule, recognition over recall |

## Rules

**Hierarchy.** One hero per screen. Size, weight and colour do the ranking, not boxes. Group by proximity
(Gestalt): 8 px inside a group, 16-24 px between groups. Fewer, larger targets (Fitts), few choices per screen (Hick).

**Type.** Two families, both bundled (SIL OFL, never fetched):
- **Fraunces** (soft serif, opsz 48, SOFT 50): screen titles, hero labels, greetings, empty-state titles. The voice.
- **Manrope**: everything else. **All numbers** use Manrope with tabular figures (Fraunces has none), so
  counting numbers never jitter.
- Scale ~1.25: 12 / 14 / 16 / 20 / 24 / 30 / 40.

**Colour (60-30-10).** 60% warm paper background, 30% surfaces, 10% emerald accent. A second warm hue
(**sun**, amber) marks attention that is not an error (due soon, set-aside). Red is only for money out and
errors. Text contrast is at least WCAG AA (4.5:1); the dark theme is warm near-black, not blue-grey.

**Motion.** Tokens in `Motion`:
- `fast` 150 ms (press, toggle), `medium` 300 ms (cards, sheets), `slow` 600-800 ms (count-ups, chart growth).
- Curves: `easeOutCubic` for entering, a critically damped spring for press (no wobble). Overshoot only for
  **success** moments (payment logged, check-in done).
- Stagger list and section entrances by 40 ms, at most ~8 items.
- Ambient motion (hero glow drifting) is slow (> 10 s loop) and subtle (< 10% of the area's contrast).
- **Reduce motion** (system setting) turns all of it off. Values then appear instantly.

**Microcopy.** Second person, plain words, short. Warm but never jokey about money. Say what happened and
what is next ("Logged. Q4 is covered."). No exclamation marks in errors.

**Accessibility.** 48 dp targets, labels on every icon button, money read out properly, colour never the only
signal, dynamic type up to 1.3x without clipping.

## Not doing
Confetti, mascots, sounds, parallax tilt. They read as gimmicks in a finance app and they cost battery.
