*********************************************************************
*								
* Equation h 2018 hghinc
*
* 1. Prepare the dataset (dataset.do)
* 2. Specify the equation for imputation (equation.do)
* 3. Imputation (imputation.do)
** 4. Tests (imputation_crossval.do) //MO: other script mentioned here (imputation_ksmirnov.do) contains only code which was also in imputation_crossval.do; thus omitted 
*		 
*********************************************************************

*  I.) CREATE WORKING EQUATION
* II.) SELECT SIGN. VARIABLES FOR "hghinc"
*		 a.) Old Samples E, I, S1,...
*   	 b.) aufwuchs samples (if they exist this year)

**MO: 	set the following variables in order to obtain the desired dataset
*the samplename globals ${roh_auf} relate to the Stichprobenkennzeichen, 
*which can be seen e.g. with tab sample1 in "$imputation\helpdata\dataset_h3.dta" 
*(generated just before the section "Erste Variable-Vorselektion & Dummy-Encodierung der Kategorien" in this Dofile)
global 	thisyear 	"18"	// set this variable to the year of the dataset, e.g. "18"
global 	lastyear	"17"	// set this variable to the previous year, e.g. "17"
global 	thiswave 	"10"	// set this variable to the number of the actual Welle, e.g. "10"
global	aufwuchs	0		// set to 0 to impute Rohdatensätze (every year)
							//	   to 1 to impute Aufwuchssamples (only in some waves there are aufwuchsementary samples!) 	
if $aufwuchs==0 global roh_auf "EIBIP14S1-4" // shorthand for all newly introduced samples in past (Rohdatensätze (E,I), BIP (BIP14) And past Aufwuchssample (S1-4)
if $aufwuchs==1 global roh_auf "S5"			 // if this year a Aufwuchssample is introduced, set the samplename accordingly (probably S5 is the right name)				

***MO: these are auxiliary variables which shall NOT be changed
global 	DEEN 		"\DE"	// in imputation only a german dataset is to be generated  

***MO: 	in the following script, the paths stay as they are for every year- 
*		changes are made automatically through the variables defined above

clear
set matsize 1600 // set matsize sets the maximum number of variables that can be included in any of Stata's estimation commands
set more off
qui do "H:\git\isdatadoku\pathways.do"  // this line must stay BEHIND def of the 4 globals above

*#####################################
*#####################################
* I.) CREATE WORKING EQUATION
*#####################################
*#####################################

*Prepare hghinc from 20${lastyear} (the non-imputed income) -> past income is the best predictor of current income
use "S:\DATA2\SOEP-IS\SOEP-IS_20${lastyear}_release\download\soep-is.20${lastyear}_stata_de\hgen.dta", clear //urspruenglich .1, aber .2 scheint aktueller zu sein, daher gewaehlt.
keep if syear==real("20${lastyear}")
keep hghinc cid hid
recode hghinc (-1=.) (-3=.)
rename hghinc hghinc20${lastyear}
save "$imputation\helpdata\h_working_hghinc.dta", replace //3.743 Obs, 3.540 valide Werte in hghinc2015

*Merge 20${thisyear} with 20${lastyear}
use "$imputation\helpdata\dataset_h.dta", clear
merge 1:1 cid hid using "$imputation\helpdata\h_working_hghinc.dta" 
drop if _merge==2 // von 3173 sind 1916 gematched, (367 observations deleted)
drop _merge
save "$imputation\helpdata\dataset_h2.dta", replace
*4.599 Obs - 648 Var

use "$imputation\helpdata\dataset_h2.dta", clear
*Set -1, -3, -5, -8 to missing & delete Variable with all missings
d						// stores no. of obs in local `r(N)'
global noobs `r(N)'		// stores no. of obs in global $noobs
ds 						// stores all variable names in local `r(varlist)'
foreach var in `r(varlist)' {
	recode `var' (-1=.) (-3=.) (-5=.) (-8=.) // sets -1, -3, -5, -8 to missing 
	count if `var'==. 					// stores no. of obs for which variable is missing in local `r(N)'
	if "`r(N)'"=="$noobs" drop `var' 	// if all entries of variable are missing, drop variable
} 
save "$imputation\helpdata\dataset_h3.dta", replace
*2017: 4.599 Obs - 176 Var
*2018: 3,717 Obs - 186 Var

****************************************************************************************************************
**************** Erste Variable-Vorselektion & Dummy-Encodierung der Kategorien ********************************
****************************************************************************************************************
* Check all variables in the dataset to identify categories (see below + Imputation.xlsx)
capture log close // The command ``capture log close'' will close a log if any is open and do nothing if no log is open. (The word capture means that Stata should not complain if there is no log open to close.
log using "$imputation\helpdata\h_working_equation.log", replace
use "$imputation\helpdata\dataset_h3.dta", clear // 176
d
tab1 _all, m
log close
****************************

use "$imputation\helpdata\dataset_h3.dta", clear
saveold "$imputation\helpdata\dataset_h3_old.dta", replace version(12) // To save a dataset in Stata 14 or Stata 15 so that it can be used in Stata 13, use the saveold command

*** Check and recode -2 for different groups as preparation for stepwise regression:
*******************
*********** Group 1. Drop unnecessary variables //MO?? nach welchem Kriterium werden "unnecessary vars ausgesucht?
*******************
*2016
drop hlk0005     intid       hpmax       hader       telk2       hergs       nach        hpmax 	///
	 iyear       hlk0056     datumtg     intza       hform1      hstu        modul				///
	 hlk0060     hghmonth    datummo     intk        herg1       split       nach_cawi			///
	 hlk0059     hghmode     hadq        telk1       hforms      regtyp      split_film
*2017
drop hlk0072 hlk0071 
*2018: keine weiteren Vars zu droppen 
saveold "$imputation\helpdata\dataset_h3_g1.dta", replace version(12)

*******************
*********** Group 2. Recode: von -2 zu 0: Var. mit nur einer Antwortkategorie ODER Betrag z.B. in Euro 
*******************
*** MO19: `"nur eine Antwortkategorie" heisst es gibt 2 Kategorien, von denen eine auf "-2 trifft nicht zu" entfÃ¤llt.
use "$imputation\helpdata\dataset_h3_g1.dta", replace
global helplist // create empty list which the following loop will fill with variables that might contain BetrÃ¤ge z.B. in Euro and which are to be checked later
global group2varlist // create empty list of group 2 variables

ds cid hid syear sample1, not // stores all variables except those mentioned in local `r(varlist)'
foreach var in `r(varlist)' {
	distinct `var' // stores number of distinct categories in local `r(ndistinct)'
	// maybe command distinct not known, then type "help distinct" and click on respective package -> install
	if `r(ndistinct)'==2 { // this if-bracket adds all variables "mit nur einer Antwortkategorie" to global $group2varlist
		count if `var'==-2 // stores frequency of var label -2 into `r(N)'
		if `r(N)'>0 global group2varlist $group2varlist `var'
		}
	else if `r(ndistinct)' >= 10 & `r(ndistinct)'<= 20 global helplist $helplist `var' // fill helplist
	else if `r(ndistinct)'> 20 global group2varlist $group2varlist `var' // fill group2varlist
}

d $group2varlist
d $helplist
tab1 $helplist // every year: check if some variables in helplist should be in group2list

global group2varlist $group2varlist hlc0047 hdbp2 hlc0068 // every year: some variables of helplist have to be added to group2varlist
recode $group2varlist (-2=0) 

saveold "$imputation\helpdata\dataset_h3_g2.dta", replace

*******************
*********** Group 3. Recode mehrere Kategorien: Var. MIT -2  (wird gedropt)
*********** Group 4. Recode mehrere Kategorien: Var. OHNE -2 (erste neu gebildete Variable wird beibehalten)
*******************
use "$imputation\helpdata\dataset_h3_g2.dta", replace
 
*** MO19: the following loop automatically checks if variable has category -2 or not and acts accordingly. 
*** execute following line and loop together! (else it wont work) 
ds $group2varlist cid hid syear, not // stores all variables except those mentioned in a local variable `r(varlist)'
foreach var in `r(varlist)' {  
	dis "`var'"
	tab `var' , gen (`var'_)		 // dummy variables are created for each category of the resp. variable 
	count if `var'==-2  			 // stores the number counted in local variable `r(N)'
	if `r(N)'>0 drop `var'_1		 // if variable has category -2, the following two lines are executed
	drop `var'
	}

saveold "$imputation\helpdata\h_working_equation_1.dta", replace version(12) // 317 vars

// GS: ZUSATZ Dez.2014 -------------------------------------------------------------------------------------------------
// * hinzufuegen von ppfad Variablen "migback" (Migrationshintergrund) & "sampreg" (Ost/West)
use "$imputation\helpdata\h_working_equation_1.dta", clear
*** ppfad: MIGBACK
use "$helpdatappfad\is_ppfad_19.dta", clear //MO 18 TODO! erneut ausführen mit diesem Datensatz, fehlte bisher!
keep cid hid20$thisyear migback
rename hid20$thisyear hid
sort cid hid
save "$imputation\helpdata\is_ppfad_help_migback_h.dta", replace     // lokal gespeichert

use "$imputation\helpdata\h_working_equation_1.dta", clear
merge m:m cid hid using "$imputation\helpdata\is_ppfad_help_migback_h.dta"
keep if _merge==3 // nur die tatsaechlich gematchten Faee behalten
bysort cid hid: gen seq=_n
keep if seq==1    // nur die urspruenglichen 3173 HHte behalten (MO?: um zu verstehen, warum seq==1 die ursprünglichen HH sind, mÃ¼sste man wsl den Code in Ppfad kennen?)
drop seq

*MO19: aber migback==4 existiert nicht, migback==-2 wird zu migback_1, migback==1 zu migback_2 usw. aber wsl irrelevant in Schätzung? 
replace migback =. if migback== -1 | migback== 4 // migback auf missing setzen fuer keine Antwort und undifferenzierte Antwort
tab migback, gen (migback_)
drop migback 
drop _merge

save "$imputation\helpdata\h_working_equation_2.dta", replace


*** ppfad: SAMPREG
use "$is$DEEN\ppfad.dta", clear //neuer ppfad weil hier aktuelle sampreg enthalten ist 
keep cid hid$thisyear sampreg$thisyear
rename hid$thisyear hid
sort cid hid
*save "S:\DATA2\SOEP-IS\SOEP-IS 2013 Generierung HiWi\Imputation_500\helpdata\is_ppfad_help_sampreg_h.dta", replace	// in Davids Ordner gespeichert, damit er später mit stone Zugriff hat
save "$imputation\helpdata\is_ppfad_help_sampreg_h.dta", replace		// lokal gespeichert

use "$imputation\helpdata\h_working_equation_2.dta", clear
merge m:m cid hid using "$imputation\helpdata\is_ppfad_help_sampreg_h.dta"
keep if _merge==3 // nur die tatsaechlich gematchten Faelle behalten
bysort cid hid: gen seq=_n
keep if seq==1 // nur die urspruenglichen 3173 HHte behalten
drop seq

tab sampreg$thisyear, gen (sampreg${thisyear}_)
drop sampreg$thisyear 

drop _merge

saveold "$imputation\helpdata\h_working_equation.dta", replace version(12)

use "$imputation\helpdata\h_working_equation.dta", clear
if $aufwuchs==1 keep if sample1_xxx==0 	//MO: xxx has to be changed to no. to match variable which indicates new supplementary sample
save "$imputation\helpdata\h_working_equation_EIBIP14S1-4.dta", replace

if $aufwuchs==1 {
	use "$imputation\helpdata\h_working_equation.dta", clear
	keep if sample1_xxx==1 				//MO: xxx has to be changed to no. to match variable which indicates new supplementary sample
	save "$imputation\helpdata\h_working_equation_!name of new sample!.dta", replace
	}

*#########################################
*#########################################
* II.) SELECT SIGN. VARIABLES FOR "hghinc"
*#########################################
*#########################################
use "$imputation\helpdata\h_working_equation_${roh_auf}.dta", clear

* 1. Regress all variables on hghinc
order cid hid hghinc
ds cid hid hghinc syear, not // stores all var apart the ones mentioned in local `r(varlist)'
foreach var in `r(varlist)' {
	regress hghinc `var'
	local z = _b["`var'"]/_se["`var'"]
	gen sig`var'= 2*(1-normal(abs(`z')))
	if sig`var'>0.10 drop `var' 
	drop sig`var'
}
*172 Var.
*184 var.
*2015: 231 var
*2016: 225
*2017: 289
*2018: 307
saveold "$imputation\helpdata\h_working_equation_g1${roh_auf}.dta", replace version(12)

* 2. Identify all highly collinear variables and
* 2.1. Keep income and  all highly collinear variables for future checks
use "$imputation\helpdata\h_working_equation_g1${roh_auf}.dta", clear
ds cid hid hghinc syear, not // stores all var apart the ones mentioned in local `r(varlist)'
_rmcoll `r(varlist)'
dis "`r(varlist)'" 				//collinear vars are marked by an o. at beginning of their names
foreach var in `r(varlist)' { 	// drop noncollinear vars
	if substr("`var'",1,2)!="o." drop `var'
	}
drop cid hid syear
saveold "$imputation\helpdata\h_working_equation_g2${roh_auf}.dta", replace version(12)

* 2.2. Drop all highly collinear variables for further procedure
use "$imputation\helpdata\h_working_equation_g1${roh_auf}.dta", clear
ds cid hid hghinc syear, not 	// stores all var apart the ones mentioned in local `r(varlist)'
_rmcoll `r(varlist)'
dis "`r(varlist)'" 				//collinear vars are marked by an o. at beginning of their names
global keeplist 				//creates empty global $keeplist, which will be filled with variable names in the following loop
foreach var in `r(varlist)' { 	// drop collinear vars
	if substr("`var'",1,2)!="o." global keeplist $keeplist `var' //extends the keeplist by the variable if it begins with "o."
	}
keep $keeplist cid hid hghinc
saveold "$imputation\helpdata\h_working_equation_g3${roh_auf}.dta", replace version(12)

* 2.3 stepwise sign. Niveau mit alpha=0.1
*Stepwise regress hghinc on all variables with significance level for removal from the model =0.1 to find significant variables
use "$imputation\helpdata\h_working_equation_g3${roh_auf}.dta", clear
* as the following command stepwise ... regress throws a collinearity error for certain variables, 
* these are stored in the following global $colvars and excluded from regression 
global collin_vars hh_sumnet_miss_2 			// TODO EVERY YEAR: delete content of list, and fill successively until stepwise...regress error-free!
ds cid hid hghinc $collin_vars, not 			// stores all vars apart of hghinc in local `r(varlist)'
stepwise, pr(.1): regress hghinc `r(varlist)' 	// removes all insignificant vars (for alpha=0.1) automatically and stores names and coefficients of significant vars in local `e(b)'
matrix b=e(b) 									// stores e(b) as matrix (colnames= variable names; entries: coefficients)
matrix a=b[1,1..`= colsof(b)-1'] 				// in a, variable names in `e(b)' are stored, but without _cons (which is always the last entry, which is omitted by extracting a matrix subset of up to the `=colsof(b)-1'-st column)
global signvarlist: colnames a 					// stores names of significant variables in global $signvarlist

* 2.4. (Intermediate step - NOT REQUIRED) Keep all non-significant variables for future checks
ds $signvarlist 								// stores names of significant variables in local `r(varlist)'
drop `r(varlist)'
saveold "$imputation\helpdata\h_working_equation_g4${roh_auf}.dta", replace version(12)

* 2.5. Keep all significant variables idenfified in step 2.3. for further procedure
use "$imputation\helpdata\h_working_equation_g3${roh_auf}.dta", clear
ds hid cid hghinc $signvarlist 
keep `r(varlist)'

* 2.6. Save final dataset of OLD/ NEW SAMPLES used for imputation
	 
*use "$imputation\helpdata\h_working_imputation_all.dta", clear
saveold "$imputation\helpdata\h_working_imputation_${roh_auf}.dta", replace version(12)
save "$imputation\helpdata\h_working_imputation_${roh_auf}.dta", replace
*old samples: 
*2014: 54 vars
*2016: 48
*2017: 57

