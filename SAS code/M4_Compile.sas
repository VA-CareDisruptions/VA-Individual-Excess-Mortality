**********************************

Compile into analytic dataset

cohort: VACS-National
started: 13 January 2022
Author: CTR

**********************************;




libname DCNP "<redacted-sensitive information>";
libname OUT "<redacted-sensitive information>";




proc contents data=DCNP.cohort;
run;


*first link in the variables that do not time-update;
data x;
merge DCNP.cohort_split (in=a)
	  DCNP.urban
	  ;
by scrssn_n;
if a;
run;

*second link in the variables that do time-update;
data ready;
merge x (in=a)
	  DCNP.sta3n_city_state
	  DCNP.CCI
	  DCNP.SCORE
	  DCNP.CCSR_SYS
	  ;
by scrssn_n DT_BASELINE;
if a;

**missing to 0;
array setmissto0 {*} CCSR_: charl_:
						;
do i = 1 to dim(setmissto0);
	if setmissto0{i} = . then setmissto0{i} = 0;
end;
drop i;

if census = "" then census = "NA";

*census region missing for 1.5% of cohort.. randomly assign to a region;
length census_nomiss $2.;
census_nomiss = census;
if census_nomiss = "" or census_nomiss = "NA" then do;
	*set seed for reproducibiility;
	call streaminit(8675309);
	x = rand('integer',1,4);
	     if x = 1 then census_nomiss = "MW";
	else if x = 2 then census_nomiss = "NE";
	else if x = 3 then census_nomiss = "S";
	else if x = 4 then census_nomiss = "W";
end;
drop x;

*one person missing sex;
if SEX = . then SEX = 1;

*missing race/eth category;
if RACE7_SR = "" then RACE7_SR = "8_Miss";

*0.001% have missing urban flag - set to more common;
if URBAN = . then URBAN = 1;

*rename missing census region so its alphabetically last;
if census = "NA" then census = "XX";
if census_nomiss = "NA" then census_nomiss = "XX";
if census_urban = "" then census_urban = "XX";

*create combined var between region and urban/rural;
length census_urban $6.;
if census = "MW" then do;
  if URBAN = 1 then census_urban = "MW_URB";
  else if URBAN = 0 then census_urban = "MW_RUR";
end;
if census = "NE" then do;
  if URBAN = 1 then census_urban = "NE_URB";
  else if URBAN = 0 then census_urban = "NE_RUR";
end;
if census = "S" then do;
  if URBAN = 1 then census_urban = "S_URB";
  else if URBAN = 0 then census_urban = "S_RUR";
end;
if census = "W" then do;
  if URBAN = 1 then census_urban = "W_URB";
  else if URBAN = 0 then census_urban = "W_RUR";
end;


*age categories;
length AGE_BL 3. AGE_BL_CAT $9.;
AGE_BL = int((DT_BASELINE-DT_BIRTH)/365.242);
*11 of >11 million records have missing age.. set to median;
     if AGE_BL ge 18 and AGE_BL lt 25 then AGE_BL_CAT = "18-24";
else if AGE_BL ge 25 and AGE_BL lt 35 then AGE_BL_CAT = "25-34";
else if AGE_BL ge 35 and AGE_BL lt 45 then AGE_BL_CAT = "35-44";
else if AGE_BL ge 45 and AGE_BL lt 55 then AGE_BL_CAT = "45-54";
else if AGE_BL ge 55 and AGE_BL lt 65 then AGE_BL_CAT = "55-64";
else if AGE_BL ge 65 and AGE_BL lt 75 then AGE_BL_CAT = "65-74";
else if AGE_BL ge 75 and AGE_BL lt 85 then AGE_BL_CAT = "75-84";
else if AGE_BL ge 85                  then AGE_BL_CAT = "85+";

*CCI cleaning up;
if CCI = . then CCI = 0;
length CCI_CAT $2.;
if CCI = 0 then CCI_CAT = "0";
else if CCI = 1 then CCI_CAT = "1";
else if CCI = 2 then CCI_CAT = "2";
else if CCI = 3 then CCI_CAT = "3";
else if CCI = 4 then CCI_CAT = "4";
else if CCI >= 5 then CCI_CAT = "5+";

*categorise VACS Index;
length SCORE_CAT $17.;
if SCORE = . then SCORE_CAT = "5_Miss";
else if SCORE <= 75.7 then SCORE_CAT = "1QTILE_29-75.7";
else if SCORE <= 84.4 then SCORE_CAT = "2QTILE_75.8-84.4";
else if SCORE <= 93.2 then SCORE_CAT = "3QTILE_84.4-93.2";
else if SCORE >  93.2 then SCORE_CAT = "4QTILE_93.2-157.9";

format dt_: mmddyy8.;
length dt_: 4.;
run;
*there are 8 patients under the age of 18/weird DOB.. identify them and exclude whne creating final dataset;
data excl_dob;
set ready (keep=scrssn_n AGE_BL where=(AGE_BL<18));
drop AGE_BL;
by scrssn_n;
if first.scrssn_n;
run;




*check max 2 lines per patient;
data check;
set ready;
by scrssn_n;
if first.scrssn_n then i = 1;
else i + 1;
proc freq data= check;
tables i;
run;


**go girl, go;
data DCNP.go ;
merge 	ready 
		excl_dob (in=excl)
;
by scrssn_n;

if excl then delete;

format DT_: mmddyy8.;
run;


