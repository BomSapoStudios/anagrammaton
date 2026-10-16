# Word data

| File | What it is | Source |
| --- | --- | --- |
| `words_pop.txt` | Every 5+ letter word that pops, lowercase, no proper nouns, blocklist removed (about 168,000 words) | [ENABLE word list](https://github.com/dolph/dictionary) (public domain), plus `antidisestablishmentarianism` |
| `words_seed.txt` | Common words: 5-letter ones are used for planted stems and hints (about 575); 4-letter ones are the only 4-letter words that pop (about 870), so obscure Scrabble words like "toea" don't | Hand-picked; every word is in ENABLE |
| `blocklist.txt` | Words that never pop, are never planted, and never appear in a generated chain | Single-word entries from [LDNOOBW](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words) (CC BY 4.0) |

The blocklist is a starting point. It needs a manual review pass for slurs
and epithets it misses before release.

The app bundles these files as resources (see `project.yml`).
