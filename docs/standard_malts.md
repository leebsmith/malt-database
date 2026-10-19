# Standard Malts (canonical)

A source-independent reference list of standard brewing malts and cereal
adjuncts. Colour and yield values are **typical/approximate** and
intentionally **unsourced for now** (no single reference selected).

**Fields:** `name` (canonical), `aliases`, `family` (malt family), `form`
(processing: `malted` vs `flaked`/`raw`/`torrefied`/`unmalted`/`hulls`),
`color_lovibond` (typical range in °L), `yield_ppg` (typical extract, points
per pound per gallon), `notes`.

**Husked vs huskless** roasted malts are kept in separate families: the
husked `roasted` family (Pale Chocolate, Chocolate, Black, Roasted Barley)
versus the huskless `dehusked` family (Carafa Special, Blackprinz, Mroost,
Midnight Wheat, Coffee/Debittered). "Carafa" is Weyermann's brand; the
dehusked/debittered class is made by other maltsters under different names.

Machine-readable version: `config/standard_malts.tsv`.

## Base

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Pilsner Malt | Pilsen, Pilsner | malted | 1.5–2.5 | 37 | Clean, pale base malt for lagers. |
| Pale Ale Malt | 2-Row, Pale Malt | malted | 2–3 | 38 | Standard American/British base malt. |
| Lager Malt | Lager | malted | 1.5–2 | 37 | Light base for lagers. |
| Mild Ale Malt | Mild | malted | 3–4 | 36 | Higher residual body; mild and brown ales. |
| 6-Row Malt | 6-Row | malted | 1.5–2 | 35 | High husk/enzyme; classic US adjunct base. |
| Wheat Malt | Pale Wheat, White Wheat | malted | 2–3 | 39 | Foam and body; wheat beers. |
| Dark Wheat Malt | Dark Wheat | malted | 6–9 | 39 | Darker wheat for dunkelweizen. |
| Rye Malt | Rye | malted | 3–4 | 38 | Spicy; roggenbier and rye ales. |
| Malted Oats | Oat Malt | malted | 1.5–2 | 33 | Silky mouthfeel; hazy/soft styles. |
| Malted Spelt | Spelt, Dinkel | malted | 2–3 | 36 | Ancient-grain base. |

## Kilned

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Vienna Malt | Vienna | malted | 3–4 | 36 | Toasty, amber; Vienna lager and märzen. |
| Munich Light | Munich I, Munich 10L | malted | 6–10 | 35 | Malty; märzen, bock, altbier. |
| Munich Dark | Munich II, Munich 20L | malted | 15–20 | 34 | Rich malt; dunkel, bock. |
| Aromatic Malt | Aromatic Munich, Aroma | malted | 18–22 | 35 | Intense malt; Belgian ales. |
| Melanoidin Malt | Melanoidin | malted | 20–30 | 35 | Melanoidin richness and body. |
| Amber Malt | Amber | malted | 20–30 | 34 | Toasty/biscuity; British ales. |
| Brown Malt | Brown | malted | 50–70 | 33 | Toasted-brown; porter and brown ale. |
| Biscuit Malt | Biscuit | malted | 20–30 | 34 | Bready, biscuity. |
| Victory Malt | Victory | malted | 25–30 | 34 | Toasty, nutty. |
| Honey Malt | Brumalt | malted | 15–25 | 34 | Honey/bread; melanoidin-style. |

## Toasted

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Toasted Oats | Toasted Oat Malt | malted | 2–8 | 28 | Toasty oats; body. |
| Toasted Wheat | Toasted Wheat | malted | 20–30 | 33 | Toasty wheat; body. |
| Toasted Rye | Toasted Rye | malted | 15–25 | 33 | Toasty rye; spice. |

## Dextrin / body

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Dextrin Malt | Carapils, Cara-Foam, Dextra-Pils | malted | 1–2 | 32 | Body and foam; minimal colour. |

## Chit

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Chit Malt | Chit | malted | 1.5–2 | 25 | Under-modified; foam/body, very low colour. |

## Acidulated

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Acidulated Malt | Sauermalz, Acid Malt | malted | 2–3 | 34 | Lowers mash pH; use 1-10%. |

## Smoked

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Smoked Malt | Rauchmalt | malted | 2–5 | 35 | Beechwood/cherry/oak smoke. |

## Peated

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Peated Malt | Peated | malted | 1.5–3.5 | 36 | Phenolic peat smoke. |

## Crystal / caramel (discrete grades)

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Caramel 10L | Cara 10, Crystal 10 | malted | 8–12 | 34 | Light caramel sweetness. |
| Caramel 20L | Cara 20, Crystal 20 | malted | 18–22 | 34 | Light caramel sweetness. |
| Caramel 30L | Cara 30, Crystal 30 | malted | 25–35 | 34 | Caramel sweetness. |
| Caramel 40L | Cara 40, Crystal 40 | malted | 35–45 | 34 | Caramel sweetness. |
| Caramel 60L | Cara 60, Crystal 60 | malted | 55–65 | 34 | Caramel/toffee. |
| Caramel 80L | Cara 80, Crystal 80 | malted | 75–85 | 34 | Toffee/caramel. |
| Caramel 100L | Cara 100, Crystal 100 | malted | 95–105 | 34 | Deep caramel. |
| Caramel 120L | Cara 120, Crystal 120 | malted | 115–125 | 34 | Deep caramel, burnt sugar. |
| Caramel 150L | Cara 150, Crystal 150 | malted | 145–155 | 34 | Dark caramel. |
| Extra Dark Crystal | Crystal 200L, Cara 200 | malted | 195–205 | 34 | Very dark caramel. |
| Special B | Special B | malted | 130–160 | 34 | Raisin/plum; dubbel and quad. |
| CaraMunich | CaraMunich | malted | 50–60 | 34 | Munich-style crystal. |
| CaraVienne | CaraVienne | malted | 20–25 | 34 | Vienna-style crystal. |
| CaraAroma | CaraAroma | malted | 120–140 | 34 | Aromatic crystal. |
| CaraAmber | CaraAmber | malted | 25–35 | 34 | Amber crystal. |
| CaraRed | CaraRed | malted | 20–25 | 34 | Red crystal. |
| Crystal Wheat | CaraWheat | malted | 50–60 | 34 | Wheat crystal. |
| Crystal Rye | CaraRye | malted | 80–100 | 34 | Rye crystal. |
| Golden Naked Oats | GNO, Crystal Oat | malted | 5–9 | 33 | Naked-oat crystal; body. |

## Roasted (husked)

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Pale Chocolate | Pale Chocolate, Carafa I | malted | 190–210 | 30 | Husked; light coffee/cocoa, some astringency. |
| Chocolate Malt | Chocolate, Carafa II | malted | 340–370 | 28 | Husked; chocolate/coffee; stouts and porters. |
| Black Malt | Black, Carafa III | malted | 500–550 | 27 | Husked; black colour and roast, astringent. |
| Roasted Barley | Roast Barley | unmalted | 300–350 | 28 | Unmalted (husked); dry stout. |

## Dehusked / debittered (huskless)

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Dehusked Light Roasted | Carafa Special I | malted | 115–140 | 30 | Huskless; smooth roast, no astringency. |
| Dehusked Chocolate | Carafa Special II, Mroost 900 | malted | 300–340 | 28 | Huskless; smooth chocolate/coffee. |
| Debittered Coffee Malt | Coffee Malt, Debittered Black | malted | 400–450 | 28 | Huskless/debittered; coffee, less harsh. |
| Dehusked Black | Carafa Special III, Blackprinz, Mroost 1400, Black Malt Extra | malted | 500–550 | 27 | Huskless black; smooth, less bitter. |
| Dehusked Black Wheat | Midnight Wheat | malted | 500–550 | 27 | Huskless black wheat. |

## Flaked (unmalted cereals)

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Flaked Barley | Flaked Barley | flaked | 1.5–2.5 | 32 | Unmalted; body, head retention. |
| Flaked Wheat | Flaked Wheat | flaked | 1.5–2.5 | 33 | Unmalted; body, haze. |
| Flaked Oats | Flaked Oats | flaked | 1.5–2.5 | 32 | Unmalted; silky body. |
| Flaked Rye | Flaked Rye | flaked | 2–3 | 32 | Unmalted; rye spice. |
| Flaked Maize | Flaked Corn | flaked | 1–2 | 37 | Light adjunct; dry finish. |
| Flaked Rice | Flaked Rice | flaked | 1–1.5 | 37 | Light adjunct; crisp finish. |

## Raw / torrefied

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Torrefied Wheat | Torrified Wheat | torrefied | 1.5–2.5 | 33 | Pre-gelatinized; body and foam. |
| Raw Wheat | Unmalted Wheat | raw | 1.5–2.5 | 36 | Unmalted; turbidity and body. |
| Raw Rye | Unmalted Rye | raw | 2–3 | 36 | Unmalted; rye spice. |

## Adjunct

| Name | Aliases | Form | Colour °L | Yield (PPG) | Notes |
|---|---|---|---|---|---|
| Rice Hulls | Rice Hulls | hulls | 0–0 | 0 | Lautering aid; no extract/colour. |

