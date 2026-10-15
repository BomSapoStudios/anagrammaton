# Anagrammaton

A Zuma-style iOS game where every bubble carries a letter. Three matching
letters pop, and so does any real word of five or more letters spelled along
the chain. Built with Godot 4.4.

## Run it

1. Install [Godot 4.4](https://godotengine.org/download).
2. Open this folder as a project and press Play (F5).

Drag to aim and release to fire. Tap the shooter (or press Space) to swap
letters. The buttons at the top toggle backward words (B) and relaxed mode
(R). After a level ends, N starts the next level or retries, and C takes a
rewarded continue.

## Tests

```sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```

`tools/screenshot.gd` plays a level and saves a screenshot (needs a display;
on Linux use `xvfb-run`).

## Layout

| Path | What it does |
| --- | --- |
| `scripts/core/chain_rules.gd` | Triple and word pops, longest-word-wins, chain reactions across closed gaps |
| `scripts/core/scoring.gd`, `score_keeper.gd` | Points: exponential word-length scoring, chain multipliers, combos, repeat and first-word rules |
| `scripts/core/letter_dealer.gd` | Picks shooter letters that complete handles, with a pity timer |
| `scripts/core/chain_generator.gd` | Builds level chains from handles and weighted filler, with no ready-made triples or blocked words |
| `scripts/core/track_generator.gd`, `track.gd` | Procedural serpentine and spiral tracks, validated for spacing and shooter clearance |
| `scripts/ads/` | Ad policy (frequency caps, remove-ads, no ads on ranked levels) and a stub provider |
| `scripts/game/game.gd` | The playable scene, drawn in code |
| `data/` | Word lists (see `data/README.md`) |

The design doc lives in the project as "Anagrammaton Game Design".
