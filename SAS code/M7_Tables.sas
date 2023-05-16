**********************************


Tables for paper

cohort: VACS-National
started: 18 November 2022
Author: CTR

**********************************;




libname DCNP "<redacted-sensitive information>";
libname OUT "<redacted-sensitive information>";







proc contents data=DCNP.go ;
run;
data tables;
set DCNP.go;
by scrssn_n;
if first.scrssn_n then i = 1;
else i + 1;
length ageb $7.;
     if age_start_rnd                        < 45 then ageb = "1_<45"; 
else if age_start_rnd >=45 and age_start_rnd < 65 then ageb = "2_45-64"; 
else if age_start_rnd >=65 and age_start_rnd < 75 then ageb = "3_65-74";
else if age_start_rnd >=75 and age_start_rnd < 85 then ageb = "4_75-84";
else if age_start_rnd >=85                        then ageb = "5_85+"; 
run;

*summary stats for paper;
proc freq data=tables;
tables PERIOD i PERIOD*i /list  missing;
run;
data pre pan;
set tables (keep=scrssn_n PERIOD DIED);
if PERIOD = 0 then output pre;
if PERIOD = 1 then output pan;
run;
data both;
merge pre (in=a) pan (in=b);
if a and b then FUP = "BOTH";
else if a then FUP = "PRE";
else if b then FUP = "PAN";
run;
proc freq data=both;
tables FUP FUP*DIED/ missing;
run;


proc means data=tables n nmiss min p1 p25 median p75 p99 max maxdec=1;
var age_start_rnd;
where PERIOD = 0;
run;
proc freq data=tables;
where PERIOD = 0;
tables ageb SEX RACE7_SR census_nomiss URBAN SCORE_CAT CCI_CAT 
		charl_MI charl_CHF charl_PVD charl_CEVD charl_PARA charl_DEM charl_COPD charl_RHEUM charl_PUD 
		charl_DIAB_NC charl_DIAB_C charl_RD charl_MILDLD charl_MSLD charl_HIV charl_CANCER charl_METS  ;
run;

/* TABLE 1 */
proc freq data=tables;
tables (ageb SEX RACE7_SR census_nomiss URBAN SCORE_CAT CCI_CAT 
		charl_MI charl_CHF charl_PVD charl_CEVD charl_PARA charl_DEM charl_COPD charl_RHEUM charl_PUD 
		charl_DIAB_NC charl_DIAB_C charl_RD charl_MILDLD charl_MSLD charl_HIV charl_CANCER charl_METS 
 ) * PERIOD /nopercent norow;
run;




