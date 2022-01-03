*********************************************************************
*		Zuletzt bearbeitet am 	19.12.17					
* Imputation 2017
*
* 1. Prepare the dataset (dataset.do)
* 2. Specify the equation for imputation (equation.do)
* 3. Imputation (imputation.do)
* 4. Tests (imputation_crossval.do) //MO: other script mentioned here (imputation_ksmirnov.do) contains only code which was also in imputation_crossval.do; thus omitted 
*		
*********************************************************************
***MO: 	set the following variables in order to obtain the desired dataset
global 	thisyear 	"18"	// set this global to the actual year, e.g. "18"
global 	lastyear	"17"	// set this global to the previous year, e.g. "17"
global 	thiswave 	"10"	// set this global to the number of the actual Welle, e.g. "10"
global 	bip			1		// set this global to 1 if BIP dataset delivered this year
global 	aufwuchs	0		// set this global to 1 if Aufwuchs dataset delivered this year
***MO: these are auxiliary variables which shall NOT be changed
global 	DEEN 		"\DE"	// in imputation only a german dataset is to be generated  

***MO: 	in the following script, the paths stay as they are for every year- 
*		changes are made automatically through the variables defined above
clear 
set more off
qui do "H:\git\isdatadoku\pathways.do"  // this line must stay BEHIND def of the 4 globals above

cap mkdir "$imputation" 			// creates folder if doesnt exist
cap mkdir "$imputation\helpdata" 	// creates folder if doesnt exist

*STEP 1: use people's dataset to create household information
*Therefore use plong, pgen, pbrutto --> later merged into people_data_working.dta 

*p_long
use "$is${DEEN}\p.dta", clear
keep if inlist(syear,real("20${lastyear}"),real("20${thisyear}"))
save "$imputation\helpdata\p_l_help.dta", replace
*2018: 11,812 Obs, 1,538 Var

*pgen
use "$is${DEEN}\pgen.dta", clear
keep if inlist(syear,real("20${lastyear}"),real("20${thisyear}"))
save "$imputation\helpdata\pgen_l_help.dta", replace
*2018: 11,812 Obs, 77 Var

*pbrutto
use "$is${DEEN}\pbrutto.dta", clear
keep if inlist(syear,real("20${lastyear}"),real("20${thisyear}"))
save "$imputation\helpdata\pbrutto_l_help.dta", replace
*2014: 19.164 obs - 40 vars // 1 extra? --> anker; irrelevant
*2016: 22.187 Obs - 50 Vars //varpgeb varpnat1 varpvor experiment pfamcode apperg bipperg balu_id...nicht relevant


* STEP 2: use Inno datasets:
** MO18 TODO: - sollte Stichwortsuche lieber nur/auch aufgrund von generierten Vars erfolgen?
** 			  - sind in Innomodul-Variablen nach mergen zu viele missings für Imputation? Wäre das ein Grund für kompletten Ausschluss der Innomodule??
* The following algorithm automatically extracts useful, income-related
* variables from current Inno datasets based on keyword search:
///////////////////////////////////////////////////////////////////////////////////////////////////////////////
	* FIRST, define keywords for which algorithm searches variables 
	* (search is performed in variable labels, capital letter or not does not affect search):
	global keywords "rente beförder feuer entlass wechsel job arbeit branche beruf lohn geld einkomm vermögen gehalt"

	* SECOND, get list of paths to .dta files in all Innofolders (in Rohdaten, and possibly BIP and Aufwuchs):
	global paths "" // defines empty string list, will be filled subsequently with all Inno dataset paths

		local files: dir "$ISaltesample" files "*.dta"
		foreach file in `files' {
		global paths `"$paths "$ISaltesample/`file'""'
		}

		if $bip == 1 {
			local files: dir "$BIP" files "*.dta"
			foreach file in `files' {
			global paths `"$paths "$BIP\\`file'""'
			}
			}
			
		if $aufwuchs == 1 {
			local files: dir "S:\DATA2\SOEP-IS\SOEP-IS data 20${thisyear} Aufwuchs Rohdaten\Netto" files "*.dta"
			foreach file in `files' {
			global paths `"$paths "S:\DATA2\SOEP-IS\SOEP-IS data 20${thisyear} Aufwuchs Rohdaten\Netto\\`file'""'
			}
			}
		
	foreach path in $paths { // prints out list of paths to all collected Inno datasets
	di "`path'"
	}
	
	* THIRD, for all these datasets, merge those together which are mergable automatically (if they contain pnrfest variable)
	* and check if in non-mergable datasets important variables are omitted:
	cap rm "$imputation\helpdata\merged_innos.dta" // avoids merging the same datasets multiple times if this dofile is executed more than once
	
	foreach path in $paths { 				// for all .dta files in Innofolders:
		di "`path'" 						// - print path
		use "`path'", clear					// - open dataset 
		cap confirm var pnrfest 			//   to check if var pnrfest exists in it (-> !_rc==1), 
		global contains_pnrfest !_rc
		if $contains_pnrfest==1 qui ds pnrfest, not
		if $contains_pnrfest==0 qui ds 
		foreach var in `r(varlist)'  {
			if !strpos("`path'","$BIP") rename `var' innoAW`var' 			// and rename vars for non-BIP datasets
			if strpos("`path'","$BIP")  rename `var' is${thisyear}`var' 	// and for BIP datasets
		}
		qui save "$imputation\helpdata\current.dta", replace
		* merge pnrfest-containing (!_rc==1) datasets together:
		if $contains_pnrfest==1 {							
			cap confirm file "$imputation\helpdata\merged_innos.dta" // check if "$imputation\helpdata\merged_innos.dta" already exists (new !_rc==1)
			if !_rc {
				qui use "$imputation\helpdata\merged_innos.dta", clear
				cap drop _merge
				qui merge 1:1 pnrfest using "$imputation\helpdata\current.dta", update
				}
			qui save "$imputation\helpdata\merged_innos.dta", replace
			}
		* for the datasets which are not merged (_rc==1), following lines create output
		* to check if any income-related variables are contained:
		if $contains_pnrfest==0 lookfor $keywords // TODO EVERY YEAR: check output if important vars missed:
		/* 2018: 
		//hume/soep-data/DATA2/SOEP-IS/SOEP-IS data 2018 W10 Rohdaten/Netto/inno18f_hh.dta

              storage   display    value
variable name   type    format     label      variable label
-----------------------------------------------------------------------------------------------------------
innoAWhdkg1     double  %10.0g     hdkg1      Kindergeld heute
innoAWhdkg2     double  %10.0g                � Kindergeld heute/Monat
innoAWhdkg3     double  %10.0g                Anzahl Kinder Kindergeld
innoAWhdkz1     double  %10.0g     hdkz1      Kindergeldzuschlag heute
innoAWhdkz2     double  %10.0g                � Kindergeldzuschlag heute/Monat
innoAWhdag1     double  %10.0g     hdag1      Arbeitslosengeld heute
innoAWhdag2     double  %10.0g                � Arbeitslosengeld heute/Monat
innoAWhdwg1     double  %10.0g     hdwg1      Wohngeld heute
innoAWhdwg2     double  %10.0g                � Wohngeld heute/Monat
innoAWhnetto    double  %10.0g                � HH-Nettoeinkommen/Monat
innoAWznetto    double  %10.0g     znetto     Einkommensschaukel

		//hume/soep-data/DATA2/SOEP-IS/BIP 2018 Datenlieferung/Netto\h18_bip.dta

              storage   display    value
variable name   type    format     label      variable label
-----------------------------------------------------------------------------------------------------------
is18hnetto      int     %16.0f                � HH-Nettoeinkommen/Monat
is18znetto      byte    %16.0f     znetto     Einkommensschaukel
is18bipekzu     byte    %16.0f     bipekzu    Einkommen ausreichend

		*/
		}

	* FORTH, in merged dataset, print income-related variables and keep only those:
	use "$imputation\helpdata\merged_innos.dta", clear
	lookfor $keywords 			 // looks for income-related variables and saves them in local `r(varlist)'
	global keptvars `r(varlist)' // saves income-related variables in global $keptvars
	keep pnrfest $keptvars 		 // keep only pnrfest and income-related variables 

		// this auxiliary program allows for fast deletion 
		// of variables in subsequent interactive code: 
		cap program drop w
		program def w 
			drop $var
			end 
		
	***********************************************************************
	* TODO EVERY YEAR: check if some kept vars not important for income, 
	* drop those manually with following interactive code (see STATA output, self-explaining):
	pause on 
	foreach var in $keptvars {
		global var `var'
		distinct `var'
		if "`r(ndistinct)'" < "20" tab `var'
		if "`r(ndistinct)'" > "19" di `"`: var label `var''"' 
		pause "TO DROP `var': type 'w' and hit enter. FOR NEXT VARIABLE: type 'q' and hit enter. TO ABORT LOOP: type 'pause off', hit enter, and type 'q' and hit enter."
		}
	pause off
	
	rename pnrfest pid
	order pid

	save "$imputation\helpdata\p_rohdaten.dta", replace
	***********************************************************************
	ds // prints names of vars that have not been manually deleted
	/* 2018:
pid           innoAWxx4a3a  innoAWpzuf04  innoAWpaz11   innoAWpaz09   is18lab01     is18pang
innoAWisp3    innoAWxx4a3b  innoAWpzuf05  innoAWpaz11a  innoAWpaz10   is18lab02     is18pamt
innoAWisp6a   innoAWxx1b1a  innoAWpek011  innoAWl1erw   innoAWpaz15   is18lab03     is18pazubi
innoAWisp6b   innoAWxx1b1b  innoAWpek02   innoAWloed    innoAWpaz16   is18lab08ka   is18pseitm
innoAWivm09   innoAWxx1b2a  innoAWpek021  innoAWpwexl1  innoAWpaz17   is18lal10a    is18pseitj
innoAWivm10   innoAWxx1b2b  innoAWpek03   innoAWpwe~14  innoAWpaz18   is18lal10b    is18pzaf
innoAWivm11   innoAWxx1b3a  innoAWpek031  innoAWpwe~15  innoAWpbrut   is18lalo      is18pbefr1
innoAWxx1a1a  innoAWxx1b3b  innoAWpek04   innoAWpber    innoAWpnett   is18lal10c    is18psst
innoAWxx1a1b  innoAWxx2b1   innoAWpek07   innoAWpoed    innoAWlv08    is18lbesch10  is18psstanz
innoAWxx1a2a  innoAWxx3b1   innoAWpek071  innoAWpbra    is18pzuf04    is18palo      is18paz08
innoAWxx1a2b  innoAWxx3b2   innoAWpek08   innoAWpstell  is18pzuf05    is18paz11     is18paz09
innoAWxx1a3a  innoAWivt584  innoAWp7tag   innoAWparb    is18pek01     is18paz11a    is18paz10
innoAWxx1a3b  innoAWxx4b4   innoAWlab01   innoAWpang    is18pek011    is18l1erw     is18paz15
innoAWxx2a1   innoAWxx4b1   innoAWlab02   innoAWpamt    is18pek02     is18loed      is18paz16
innoAWxx3a1   innoAWxx4b1a  innoAWlab03   innoAWpazubi  is18pek021    is18pwexl1    is18paz17
innoAWxx3a2   innoAWxx4b1b  innoAWlab0~a  innoAWpseitm  is18pek03     is18pwexl14   is18paz18
innoAWivt574  innoAWxx4b2   innoAWlal10a  innoAWpseitj  is18pek031    is18pwexl15   is18pbrut
innoAWxx3a3   innoAWxx4b2a  innoAWlal10b  innoAWpzaf    is18pek04     is18pber      is18pnett
innoAWxx4a1a  innoAWxx4b2b  innoAWlalo    innoAWpbefr1  is18pek07     is18poed      is18lv08
innoAWxx4a1b  innoAWxx4b3   innoAWlal10c  innoAWpsst    is18pek071    is18pbra
innoAWxx4a2a  innoAWxx4b3a  innoAWlbe~10  innoAWpsst~z  is18pek08     is18pstell
innoAWxx4a2b  innoAWxx4b3b  innoAWpalo    innoAWpaz08   is18p7tag     is18parb
*/
	lookfor $keywords //prints vars and labels that have not been manually deleted;
	/* 2018: MO18 TODO print output here!
              storage   display    value
variable name   type    format     label      variable label
-----------------------------------------------------------------------------------------------------------------------------------------------------------
innoAWisp3      double  %10.0g                � HH-Bruttoeinkommen 2016
innoAWisp6a     double  %10.0g                Einordnung Einkommen Deutschland gesch�tzt
innoAWisp6b     double  %10.0g                Einordnung Einkommen weltweit gesch�tzt
innoAWivm09     double  %10.0g                Ideale Einkommensverteilung A: �ber welchen Anteil des gesamten Nettoeinkommens
innoAWivm10     double  %10.0g                Sch�tzung Einkommensverteilung B: �ber welchen Anteil der gesamten Nettoeinkomme
innoAWivm11     double  %10.0g                Ideale Einkommensverteilung B: �ber welchen Anteil des gesamten Nettoeinkommens
innoAWxx1a1a    double  %10.0g                VZ Wahrscheinlichkeit weniger Gehalt in einem Jahr in Prozent
innoAWxx1a1b    double  %10.0g                VZ Wahrscheinlichkeit mehr Gehalt in einem Jahr in Prozent
innoAWxx1a2a    double  %10.0g                VZ Wahrscheinlichkeit weniger Gehalt in 2 Jahren in Prozent
innoAWxx1a2b    double  %10.0g                VZ Wahrscheinlichkeit mehr Gehalt in 2 Jahren in Prozent
innoAWxx1a3a    double  %10.0g                VZ Wahrscheinlichkeit weniger Gehalt in 10 Jahren in Prozent
innoAWxx1a3b    double  %10.0g                VZ Wahrscheinlichkeit mehr Gehalt in 10 Jahren in Prozent
innoAWxx2a1     double  %10.0g                VZ Erwarteter Bruttolohn Teilzeitjob
innoAWxx3a1     double  %10.0g                VZ Wahrscheinlichkeit f�r weniger Gehalt
innoAWxx3a2     double  %10.0g                VZ Wahrscheinlichkeit f�r mehr Gehalt
innoAWivt574    double  %10.0g                Erwarteter Bruttoverdient in TZ Berechnung: Ich habe einen h�heren Stundenlohn a
innoAWxx3a3     double  %10.0g                Wahrscheinlichkeit Wechsel von Vollzeit in Teilzeit in Prozent
innoAWxx4a1a    double  %10.0g                Beibehalten TZ: Wahrscheinlichkeit f�r weniger Gehalt in einem Jahr in Prozent
innoAWxx4a1b    double  %10.0g                Beibehalten TZ: Wahrscheinlichkeit f�r mehr Gehalt in einem Jahr in Prozent
innoAWxx4a2a    double  %10.0g                Beibehalten TZ: Wahrscheinlichkeit f�r weniger Gehalt in 2 Jahren in Prozent
innoAWxx4a2b    double  %10.0g                Beibehalten TZ: Wahrscheinlichkeit f�r mehr Gehalt in 2 Jahren in Prozent
innoAWxx4a3a    double  %10.0g                Beibehalten TZ: Wahrscheinlichkeit f�r weniger Gehalt in 10 Jahren in Prozent
innoAWxx4a3b    double  %10.0g                Beibehalten TZ: Wahrscheinlichkeit f�r mehr Gehalt in 10 Jahren in Prozent
innoAWxx1b1a    double  %10.0g                TZ Wahrscheinlichkeit weniger Gehalt in einem Jahr in Prozent
innoAWxx1b1b    double  %10.0g                TZ Wahrscheinlichkeit mehr Gehalt in einem Jahr in Prozent
innoAWxx1b2a    double  %10.0g                TZ Wahrscheinlichkeit weniger Gehalt in 2 Jahren in Prozent
innoAWxx1b2b    double  %10.0g                TZ Wahrscheinlichkeit mehr Gehalt in 2 Jahren in Prozent
innoAWxx1b3a    double  %10.0g                TZ Wahrscheinlichkeit weniger Gehalt in 10 Jahren in Prozent
innoAWxx1b3b    double  %10.0g                TZ Wahrscheinlichkeit mehr Gehalt in 10 Jahren in Prozent
innoAWxx2b1     double  %10.0g                TZ Erwarteter Bruttolohn Vollzeitjob
innoAWxx3b1     double  %10.0g                TZ Wahrscheinlichkeit f�r weniger Gehalt
innoAWxx3b2     double  %10.0g                TZ Wahrscheinlichkeit f�r mehr Gehalt
innoAWivt584    double  %10.0g                Erwarteter Bruttoverdient in VZ Berechnung: Ich habe einen h�heren Stundenlohn a
innoAWxx4b4     double  %10.0g                Wahrscheinlichkeit Wechsel von Teilzeit in Vollzeit in Prozent
innoAWxx4b1     double  %10.0g                TZ Erwartetes Brutto in einem Jahr Vollzeitjob
innoAWxx4b1a    double  %10.0g                Beibehalten VZ: Wahrscheinlichkeit f�r weniger Gehalt in einem Jahr in Prozent
innoAWxx4b1b    double  %10.0g                Beibehalten VZ: Wahrscheinlichkeit f�r mehr Gehalt in einem Jahr in Prozent
innoAWxx4b2     double  %10.0g                TZ Erwartetes Brutto in 2 Jahren Vollzeitjob
innoAWxx4b2a    double  %10.0g                Beibehalten VZ: Wahrscheinlichkeit f�r weniger Gehalt in 2 Jahren in Prozent
innoAWxx4b2b    double  %10.0g                Beibehalten VZ: Wahrscheinlichkeit f�r mehr Gehalt in 2 Jahren in Prozent
innoAWxx4b3     double  %10.0g                TZ Erwartetes Brutto in 10 Jahren Vollzeitjob
innoAWxx4b3a    double  %10.0g                Beibehalten VZ: Wahrscheinlichkeit f�r weniger Gehalt in 10 Jahren in Prozent
innoAWxx4b3b    double  %10.0g                Beibehalten VZ: Wahrscheinlichkeit f�r mehr Gehalt in 10 Jahren in Prozent
innoAWpzuf04    byte    %16.0f     pzuf20     Zufriedenheit mit HH-Einkommen
innoAWpzuf05    byte    %16.0f     pzuf01     Zufriedenheit mit gegenw�rtigem Einkommen
innoAWpek011    int     %16.0f                Rente/Pension Brutto letzter Monat
innoAWpek02     byte    %16.0f     pek01      Witwen/Waisenrente letzter Monat
innoAWpek021    int     %16.0f                Witwen/Waisenrente Brutto letzter Monat
innoAWpek03     byte    %16.0f     pek03      Arbeitslosengeld
innoAWpek031    int     %16.0f                � Betrag Arbeitslosengeld im letzten Monat
innoAWpek04     byte    %16.0f     pek03      Sozialgeld
innoAWpek07     byte    %16.0f     pek01      Mutterschafts-/Elterngeld letzter Monat
innoAWpek071    int     %16.0f                Mutterschafts-/Elterngeld Brutto letzter Monat
innoAWpek08     byte    %16.0f     pek03      BAf�G, Stipendium oder Berufsausbildungsbeihilfe
innoAWp7tag     byte    %16.0f     ppol2      Arbeit letzte 7 Tage
innoAWlab01     byte    %16.0f     lp1a       Abschluss Berufsausbildung / Studium in Deutschland
innoAWlab02     byte    %16.0f     lab02      Lehre / Facharbeiter
innoAWlab03     byte    %16.0f     lab03      Berufsfachschule etc.
innoAWlab08ka   byte    %16.0f                GesamtKA Berufsausbildung / Studium in Deutschland
innoAWlal10a    byte    %16.0f     lsta1      Arbeitslosigkeit letzte 10 Jahre
innoAWlal10b    byte    %16.0f                Anzahl Arbeitslosigkeitsperioden
innoAWlalo      byte    %16.0f     lsta1      Arbeitslosigkeit derzeit
innoAWlal10c    byte    %16.0f                Monate Arbeitslosigkeit
innoAWlbesch10  byte    %16.0f                Anzahl Arbeitgeber/Stellen
innoAWpalo      byte    %16.0f     ppol2      Arbeitslos gemeldet
innoAWpaz11     byte    %16.0f     paz11      Mini-/Midi-Job
innoAWpaz11a    byte    %16.0f     ppol2      Freiwillige Beitragsaufstockung Rentenversicherung
innoAWl1erw     byte    %16.0f                Alter erste Berufst�tigkeit
innoAWloed      byte    %16.0f     lp1a       �ffentlicher Dienst (letzter Job)
innoAWpwexl1    byte    %16.0f     pend1      Stellenwechsel nach 31.12.2016
innoAWpwexl14   byte    %16.0f                Einmal Stellenwechsel nach 31.12.2016
innoAWpwexl15   byte    %16.0f                Anzahl Stellenwechsel nach 31.12.2016
innoAWpber      str60   %-60s                 Offene Nennung derzeitige berufliche T�tigkeit
innoAWpoed      byte    %16.0f     pek03      Arbeit im �ffentlichen Dienst
innoAWpbra      str60   %-60s                 Offene Nennung Wirtschaftszweig/Branche/Dienstleistungsbereich derzeitige T�tigk
innoAWpstell    byte    %16.0f     pstell     Derzeitige berufliche Stellung
innoAWparb      byte    %16.0f     parb       Derzeitige berufliche Stellung als Arbeiter
innoAWpang      byte    %16.0f     pang       Derzeitige berufliche Stellung als Angestellter
innoAWpamt      byte    %16.0f     pamt       Berufliche Stellung Beamte
innoAWpazubi    byte    %16.0f     pazubi     Berufliche Stellung als Auszubildender
innoAWpseitm    byte    %16.0f                Monat jetziger Arbeitgeber
innoAWpseitj    int     %16.0f                Jahr jetziger Arbeitgeber
innoAWpzaf      byte    %16.0f     pek03      Zeitarbeit
innoAWpbefr1    byte    %16.0f     pbefr1     Befristung des Arbeitsvertrags
innoAWpsst      byte    %16.0f     psst       Derzeitige berufliche Stellung als Selbst�ndiger
innoAWpsstanz   byte    %16.0f     psstanz    Anzahl der Mitarbeiter
innoAWpaz08     int     %16.0f                Vereinbarte Arbeitszeit ohne �berstunden Std./Wo.
innoAWpaz09     byte    %16.0f                Keine festgelegte Arbeitszeit
innoAWpaz10     int     %16.0f                Tats�chliche Arbeitszeit mit �berstunden Std./Wo.
innoAWpaz15     byte    %16.0f     paz15      Abendarbeit
innoAWpaz16     byte    %16.0f     paz15      Nachtarbeit
innoAWpaz17     byte    %16.0f     paz17      Wochenendarbeit: Samstag
innoAWpaz18     byte    %16.0f     paz17      Wochendarbeit: Sonntag
innoAWpbrut     long    %16.0f                Bruttoarbeitsverdienst im letzten Monat
innoAWpnett     int     %16.0f                Nettoarbeitsverdienst im letzten Monat
innoAWlv08      byte    %16.0f     lv08       Berufliche Stellung Vater Arbeiter
is18pzuf04      byte    %16.0f     pzuf20     Zufriedenheit mit HH-Einkommen
is18pzuf05      byte    %16.0f     pzuf01     Zufriedenheit mit gegenw�rtigem Einkommen
is18pek01       byte    %16.0f     pek01      Rente/Pension letzter Monat
is18pek011      int     %16.0f                Rente/Pension Brutto letzter Monat
is18pek02       byte    %16.0f     pek01      Witwen/Waisenrente letzter Monat
is18pek021      int     %16.0f                Witwen/Waisenrente Brutto letzter Monat
is18pek03       byte    %16.0f     pek03      Arbeitslosengeld
is18pek031      int     %16.0f                � Betrag Arbeitslosengeld im letzten Monat
is18pek04       byte    %16.0f     pek03      Sozialgeld
is18pek07       byte    %16.0f     pek01      Mutterschafts-/Elterngeld letzter Monat
is18pek071      int     %16.0f                Mutterschafts-/Elterngeld Brutto letzter Monat
is18pek08       byte    %16.0f     pek03      BAf�G, Stipendium oder Berufsausbildungsbeihilfe
is18p7tag       byte    %16.0f     ppol2      Arbeit letzte 7 Tage
is18lab01       byte    %16.0f     lp1a       Abschluss Berufsausbildung / Studium in Deutschland
is18lab02       byte    %16.0f     lab02      Lehre / Facharbeiter
is18lab03       byte    %16.0f     lab03      Berufsfachschule etc.
is18lab08ka     byte    %16.0f                GesamtKA Berufsausbildung / Studium in Deutschland
is18lal10a      byte    %16.0f     lsta1      Arbeitslosigkeit letzte 10 Jahre
is18lal10b      byte    %16.0f                Anzahl Arbeitslosigkeitsperioden
is18lalo        byte    %16.0f     lsta1      Arbeitslosigkeit derzeit
is18lal10c      byte    %16.0f                Monate Arbeitslosigkeit
is18lbesch10    byte    %16.0f                Anzahl Arbeitgeber/Stellen
is18palo        byte    %16.0f     ppol2      Arbeitslos gemeldet
is18paz11       byte    %16.0f     paz11      Mini-/Midi-Job
is18paz11a      byte    %16.0f     ppol2      Freiwillige Beitragsaufstockung Rentenversicherung
is18l1erw       byte    %16.0f                Alter erste Berufst�tigkeit
is18loed        byte    %16.0f     lp1a       �ffentlicher Dienst (letzter Job)
is18pwexl1      byte    %16.0f     pend1      Stellenwechsel nach 31.12.2016
is18pwexl14     byte    %16.0f                Einmal Stellenwechsel nach 31.12.2016
is18pwexl15     byte    %16.0f                Anzahl Stellenwechsel nach 31.12.2016
is18pber        str60   %-60s                 Offene Nennung derzeitige berufliche T�tigkeit
is18poed        byte    %16.0f     pek03      Arbeit im �ffentlichen Dienst
is18pbra        str60   %-60s                 Offene Nennung Wirtschaftszweig/Branche/Dienstleistungsbereich derzeitige T�tigk
is18pstell      byte    %16.0f     pstell     Derzeitige berufliche Stellung
is18parb        byte    %16.0f     parb       Derzeitige berufliche Stellung als Arbeiter
is18pang        byte    %16.0f     pang       Derzeitige berufliche Stellung als Angestellter
is18pamt        byte    %16.0f     pamt       Berufliche Stellung Beamte
is18pazubi      byte    %16.0f     pazubi     Berufliche Stellung als Auszubildender
is18pseitm      byte    %16.0f                Monat jetziger Arbeitgeber
is18pseitj      int     %16.0f                Jahr jetziger Arbeitgeber
is18pzaf        byte    %16.0f     pek03      Zeitarbeit
is18pbefr1      byte    %16.0f     pbefr1     Befristung des Arbeitsvertrags
is18psst        byte    %16.0f     psst       Derzeitige berufliche Stellung als Selbst�ndiger
is18psstanz     byte    %16.0f     psstanz    Anzahl der Mitarbeiter
is18paz08       int     %16.0f                Vereinbarte Arbeitszeit ohne �berstunden Std./Wo.
is18paz09       byte    %16.0f                Keine festgelegte Arbeitszeit
is18paz10       int     %16.0f                Tats�chliche Arbeitszeit mit �berstunden Std./Wo.
is18paz15       byte    %16.0f     paz15      Abendarbeit
is18paz16       byte    %16.0f     paz15      Nachtarbeit
is18paz17       byte    %16.0f     paz17      Wochenendarbeit: Samstag
is18paz18       byte    %16.0f     paz17      Wochendarbeit: Sonntag
is18pbrut       int     %16.0f                Bruttoarbeitsverdienst im letzten Monat
is18pnett       int     %16.0f                Nettoarbeitsverdienst im letzten Monat
is18lv08        byte    %16.0f     lv08       Berufliche Stellung Vater Arbeiter
*/
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

*STEP 3: MERGE EVERYTHING:
*merge p_long, pgen, pbrutto and selected Inno-vars:
use "$imputation\helpdata\p_l_help.dta", clear
merge 1:1 pid syear using "$imputation\helpdata\pgen_l_help.dta"
rename _merge _merge1
merge 1:1 pid syear using "$imputation\helpdata\pbrutto_l_help.dta"
drop if _merge==2 
drop if _merge1==2
save "$imputation\helpdata\people_data_working.dta", replace 	//2018: 11,812 Obs, 1660 Vars
rename _merge _merge2
keep if syear==real("20${thisyear}")							//2018: 5,633 Obs
*- > a quasi wide format
merge 1:1 pid using "$imputation\helpdata\p_rohdaten.dta"
drop if _merge==2
drop _merge
save "$imputation\helpdata\allmerged.dta", replace

* STEP 4: Create HH-aggregated vars:
* every newly generated var in STEP 4 has to start with hh_  !
use "$imputation\helpdata\allmerged.dta", clear

* Create aggregated HH-information from plb0022, Erwerbsstatus:
tab plb0022,m
levelsof plb0022
foreach value in `r(levels)' {
egen hh_erwerb`value' = total(plb0022==`value'), by(hid)
local valuelabel: label plb0022 `value'
label var hh_erwerb`value' "Anz. Personen im HH mit Erwerbsstatus `valuelabel'"
tab hh_erwerb`value',m
}

* Create # of employed persons in HH from plb0022, Erwerbsstatus:
egen hh_erwerbyes = total(plb0022!=9), by(hid)
label var hh_erwerbyes "Anz. Personen im HH in Erwerbsarbeit"
tab hh_erwerbyes,m

*sum up individual labor incomes: net income	-->sumnet
recode pglabnet (-2=0) (-3 -1=.) 
egen hh_sumnet=sum(pglabnet), by(hid) 
egen hh_sumnet_miss=total(pglabnet==.), by(hid)
label var hh_sumnet "hh net income (sum(pglabnet))"
label var hh_sumnet_miss "# of missing incomes (of pglabnet) in HH"

*sum up individual labor incomes: gross income	-->sumgross
recode pglabgro (-2=0) (-3 -1=.) 
egen hh_sumgross=sum(pglabgro), by(hid)
egen hh_sumgross_miss=total(pglabgro==.), by(hid)
label var hh_sumgross "hh gross income (sum(pglabgro))"
label var hh_sumgross_miss "# of missing incomes (of pglabgro) in HH"

*sum for other income sources --> sumother
global othervars plc0153 plc0131 plc0134 plc0168 plc0233 plc0274 plc0203 plc0062 plc0184
foreach var in $othervars { 
	di `"`var': `: var label `var''"' 
	}
global sumothervars
global sumother_miss

foreach var in $othervars {
	recode `var' (-2=0) (-3 -1=.)
	egen hh_sum`var'=sum(`var'), by(hid)
	egen hh_sum`var'_miss=total(`var'==.), by(hid)
		global sumothervars $sumothervars hh_sum`var'
		global sumother_miss $sumother_miss hh_sum`var'_miss
	}
egen hh_sumother = rowtotal(${sumothervars})
egen hh_sumother_miss = rowtotal(${sumother_miss})
label var hh_sumother "HH other income sources"
label var hh_sumother_miss "# of missing values of other income sources for HH"
drop $sumothervars $sumother_miss

*type of employment on hh level -- create with pgstib
egen hh_pensioner=sum(pgstib==13), by(hid)
egen hh_curredu=sum(pgstib==11), by(hid)
egen hh_milorcom=sum(pgstib==15), by(hid)
egen hh_apprentice=sum(inrange(pgstib,110,150)), by(hid)
egen hh_selfemp=sum(inrange(pgstib,410,440)), by(hid)
egen hh_manlab=sum(inrange(pgstib,210,250)), by(hid)
egen hh_empl=sum(inrange(pgstib,510,550)), by(hid)
egen hh_civilser=sum(inrange(pgstib,610,650)), by(hid)
label var hh_pensioner "# of pensioner in hh"
label var hh_curredu "# of persons currently in education in hh"
label var hh_milorcom "# of persons currently in military / community service"
label var hh_apprentice "# of apprentice in hh"
label var hh_selfemp "# of self-employed in hh"
label var hh_manlab "# of manual laborer in hh"
label var hh_empl "# of employee in hh"
label var hh_civilser "# of persons in civil service in hh"

* firm size on hh level -- create with pgbetr
egen hh_firmsize1=sum(pgstib==1), by(hid)
egen hh_firmsize2=sum(pgstib==2), by(hid)
egen hh_firmsize3=sum(pgstib==3), by(hid)
egen hh_firmsize4=sum(pgstib==6), by(hid)
egen hh_firmsize5=sum(pgstib==7), by(hid)
egen hh_firmsize6=sum(pgstib==9), by(hid)
egen hh_firmsize7=sum(pgstib==10), by(hid)
egen hh_firmsize8=sum(pgstib==11), by(hid)
label var hh_firmsize1 "# of persons in HH: in firm size of less than 5"
label var hh_firmsize2 "# of persons in HH: in firm size of greater equal 5 less than 10 "
label var hh_firmsize3 "# of persons in HH: in firm size of greater equal 11 less than 20 "
label var hh_firmsize4 "# of persons in HH: in firm size of greater equal 20 less than 100"
label var hh_firmsize5 "# of persons in HH: in firm size of greater equal 100 less than 200"
label var hh_firmsize6 "# of persons in HH: in firm size of greater equal 200 less than 2000"
label var hh_firmsize7 "# of persons in HH: in firm size of greater equal 2000"
label var hh_firmsize8 "# of persons in HH: Self-Employed Without Coworkers"

* hh level jobchanges, bad health, disabled
egen hh_jobchange=sum(pgjobch==4), by(hid)
egen hh_badh=sum(ple0008==5), by(hid)
egen hh_disable=sum(ple0040==1), by(hid)
label var hh_jobchange "# of persons with jobchange in hh"
label var hh_badh "# of persons in bad health in hh"
label var hh_disable "# of persons disabled in hh"

* hh level education (school) -- create with pgsbil
egen hh_haupt=sum(pgsbil==1), by(hid)
egen hh_real=sum(pgsbil==2), by(hid)
egen hh_fach=sum(pgsbil==3), by(hid)
egen hh_abi=sum(pgsbil==4), by(hid)
egen hh_diff=sum(pgsbil==5), by(hid)
egen hh_without=sum(inlist(pgsbil,6,7)), by(hid)
label var hh_haupt "# of persons in HH with Hauptschule"
label var hh_real "# of persons in HH with Realschule"
label var hh_fach "# of persons in HH with Fachhochschulreife"
label var hh_abi "# of persons in HH with Abitur"
label var hh_diff "# of persons in HH different degree"
label var hh_without "# of persons in HH without degree"

* hh level education (university) -- create with pgbbil02
egen hh_fachhoch=sum(inlist(pgbbil02,1,4)), by(hid)
egen hh_uni=sum(inlist(pgbbil02,2,5)), by(hid)
egen hh_ausland=sum(pgbbil02==3), by(hid)
egen hh_promotion=sum(pgbbil02==6), by(hid)
label var hh_fachhoch "# of persons in HH with Fachhochschule"
label var hh_uni "# of persons in HH with UNI"
label var hh_ausland "# of persons in HH with Hochschule im Ausland"
label var hh_promotion "# of persons in HH with Promotion"

* hh working hours and overtime -- create with pgvebzt
recode pgvebzt pguebstd (-5 -2 -1=0)
egen hh_hours=sum(pgvebzt), by(hid) 
egen hh_ovhours=sum(pguebstd), by(hid)
label var hh_hours "Sum of all working hours in HH"
label var hh_ovhours "Sum of all overtime hours in HH"

* hh level marital and partner status -- create with pld0132 & pgfamstd
recode pld0132 (-2 -1=0)
egen hh_anysng=sum(pld0132==2), by(hid)
egen hh_partner=sum(pld0132==1), by(hid)
egen hh_anymar=sum(inlist(pgfamstd,1,2)), by(hid)
egen hh_anydiv=sum(pgfamstd==4), by(hid)
egen hh_anywid=sum(pgfamstd==5), by(hid)
label var hh_anysng "# of persons that are single in HH"
label var hh_partner "any partnered in HH"
label var hh_anymar "# of persons that aremarried in HH"
label var hh_anydiv "# of persons that aredivorced in HH"
label var hh_anywid "# of persons that arewidowed in HH"

* age + gender counts
gen alter=2014-geburt
egen hh_num50plus=sum(alter>=50), by(hid)
egen hh_numfem=sum(sex==2), by(hid)
label var hh_num50plus "# of 50+ persons in HH"
label var hh_numfem "# of females in HH"

* other household vars
egen hh_mixed_d=max(pnat!=1), by(hid)  // returns 1 if any non-german in HH
egen hh_numberhh=sum(1), by(hid)
egen hh_psize=sum(inlist(pergz,10,19)), by(hid)
label var hh_mixed_d "Dummy: HH not only german"
label var hh_numberhh "# of persons in HH"
label var hh_psize "# of p questionaires in HH"

save "$imputation\helpdata\dataset_h_help1.dta", replace

*Delete duplicats
use "$imputation\helpdata\dataset_h_help1.dta", clear
sort hid 
by hid: gen dup = cond(_N==1,0,_n)
drop if dup>1 //2018: (1903 observations deleted)
drop dup

*Keep only the generated variables
keep hid hh_*

save "$imputation\helpdata\dataset_h_help2.dta", replace
* MO18 TODO: Innodatensätze werden glaube ich bisher nicht beachtet, 
* 			 da alle nicht-generierten Variablen hier gedroppt werden!
*			 überlegen ob/ wie sie eingebunden werden sollen!!
*2018: 3712 Obs, 57 Var

*STEP 5: merge the h_datasets and generated p-dataset variables

*h_long
use "$is${DEEN}\h.dta", clear
keep if inlist(syear,real("20${lastyear}"),real("20${thisyear}"))
save "$imputation\helpdata\h_l_help.dta", replace
*2018: 7790 Obs, 513 Vars

*hgen
use "$is${DEEN}\hgen.dta", clear
keep if inlist(syear,real("20${lastyear}"),real("20${thisyear}"))
save "$imputation\helpdata\hgen_l_help.dta", replace
*2018 7790 Obs, 57 Vars

*hbrutto
use "$is${DEEN}\hbrutto.dta", clear
keep if inlist(syear,real("20${lastyear}"),real("20${thisyear}"))
save "$imputation\helpdata\hbrutto_l_help.dta", replace
*2013: 9344 Obs, 47 Vars

*merge all:
use "$imputation\helpdata\h_l_help.dta", clear
merge 1:1  hid syear using "S:\DATA2\SOEP-IS\SOEP-IS 20${thisyear} Generierung HiWi\Imputation\helpdata\hgen_l_help.dta"
rename _merge _merge1
merge 1:1 hid syear using "$imputation\helpdata\hbrutto_l_help.dta"
drop if _merge==2 | _merge1==2
drop _merge _merge1
keep if syear==real("20${thisyear}") 
save "$imputation\helpdata\h_working.dta", replace
*2018: 3717 Obs, 609 Vars
use "$imputation\helpdata\h_working.dta", clear
merge 1:1 hid using "$imputation\helpdata\dataset_h_help2.dta"
drop if _merge==2
drop _merge
save "$imputation\helpdata\h_working2.dta", replace
*2018: 3717 Obs, 665 Vars
*--------------------------------------------------------------------------------------------------------------------------//


********************************************************************************
************* Create Information from the HH Datasets **************************
********************************************************************************

use "$imputation\helpdata\h_working2.dta",clear
*generate variable cost of living
tab hlf0001,m
gen sum_rent=0
replace sum_rent=hlf0074 if inlist(hlf0001,1,2,4)
recode sum_rent (-2=0) // Hoehe Miete

*generate cost of living if proprietary
gen sum_int=0
gen sum_rep=0
gen sum_neb=0
gen sum_hall=0
replace sum_int=hlf0088 if hlf0001==3 // Monatl. Zins- & Tilgungszahlen
replace sum_rep=hlf0089 if hlf0001==3  // Hoehe Instandhaltugskosten lz. Jahr
replace sum_neb=hlf0091 if hlf0001==3  // Jaehrliche NK in Euro
replace sum_hall=hlf0093 if hlf0001==3 // Wohngeld pro Monat

recode sum_int sum_rep sum_neb sum_hall (-1=.) (-2 -3=0)
replace sum_rep=sum_rep/12 
replace sum_neb=sum_neb/12 

gen cost_liv=sum_rent+sum_int+sum_rep+sum_hall+sum_neb
label var cost_liv "Hoehe monatl. Wohnkosten (bei Miete oder Eigentum)"

drop sum_rent sum_int sum_rep sum_hall sum_neb

drop hlf0074 hlf0088 hlf0089 hlf0091 hlf0093 hlf0019 hlf0107 hlf0016 hlk0006 ///
	 sampreg schk intid1 hlf0017 hlf0155 hlf0154 hlf0106

recode hlf0081 hlc0008 hlc0111 hlc0112 hlc0113 hlc0084 hlc0043 hlc0045 hlc0068 ///
	   hlc0090 hlc0114 hlc0120 hlc0071 hlc0065 hlc0047 hgutil hgrent (-2=0)

*Diff between persons im hh and p-questionaires
gen diff_persons=hhgr-hh_psize
label var diff_persons "Diff. between persons im hh and p-questionaires"

save "$imputation\helpdata\dataset_h.dta", replace //  642 vars
