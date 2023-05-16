**********************************

Use Lexis expansion to split observation time pre-pandemic and pandemic into separate records

cohort: VACS-National
started: 31 January 2022
Author: CTR

**********************************;




libname DCNP "<redacted-sensitive information>";
libname OUT "<redacted-sensitive information>";





*Implement Lexis expansion macro;
%include "<redacted-sensitive information>/Stats/SAS_code/Lexis.sas";

*split on calendar time;
%Lexis(data = DCNP.cohort, 
	   out = split,
	   entry = DT_BASELINE,
	   exit = DT_LAST,
	   fail = DIED,
	   breaks = %str("1MAR2018"d, "1MAR2020"d, "28FEB2022"d));

	   
proc freq data=split;
tables left;
format left mmddyy10.;;
run;


data DCNP.cohort_split;
set split;
by scrssn_n;

format left mmddyy8.;

*indicator for pre-pandemic vs pandemic fup;
if left = "1MAR2018"d then PERIOD = 0;
else if left = "1MAR2020"d then PERIOD = 1;

*start age (substract a tiny amount from entry age so patients enter risk at the exact age at baseline) ;
if first.scrssn_n then age_start = ((DT_BASELINE-DT_BIRTH)/365.242) - 0.0001;
else age_start = (DT_BASELINE-DT_BIRTH)/365.242;

*end age;
age_end = (DT_LAST-DT_BIRTH)/365.242;

*round so models process faster;
age_start_rnd = round(age_start,0.01);
age_end_rnd = round(age_end,0.01);

*model will exclude those where age_start = age_end. add +0.01 (equivalent to about 4 days (0.01*365);
if age_start_rnd = age_end_rnd then do;
	age_end_rnd = age_end_rnd + 0.01;
end;

**clean up as this is massive dataset;
drop NewRace NewHispanic ln_scrssn DT_FIRST_VA DT_FIRST_VA_p365 ;
length DIED 3. left 4. risk 3. PERIOD 3. ;
run;







