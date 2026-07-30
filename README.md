# cxchangelog

Rebuild a cross-wave survey codebook from a long-format crosswalk, in Stata.

A survey that runs for years accumulates a quiet liability: questions get
reworded, response options get added, items get dropped, and after enough
waves nobody can say for certain what changed when. Reconstructing that
history by hand, comparing spreadsheets wave against wave, takes an afternoon
every cycle and invites errors each time. `cxchangelog` regenerates the
whole inventory from one long-format crosswalk file (one row per concept per
wave, saved as `.xlsx`, `.xls`, or `.csv`), so the answer to "did we change
this question in 2024?" is the same no matter who runs it.

Given the crosswalk and three column mappings — the wave identifier, the
stable concept id, and the question wording — the command writes an
items-by-wave grid (one row per concept, one wording column per wave, blank
cell = not fielded), counts what was added, removed, and reworded wave over
wave, and can diff the entire crosswalk against a frozen prior vintage to
show exactly what shifted between releases. Optional mappings add an
options-by-wave sheet (response-option text) and a study coverage matrix
(fielded-item counts by study or module).

Everything lands in one Excel workbook, one sheet per table, or in one
`.csv` file per table with the `csv` option. The command reads the crosswalk
file itself; the data in memory are preserved and restored untouched. There
are no dependencies beyond Stata 16.0.

## Install

From GitHub:

```stata
net install cxchangelog, from("https://raw.githubusercontent.com/ericabooth/cxchangelog-stata-public/main/") replace force
help cxchangelog
```

## Quick start

```stata
* a tiny two-wave crosswalk: q1 reworded, q3 added in wave 2
clear
input str3 concept wave str44 wording
"q1" 1 "How safe do you feel in your neighborhood?"
"q1" 2 "How safe do you feel walking near home?"
"q2" 1 "In general, how is your health?"
"q2" 2 "In general, how is your health?"
"q3" 2 "Do you have reliable internet at home?"
end
export excel using crosswalk.xlsx, firstrow(variables) replace

cxchangelog using crosswalk.xlsx, wave(wave) concept(concept) ///
    wording(wording) summary out(codebook) replace
return list
```

This writes `codebook.xlsx` with an `items_by_wave` sheet and a
`wave_summary` sheet, and reports one item added and one reworded in wave 2.
A full call maps the optional columns and diffs a prior vintage:

```stata
cxchangelog using item_changes_w10.xlsx, wave(wave) concept(concept_id) ///
    wording(q_text) options(options) study(study) summary               ///
    compare(item_changes_w9.xlsx) out(codebook_w10) replace
```

## Syntax

```
cxchangelog using filename, wave(column) concept(column) wording(column)
    [options(column) study(column) summary compare(filename) out(stub)
     csv replace]
```

See `help cxchangelog` for details on every option.

## Stored results

`cxchangelog` stores the following in `r()`:

| Result          | Meaning                                                                 |
| --------------- | ----------------------------------------------------------------------- |
| `r(n_concepts)` | number of distinct concepts                                              |
| `r(n_waves)`    | number of waves                                                          |
| `r(n_changes)`  | wave-over-wave rewordings (fielded in consecutive waves, wording differs)|
| `r(n_added)`    | items added after the first wave                                         |
| `r(n_removed)`  | items removed after the first wave                                       |
| `r(n_diff)`     | cells differing from the `compare()` vintage (only with `compare()`)    |
| `r(outfile)`    | main output file written                                                 |
| `r(outstub)`    | output stub used                                                         |

## Limitations in v0.1.0

- `highlight()` and `code()` (per-cell lifecycle styling and codes in the
  workbook) are accepted in the syntax but exit with an error; both are
  planned for v0.2.
- Changes in response-option text alone are not counted as rewordings; they
  are visible in the `options_by_wave` sheet.
- Only the first worksheet of an `.xlsx` input is read.

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Eric A. Booth.

Support: eric.a.booth@gmail.com
