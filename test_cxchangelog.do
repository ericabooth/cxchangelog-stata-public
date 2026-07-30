* ===========================================================================
* test_cxchangelog.do -- test battery for cxchangelog v0.1.0
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
* 7. Clean up every file this test created
* ---------------------------------------------------------------------------
clear
local kill : dir "$cxtest" files "*"
foreach f of local kill {
    capture erase "$cxtest/`f'"
}
capture rmdir "$cxtest"

di as res _n "test_cxchangelog.do: ALL TESTS PASSED"
