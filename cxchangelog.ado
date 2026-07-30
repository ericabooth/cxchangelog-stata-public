*! version 0.1.0  20260706  Eric A. Booth, Sr Researcher, Texas 2036
*! cxchangelog: rebuild a cross-wave survey codebook from a long-format crosswalk
*
*  version 16.0: no feature above the 16.0 baseline is required; 16.0 is the
*  floor the package is tested against.  marksample is not used because the
*  command operates on an imported file, not on the data in memory (which are
*  preserved and restored untouched).

program define cxchangelog, rclass
    version 16.0

    syntax using/ , WAve(name) CONcept(name) WORDing(name)          ///
        [ OPTions(name) STudy(name) SUMmary COMPare(string)         ///
          OUT(string) CSV REPlace HIGHlight(string) CODE(string) ]

    * ---- options deferred to a later release --------------------------------
    if `"`highlight'"' != "" {
        di as err "option highlight() is not implemented in cxchangelog 0.1.0; lifecycle highlighting is planned for v0.2"
        exit 198
    }
    if `"`code'"' != "" {
        di as err "option code() is not implemented in cxchangelog 0.1.0; lifecycle codes are planned for v0.2"
        exit 198
    }

    * ---- input file ----------------------------------------------------------
    confirm file `"`using'"'
    local dot = strrpos(`"`using'"', ".")
    local ext = cond(`dot' > 0, lower(substr(`"`using'"', `dot', .)), "")
    if !inlist("`ext'", ".xlsx", ".xls", ".csv") {
        di as err "cxchangelog reads .xlsx, .xls, or .csv crosswalk files"
        exit 198
    }

    * ---- compare() file, validated before any work ----------------------------
    if `"`compare'"' != "" {
        confirm file `"`compare'"'
        local pdot = strrpos(`"`compare'"', ".")
        local pext = cond(`pdot' > 0, lower(substr(`"`compare'"', `pdot', .)), "")
        if !inlist("`pext'", ".xlsx", ".xls", ".csv") {
            di as err "compare() must name a .xlsx, .xls, or .csv file"
            exit 198
        }
    }

    * ---- output names ----------------------------------------------------------
    * out() is a stub: any .xlsx/.xls/.csv extension the user typed is stripped.
    * Default stub is the input filename with _codebook appended.
    if `"`out'"' == "" local out = substr(`"`using'"', 1, `dot' - 1) + "_codebook"
    foreach e in .xlsx .xls .csv {
        local le = strlen("`e'")
        if lower(substr(`"`out'"', -`le', .)) == "`e'" {
            local out = substr(`"`out'"', 1, strlen(`"`out'"') - `le')
        }
    }
    local ncheck 0
    if "`csv'" == "" {
        local f_book `"`out'.xlsx"'
        local ++ncheck
        local chk`ncheck' `"`f_book'"'
    }
    else {
        local f_items    `"`out'_items.csv"'
        local f_options  `"`out'_options.csv"'
        local f_coverage `"`out'_coverage.csv"'
        local f_summary  `"`out'_summary.csv"'
        local f_compare  `"`out'_compare.csv"'
        local ++ncheck
        local chk`ncheck' `"`f_items'"'
        foreach t in options coverage summary compare {
            if "`t'" == "coverage" local on "`study'"
            else if "`t'" == "compare" local on `"`compare'"'
            else local on "``t''"
            if `"`on'"' != "" {
                local ++ncheck
                local chk`ncheck' `"`f_`t''"'
            }
        }
    }
    if "`replace'" == "" {
        forvalues j = 1/`ncheck' {
            capture confirm new file `"`chk`j''"'
            if _rc {
                di as err `"output file `chk`j'' already exists; specify the replace option"'
                exit 602
            }
        }
    }

    * ---- everything below runs on a scratch copy; user data are untouched -----
    preserve

    quietly {
        if "`ext'" == ".csv" import delimited `"`using'"', varnames(1) clear
        else import excel `"`using'"', firstrow clear
    }

    * mapped columns must exist in the imported file
    foreach o in wave concept wording options study {
        if "``o''" == "" continue
        capture confirm variable ``o''
        if _rc {
            quietly ds
            di as err "`o'(``o'') is not a column of the crosswalk file"
            di as err `"columns found: `r(varlist)'"'
            exit 111
        }
    }
    capture unab cxreserved : _cx*
    if !_rc {
        di as err "the crosswalk file has columns named _cx*, which cxchangelog reserves; rename them and rerun"
        exit 110
    }

    * standardize: _cxconcept _cxwkey _cxwnum _cxworder _cxword _cxopt _cxstudy
    local pass wave(`wave') concept(`concept') wording(`wording')
    if "`options'" != "" local pass `pass' options(`options')
    if "`study'"   != "" local pass `pass' study(`study')
    _cxc_prep, `pass' tag(the crosswalk file)
    local n_concepts = r(n_concepts)
    local n_waves    = r(n_waves)
    local wkeys      `"`r(wkeys)'"'

    * column-safe names for the wave columns of the wide sheets
    local i 0
    foreach kk of local wkeys {
        local ++i
        local wlab`i' `"`kk'"'
        local cand = strtoname(`"w`kk'"')
        if strlen("`cand'") > 28 local cand = substr("`cand'", 1, 28)
        forvalues j = 1/`= `i' - 1' {
            if "`cand'" == "`wname`j''" local cand "`cand'_`i'"
        }
        local wname`i' "`cand'"
        local wcols `wcols' `cand'
    }

    tempfile base
    quietly save `base'

    * ---- wave-over-wave change counts (always computed; feeds r() results) -----
    * An item is "fielded" in a wave when its wording cell is nonblank.  The
    * wide-then-long reshape rectangularizes the concept-by-wave grid so that
    * added/removed/reworded can be read off consecutive waves.
    quietly {
        keep _cxconcept _cxworder _cxword
        reshape wide _cxword, i(_cxconcept) j(_cxworder)
        reshape long _cxword, i(_cxconcept) j(_cxworder)
        gen byte _cxpres = _cxword != ""
        sort _cxconcept _cxworder
        by _cxconcept: gen byte _cxadd = _cxpres == 1 & _n > 1 & _cxpres[_n - 1] == 0
        by _cxconcept: gen byte _cxrem = _cxpres == 0 & _n > 1 & _cxpres[_n - 1] == 1
        by _cxconcept: gen byte _cxrew = _cxpres == 1 & _n > 1 & _cxpres[_n - 1] == 1 ///
            & _cxword != _cxword[_n - 1]
        collapse (sum) fielded=_cxpres added=_cxadd removed=_cxrem reworded=_cxrew, ///
            by(_cxworder)
        summarize added, meanonly
        local n_added = r(sum)
        summarize removed, meanonly
        local n_removed = r(sum)
        summarize reworded, meanonly
        local n_changes = r(sum)
        gen wave = ""
        forvalues i = 1/`n_waves' {
            replace wave = `"`wlab`i''"' if _cxworder == `i'
        }
        order wave fielded added removed reworded
        drop _cxworder
        tempfile fsum
        save `fsum'
    }

    * ---- diff against a prior crosswalk vintage ---------------------------------
    local n_diff 0
    if `"`compare'"' != "" {
        quietly {
            use `base', clear
            keep _cxconcept _cxwkey _cxwnum _cxword
            tempfile fcur
            save `fcur'
            if "`pext'" == ".csv" import delimited `"`compare'"', varnames(1) clear
            else import excel `"`compare'"', firstrow clear
        }
        foreach o in wave concept wording {
            capture confirm variable ``o''
            if _rc {
                di as err "`o'(``o'') is not a column of the compare() file; the prior vintage must use the same column names as the crosswalk"
                exit 111
            }
        }
        capture unab cxreserved : _cx*
        if !_rc {
            di as err "the compare() file has columns named _cx*, which cxchangelog reserves; rename them and rerun"
            exit 110
        }
        _cxc_prep, wave(`wave') concept(`concept') wording(`wording') tag(the compare() file)
        quietly {
            keep _cxconcept _cxwkey _cxword
            rename _cxword _cxpriorword
            tempfile fprior
            save `fprior'
            use `fcur', clear
            merge 1:1 _cxconcept _cxwkey using `fprior'
            gen status = cond(_merge == 1, "added",      ///
                cond(_merge == 2, "removed",             ///
                cond(_cxword != _cxpriorword, "reworded", "same")))
            drop if status == "same"
            local n_diff = _N
            sort _cxconcept _cxwkey
            drop _merge _cxwnum
            rename (_cxconcept _cxwkey _cxword _cxpriorword) ///
                   (concept wave current_wording prior_wording)
            order concept wave status prior_wording current_wording
            tempfile fdiff
            save `fdiff'
        }
    }

    * ---- items-by-wave sheet ------------------------------------------------------
    quietly {
        use `base', clear
        keep _cxconcept _cxworder _cxword _cxstudy
        local ivars _cxconcept
        if "`study'" != "" {
            bysort _cxconcept (_cxworder): replace _cxstudy = _cxstudy[1]
            local ivars _cxconcept _cxstudy
        }
        else drop _cxstudy
        reshape wide _cxword, i(`ivars') j(_cxworder)
        forvalues i = 1/`n_waves' {
            rename _cxword`i' `wname`i''
            label variable `wname`i'' `"wording in wave `wlab`i''"'
        }
        rename _cxconcept concept
        if "`study'" != "" rename _cxstudy study
        sort concept
        if "`study'" != "" order concept study `wcols'
        else order concept `wcols'
        if "`csv'" == "" {
            export excel using `"`f_book'"', firstrow(variables) ///
                sheet("items_by_wave") replace
        }
        else export delimited using `"`f_items'"', replace
    }

    * ---- options-by-wave sheet -----------------------------------------------------
    if "`options'" != "" {
        quietly {
            use `base', clear
            keep _cxconcept _cxworder _cxopt
            reshape wide _cxopt, i(_cxconcept) j(_cxworder)
            forvalues i = 1/`n_waves' {
                rename _cxopt`i' `wname`i''
                label variable `wname`i'' `"response options in wave `wlab`i''"'
            }
            rename _cxconcept concept
            sort concept
            order concept `wcols'
            if "`csv'" == "" {
                export excel using `"`f_book'"', firstrow(variables) ///
                    sheet("options_by_wave") sheetreplace
            }
            else export delimited using `"`f_options'"', replace
        }
    }

    * ---- study coverage matrix ------------------------------------------------------
    if "`study'" != "" {
        quietly {
            use `base', clear
            gen byte _cxone = 1
            collapse (count) _cxone, by(_cxstudy _cxworder)
            reshape wide _cxone, i(_cxstudy) j(_cxworder)
            forvalues i = 1/`n_waves' {
                capture confirm variable _cxone`i'
                if _rc gen _cxone`i' = 0
                rename _cxone`i' `wname`i''
                replace `wname`i'' = 0 if missing(`wname`i'')
                label variable `wname`i'' `"items fielded in wave `wlab`i''"'
            }
            rename _cxstudy study
            sort study
            order study `wcols'
            if "`csv'" == "" {
                export excel using `"`f_book'"', firstrow(variables) ///
                    sheet("study_coverage") sheetreplace
            }
            else export delimited using `"`f_coverage'"', replace
        }
    }

    * ---- header -----------------------------------------------------------------------
    di as txt _n "cxchangelog 0.1.0"
    di as txt "  crosswalk: " as res `"`using'"'
    di as txt "  concepts: " as res `n_concepts' as txt "    waves: " as res `n_waves'
    di as txt "  wave-over-wave: " as res `n_added' as txt " added, "  ///
        as res `n_removed' as txt " removed, " as res `n_changes' as txt " reworded"

    * ---- per-wave summary ----------------------------------------------------------------
    if "`summary'" != "" {
        quietly use `fsum', clear
        if "`csv'" == "" {
            quietly export excel using `"`f_book'"', firstrow(variables) ///
                sheet("wave_summary") sheetreplace
        }
        else quietly export delimited using `"`f_summary'"', replace
        di as txt _n "Per-wave changes relative to the previous wave (first wave is the baseline):"
        list wave fielded added removed reworded, noobs sep(0) abbreviate(12)
    }

    * ---- compare report ---------------------------------------------------------------------
    if `"`compare'"' != "" {
        quietly use `fdiff', clear
        if `n_diff' > 0 {
            if "`csv'" == "" {
                quietly export excel using `"`f_book'"', firstrow(variables) ///
                    sheet("compare") sheetreplace
            }
            else quietly export delimited using `"`f_compare'"', replace
        }
        di as txt _n "Differences vs " as res `"`compare'"' as txt ": " as res `n_diff'
        if `n_diff' > 0 list concept wave status, noobs sep(0) abbreviate(12)
        else di as txt "  (no compare sheet written: the two vintages match)"
    }

    restore

    * ---- files written -------------------------------------------------------------------------
    if "`csv'" == "" di as txt _n "wrote " as res `"`f_book'"'
    else {
        di as txt _n "wrote " as res `"`f_items'"'
        if "`options'" != "" di as txt "wrote " as res `"`f_options'"'
        if "`study'"   != "" di as txt "wrote " as res `"`f_coverage'"'
        if "`summary'" != "" di as txt "wrote " as res `"`f_summary'"'
        if `"`compare'"' != "" & `n_diff' > 0 di as txt "wrote " as res `"`f_compare'"'
    }

    * ---- stored results ----------------------------------------------------------------------------
    return scalar n_concepts = `n_concepts'
    return scalar n_waves    = `n_waves'
    return scalar n_changes  = `n_changes'
    return scalar n_added    = `n_added'
    return scalar n_removed  = `n_removed'
    if `"`compare'"' != "" return scalar n_diff = `n_diff'
    return local outstub `"`out'"'
    if "`csv'" == "" return local outfile `"`f_book'"'
    else return local outfile `"`f_items'"'
end


* ---------------------------------------------------------------------------
* _cxc_prep: standardize an imported crosswalk into _cx* working variables.
* Leaves one row per fielded concept-wave, with:
*   _cxconcept  concept id (trimmed string)
*   _cxwkey     wave value as a string key
*   _cxwnum     numeric wave sort value (real value, or alphabetical rank)
*   _cxworder   dense wave rank 1..k
*   _cxword     question wording (trimmed string; nonblank)
*   _cxopt      response options ("" when options() not given)
*   _cxstudy    study/module tag ("" when study() not given)
* Returns r(n_concepts), r(n_waves), and r(wkeys) (wave keys in order).
* ---------------------------------------------------------------------------
program define _cxc_prep, rclass
    version 16.0
    syntax , WAVE(name) CONCEPT(name) WORDING(name) ///
        [ OPTIONS(name) STUDY(name) TAG(string) ]

    * concept and wording as trimmed strings
    capture confirm string variable `concept'
    if _rc {
        quietly gen _cxconcept = strtrim(strofreal(`concept', "%18.0g"))
        quietly replace _cxconcept = "" if missing(`concept')
    }
    else quietly gen _cxconcept = strtrim(`concept')

    capture confirm string variable `wording'
    if _rc {
        quietly gen _cxword = strtrim(strofreal(`wording', "%18.0g"))
        quietly replace _cxword = "" if missing(`wording')
    }
    else quietly gen _cxword = strtrim(`wording')

    * wave key and ordering: numeric order when wave values are numbers,
    * alphabetical order otherwise
    capture confirm string variable `wave'
    if _rc {
        quietly gen _cxwkey = strtrim(strofreal(`wave', "%18.0g"))
        quietly replace _cxwkey = "" if missing(`wave')
        quietly gen double _cxwnum = `wave'
    }
    else {
        quietly gen _cxwkey = strtrim(`wave')
        quietly gen double _cxwnum = real(_cxwkey)
        capture assert !missing(_cxwnum) if _cxwkey != ""
        if _rc {
            drop _cxwnum
            quietly egen double _cxwnum = group(_cxwkey)
        }
    }

    * options / study, when mapped
    if "`options'" != "" {
        capture confirm string variable `options'
        if _rc {
            quietly gen _cxopt = strtrim(strofreal(`options', "%18.0g"))
            quietly replace _cxopt = "" if missing(`options')
        }
        else quietly gen _cxopt = strtrim(`options')
    }
    else quietly gen _cxopt = ""
    if "`study'" != "" {
        capture confirm string variable `study'
        if _rc {
            quietly gen _cxstudy = strtrim(strofreal(`study', "%18.0g"))
            quietly replace _cxstudy = "" if missing(`study')
        }
        else quietly gen _cxstudy = strtrim(`study')
    }
    else quietly gen _cxstudy = ""

    * usable rows: a fielded item has a concept, a wave, and a nonblank wording
    quietly drop if _cxconcept == "" | _cxwkey == "" | _cxword == ""
    if _N == 0 {
        di as err "no usable rows in `tag': every row lacks a concept, a wave, or a wording"
        exit 2000
    }

    * one row per concept per wave
    capture isid _cxconcept _cxwkey
    if _rc {
        di as err "`tag' has more than one row for the same concept and wave; keep one row per concept per wave"
        exit 459
    }

    sort _cxwnum _cxconcept
    quietly egen int _cxworder = group(_cxwnum)
    keep _cxconcept _cxwkey _cxwnum _cxworder _cxword _cxopt _cxstudy

    * results
    quietly summarize _cxworder, meanonly
    local k = r(max)
    forvalues i = 1/`k' {
        quietly levelsof _cxwkey if _cxworder == `i', local(kk)
        local wkeys `"`wkeys' `kk'"'
    }
    tempvar tg
    quietly egen byte `tg' = tag(_cxconcept)
    quietly count if `tg'
    return scalar n_concepts = r(N)
    return scalar n_waves = `k'
    return local wkeys `"`wkeys'"'
end
