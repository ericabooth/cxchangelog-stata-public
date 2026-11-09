* ===========================================================================
* test_cxchangelog.do -- test battery for cxchangelog v0.1.1
* Run in batch from any scratch directory:
*     stata-mp -b do test_cxchangelog.do
* Judge the run by the log: no r(NNN) errors, no "assertion is false".
* ---------------------------------------------------------------------------
* All paths live in globals set in this header (the package will move to its
* own repo; edit $pkgroot only).
* ===========================================================================
global pkgroot "/Users/ebooth/Documents/GitHub/Book Manuscript:Applied Evaluation-Stata/cxchangelog-stata-public"

version 16.0
clear all
set more off
set seed 20260706
adopath + "$pkgroot"

* scratch directory for every file this test creates (cleaned up at the end)
global cxtest "`c(tmpdir)'"
if substr("$cxtest", -1, .) != "/" global cxtest "$cxtest/"
global cxtest "${cxtest}cxchangelog_test"
capture mkdir "$cxtest"

* ---------------------------------------------------------------------------
* 1. Synthetic 3-wave crosswalk: 12 concepts; one wording change in wave 2
*    (c05); one item added in wave 2 (c12); one item dropped in wave 3 (c09).
*    This is the demo dataset promised in the book chapter.
* ---------------------------------------------------------------------------
clear
set obs 12
gen str8 concept_id = "c" + string(_n, "%02.0f")
expand 3
bysort concept_id: gen wave = _n
gen str80 q_text = "Wording for " + concept_id + " (baseline)"
* one wording change in wave 2, persisting into wave 3: c05
replace q_text = "Wording for c05, revised in wave 2" ///
    if concept_id == "c05" & wave >= 2
* one item added in wave 2: c12 was not fielded in wave 1
drop if concept_id == "c12" & wave == 1
* one item dropped in wave 3: c09
drop if concept_id == "c09" & wave == 3
gen str40 options = "1 Yes/2 No"
replace options = "1 Yes/2 No/3 Not sure" if concept_id == "c03" & wave >= 2
gen str8 study = cond(real(substr(concept_id, 2, .)) <= 6, "core", "module")
assert _N == 34
export excel using "$cxtest/crosswalk_w3.xlsx", firstrow(variables) replace
export delimited using "$cxtest/crosswalk_w3.csv", replace

* prior vintage: identical except c05's wave-2 rewording is not yet recorded
preserve
replace q_text = "Wording for c05 (baseline)" if concept_id == "c05" & wave == 2
export excel using "$cxtest/crosswalk_prior.xlsx", firstrow(variables) replace
restore

* ---------------------------------------------------------------------------
* 2. Full run: every documented option at once (xlsx in, xlsx out)
* ---------------------------------------------------------------------------
cxchangelog using "$cxtest/crosswalk_w3.xlsx", wave(wave)          ///
    concept(concept_id) wording(q_text) options(options)           ///
    study(study) summary compare("$cxtest/crosswalk_prior.xlsx")   ///
    out("$cxtest/codebook1") replace
assert r(n_concepts) == 12
assert r(n_waves)    == 3
assert r(n_changes)  == 1
assert r(n_added)    == 1
assert r(n_removed)  == 1
assert r(n_diff)     == 1
assert `"`r(outfile)'"' == "$cxtest/codebook1.xlsx"

* --- items_by_wave sheet: 12 rows, blank cell = not fielded ---
import excel using "$cxtest/codebook1.xlsx", sheet("items_by_wave") ///
    firstrow clear
confirm variable concept study w1 w2 w3
assert _N == 12
quietly count if w1 == ""
assert r(N) == 1
assert concept == "c12" if w1 == ""
quietly count if w3 == ""
assert r(N) == 1
assert concept == "c09" if w3 == ""
assert w1 == "Wording for c05 (baseline)"          if concept == "c05"
assert w2 == "Wording for c05, revised in wave 2"  if concept == "c05"
assert w3 == w2                                    if concept == "c05"
assert w1 == w2 & w2 == w3                         if concept == "c01"
assert study == "core"   if concept == "c01"
assert study == "module" if concept == "c12"

* --- wave_summary sheet: added/removed/reworded match construction ---
import excel using "$cxtest/codebook1.xlsx", sheet("wave_summary") ///
    firstrow clear
assert _N == 3
capture confirm numeric variable wave
if _rc destring wave, replace
sort wave
assert fielded[1] == 11 & fielded[2] == 12 & fielded[3] == 11
assert added[1]   == 0  & added[2]   == 1  & added[3]   == 0
assert removed[1] == 0  & removed[2] == 0  & removed[3] == 1
assert reworded[1] == 0 & reworded[2] == 1 & reworded[3] == 0

* --- options_by_wave sheet ---
import excel using "$cxtest/codebook1.xlsx", sheet("options_by_wave") ///
    firstrow clear
assert _N == 12
assert w1 == "1 Yes/2 No"            if concept == "c03"
assert w2 == "1 Yes/2 No/3 Not sure" if concept == "c03"

* --- study_coverage sheet: fielded-item counts by study and wave ---
import excel using "$cxtest/codebook1.xlsx", sheet("study_coverage") ///
    firstrow clear
assert _N == 2
sort study
assert w1 == 6 & w2 == 6 & w3 == 6 if study == "core"
assert w1 == 5 & w2 == 6 & w3 == 5 if study == "module"

* --- compare sheet: exactly the one planted rewording ---
import excel using "$cxtest/codebook1.xlsx", sheet("compare") ///
    firstrow clear
assert _N == 1
assert concept == "c05"
capture confirm numeric variable wave
if _rc destring wave, replace
assert wave == 2
assert status == "reworded"
assert prior_wording   == "Wording for c05 (baseline)"
assert current_wording == "Wording for c05, revised in wave 2"

* ---------------------------------------------------------------------------
* 3. csv in, csv out: same answers, files split by table
* ---------------------------------------------------------------------------
cxchangelog using "$cxtest/crosswalk_w3.csv", wave(wave)  ///
    concept(concept_id) wording(q_text) options(options)   ///
    study(study) summary csv out("$cxtest/codebook2") replace
assert r(n_concepts) == 12
assert r(n_waves)    == 3
assert r(n_changes)  == 1
assert r(n_added)    == 1
assert r(n_removed)  == 1
confirm file "$cxtest/codebook2_items.csv"
confirm file "$cxtest/codebook2_options.csv"
confirm file "$cxtest/codebook2_coverage.csv"
confirm file "$cxtest/codebook2_summary.csv"
import delimited "$cxtest/codebook2_items.csv", varnames(1) clear
assert _N == 12
quietly count if w1 == ""
assert r(N) == 1
assert concept == "c12" if w1 == ""
assert w2 == "Wording for c05, revised in wave 2" if concept == "c05"

* ---------------------------------------------------------------------------
* 4. Minimal call: required options only; default out() stub
* ---------------------------------------------------------------------------
capture erase "$cxtest/crosswalk_w3_codebook.xlsx"
cxchangelog using "$cxtest/crosswalk_w3.xlsx", wave(wave) ///
    concept(concept_id) wording(q_text)
confirm file "$cxtest/crosswalk_w3_codebook.xlsx"
assert r(n_concepts) == 12
assert r(n_waves)    == 3
import excel using "$cxtest/crosswalk_w3_codebook.xlsx", ///
    sheet("items_by_wave") firstrow clear
assert _N == 12
capture confirm variable study
assert _rc != 0

* ---------------------------------------------------------------------------
* 5. The data in memory are preserved and restored
* ---------------------------------------------------------------------------
sysuse auto, clear
cxchangelog using "$cxtest/crosswalk_w3.xlsx", wave(wave) ///
    concept(concept_id) wording(q_text) out("$cxtest/codebook3") replace
assert _N == 74
assert make[1] == "AMC Concord"

* ---------------------------------------------------------------------------
* 6. Deliberate error cases: assert the documented exit codes
* ---------------------------------------------------------------------------
* missing required option -> 198
capture cxchangelog using "$cxtest/crosswalk_w3.xlsx", ///
    wave(wave) concept(concept_id)
assert _rc == 198

* nonexistent input file -> 601
capture cxchangelog using "$cxtest/no_such_file.xlsx", ///
    wave(wave) concept(concept_id) wording(q_text)
assert _rc == 601

* unsupported input extension -> 198
tempname fh
file open `fh' using "$cxtest/bad.txt", write replace
file write `fh' "not a crosswalk" _n
file close `fh'
capture cxchangelog using "$cxtest/bad.txt", ///
    wave(wave) concept(concept_id) wording(q_text)
assert _rc == 198

* mapped column not in the file -> 111
capture cxchangelog using "$cxtest/crosswalk_w3.xlsx", ///
    wave(wave) concept(concept_id) wording(bogus) out("$cxtest/x1") replace
assert _rc == 111

* highlight() and code() are deferred to v0.2 -> 198
capture cxchangelog using "$cxtest/crosswalk_w3.xlsx", wave(wave) ///
    concept(concept_id) wording(q_text) highlight(vintage)
assert _rc == 198
capture cxchangelog using "$cxtest/crosswalk_w3.xlsx", wave(wave) ///
    concept(concept_id) wording(q_text) code(baseline)
assert _rc == 198

* existing output without replace -> 602
capture cxchangelog using "$cxtest/crosswalk_w3.xlsx", wave(wave) ///
    concept(concept_id) wording(q_text) out("$cxtest/codebook1")
assert _rc == 602

* duplicate concept-wave rows -> 459
clear
input str3 concept_id wave str20 q_text
"a" 1 "text one"
"a" 1 "text two"
end
export excel using "$cxtest/dup.xlsx", firstrow(variables) replace
capture cxchangelog using "$cxtest/dup.xlsx", wave(wave) ///
    concept(concept_id) wording(q_text) out("$cxtest/dupout") replace
assert _rc == 459

* ---------------------------------------------------------------------------
* 6b-6f. The stray-quote rule (0.1.1).  A .csv crosswalk is read with
*     bindquote(strict).  When a cell has a line break and a later line of
*     that cell looks like a data row (at least k-1 delimiters; for k <= 2
*     also an id-like leading token), a stray quote joined rows: cxchangelog
*     warns and uses loose binding.  Otherwise strict is kept silently.  The
*     checks read warnings from text logs and call the private helper
*     _cxc_qguard to count imports (it leaves qg_* locals).
* ---------------------------------------------------------------------------
capture program drop _cx_countin
program define _cx_countin, rclass
    args fn needle
    mata: st_numscalar("r(hits)", ///
        sum(strpos(cat(st_local("fn")), st_local("needle")) :> 0))
    return scalar hits = r(hits)
end
* the helper is private to cxchangelog.ado; running the file defines it for
* this do-file (discard first, so nothing is defined twice)
discard
capture program drop cxchangelog _cxc_qguard _cxc_prep
quietly run "$pkgroot/cxchangelog.ado"
local ls0 = c(linesize)
set linesize 255                  // keep each warning line on one log line

* 6b. quoted cells with line breaks (legitimate multi-line wording and option
*     lists) stay one cell by default, with no warning and one import.
*     0.1.0 split those cells into fragment rows, dropped the fragments, and
*     kept only the text before the break.
clear
input str4 concept int wave str60 wording str40 options
"q1" 1 "How safe do you feel?" "1=Very safe;2=Unsafe"
"q1" 2 "How safe do you feel?" "X"
"q2" 1 "X" "1=Good;2=Poor"
"q2" 2 "In general, how is your health?" "1=Good;2=Poor"
end
replace options = "1=Very safe" + char(10) + "2=Unsafe" in 2
replace wording = "In general," + char(10) + "how is your health?" in 3
export delimited using "$cxtest/cw_ml.csv", quote replace
quietly import delimited using "$cxtest/cw_ml.csv", varnames(1) clear
assert _N > 4                        // loose binding splits the cells
quietly log using "$cxtest/w_ml.log", text replace name(wml)
cxchangelog using "$cxtest/cw_ml.csv", wave(wave) concept(concept) ///
    wording(wording) options(options) summary ///
    compare("$cxtest/cw_ml.csv") out("$cxtest/cwml") replace
assert r(n_concepts) == 2 & r(n_waves) == 2
assert r(n_diff) == 0
quietly log close wml
_cx_countin "$cxtest/w_ml.log" "warning:"
assert r(hits) == 0
import excel using "$cxtest/cwml.xlsx", sheet("items_by_wave") firstrow clear
assert _N == 2
assert w1 == "In general," + char(10) + "how is your health?" if concept == "q2"
import excel using "$cxtest/cwml.xlsx", sheet("options_by_wave") firstrow clear
assert w2 == "1=Very safe" + char(10) + "2=Unsafe" if concept == "q1"
assert w1 == "1=Good;2=Poor" if concept == "q2"
_cxc_qguard "$cxtest/cw_ml.csv", varnames(1)
assert "`qg_status'" == "multiline" & `qg_nread' == 1 & _N == 4
* strictquotes gives the same result (strictq is the minimum abbreviation)
cxchangelog using "$cxtest/cw_ml.csv", wave(wave) concept(concept) ///
    wording(wording) options(options) out("$cxtest/cwml") strictq replace
assert r(n_concepts) == 2 & r(n_waves) == 2

* 6c. a clean .csv (no line break in any cell): no warning, one import
clear
input str4 concept int wave str30 wording
"q1" 1 "Plain wording"
"q1" 2 "Plain wording, revised"
end
export delimited using "$cxtest/cw_ok.csv", quote replace
quietly log using "$cxtest/w_ok.log", text replace name(wok)
cxchangelog using "$cxtest/cw_ok.csv", wave(wave) concept(concept) ///
    wording(wording) out("$cxtest/cwok") replace
assert r(n_concepts) == 1 & r(n_changes) == 1
quietly log close wok
_cx_countin "$cxtest/w_ok.log" "warning:"
assert r(hits) == 0
_cxc_qguard "$cxtest/cw_ok.csv", varnames(1)
assert "`qg_status'" == "clean" & `qg_nread' == 1 & _N == 2

* 6d. a stray inch mark.  Strict binding alone folds q1 wave 2 and all of q2
*     into one cell (2 concepts -> 1, r(n_changes) = 0); the rule finds
*     data-row lines inside that cell, warns, and keeps the four loose rows.
*     The same file as compare() is checked too.
file open fh using "$cxtest/cw_inch.csv", write replace text
file write fh "concept,wave,wording,options" _n
file write fh `"q1,1,Screen size 5" or more?,1=Yes;2=No"' _n
file write fh "q1,2,Screen size?,1=Yes;2=No" _n
file write fh "q2,1,Health?,1=Good;2=Poor" _n
file write fh "q2,2,Health?,1=Good;2=Poor" _n
file close fh
quietly import delimited using "$cxtest/cw_inch.csv", varnames(1) ///
    bindquote(strict) maxquotedrows(unlimited) clear
assert _N == 1                       // the failure the rule exists for
quietly log using "$cxtest/w_inch.log", text replace name(winch)
cxchangelog using "$cxtest/cw_inch.csv", wave(wave) concept(concept) ///
    wording(wording) options(options) summary ///
    compare("$cxtest/cw_inch.csv") out("$cxtest/cwinch") replace
assert r(n_concepts) == 2 & r(n_waves) == 2
assert r(n_changes) == 1             // q1 reworded in wave 2
assert r(n_diff) == 0
quietly log close winch
_cx_countin "$cxtest/w_inch.log" "stray-quote check on file $cxtest/cw_inch.csv"
assert r(hits) == 2                  // once for the crosswalk, once for compare()
_cx_countin "$cxtest/w_inch.log" "In the strict read, the quoted cell in row 1, column wording runs on into lines"
assert r(hits) == 2
_cx_countin "$cxtest/w_inch.log" "strict quote binding read 1 row(s); loose binding read 4 row(s); using the loose result."
assert r(hits) == 2
import excel using "$cxtest/cwinch.xlsx", sheet("items_by_wave") firstrow clear
assert _N == 2
* loose binding runs the stray-quote cell to the end of its own line, so
* that one cell still needs repair upstream; every other cell is intact
assert w1 == `"Screen size 5" or more?,1=Yes;2=No"' if concept == "q1"
assert w2 == "Screen size?" if concept == "q1"
assert w1 == "Health?" & w2 == "Health?" if concept == "q2"
quietly _cxc_qguard "$cxtest/cw_inch.csv", varnames(1) nowarn
assert "`qg_status'" == "stray" & `qg_nread' == 2 & _N == 4
assert `qg_nstrict' == 1 & `qg_nloose' == 4 & "`qg_var'" == "wording"
* strictquotes forces strict binding with no fallback (the swallowed result)
quietly log using "$cxtest/w_inch2.log", text replace name(winch2)
cxchangelog using "$cxtest/cw_inch.csv", wave(wave) concept(concept) ///
    wording(wording) options(options) out("$cxtest/cwinch") ///
    strictquotes replace
assert r(n_concepts) == 1 & r(n_changes) == 0
quietly log close winch2
_cx_countin "$cxtest/w_inch2.log" "warning:"
assert r(hits) == 0

* 6e. both in one file: a legitimate quoted line break and a stray quote.
*     Documented rule: the stray-quote warning wins, so the loose result is
*     kept (the multi-line wording splits too); strictquotes keeps the strict
*     result.  Neither is right: such a file must be fixed upstream.
file open fh using "$cxtest/cw_both.csv", write replace text
file write fh "concept,wave,wording,options" _n
file write fh `"q1,1,"In general,"' _n
file write fh `"how is your health?",1=Good;2=Poor"' _n
file write fh `"q1,2,Screen size 5" or more?,1=Yes;2=No"' _n
file write fh "q2,1,Screen size?,1=Yes;2=No" _n
file write fh "q2,2,Health?,1=Good;2=Poor" _n
file close fh
quietly import delimited using "$cxtest/cw_both.csv", varnames(1) clear
local nloose = _N
quietly import delimited using "$cxtest/cw_both.csv", varnames(1) ///
    bindquote(strict) maxquotedrows(unlimited) clear
local nstrict = _N
assert `nloose' > `nstrict'
quietly log using "$cxtest/w_both.log", text replace name(wboth)
cxchangelog using "$cxtest/cw_both.csv", wave(wave) concept(concept) ///
    wording(wording) options(options) out("$cxtest/cwboth") replace
assert r(n_concepts) == 2            // the split fragment rows are dropped
quietly log close wboth
_cx_countin "$cxtest/w_both.log" "warning:"
assert r(hits) == 1
_cx_countin "$cxtest/w_both.log" "In the strict read, the quoted cell in row 2, column wording"
assert r(hits) == 1
_cx_countin "$cxtest/w_both.log" "strict quote binding read `nstrict' row(s); loose binding read `nloose' row(s)"
assert r(hits) == 1
quietly _cxc_qguard "$cxtest/cw_both.csv", varnames(1) nowarn
assert "`qg_status'" == "stray" & _N == `nloose'
quietly log using "$cxtest/w_both2.log", text replace name(wboth2)
cxchangelog using "$cxtest/cw_both.csv", wave(wave) concept(concept) ///
    wording(wording) options(options) out("$cxtest/cwboth") ///
    strictquotes replace
quietly log close wboth2
_cx_countin "$cxtest/w_both2.log" "warning:"
assert r(hits) == 0

* 6f. tab-delimited variants (a .csv file whose delimiter is a tab; import
*     delimited detects it, and so does the rule).  Wording whose second
*     line has two commas (k-1 for k = 3, were commas the delimiter) stays
*     one cell; a stray inch mark warns.
file open fh using "$cxtest/cw_tab.csv", write replace text
file write fh "concept" _tab "wave" _tab "wording" _n
file write fh "q1" _tab "1" _tab `""In general,"' _n
file write fh `"how, overall, is your health?""' _n
file write fh "q1" _tab "2" _tab "Health?" _n
file close fh
quietly log using "$cxtest/w_tab.log", text replace name(wtab)
cxchangelog using "$cxtest/cw_tab.csv", wave(wave) concept(concept) ///
    wording(wording) out("$cxtest/cwtab") replace
assert r(n_concepts) == 1 & r(n_changes) == 1
quietly log close wtab
_cx_countin "$cxtest/w_tab.log" "warning:"
assert r(hits) == 0
_cxc_qguard "$cxtest/cw_tab.csv", varnames(1)
assert "`qg_status'" == "multiline" & _N == 2
assert wording[1] == "In general," + char(10) + "how, overall, is your health?"
file open fh using "$cxtest/cw_tabinch.csv", write replace text
file write fh "concept" _tab "wave" _tab "wording" _n
file write fh "q1" _tab "1" _tab `"Screen 5" or more?"' _n
file write fh "q1" _tab "2" _tab "Screen size?" _n
file write fh "q2" _tab "1" _tab "Health?" _n
file close fh
quietly log using "$cxtest/w_tab2.log", text replace name(wtab2)
cxchangelog using "$cxtest/cw_tabinch.csv", wave(wave) concept(concept) ///
    wording(wording) out("$cxtest/cwtab") replace
assert r(n_concepts) == 2
quietly log close wtab2
_cx_countin "$cxtest/w_tab2.log" "strict quote binding read 1 row(s); loose binding read 3 row(s)"
assert r(hits) == 1
set linesize `ls0'

* ---------------------------------------------------------------------------
* 7. Clean up every file this test created
* ---------------------------------------------------------------------------
clear
local kill : dir "$cxtest" files "*"
foreach f of local kill {
    capture erase "$cxtest/`f'"
}
capture rmdir "$cxtest"

di as res _n "test_cxchangelog.do: ALL TESTS PASSED"
