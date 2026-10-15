# Word data

| File | What it is | Source |
| --- | --- | --- |
| `words_pop.txt` | Every word that pops: 5+ letters, lowercase, no proper nouns, blocklist removed (about 168,000 words) | [ENABLE word list](https://github.com/dolph/dictionary) (public domain), plus `antidisestablishmentarianism` |
| `words_seed.txt` | Common 5-letter words used for planted stems and shooter hints (about 575 words) | Hand-picked; every word is in the pop list |
| `blocklist.txt` | Words that never pop, are never planted, and never appear in a generated chain | Single-word entries from [LDNOOBW](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words) (CC BY 4.0) |

The blocklist is a starting point. It needs a manual review pass for slurs
and epithets it misses before release.

When exporting, add `data/*.txt` to the export preset's non-resource file
filter, or the word files will not ship.
