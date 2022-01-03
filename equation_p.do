*********************************************************************
*								
* Imputation 2017
*
* 1. Prepare the dataset (dataset.do)
* 2. Specify the equation for imputation (equation.do)
* 3. Imputation (imputation.do)
** 4. Tests
*		(imputation_crossval.do)
*		(imputation_ksmirnov.do)
*********************************************************************

**MO: 	set the following variables in order to obtain the desired dataset
global 	thisyear 	"17"		// set this variable to the year of the dataset, e.g. "18"
global 	lastyear	"16"		// set this variable to the previous year, e.g. "17"
global 	thiswave 	"9"			// set this variable to the number of the actual Welle, e.g. "10"
global	suppl		0			// set to 0 to impute old samples 
								//	   to 1 to impute supplementary samples (only in some waves there are supplementary samples!)   
											*MK17: In the current state, this script does not use $suppl to change the generation according to the status of the sample (new supplementary or not).
global	dataset 	"pglabgro"	// set to "pglabgro" or "pglabnet" to generate respective datasets below				

**MO: 	in the following script, the paths stay as they are for every year- 
*		changes are made automatically through the variables defined above

clear
set matsize 11000
set more off
qui do "H:\git\isdatadoku\pathways.do"  							// this line must stay BEHIND def of the 4 globals above

capture log close  													// closes potentially existing open log files
log using "$imputation\helpdata\equation_p_${dataset}.log", replace // opens a log file and stores all commands and results in it; overwritten every time the script is executed

*Merge datasets from dataset_h and dataset_p
use "$imputation\helpdata\p_working_3.dta", clear
keep if syear==20${thisyear}
merge 1:1 pid using "$imputation\helpdata\p_rohdaten.dta"
drop _merge

*Delete persons who are "nicht erwerbstaetig" 
keep if plb0022!=9 

d inno* 															// codebook inno*
 
*Set different types of missing answers to .
*and delete string variables as well as variables where all obs have same value // with all missings
ds, has(type string) 												// stores all string variables in local `r(varlist)'
drop `r(varlist)'													// drops all string variables
d																	// stores no. of obs in local `r(N)'
global noobs `r(N)'													// stores no. of obs in global $noobs
ds																	// stores all variable names in `r(varlist)'
foreach var in `r(varlist)' {
	recode `var' (-1=.) (-3=.) (-5=.) (-8=.) 
	distinct `var', miss 											// stores the number of different value categories in local `r(ndistinct)' where
	if `r(ndistinct)'==1 drop `var'									// missings are a category; thus, if a variable has only values 1 and ., `r(ndistinct)' is set to 2. 
	}
save "$imputation\helpdata\p_working_equation_new.dta", replace

*Prepare income from last year (the non-imputed income) -> past income is the best predictor of current income
use "$imputation\helpdata\p_working_3.dta", clear
keep if syear==20$lastyear
keep pglabgro pglabnet pid
rename pglabgro pglabgro20$lastyear
rename pglabnet pglabnet20$lastyear

*Merge dataset of last year with the one of this year
merge 1:1 pid using "$imputation\helpdata\p_working_equation_new.dta"
drop if _merge==1  
drop _merge
save "$imputation\helpdata\p_working_equation.dta", replace

*Handle -2 Values & Generate some variables
use "$imputation\helpdata\p_working_equation.dta", clear
drop if plb0022==6 | plb0022==7
recode pglabgro (-2=.) if plb0022==5
recode pglabnet (-2=.) 
recode pglabgro20$lastyear pglabnet20$lastyear (-3=.) (-2=.) (-1=.)
recode pgbetr (-2=0) (11=0) (6=4) (7=5) (9=6) (10=7)
recode pgallbet (5=0) (-2=0)

global dlist 						//MK17: Ist dieser Abschnitt noch nötig?
qui ds
foreach var in `r(varlist)' { 
	qui count if `var'==-2
	if `r(N)'>0 global dlist $dlist `var'
}
*MO???: warum werden hier nur folgende Variablen von -2 auf . gesetzt?
foreach var in plh0173 plb0176 plb0186 plb0216 plb0217 plb0218 plb0219 pgvebzt plh0161 {
	recode `var' (-2=.) 
} 

*tab pnat, gen (pnat_) //MO: diese Zeile sollte man mal ausprobieren wenn Zeit ist, bzw mit gruppierten Ländern. 
drop pnat

* Generate Altersvariable
gen alter=20${thisyear}-geburt
tab alter,m

* Generate Arbeitsjahre-Variable
capture drop arbjahre
gen arbjahre=plb0036 
replace arbjahre=20${lastyear}-plb0036 if plb0036>0
tab arbjahre, m

*save "S:\DATA2\SOEP-IS\SOEP-IS 2015 Generierung HiWi\Imputation\helpdata\p_working_equation_1_1.dta", replace
saveold "$imputation\helpdata\p_working_equation_1_1_old.dta", replace

****************************************************************************************************************
**************** Erste Variablen-Vorselektion & Dummy-Encodierung der Kategorien ********************************
****************************************************************************************************************
use "$imputation\helpdata\p_working_equation_1_1_old.dta", clear // 341 vars
*MO!!! es ist absolut nicht klar, wieso 2016 irgendwo in diesen Gruppenschritten alle 
*		Innovariablen verschwinden. Ich denke nicht, dass man sie pauschal einfach
* 		löschen kann, weiß aber auch nicht, welche ich wirklich rausnehmen kann. 
* 		Daher nehm ich weiter unten bei *hier* erstmal die raus, die wahrscheinlich
*		kein Indikator fürs Einkommen sind. Sonst werden im Laufe des Skripts zu viele 
* 		Variablen generiert und es gibt ein Problem

********** Group 1 Drop unnecessary variables (nach welchem Kriterium "unnecessary"? sollte das nicht der hierauf folgende Algorithmus entscheiden?
*MO: the following variables should not influence income of individuals
* a) including "organisational" Information (e.g. syear, lint, pform...)
* b) including only months
* c) including information regarding unemployment
drop auszugj	auszugm	befstat	bio	hlk0005	iyear	paderq	pergz	pform pgmonth ///
	pla0013	pla0014	plb0035	plb0298	plc0130	plc0131	pld0039	pld0040	pld0135	pld0136	///
	pld0139	pld0141	pld0142	pld0144	pld0145	pld0150	pld0151	pld0154	pld0156	pld0158	pld0161	pld0162	pld0164	pld0170		///
	plg0074		plk0001	pmonin	ptagin	stistat einzugm	geburt	intid	pergz pergzv	pgpartnr	plb0032	///
	plb0033		pld0138	pld0147	pld0148	pld0153	pld0165	pld0167	pld0168	pld0171		plg0073			///
	pnrold	varpgeb varpvor	zupan  pdatst pdatmi plb0299 
d
tab1 migback_* sampreg17_*
* Drop Variable A:
* a) w/ insufficient observations for cases with missing income (pglabgro = variable B)
* 		-> MO???: wie groß muss mind-Anzahl / Anteil sein, damit insufficient?
*		-> ich nehme an, dass das nur ein Problem ist, falls die missing rate von A
*			für B==. deutlich größer ist als für B!=. (nicht-Beantwortung nicht-random) 
*		-> daher Loop eingebaut, der Variablen A in einer Liste speichert, bei denen 
*			folgende 2 Punkte erfüllt sind 
*						- Missingrate für B==. um mind 20% höher ist als bei B!=.
*						- Missingrate für B==. > 30%
*			(das sind willkürlich gewählte Grenzen, erstmal Probedurchlauf damit)
*			nur für pglabgro überprüft, da Missings von pglabgro und pglabnet stark korrelieren

gen ${dataset}_dum=1						//MK17: I changed this to either refer to pglabgro or pglabnet (according to the global defined at the start).
replace ${dataset}_dum=0  if ${dataset}==.

global checkvars
ds ${dataset}, not
foreach var in `r(varlist)' {
qui mdesc `var' if ${dataset}_dum==0 
if `r(percent)'>30 {
	global misper `r(percent)'
	qui mdesc `var' if ${dataset}_dum==1 
	if $misper/`r(percent)'>1.2 {
		dis "`var' miss. percent: $misper , nomiss. percent: `r(percent)' , rate: `=$misper/`r(percent)''"
		global checkvars $checkvars `var'
		}
}
}
d $checkvars
mdesc $checkvars if ${dataset}_dum==0

if $dataset==pglabgro drop plc0013   // Rest wird trotz möglichen not-MAR Problems erstmal drin gelassen
if $dataset==pglabnet drop plc0014   // Rest wird trotz möglichen not-MAR Problems erstmal drin gelassen

save "$imputation\helpdata\p_working_equation_group1.dta", replace

********** Group 2: Recode values from -2 to 0: vars only with 1 category or a sum or percentage, in euro, hours, percent...
use "$imputation\helpdata\p_working_equation_group1.dta", clear //MK17: Corrected this from "...group2.dta".
global helplist 		// create empty list which the following loop will fill with variables that might contain Beträge z.B. in Euro and which are to be checked later
global group2varlist 	// create empty list of group 2 variables
ds cid hid sample1, not // stores all variables except those mentioned in local `r(varlist)'
/*foreach var in `r(varlist)' {
qui mdesc `var'
if `r(percent)' > 50 dis "`var'"
}*/
foreach var in `r(varlist)' {
	count if `var'==-2 	// stores frequency of var label -2 into `r(N)'
	if `r(N)'>0 { 		// this if-bracket is executed only if var has -2 value at least once
		* if following command "distinct" not known, type "help distinct" and click on respective package -> install
		distinct `var' 	// stores number of distinct categories in local `r(ndistinct)'
		if `r(ndistinct)'==2 global group2varlist $group2varlist `var' 	// adds all variables with only 1 category to global $group2varlist
		if `r(ndistinct)'> 2 global helplist $helplist `var' 			// fill helplist to later check only variables w/ at least once exhibit value of -2
	}
}
* every year: check if some variables in helplist (they all at least once exhibit value -2)
* should be in group2list:  variables like sums or other value/ income variables in euro 
* are to be added to group2list after the tab-check
d $helplist 
tab1 pek241 plc0233 plc0274 plc0153 plc0168 plc0201 plc0184 plc0203 pvbrstd2 ///							//MK17: not sure where this list comes from!
pnebbr pgsndjob innoW9pt4_2 innoW9pspa02 innoW9isp3 innoW9fe01a innoW9fe02a innoW9fe04a innoW9fe03a /// 
paz11a innoW9pt3a_3 innoW9pt3b_3 innoW9pt4_1 innoW9pspa01 innoW9irm22 innoW9ifkr08 ///
innoW9ifkr* innoW9im012 innoW9im21 innoW9im24 innoW9im27 innoW9im142- innoW9im144 ///
innoW9xx1a1-innoW9xx2a1 innoW9xx4a1-innoW9xx2b1 innoW9xx4b1- innoW9xx4b3 innoW9fe01a-innoW9fe03a ///
pgisei08 pgmps88 pgsiops08 //MK17: added these prestige scores

* add variables from helplist which should be in group2list
global group2varlist $group2varlist  pek241 plc0233 plc0274 plc0153 plc0168 plc0201 ///
plc0184 plc0203 pvbrstd2 pnebbr pgsndjob innoW9pt4_2 innoW9pspa02 innoW9isp3 ///
innoW9irm22  innoW9ifkr06a innoW9ifkr09 innoW9ifkr11 innoW9ifkr13 innoW9ifkr15 ///
innoW9ifkr18 innoW9ifkr18b innoW9ifkr20  innoW9xx1a1-innoW9xx2a1 innoW9xx4a1-innoW9xx2b1 ///
innoW9xx4b1 innoW9xx4b2 innoW9xx4b3 innoW9fe01a innoW9fe02a innoW9fe03a innoW9fe04a ///
pgtatzt pgvebzt pguebstd  pgbilzt pgerwzt

/* 2017: following vars had to be added to $group2list after the loop: 
pek241 plc0233 plc0274 plc0153 plc0168 plc0201 ///
plc0184 plc0203 pvbrstd2 pnebbr pgsndjob innoW9pt4_2 innoW9pspa02 innoW9isp3 ///
innoW9irm22  innoW9ifkr06a innoW9ifkr09 innoW9ifkr11 innoW9ifkr13 innoW9ifkr15 ///
innoW9ifkr18 innoW9ifkr18b innoW9ifkr20  innoW9xx1a1-innoW9xx2a1 innoW9xx4a1-innoW9xx2b1 ///
innoW9xx4b1- innoW9xx4b3 innoW9fe01a innoW9fe02a innoW9fe03a innoW9fe04a */

foreach var in $group2varlist { 
	recode `var' (-2=0) 
}

* MO: these vars are metric variables, partly they are sum variables, but 
* replacement of -2 by 0 inadequate as these are really missing values
ds pld0047 plh0138 plh0140 plb0176 plb0186 pli0059 pli0060 ///
ple0072 innoW9pt3a_2 innoW9pt3b_2 innoW9isp4 innoW9spo1 innoW9spo21 innoW9spo22 ///
innoW9spo23 innoW9spo24 innoW9spo12 innoW9spo131  innoW9iap01a innoW9iap01b ///
innoW9iap01c  innoW9paz08 innoW9iap02b innoW9paz10 innoW9iap03b innoW9iap07 ///
innoW9iap07b innoW9iap08a innoW9iap08b innoW9iap08c innoW9iap08d1 innoW9iap08e1 ///
innoW9iap08f1 -innoW9iap08f1 innoW9ifkr06 innoW9ifkr15-innoW9ifkr18  ///
innoW9ifkr20-innoW9ifkr23 innoW9ibmi1 innoW9ibmi2 innoW9iigew innoW9iegew ///
innoW9im09 innoW9im10 innoW9im19 innoW9im20 innoW9im12 innoW9im13 innoW9im22 ///
innoW9im25 innoW9im26 innoW9im28  innoW9im29 innoW9im03 innoW9im04 innoW9im31 ///
innoW9im32 innoW9im06 innoW9im07 innoW9im141 - innoW9im144 innoW9pchange~l ///
innoW9pchange~t innoW9missing~r innoW9missing~e innoW9fe02bund innoW9fe02dax ///
alter arbjahre innoW9ire03a- innoW9ire06b innoW9fej1 innoW9fej2 innoW9ire02 innoW9ire01 ///
innoW9iap01d1 innoW9iap01e1 innoW9ibge2a innoW9ibge2b innoW9irm19 plb0036 ple0046 ///
pgisei08 pgmps88 pgsiops08 //MK17: added these prestige scores
global metricvars `r(varlist)'
foreach var in $metricvars { 
	recode `var' (-2=.) 
}
//MK17: removed plc0013/plc0014 from list above because I changed the procedure deciding whether they are dropped
global varnr cond("${dataset}"==("pglabgro"),14,13) // returns 14 if dataset is pglabgro
recode plc00$varnr (-2=.)
global metricvars $metricvars plc00$varnr 			// adding it back to the global

* MO!!! droppe *hier* alle wsl irrelevanten Variablen:
d `r(varlist)'
drop innoW9pt7_11_1-innoW9pt7_53_5 	// Vertraute Personen 1-5 diverse Fragen
drop innoW9p1pera- innoW9p5pere		// Vertraute Personen 1-5 diverse Fragen
drop innoW9si01-innoW9ispra08a12 	//Dialekt sprechen und Meinung zu Dialekten
drop innoW9spo41a-innoW9spo7b  		// Sportart A und B Häufigkeit
drop innoW9Infonr 					// Info Nr aus externer Datei
drop pgnation						// da pnat vorher ebenso gedroppt
save "$imputation\helpdata\p_working_equation_group2.dta", replace

******* Group 3: more categories: Var. with a -2 value, create dummies and drop the -2 dummy
******* & Group 4: more categories: Var. without a -2 value, create dummies and keep them all
use "$imputation\helpdata\p_working_equation_group2.dta", clear
/*global many
ds $group2varlist $metricvars  pid cid hid sample1 pglabgro2016 pglabnet2016 pglabgro pglabnet, not // stores all variables except those mentioned in local `r(varlist)'
foreach var in `r(varlist)' {
	qui distinct `var'
	if `r(ndistinct)'> 10 global many $many `var'
	}
d $many*/

*MK17: there are still variables in the global $group2varlist that have already been dropped above!
local oldgroup2 $group2varlist
dis "`oldgroup2'"
local except "innoW9pnoa innoW9pnob innoW9pnoc innoW9pnod innoW9pt7_22_4 innoW9pt7_42_4 innoW9pt7_22_5 innoW9pt7_42_5 innoW9ispra051 innoW9ispra052 innoW9ispra053 innoW9ispra054 innoW9ispra055 innoW9ispra056"
global group2varlist: list oldgroup2 - except //removes those variables from the global that are not found below in the ds command

global group3varlist 
ds $group2varlist $metricvars  pid cid hid sample1 pglabgro2016 pglabnet2016 pglabgro pglabnet, not // stores all variables except those mentioned in local `r(varlist)'
foreach var in `r(varlist)' {
	qui count if `var'==-2 	// stores frequency of var label -2 into `r(N)'
	global co `r(N)'
	qui distinct `var'
	if $co>0 & `r(ndistinct)'>2 global group3varlist $group3varlist `var'
}
global group4varlist 
ds $group2varlist $group3varlist $metricvars pid cid hid sample1 pglabgro2016 pglabnet2016 pglabgro pglabnet, not // stores all variables except those in group2varlist in a local variable `r(varlist)'
foreach var in `r(varlist)' {  
	count if `var'==-2  // stores the number counted in local variable `r(N)'
	global co `r(N)'
	qui distinct `var'
	dis "$co"
	if $co==0 & `r(ndistinct)'>2 global group4varlist $group4varlist `var'
}


ds $group3varlist	
foreach var in `r(varlist)' {
	dis "`var'"
	qui tab `var' , gen (`var'__)
	qui drop `var'  `var'__1
}
ds $group4varlist
foreach var in `r(varlist)' {    // if variable does not have category -2, the following two lines are executed
	qui tab `var', gen (`var'__)
	qui drop `var'
	/*qui ds `var'_*
	foreach varr in `r(varlist)' {
		qui count if `varr'==1
		if `r(N)'<10 drop `varr'
	}*/
}

save "$imputation\helpdata\p_working_equation_2_stata.dta", replace
*******************************************************************************
**** Ab hier fuer alle 4 Kombinationen aus suppl={0,1} und dataset={"pglabgro","pglabnet"}!			//MK17: Momentan händelt das do-file noch nicht die suppl={0,1} Unterschiede. Wenn in zukünftiger Welle ein neues Aufwuchssample dazukommt, muss dieser Part erweitert werden!
**** definiere die globals am Anfang des Skripts entsprechend 
*-------------------------------------------------------------------------------------------------------------
* Jetzt werden einzelne equation Datensaetze mit den jeweiligen sign. Variablen erstellt 
* fuer supplementary (falls vorhanden) und old Sample und fuer labgro bzw. labnet.
* Wir erstellen also insgesamt 4 Datensaetze.
*-------------------------------------------------------------------------------------------------------------
*2014
* 1. LABGRO S3
* 2. LABNET S3
* 3. LABGRO EIS1
* 4. LABNET EIS1

*2015
* No new samples
* 1. LABGRO all
* 2. LABNET all

*2016
* 1. LABGRO new Sample
* 2. LABNET new Sample
* 3. LABGRO old Samples
* 4. LABNET old Samples

use "$imputation\helpdata\p_working_equation_2_stata.dta", clear

*Choose old samples (only if there is supplementary sample)
*drop if inlist(sample1,32)
order cid hid pid $dataset

*Delete variable where all obsv. are systemmissing
ds cid hid pid $dataset, not 
foreach var in `r(varlist)' {
	mdesc `var' 		// stores percentage of missings in local `r(percent)'
	if `r(percent)'==100 drop `var'
}

*736 Var.

*Regress all variables on pglabgro/pglabnet
ds cid hid pid $dataset, not 
foreach var in `r(varlist)' {
	regress $dataset `var'
	local z = _b["`var'"]/_se["`var'"]
	gen sig`var'= 2*(1-normal(abs(`z')))
	if sig`var'>0.10 drop `var' 
	drop sig`var'
}
*395 Var.
*2017: 1364 Var., weil bei mir die Inno-Variablen drin gelassen wurden
*recode pgsiops (-2=.)
save "$imputation\helpdata\help1.dta", replace

use "$imputation\helpdata\help1.dta", clear
*Drop variable with between term collinearity
ds cid hid pid $dataset pglabgro20$lastyear pglabnet20$lastyear, not //MK17: I changed $dataset to "$dataset pglabgro20$lastyear pglabnet20$lastyear". These should not be excluded in equation_p.do (for theoretical reasons).
foreach var in `r(varlist)' {
qui mdesc `var'
if `r(percent)'>10 drop `var' // willkürliche Grenze, um _rmcoll zu ermöglichen
}

ds cid hid pid $dataset, not 
_rmcoll `r(varlist)'
dis "`r(varlist)'" //collinear vars are marked by an o. at beginning of their names
global keeplist //creates empty global $keeplist, which will be filled with variable names in the following loop
foreach var in `r(varlist)' { // drop collinear vars
	if substr("`var'",1,2)!="o." global keeplist $keeplist `var' //extends the keeplist by the variable if it begins with "o."
	}
keep $keeplist cid hid pid $dataset pglabgro20$lastyear pglabnet20$lastyear //MK17: changed $dataset to "$dataset pglabgro20$lastyear pglabnet20$lastyear".

ds
foreach var in `r(varlist)' {
qui mdesc `var'
if `r(percent)' > 10 dis "`var'"
}
*Stepwise regress $dataset on all variables
*2016 , 432 vars
*2017:  586
ds cid hid pid $dataset sample1, not
global finalvars "`r(varlist)'" //MK17: I added this step because using `r(varlist)' directly in regress command produces error message "invalid observation number"

stepwise, pr(.1): regress $dataset $finalvars // removes all insignificant vars (for alpha=0.1) automatically and stores names and coefficients of significant vars in local `e(b)'
matrix b=e(b) // stores e(b) as matrix (colnames= variable names; entries: coefficients)
matrix a=b[1,1..`= colsof(b)-1'] // in a, variable names in `e(b)' are stored, but without _cons (which is always the last entry, which is omitted by extracting a matrix subset of up to the `=colsof(b)-1'-st column)
global signvarlist: colnames a //stores names of significant variables in global $signvarlist  //MK17: includes pglabgro & pglabnet from previous wave now!

ds cid hid pid $dataset sample1 $signvarlist 
keep `r(varlist)'

*2016, 286 vars
*2017, 132 vars

*MK17: For theoretical reasons, I want pglabgro pglabgro20$lastyear pglabnet pglabnet20$lastyear to all be included in each final dataset. These will be used in imputation_p.do regardless of their association with $dataset.
*	   (both were kicked out in a previous version of the script)
save "$imputation\helpdata\p_working_imputation_${dataset}.dta", replace

*MK17: save new supplementary dataset as:
*save "$imputation\helpdata\p_working_imputation_${dataset}_suppl.dta", replace

log close

