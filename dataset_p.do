*********************************************************************
*								
* Imputation 2017
*
* 1. Prepare the dataset (dataset.do)
* 2. Specify the equation for imputation (equation.do)
* 3. Imputation (imputation.do)
* 4. Tests
*		(imputation_crossval.do)
*		(imputation_ksmirnov.do)
*********************************************************************

***MO: 	set the following variables in order to obtain the desired dataset
global 	thisyear 	"18"				// set this variable to the actual year, e.g. "18"
global 	lastyear	"17"				// set this variable to the previous year, e.g. "17"
global 	thiswave 	"10"				// set this variable to the number of the actual Welle, e.g. "10"

***MO: 	in the following script, the paths stay as they are for every year- 
*		changes are made automatically through the variables defined above
clear 
set more off
qui do "H:\git\isdatadoku\pathways.do"  // this line must stay BEHIND def of the 4 globals above

* Import people_data_working.dta (generated in dataset_h.do)
use "$imputation\helpdata\people_data_working.dta", clear
save "$imputation\helpdata\p_working_1.dta", replace
*2013: 8837 Obs - 1573 Var
*2014: 11.779 obs - 1562 var
*2016: 12.994 Obs - 1.611 vars

* Add ppfad variables "migback" (Migrationshintergrund) & "sampreg" (Ost/West)
*** ppfad: MIGBACK
use "S:\DATA2\SOEP-IS\SOEP-IS 20${thisyear} Generierung HiWi\Data\finaldata\DE\ppfad.dta", clear 	// alter ppfad weil hier migback enthalten ist
keep pid migback
save "$imputation\helpdata\is_ppfad_help_migback_p.dta", replace     

use "$imputation\helpdata\p_working_1.dta", clear
merge m:1 pid using "$imputation\helpdata\is_ppfad_help_migback_p.dta"
keep if _merge==3 																					// nur die tatsächlich gematchten Fälle behalten

replace migback =. if migback== -1 | migback== 4 													// migback auf missing setzen für keine Antwort und undifferenzierte Antwort
tab migback, gen (migback_)
drop migback _merge 
save "$imputation\helpdata\p_working_2.dta", replace

*** ppfad: SAMPREG
use  "S:\DATA2\SOEP-IS\SOEP-IS 20${thisyear} Generierung HiWi\Data\finaldata\DE\ppfad.dta", clear 	// neuer ppfad weil hier aktuelle sampreg enthalten ist 
keep pid sampreg${thisyear}
save "$imputation\helpdata\is_ppfad_help_sampreg_p.dta", replace	

use "$imputation\helpdata\p_working_2.dta", clear
merge m:1 pid using "$imputation\helpdata\is_ppfad_help_sampreg_p.dta"
keep if _merge==3 																					// nur die tatsächlich gematchten Fälle behalten
tab sampreg${thisyear}, gen (sampreg${thisyear}_)
drop sampreg${thisyear} sampreg${thisyear}_1 _merge

save "$imputation\helpdata\p_working_3.dta", replace
*2013: 8837 Obs - 1578 Var
*2014: 11.009 obs - 1567 var // 11 missing vars
*2016: 12.994 obs - 1.613 Var
