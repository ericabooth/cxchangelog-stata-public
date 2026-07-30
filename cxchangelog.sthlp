{smcl}
{* *! version 0.1.0  2026-07-06}{...}
{viewerjumpto "Syntax" "cxchangelog##syntax"}{...}
{viewerjumpto "Description" "cxchangelog##description"}{...}
{viewerjumpto "Options" "cxchangelog##options"}{...}
{viewerjumpto "Output" "cxchangelog##output"}{...}
{viewerjumpto "Stored results" "cxchangelog##results"}{...}
{viewerjumpto "Examples" "cxchangelog##examples"}{...}
{viewerjumpto "Remarks" "cxchangelog##remarks"}{...}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :{cmd:cxchangelog} {hline 2}}Rebuild a cross-wave survey codebook from a long-format crosswalk{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:cxchangelog} {cmd:using} {it:filename}{cmd:,}
{cmd:wave(}{it:column}{cmd:)} {cmd:concept(}{it:column}{cmd:)}
{cmd:wording(}{it:column}{cmd:)} [{it:options}]

{pstd}
{it:filename} is a long-format crosswalk of the instrument, one row per
concept per wave, saved as {cmd:.xlsx}, {cmd:.xls}, or {cmd:.csv}.  Each
{it:column} argument names a column of that file (as imported by
{help import excel} or {help import delimited}), not a variable in memory.

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab :Required}
{synopt :{cmd:wave(}{it:column}{cmd:)}}column holding the wave identifier{p_end}
{synopt :{cmd:concept(}{it:column}{cmd:)}}column holding the stable concept/item id{p_end}
{synopt :{cmd:wording(}{it:column}{cmd:)}}column holding the question wording; blank = not fielded that wave{p_end}

{syntab :Optional}
{synopt :{cmd:options(}{it:column}{cmd:)}}column holding the response options; adds an options-by-wave sheet{p_end}
{synopt :{cmd:study(}{it:column}{cmd:)}}column tagging the study/module; adds a study coverage sheet{p_end}
{synopt :{cmd:summary}}display and export a per-wave change summary (added/removed/reworded){p_end}
{synopt :{cmd:compare(}{it:filename}{cmd:)}}diff against a prior crosswalk vintage (same column names){p_end}
{synopt :{cmd:out(}{it:stub}{cmd:)}}output file stub; default is the input filename plus {it:_codebook}{p_end}
{synopt :{cmd:csv}}write one .csv per table instead of one multi-sheet .xlsx{p_end}
{synopt :{cmd:replace}}overwrite existing output files{p_end}

{syntab :Planned for v0.2 (not yet available)}
{synopt :{cmd:highlight(}{it:...}{cmd:)}}highlight a vintage in the workbook; exits with an error in 0.1.0{p_end}
{synopt :{cmd:code(}{it:...}{cmd:)}}per-cell lifecycle codes; exits with an error in 0.1.0{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:cxchangelog} turns a long-format crosswalk of a multi-wave survey
instrument into a cross-wave codebook.  A survey that runs for years
accumulates reworded questions, added items, and dropped items; rebuilding
that history by hand each cycle is slow and error-prone.  Given one row per
concept per wave, {cmd:cxchangelog} produces an items-by-wave grid (one row
per concept, one column per wave, cell = the wording fielded that wave, blank
= not fielded), counts what was added, removed, and reworded wave over wave,
and can diff the whole crosswalk against a frozen prior vintage.

{pstd}
The command reads the crosswalk file itself; the data in memory are preserved
and restored untouched.  Results are written with {help export excel} (one
workbook, one sheet per table) or, with {cmd:csv}, with
{help export delimited} (one file per table).


{marker options}{...}
{title:Options}

{phang}{cmd:wave(}{it:column}{cmd:)} names the wave identifier.  Waves are
ordered numerically when every wave value is a number (1, 2, 3 or 2022, 2023,
...), and alphabetically otherwise.  Wave columns in the wide sheets are named
{cmd:w}{it:value} (for example {cmd:w1}, {cmd:w2023}).{p_end}

{phang}{cmd:concept(}{it:column}{cmd:)} names the stable id that links the
same question across waves.  The crosswalk must have at most one row per
concept per wave; duplicates stop the command with error 459.{p_end}

{phang}{cmd:wording(}{it:column}{cmd:)} names the question text.  A blank or
missing wording means the concept was not fielded in that wave, so leave the
cell empty (or omit the row) for waves in which an item did not run.{p_end}

{phang}{cmd:options(}{it:column}{cmd:)} names the response-option text and adds
an {cmd:options_by_wave} sheet with the same layout as the items sheet.{p_end}

{phang}{cmd:study(}{it:column}{cmd:)} names a study or module tag.  It adds a
{cmd:study} column to the items sheet (the tag from each concept's first
fielded wave) and a {cmd:study_coverage} sheet counting fielded items by study
and wave.{p_end}

{phang}{cmd:summary} displays a per-wave table of fielded, added, removed, and
reworded counts, each relative to the previous wave, and exports it as the
{cmd:wave_summary} sheet.  The first wave is the baseline, so its change
counts are zero by definition.{p_end}

{phang}{cmd:compare(}{it:filename}{cmd:)} reads a prior vintage of the
crosswalk (same column names as the main file) and reports every concept-wave
cell that differs: {cmd:added} (in the current file only), {cmd:removed} (in
the prior file only), or {cmd:reworded} (in both, with different wording).
The diff is exported as the {cmd:compare} sheet when at least one difference
exists.{p_end}

{phang}{cmd:out(}{it:stub}{cmd:)} sets the output name.  Without {cmd:csv} the
command writes {it:stub}{cmd:.xlsx}; with {cmd:csv} it writes
{it:stub}{cmd:_items.csv}, {it:stub}{cmd:_options.csv},
{it:stub}{cmd:_coverage.csv}, {it:stub}{cmd:_summary.csv}, and
{it:stub}{cmd:_compare.csv} as applicable.  Any .xlsx/.xls/.csv extension
typed in {cmd:out()} is stripped first.{p_end}

{phang}{cmd:replace} permits overwriting; without it an existing output file
stops the command with error 602.{p_end}


{marker output}{...}
{title:Output}

{pstd}One workbook (or set of .csv files) containing, as requested:{p_end}

{p2colset 8 26 28 2}{...}
{p2col :{cmd:items_by_wave}}always; one row per concept, one wording column per wave{p_end}
{p2col :{cmd:options_by_wave}}with {cmd:options()}; response options per concept per wave{p_end}
{p2col :{cmd:study_coverage}}with {cmd:study()}; count of fielded items by study and wave{p_end}
{p2col :{cmd:wave_summary}}with {cmd:summary}; fielded/added/removed/reworded per wave{p_end}
{p2col :{cmd:compare}}with {cmd:compare()}; cells that differ from the prior vintage{p_end}
{p2colreset}{...}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:cxchangelog} stores in {cmd:r()}:{p_end}
{synoptset 16 tabbed}{...}
{synopt :{cmd:r(n_concepts)}}number of distinct concepts{p_end}
{synopt :{cmd:r(n_waves)}}number of waves{p_end}
{synopt :{cmd:r(n_changes)}}wave-over-wave rewordings (items fielded in consecutive waves with different wording){p_end}
{synopt :{cmd:r(n_added)}}items added after the first wave{p_end}
{synopt :{cmd:r(n_removed)}}items removed after the first wave{p_end}
{synopt :{cmd:r(n_diff)}}cells differing from the {cmd:compare()} vintage (only with {cmd:compare()}){p_end}
{synopt :{cmd:r(outfile)}}main output file written{p_end}
{synopt :{cmd:r(outstub)}}output stub used{p_end}
{p2colreset}{...}


{marker examples}{...}
{title:Examples}

{pstd}Build a small two-wave crosswalk and generate its codebook:{p_end}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str3 concept wave str44 wording}{p_end}
{phang2}{cmd:  "q1" 1 "How safe do you feel in your neighborhood?"}{p_end}
{phang2}{cmd:  "q1" 2 "How safe do you feel walking near home?"}{p_end}
{phang2}{cmd:  "q2" 1 "In general, how is your health?"}{p_end}
{phang2}{cmd:  "q2" 2 "In general, how is your health?"}{p_end}
{phang2}{cmd:  "q3" 2 "Do you have reliable internet at home?"}{p_end}
{phang2}{cmd:  end}{p_end}
{phang2}{cmd:. export excel using crosswalk.xlsx, firstrow(variables) replace}{p_end}
{phang2}{cmd:. cxchangelog using crosswalk.xlsx, wave(wave) concept(concept) wording(wording) summary out(codebook) replace}{p_end}
{phang2}{cmd:. return list}{p_end}

{pstd}Full call with modules, options text, and a diff against last year's
frozen crosswalk:{p_end}

{phang2}{cmd:. cxchangelog using item_changes_w10.xlsx, wave(wave) concept(concept_id) wording(q_text) options(options) study(study) summary compare(item_changes_w9.xlsx) out(codebook_w10) replace}{p_end}

{pstd}The same, but as a set of .csv files:{p_end}

{phang2}{cmd:. cxchangelog using item_changes_w10.xlsx, wave(wave) concept(concept_id) wording(q_text) summary csv out(codebook_w10) replace}{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:What counts as a change.}  {cmd:reworded} compares consecutive fielded
waves.  An item that skips a wave and returns with new wording is counted as
removed and then added, not reworded.  Changes in {cmd:options()} text alone
are not counted as rewordings in 0.1.0; they are visible in the
{cmd:options_by_wave} sheet.

{pstd}
{bf:Column names.}  The column arguments must match the names produced by
{help import excel} (header row) or {help import delimited}, which may adjust
invalid names.  Columns named {cmd:_cx*} are reserved by the command.  Only
the first worksheet of an .xlsx input is read.

{pstd}
{bf:Deferred to v0.2.}  {cmd:highlight()} and {cmd:code()} (per-cell lifecycle
styling and codes in the workbook) are accepted in the syntax but exit with
error 198 in 0.1.0.


{title:Author}

{pstd}
Eric A. Booth, Sr Researcher, Texas 2036, 2026.
Support: eric.a.booth@gmail.com.  MIT-licensed.
