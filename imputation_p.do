*********************************************************************
*								
* Imputation 2017 labgro & labnet (p) (All Samples together)
*
* 1. Prepare the dataset (dataset_p.do)
* 2. Specify the equation for imputation (equation_p.do)
* 3. Imputation (imputation_p_merged.do)
* 4. Tests (imputation_p_crossval.do) //MO: other script mentioned here (imputation_ksmirnov.do) contains only code which was also in imputation_crossval.do; thus omitted 
*		
*********************************************************************

**************************************************************
* INSTRUCTIONS:
*
* Multiple Imputation of HH-income: use the predictive mean model (PMM): 
* -->  Read UsefulGuidelines.docx
* Necessary to choose knn, default is knn=1 but not recommended. Hence try out knn=5 and knn=10
* First, create the model and make it run on a low burnin (50), evaluate the model, choose the best one: knn=5 or knn=10
* Second, copy the best model into a Imputation_stone folder with different paths, increase the burnin (2000), 
*         send to David Richter who will run it on the Stone (or Crunch) server 
* Third, evaluate the stone-results 
* Fourth, let the person generating hgen know about the final dataset
**************************************************************

**MO: 	set the following variables in order to obtain the desired dataset
global 	thisyear 	"17"	// set to the actual year, e.g. "18"
global 	lastyear	"16"	// set to the previous year, e.g. "17"
global 	thiswave 	"9"		// set to the number of the actual wave, e.g. "10"
global	suppl		0		// set to 0 to impute old samples 
							//	   to 1 to impute supplementary samples (only in some waves there are supplementary samples!) 		//MK17: In other words, only set to 1 if there is a NEW supplementary sample in its first wave.
global	stone		0		// David: set to 1 if code is to be executed on Stone-Server, 
							//     		  to 0 if code is to be executed regularly 
global	logit		0		// David: set to 0 to impute all variables with pmm
							//		      to 1 to impute continuous variables with pmm and byte variables with logit
							// with logit errors occur, no idea why; so maybe stick with pmm if considered suitable for binary variables
global	noburnin	50	// set to number of iterations of burn-in period, e.g. 50
global 	noknn		10		// set to 5 and 10 and compare distributions and correlations of 
							// observed and imputed values for hghinc; choose the better model
global	dataset 	"pglabnet"	// set to "pglabgro" or "pglabnet" to generate respective datasets below

***MO: these are auxiliary variables which shall NOT be changed
global 	DEEN 		"\DE"	// in imputation only a german dataset is to be generated  

***MO: 	in the following script, the paths stay as they are for every year- 
*		changes are made automatically through the variables defined above

*MK17: In previous waves, pglabgro & pglabnet were imputed jointly in a merged dataset containing all variables from the equation datasets of both variables of interest.
*	   This procedure does not work for wave 2017 giving the following error message:
*	 mi impute: VCE is not positive definite 
*    The posterior distribution from which mi impute drew the imputations for !var_x! is not proper when the VCE estimated from the observed
*    data is not positive definite.  This may happen, for example, when the number of parameters exceeds the number of observations. Choose
*    an alternate imputation model.
*Therefore, I impute pglabgro & pglabnet separately each using their own estimation model from equation_p.do (except that I add pglabnet to pglabgro's model, and vice versa).

*##########################################################################
* I.) IMPUTATION of non-supplementary and supplementary datasets (set global suppl accordingly above) 
*##########################################################################

capture log close
if $stone==0 qui do "pathways.do"  // this line must stay BEHIND def of the global variables above
set more off

*MO17: knn=5 and knn=10 worked both well, take knn=10 as no of observations high ~3300

if $stone==0 & $suppl==0 log using "$imputation\helpdata\imputation_p_${dataset}.log", replace 
if $stone==0 & $suppl==1 log using "$imputation\helpdata\imputation_p_${dataset}_suppl.log", replace 
if $stone==1 & $suppl==0 log using "/soep/drichter/homes/Imputation/imputation_p_${dataset}.log", replace
if $stone==1 & $suppl==1 log using "/soep/drichter/homes/Imputation/imputation_p_${dataset}_suppl.log", replace

if $stone==0 & $suppl==0 use "$imputation\helpdata\p_working_imputation_${dataset}.dta", clear
if $stone==0 & $suppl==1 use "$imputation\helpdata\p_working_imputation_${dataset}_suppl.dta", clear
if $stone==1 & $suppl==0 use "/soep/drichter/homes/imputation/p_working_imputation_${dataset}.dta", clear
if $stone==1 & $suppl==1 use "/soep/drichter/homes/imputation/p_working_imputation_${dataset}_suppl.dta", clear

ds cid hid pid $dataset sample1, not 
global varl `r(varlist)' // stores names of original vars in global $varl

set matsize 800
*gen _mi_miss = 0 //MK17: For some reason, this deviates from the procedure in imputation_h.do where data were already mi set. 
*MO17:	die folgenden auskommentierten Zeilen verstehe ich noch absolut nicht, 
*		unnötige vars werden generiert die redundante infos zu erhalten scheinen! (dadurch Collinearitätsproblem?)
*		im 2016er Datensatz nötig damit set wide funktioniert, jedoch werden auch redundante vars generiert,
*		im 2015er Datensatz geht es OHNE unset
*		unter help mi_set##unset steht "your best choices are mi extract..." 
*		und "mi unset is included for completeness, and if it has any use at all, it would be by programmers."
*		daher nun extract verwendet, welches keine zusätzlichen Vars generiert. 
/*gen _mi_m = 0	//MO17: Scheint redundant zu sein fuer mi extract 0
gen _mi_id = _n	//MO17: Scheint redundant zu sein fuer mi extract 0
qui mi unset  //Datensatz muss mi unset gesetzt werden, sonst laesst sich der ausgelieferte Datensatz nicht reshapen!!!
ds
drop _mi_miss _mi_id _mi_m //MO17 nun redundant da durch mi extract _mi_miss entfällt
*/	
*mi extract 0, clear // necessary to prevent errors in subsequent code execution 	//MK17: not necessary as compared to imputation_h.do

*set style of the data set:
mi set wide // sets data style to wide and unregisteres variables which are possibly still registered from former imputations
mi xtset, clear // has to be done to prevent error some lines below
  
*register variables for which values should be imputed
ds cid hid pid sample1 _mi_miss, not  //stores all variables except those mentioned in local `r(varlist)'
mi register imputed `r(varlist)'

*Main imputation procedure:

*** Short explanation of important aspects of impute method: 
* chained: multiple imputation method for arbitrarily missing variables of mixed types
* pmm: 	predictive mean matching: imputation method to fill missings of continuous variables
		//	(not all imputed vars here continuous, still right? for binary: logit)
		//	(its possible to do the following: mi imp chained (reg) bmi age (logit) smokes for binary vars
		// 	try; only pmm saved in impu_milu.dta, pmm and logit saved in impu_milu2.dta 
		//	->> with logit: convergence not achieved, so use only-pmm-model
		//	pmm preferable to regress method when normality of underlying model suspect
		//	normal linear regression yields normal linear predictions, from which 
		// 	distance to nearest observed neighbors is calculated; from closest # value is randomly drwan
		//	pmm thus preserves distribution of observed values (thus preserves also binarity)
* knn(#): specifies the # of closest observations (nearest neighbors) from which to draw
        //	imputed values.  Closeness is determined based on the absolute difference between 
		// 	the linear prediction for the missing value and that for the complete values.  
* add(#): specify # of imputations to add; required when no imputations exist
* augment: perform augmented regression in the presence of perfect prediction for all categorical imputation variables
* burnin(#): specify number of iterations for the burn-in period 
		//   = # of iterations until convergence to stationary distribution

if $logit==0 {
	ds cid hid pid sample1 _mi_miss, not  //stores all variables except those mentioned in local `r(varlist)'; (MO17: in previous years, all variables in dataset except cid and hid were registered)
	mi impute chained (pmm, knn($noknn))  `r(varlist)', ///
	add(5) showiter(1) augment burnin($noburnin) rseed(6525413) force dots noisily nomonotone	 
	}
	
if $logit==1 {
	qui ds cid hid pid sample1 _mi_miss, not //stores all variables except those mentioned in local `r(varlist)'
	ds `r(varlist)', has(type byte) // stores all byte variables in local `r(varlist)'
	global bytel `r(varlist)' // stores all byte variables in global list $bytel

	qui ds cid hid pid sample1 _mi_miss, not //stores all variables except those mentioned in local `r(varlist)'
	ds `r(varlist)', has(type double) // stores all continuous variables in local `r(varlist)'
	global contl `r(varlist)' // stores all continuous variables in global list $contl

	mi impute chained (pmm, knn($noknn)) $contl (logit) $bytel, ///
	add(5) showiter(1) augment burnin($noburnin) rseed(6525413) force dots noisily nomonotone
	// MO17: error occured during imputation on m=1 for burnin=10 and burnin=50; seems not to work. great.
	}
	
* Examine your imputations to verify that nothing abnormal occurred during imputation. 

* Compare main descriptive statistics of some imputations to observed data 
mi xeq 0 1 5: summarize $dataset //summarizes original data (m = 0), the first (m = 1) and last imputation (m = 5) after burnin period
*pglabgro
*2017: 	mean: 2816 - 2813 - 2821 -> pretty close
*		std dev: 2161 - 2136 - 2147 -> std deviation does not change much 
*pglabnet
*2017: 	mean: 1856 - 1858 - 1863 -> slightly overestimated
*		std dev: 1286 - 1289 - 1304 -> std deviation does not change much 
								
* Check the significance of original variables $varl by a simple regression:
reg $dataset	$varl
*pglabgro
*2017: not all vars have a P(>|t|) < 0.05, for example plh0187__4 plg0079__4, many more    
*pglabnet
*2017: not all vars have a P(>|t|) < 0.05, for example pgef7__4 plb0049__8, many more    

if "${dataset}"==("pglabgro") {
	*Density plots of only the imputed personal incomes
	generate lg1=_1_$dataset if $dataset==.
	generate lg2=_2_$dataset if $dataset==.
	generate lg3=_3_$dataset if $dataset==.
	generate lg4=_4_$dataset if $dataset==.
	generate lg5=_5_$dataset if $dataset==.
	*midiagplots is a forthcoming user-written command
	*midiagplots age, m(1/5) combine
	twoway kdensity lg1 || kdensity lg2 || kdensity lg3 || kdensity lg4 || kdensity lg5 || kdensity $dataset
}
if "${dataset}"==("pglabnet") {
	*Density plots of only the imputed personal incomes
	generate ln1=_1_$dataset if $dataset==.
	generate ln2=_2_$dataset if $dataset==.
	generate ln3=_3_$dataset if $dataset==.
	generate ln4=_4_$dataset if $dataset==.
	generate ln5=_5_$dataset if $dataset==.
	*midiagplots is a forthcoming user-written command
	*midiagplots age, m(1/5) combine
	twoway kdensity ln1 || kdensity ln2 || kdensity ln3 || kdensity ln4 || kdensity ln5 || kdensity $dataset
}

*2017: in mi exq and plot same observations for knn=5 and knn=10
if $stone==0 & $suppl==0 graph save Graph "$imputation\ImpGraphs\\${dataset}_knn${noknn}.gph", replace
if $stone==0 & $suppl==1 graph save Graph "$imputation\ImpGraphs\\${dataset}_knn${noknn}_suppl.gph", replace
if $stone==1 & $suppl==0 graph save Graph "/soep/drichter/homes/Imputation/${dataset}_knn${noknn}.gph", replace
if $stone==1 & $suppl==1 graph save Graph "/soep/drichter/homes/Imputation/${dataset}_knn${noknn}_suppl.gph", replace

if "${dataset}"==("pglabgro") {
	correlate lg1 lg2 lg3 lg4 lg5
}   
*2017: knn=5:  > 0.69  ---  pretty good! (burnin=50)
/*
             |      lg1      lg2      lg3      lg4      lg5
-------------+---------------------------------------------
         lg1 |   1.0000
         lg2 |   0.6951   1.0000
         lg3 |   0.7515   0.7816   1.0000
         lg4 |   0.6887   0.7465   0.7790   1.0000
         lg5 |   0.7551   0.7738   0.7816   0.7357   1.0000
*/


*2017: knn=10: corr(lg(i),lg(i-1)) > 0.71  ---  good! (burnin=50)
/*
             |      lg1      lg2      lg3      lg4      lg5
-------------+---------------------------------------------
         lg1 |   1.0000
         lg2 |   0.7811   1.0000
         lg3 |   0.7531   0.7484   1.0000
         lg4 |   0.7590   0.7590   0.7102   1.0000
         lg5 |   0.7765   0.7867   0.7157   0.7513   1.0000
*/

*2017: knn=10: corr(lg(i),lg(i-1)) > 0.71  ---  pretty good! (burnin=10) -- using CRUNCH
/*
             |      lg1      lg2      lg3      lg4      lg5
-------------+---------------------------------------------
         lg1 |   1.0000
         lg2 |   0.7294   1.0000
         lg3 |   0.7426   0.7269   1.0000
         lg4 |   0.7327   0.7262   0.7102   1.0000
         lg5 |   0.7171   0.7656   0.7271   0.7239   1.0000
*/

*2017: knn=10: corr(lg(i),lg(i-1)) > 0.70  ---  pretty good! (burnin=1000) -- using CRUNCH
/*
             |      lg1      lg2      lg3      lg4      lg5
-------------+---------------------------------------------
         lg1 |   1.0000
         lg2 |   0.7032   1.0000
         lg3 |   0.7177   0.7182   1.0000
         lg4 |   0.7501   0.7392   0.7449   1.0000
         lg5 |   0.8079   0.7279   0.7540   0.7514   1.0000
*/


if "${dataset}"==("pglabnet") {
	correlate ln1 ln2 ln3 ln4 ln5
}   
*2017: knn=5: > 0.69  ---  pretty good (burnin=50)
/*
             |      ln1      ln2      ln3      ln4      ln5
-------------+---------------------------------------------
         ln1 |   1.0000
         ln2 |   0.7966   1.0000
         ln3 |   0.7463   0.7813   1.0000
         ln4 |   0.7220   0.7553   0.6930   1.0000
         ln5 |   0.7256   0.7773   0.6936   0.7789   1.0000
*/


*2017: knn=10: corr(lg(i),lg(i-1)) > 0.76  ---  good (burnin=50)
/*
             |      ln1      ln2      ln3      ln4      ln5
-------------+---------------------------------------------
         ln1 |   1.0000
         ln2 |   0.7563   1.0000
         ln3 |   0.7764   0.7625   1.0000
         ln4 |   0.7076   0.7247   0.7591   1.0000
         ln5 |   0.7630   0.8102   0.8412   0.8154   1.0000
*/

*2017: knn=10: corr(lg(i),lg(i-1)) > 0.66  ---  okay! (burnin=10) (local)
/*
             |      ln1      ln2      ln3      ln4      ln5
-------------+---------------------------------------------
         ln1 |   1.0000
         ln2 |   0.6578   1.0000
         ln3 |   0.7164   0.7401   1.0000
         ln4 |   0.7868   0.7487   0.7980   1.0000
         ln5 |   0.7383   0.7141   0.7875   0.7716   1.0000
*/

if $stone==0 & $suppl==0 save "$imputation\finaldata/p_imputation_final_${dataset}_knn${noknn}.dta", replace
if $stone==0 & $suppl==1 save "$imputation\finaldata/p_imputation_final_${dataset}_knn${noknn}_suppl.dta", replace
if $stone==1 & $suppl==0 save "/soep/drichter/homes/Imputation/p_imputation_final_${dataset}_knn${noknn}.dta", replace
if $stone==1 & $suppl==1 save "/soep/drichter/homes/Imputation/p_imputation_final_${dataset}_knn${noknn}_suppl.dta", replace


*###########################################
* II.) Append final datasets (EIS1S2S3S4 & !name of new sample!) 
*###########################################

* !only execute the following code if you have successfully executed the code above once for $suppl==0 (and $suppl==1, if there is a supplementary sample this year)

/* !only execute this code chunck (now commented out) if there is a supplementary sample in the current year
if $stone==0 {
	use "$imputation\finaldata/p_imputation_final_${dataset}_knn${noknn}.dta", clear
	append using "$imputation\finaldata/p_imputation_final_${dataset}_knn${noknn}_suppl.dta"
	}
if $stone==1 {
	use "/soep/drichter/homes/Imputation/p_imputation_final_${dataset}_knn${noknn}.dta", clear
	append using "/soep/drichter/homes/Imputation/p_imputation_final_${dataset}_knn${noknn}_suppl.dta"
	}*/
keep cid hid pid $dataset _1_$dataset _2_$dataset _3_$dataset _4_$dataset _5_$dataset

*gen _mi_miss = 0
*mi extract 0, clear // necessary to prevent errors in subsequent code execution

if "${dataset}"==("pglabgro") {									
	*Density plots of only the imputed $datasets
	generate lg1=_1_$dataset if $dataset==.
	generate lg2=_2_$dataset if $dataset==.
	generate lg3=_3_$dataset if $dataset==.
	generate lg4=_4_$dataset if $dataset==.
	generate lg5=_5_$dataset if $dataset==.

	twoway kdensity lg1 || kdensity lg2 || kdensity lg3 || kdensity lg4 || kdensity lg5 || kdensity $dataset

	correlate lg1 lg2 lg3 lg4 lg5
}
if "${dataset}"==("pglabnet") {									
	*Density plots of only the imputed $datasets
	generate ln1=_1_$dataset if $dataset==.
	generate ln2=_2_$dataset if $dataset==.
	generate ln3=_3_$dataset if $dataset==.
	generate ln4=_4_$dataset if $dataset==.
	generate ln5=_5_$dataset if $dataset==.

	twoway kdensity ln1 || kdensity ln2 || kdensity ln3 || kdensity ln4 || kdensity ln5 || kdensity $dataset

	correlate ln1 ln2 ln3 ln4 ln5
}
if $stone==0 save  "$imputation\finaldata/p_imputation_final_${dataset}_merged_knn${noknn}.dta", replace
if $stone==1 save "/soep/drichter/homes/Imputation/p_imputation_final_${dataset}_merged_knn${noknn}.dta", replace

capture log close
