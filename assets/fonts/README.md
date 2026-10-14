# Bundled interface fonts

The interface uses JetBrains Mono for its terminal style and Noto Sans Symbols as a
fallback for circled digits and the queue pause mark. All three files are unmodified
upstream fonts licensed under the SIL Open Font License 1.1. Their accompanying
`*-OFL.txt` files are explicitly included in both export presets.

JetBrains Mono version 2.305, from the official JetBrains repository at commit
[`19371302b95d218af43299bce79ddbddd0bc364d`](https://github.com/JetBrains/JetBrainsMono/tree/19371302b95d218af43299bce79ddbddd0bc364d/fonts/ttf):

| File | SHA-256 |
| --- | --- |
| JetBrainsMono-Regular.ttf | `e6fd0d7e91550b3ed2b735d4312474362c4716edc4fc0577a0f61ed782d5aed1` |
| JetBrainsMono-Bold.ttf | `d22c4f3821d725eb01210d278d95dfcfcaadc34699a06658d47c8a5cc5830ada` |

Noto Sans Symbols version 2.001, from the official Noto repository at commit
[`ffebf8c1ee449e544955a7e813c54f9b73848eac`](https://github.com/notofonts/noto-fonts/tree/ffebf8c1ee449e544955a7e813c54f9b73848eac/hinted/ttf/NotoSansSymbols):

| File | SHA-256 |
| --- | --- |
| NotoSansSymbols-Regular.ttf | `8f02f31959bbdf6061547a188248e13f84dc5fdd940326ec494675f453f072bb` |

The JetBrains Mono font covers arrows, mathematical minus, the stop square,
ellipsis, en/em dashes, and the multiplication sign. The Noto fallback covers
`Ⅱ` (U+2161) and the circled digits `①②` (U+2460/U+2461). Both the normal and
bold theme fonts use this explicit fallback, so these interface symbols do not
depend on the fonts installed on the player's machine.
