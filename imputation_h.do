*********************************************************************
*								
* Imputation 2018 hghinc (All Samples together)
*
* 1. Prepare the dataset (dataset.do)
* 2. Specify the equation for imputation (equation.do)
* 3. Imputation (imputation.do)
* 4. Tests (imputation_crossval.do)  
*		
*********************************************************************

**************************************************************
* INSTRUCTIONS:
*
* Multiple Imputation of HH-income: use appropriate model (predictive mean model, PMM or PMM&logit): 
* -->  Read UsefulGuidelines.docx
* Necessary to choose knn, default is knn=1 but not recommended. Hence try out knn=5 and knn=10
* 
* First, run dofile on local machine with global stone set to 0: (automatically sets low burnin of 50 to reduce calculation time)
* 		-> create and run the models (run dofile with globals knn set to 5 and 10 and logit set to 0 or 1 (thus, four times in total)) 
*		-> evaluate models and choose the best knn and logit
* Second, run dofile again with global stone set to 1: 
*		-> best model(set knn and logit accordingly) is automatically copied into a Imputation_stone folder and burnin is increased to 2000, 
*       -> inform David Richter who will run it on the Stone (or Crunch) server 
* Third, evaluate the stone-results 
* Fourth, let the person generating hgen know about the final dataset
**************************************************************

***TODO EVERY YEAR: Set the following variables in order to obtain the desired dataset (this dofile structure was created by MO)
* 					the samplename globals ${roh_auf} relate to the Stichprobenkennzeichen, which can be seen e.g. with 'tab sample1' in "$imputation\helpdata\dataset_h3.dta" 
* 					(generated just before the section "Erste Variable-Vorselektion & Dummy-Encodierung der Kategorien" in equation_h.do)
** these variables have to be set once initially every year:
global 	thisyear 	"18"								// set to the actual year, e.g. "18"
global 	lastyear	"17"								// set to the previous year, e.g. "17"
global 	thiswave 	"10"								// set to the number of the actual wave, e.g. "10"
global  aufwuchs	0									// set to 0 if there is no Aufwuchssample, or to 1 if there is an Aufwuchssample this year
global 	rohname 	"EIBIP14S1-4" 						// set to shorthand for all newly introduced samples in past (Rohdatensätze (E,I), BIP (BIP14) And past Aufwuchssample (S1-4)
global 	aufname		"S5"								// if this year a Aufwuchssample is introduced, set the samplename accordingly (probably S5 is the right name)	
** this dofile has to be executed various times for different setups of the following variables:
global	suppl		0									// set to 0 to impute old samples (every year!)
														//	   to 1 to impute supplementary samples (only in some waves there are supplementary samples!) 	
global 	noknn		5									// set to 5 and 10 and compare distributions and correlations of observed and imputed values for hghinc; choose the better model
														// -> 2017: knn=5 and knn=10 worked both well, take knn=10 as no of observations high ~3300
global	logit		0									// set to 0 to impute all variables with pmm
														//	   to 1 to impute continuous variables with pmm and byte variables with logit
														// 	   -> 2017: with logit errors occur, no idea why; so maybe stick with pmm if considered suitable for binary variables
global	stone		0									// David: set to 1 if code is to be executed on Stone-Server, 
														//     		  to 0 if code is to be executed on local machine

***these are auxiliary variables which shall NOT be changed:
global 	DEEN 		"\DE"								// in imputation only a german dataset is to be generated  
if $suppl==0 global roh_auf  $rohname 				
if $suppl==1 global roh_auf  $aufname			
if $stone==0 {											// only used for knn=5 and knn=10 model comparison: 
	global path 	"$imputation"						// - calculation on local machine
	global noburnin	50									// - low burnin saves computation time 
	}
if $stone==1 {											// only used when model is chosen (knn=5 OR knn=10)
	global path 	"/soep/drichter/homes/Imputation"	// - calculation on cluster (more computing power)
	global noburnin 2000								// - high burnin for more accurate computation
	}

***in the following dofile, the paths stay as they are for every year- changes are made automatically through the variables defined above:
cap log close														// closes logfile if open
if $stone==0 qui do "H:\git\isdatadoku\pathways.do"  				// this line must stay BEHIND def of the global variables above
set more off
set matsize 800

*##########################################################################
* I.) IMPUTATION of non-supplementary and supplementary datasets (set global suppl accordingly above)
*##########################################################################
cap mkdir "${path}\helpdata\"										// creates folder if doesnt exist
log using "${path}\helpdata\imputation_H_${roh_auf}.log", replace 
use "${path}\helpdata\h_working_imputation_${roh_auf}.dta", clear

ds cid hid hghinc, not 		// stores all vars except those mentioned in local `r(varlist)'
global varl `r(varlist)' 	// stores names of original vars in global $varl

* Preparation for multiple imputation (mi):
gen _mi_miss = 0
mi extract 0, clear 			 // necessary to prevent errors in subsequent code execution
mi set wide 					 // sets data style to wide and unregisteres variables which are possibly still registered from former imputations
mi xtset, clear 				 // xt-style has to be set to prevent error some lines below
	ds cid hid _mi_miss, not  	 // stores all variables except those mentioned in local `r(varlist)'; (MO17: in previous years, all variables in dataset except cid and hid were registered)
mi register imputed `r(varlist)' // register variables for which values should be imputed

*Main imputation procedure:

*** Short explanation of important parameters of impute method: 
* chained: multiple imputation method for arbitrarily missing variables of mixed types
* pmm: 	predictive mean matching: imputation method to fill missings of continuous variables
		//	(not all imputed vars here continuous, still right? for binary: logit)
		//	(its possible to do the following: mi imp chained (reg) bmi age (logit) smokes for binary vars
		// 	try; only pmm saved in impu_milu.dta, pmm and logit saved in impu_milu2.dta 
		//	->> with logit: convergence not achieved, so use only-pmm-model
		//	pmm preferable to regress method when normality of underlying model suspect
		//	normal linear regression yields normal linear predictions, from which 
		// 	distance to nearest observed neighbors is calculated; from closest # value is randomly drawn
		//	pmm thus preserves distribution of observed values (thus preserves also binarity)
* knn(#): specifies the # of closest observations (nearest neighbors) from which to draw
        //	imputed values.  Closeness is determined based on the absolute difference between 
		// 	the linear prediction for the missing value and that for the complete values.  
* add(#): specify # of imputations to add; required when no imputations exist
* augment: perform augmented regression in the presence of perfect prediction for all categorical imputation variables
* burnin(#): specify number of iterations for the burn-in period 
		//   = # of iterations until convergence to stationary distribution

if $logit==0 {
	ds cid hid _mi_miss, not  			//stores all variables except those mentioned in local `r(varlist)'; (MO17: in previous years, all variables in dataset except cid and hid were registered)
	mi impute chained (pmm, knn($noknn))  `r(varlist)', ///
	add(5) showiter(1) augment burnin($noburnin) rseed(6525413) force dots noisily nomonotone	 
	}
	
if $logit==1 {
	qui ds cid hid  _mi_miss, not 		// stores all variables except those mentioned in local `r(varlist)'
	ds `r(varlist)', has(type byte) 	// stores all byte variables in local `r(varlist)'
	global bytel `r(varlist)' 			// stores all byte variables in global list $bytel

	qui ds cid hid  _mi_miss, not 		//stores all variables except those mentioned in local `r(varlist)'
	ds `r(varlist)', has(type double) 	// stores all continuous variables in local `r(varlist)'
	global contl `r(varlist)' 			// stores all continuous variables in global list $contl

	mi impute chained (pmm, knn($noknn)) $contl (logit) $bytel, ///
	add(5) showiter(1) augment burnin($noburnin) rseed(6525413) force dots noisily nomonotone
	// MO17: error occured during imputation on m=1 for burnin=10 and burnin=50; seems not to work. great.
	}
	
* Examine your imputations to verify that nothing abnormal occurred during imputation by 
* comparing main descriptive statistics of some imputations to observed data: 
mi xeq 0 1 5: summarize hghinc 			// summarizes original data (m = 0), the first (m = 1) and last imputation (m = 5) after burnin period
* 2017:	mean:    2892 - 2875 - 2878 -> both very wealthy and relatively poor people underreport thus a lower mean for imputed values perfectly possible
*		std dev: 1710 - 1708 - 1708 -> std deviation does not change much 
								
* Check the significance of original variables $varl by a simple regression:
reg hghinc	$varl
* 2017: not all vars have a P(>|t|) < 0.05, for example hlc0012  hlc0013, many more    

*Density plots of only the imputed hghincs
generate hh1=_1_hghinc if hghinc==.
generate hh2=_2_hghinc if hghinc==.
generate hh3=_3_hghinc if hghinc==.
generate hh4=_4_hghinc if hghinc==.
generate hh5=_5_hghinc if hghinc==.

*midiagplots is a forthcoming user-written command
*midiagplots age, m(1/5) combine

twoway kdensity hh1 || kdensity hh2 || kdensity hh3 || kdensity hh4 || kdensity hh5 || kdensity hghinc
*2017: in mi exq and plot same observations for knn=5 and knn=10

cap mkdir "${path}\ImpGraphs\"																			// creates folder if doesnt exist
graph save Graph "${path}\ImpGraphs\hghinc_knn${noknn}_${roh_auf}.gph", replace

correlate hh1 hh2 hh3 hh4 hh5   
*2017: knn=5: convergence of imputed values is visible in corr(hh5, hh4)=0.85
			// but could be stronger, more burnin-periods needed  
*2017: knn=10: corr(hh(i),hh(i-1)) > 0.8 for i=1,2,3,4,5, thus ok, but no convergence observed:
			// corr(hh5,hh4) < corr(hh(i),hh(i-1)) for i=1,2,3,4 MO?: bad or doesnt matter?

			
*2017: knn=10: corr(hh(i),hh(i-1)) > 0.74  ---  good (burnin=50)			
/*
             |      hh1      hh2      hh3      hh4      hh5
-------------+---------------------------------------------
         hh1 |   1.0000
         hh2 |   0.7642   1.0000
         hh3 |   0.7896   0.7669   1.0000
         hh4 |   0.7675   0.7495   0.7413   1.0000
         hh5 |   0.7585   0.7757   0.7763   0.7655   1.0000
*/

*2017: knn=5: corr(hh(i),hh(i-1)) > 0.70  ---  good (burnin=2000)
/*
             |      hh1      hh2      hh3      hh4      hh5
-------------+---------------------------------------------
         hh1 |   1.0000
         hh2 |   0.7030   1.0000
         hh3 |   0.7319   0.7500   1.0000
         hh4 |   0.7434   0.7596   0.8224   1.0000
         hh5 |   0.7463   0.7911   0.8054   0.7970   1.0000
*/
			
*2017: knn=10: corr(hh(i),hh(i-1)) > 0.67  ---  good (burnin=2000)
/*
             |      hh1      hh2      hh3      hh4      hh5
-------------+---------------------------------------------
         hh1 |   1.0000
         hh2 |   0.7927   1.0000
         hh3 |   0.7428   0.8013   1.0000
         hh4 |   0.8000   0.8091   0.6710   1.0000
         hh5 |   0.7606   0.8202   0.7253   0.7455   1.0000
*/
*2017: knn=10: corr(hh(i),hh(i-1)) > 0.68  ---  (burnin=5000) -> overall worse than burnin=2000 (?)
/*
             |      hh1      hh2      hh3      hh4      hh5
-------------+---------------------------------------------
         hh1 |   1.0000
         hh2 |   0.7864   1.0000
         hh3 |   0.6895   0.7321   1.0000
         hh4 |   0.7791   0.8069   0.7073   1.0000
         hh5 |   0.7039   0.7975   0.7110   0.6913   1.0000
*/			
cap mkdir "${path}\finaldata"													// creates folder if doesnt exist			
save "${path}\finaldata/h_imputation_final_knn${noknn}_${roh_auf}.dta", replace

*###########################################
* II.) Append final datasets ($rohname & $aufname) 
*###########################################

* only execute the following code if you have successfully executed the code above once for $suppl==0 
* (and $suppl==1, if there is a supplementary sample this year and thus $aufwuchs==1) -> else, error!
use "${path}\finaldata/h_imputation_final_knn${noknn}_${rohname}.dta", clear
if $aufwuchs==1 append using "${path}\finaldata/h_imputation_final_knn${noknn}_${aufname}.dta" 
keep cid hid hghinc _1_hghinc _2_hghinc _3_hghinc _4_hghinc _5_hghinc

*Density plots of only the imputed hghincs
generate hh1=_1_hghinc if hghinc==.
generate hh2=_2_hghinc if hghinc==.
generate hh3=_3_hghinc if hghinc==.
generate hh4=_4_hghinc if hghinc==.
generate hh5=_5_hghinc if hghinc==.

twoway kdensity hh1 || kdensity hh2 || kdensity hh3 || kdensity hh4 || kdensity hh5 || kdensity hghinc

correlate hh1 hh2 hh3 hh4 hh5
  
save  "${path}\finaldata/h_imputation_final_merged_knn${noknn}.dta", replace

capture log close

