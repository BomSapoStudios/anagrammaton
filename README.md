# Anagrammaton

A Zuma-style iOS game where every bubble carries a letter. Three matching
letters pop, and so does any real word of five or more letters spelled along
the chain. Built in Swift with SpriteKit.

## Run it

You need a Mac with Xcode 16 or later.

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. In this folder, run `xcodegen generate`. It writes `Anagrammaton.xcodeproj`.
3. Open `Anagrammaton.xcodeproj`, pick an iPhone simulator, and press Run (Cmd-R).

Drag to aim and release to fire. Tap the shooter to swap letters. The buttons
at the top toggle backward words and relaxed mode.

## Tests

```sh
swift test --package-path Core
```

CI runs those tests, builds the app for the simulator, plays levels 1 and 4
automatically, and uploads screenshots as a build artifact.

## Layout

| Path | What it does |
| --- | --- |
| `Core/Sources/AnagrammatonCore/ChainRules.swift` | Triple and word pops, longest-word-wins, screen-order reading, chain reactions across closed gaps |
| `Core/Sources/AnagrammatonCore/Scoring.swift` | Points: exponential word-length scoring, chain multipliers, combos, repeat and first-word rules |
| `Core/Sources/AnagrammatonCore/LetterDealer.swift` | Picks shooter letters that complete handles, with a pity timer |
| `Core/Sources/AnagrammatonCore/ChainGenerator.swift` | Builds level chains from handles and weighted filler, with no ready-made triples or blocked words |
| `Core/Sources/AnagrammatonCore/TrackGenerator.swift`, `Track.swift` | Procedural serpentine and spiral tracks, validated for spacing and shooter clearance |
| `Core/Sources/AnagrammatonCore/AdPolicy.swift`, `App/Ads/` | Ad rules (frequency caps, remove-ads, no ads on ranked levels) and a stub provider |
| `App/GameScene.swift` | The playable SpriteKit scene |
| `data/` | Word lists (see `data/README.md`) |
| `project.yml` | XcodeGen spec for the Xcode project |

The game rules live in a Swift package with no UIKit or SpriteKit, so they
run and test anywhere Swift does. The design doc lives in the project as
"Anagrammaton Game Design".
