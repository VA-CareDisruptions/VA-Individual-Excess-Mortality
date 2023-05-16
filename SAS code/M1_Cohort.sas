**********************************


Identify cohort for DCNP Aim 3

Pre-pandemic: 1 Mar 2018 to 29 Feb 2020
Pandemic: 1 Mar 2020 to 28 Feb 2022

cohort: VACS-National
Author: CTR

**********************************;


libname DCNP "<redacted-sensitive information>";
libname OUT "<redacted-sensitive information>";


*Extract VACS-National;
data full; /* 1 min */
informat scrssn $9. patienticn $10.; 
format scrssn $9. patienticn $10.;
length scrssn $9. patienticn $10.;
set <redacted-sensitive information>DFT.FullVA_demog (keep=patienticn scrssn   race4   gender newrace newhispanic DT_: rename=(DT_BIRTH_SP=DT_BIRTH));
scrssn_n = scrssn*1;

*create date for one year after first VA;
DT_FIRST_VA_p365 = DT_FIRST_VA + 365;

*race/ethnicity (7 groups);
length RACE7_SR $8.;
if NewHispanic = 1 then RACE7_SR = "3_Hisp";
else if NewRace = "White" then RACE7_SR = "1_White";
else if NewRace = "Black" then RACE7_SR = "2_Black";
else if NewRace = "Asian" then RACE7_SR = "4_Asian";
else if NewRace = "AmIndian" then RACE7_SR = "5_AI/AN";
else if NewRace = "PacIslander" then RACE7_SR = "6_PI/NH";
else if NewRace = "MixedRace" then RACE7_SR = "7_Mixed";

*race/ethnicity (5 groups);
length RACE5_SR $8.;
RACE5_SR=RACE7_SR;
if RACE7_SR in("5_AI/AN" , "6_PI/NH" , "7_Mixed") then RACE5_SR = "5_Other";

*sex;
length SEX 3.;
if gender  = "" then SEX = .;
else if gender= "M" then SEX= 1;
else if gender= "F" then SEX = 0;

*dates;
format DT_: mmddyy8.;
drop race4 gender   ;

drop DT_LAST_VA DT_DEATH_SP DT_DEATH_VS;**going to update later in code;
run;



*update deaths (3 mins);
proc sql;
create table newdeaths as
select distinct(d.patienticn), min(datepart(sp.deathdatetime)) as DT_DEATH_SP format=mmddyy8., min(v.dod) AS DT_DEATH_VS format=mmddyy8.
FROM full d inner join <redacted-sensitive information>SRC.CohortCrosswalk x on d.scrssn = x.scrssn
left join <redacted-sensitive information>SRC.VitalStatus_Mini v on d.scrssn = v.scrssn
left join <redacted-sensitive information>SRC.spatient_spatient sp on x.patientsid = sp.patientsid
group by d.patienticn
order by d.patienticn;
quit;run;

****DT_LAST_VA updated;
*ip;
proc sql;/*1 minute*/
create table lastip as
select distinct(x.patienticn), max(datepart(admitdatetime)) as DT_LAST_IP format=mmddyy8.
  from full d inner join <redacted-sensitive information>SRC.CohortCrosswalk x on d.scrssn = x.scrssn
  left join <redacted-sensitive information>SRC.inpat_inpatient ip on x.patientsid=ip.patientsid
  inner join DIM_RB02.AdmitSource adm on ip.AdmitSourceSID = adm.admitsourcesid
   where admitdatetime is not null and admitdatetime >=  mdy(10,01,1999)
and   (admitdatetime >= mdy(03,01,2018) or dischargedatetime is null)
group by x.patienticn
order by x.patienticn;
quit;
proc print data=lastip (obs=50);
run;
*op - 5 mins;
proc sql;
create table lastop as
select distinct(d.patienticn), DT_LAST_OP format=mmddyy8.
from full d left join <redacted-sensitive information>DFT.FullVA_Last_OP op on d.patienticn=op.patienticn
group by d.patienticn
order by d.patienticn, DT_LAST_OP;
quit;
*only keep last;
data lastop2;
set lastop;
by patienticn;
if last.patienticn;
run;
*combine;
proc sort data=full;
by patienticn;
data demog;
merge full (in=a) newdeaths lastip lastop2;
by patienticn;
if a;
DT_LAST_VA = max(of DT_LAST_IP, DT_LAST_OP);
DT_DEATH = min(of DT_DEATH_SP, DT_DEATH_VS);
format DT_: mmddyy8.;
drop DT_LAST_IP DT_LAST_OP DT_DEATH_SP DT_DEATH_VS;
run;




*inclusion criteria: must have VA IP or OP in the 2 years prior to baseline;
proc sql; /*2 hours*/
create table visits as 
select scrssn_n
from <redacted-sensitive information>DFT.FullVA_DX_Long_v
where mdy(3,1,2016) <= datepart(recdatetime) <= mdy(02,28,2018)
order by scrssn_n;
run;
data INCL_VISIT_BL;
set visits;
by scrssn_n;
if first.scrssn_n;
length INCL_VISIT_BL 3.;
INCL_VISIT_BL = 1;
run;
*combine with demog;
proc sort data=demog;
by scrssn_n;
data demog2;
merge demog (in=a) INCL_VISIT_BL;
by scrssn_n;
if a;
if INCL_VISIT_BL = . then INCL_VISIT_BL = 0;
run;









*Create study-specific cohort;
data DCNP.cohort;
set demog2;

if DT_DEATH ne . and DT_DEATH le mdy(3,1,2018) then EXCL_DEATH = 1;    
if DT_LAST_VA le mdy(3,1,2018) then EXCL_VISIT = 1;	
if EXCL_DEATH = 1 or EXCL_VISIT = 1 or INCL_VISIT_BL = 0 then delete;
drop EXCL_: INCL_:;

*baseline is greater of 1 mar 2018 or DT_FIRST_VA_p365;
DT_BASELINE = max(of DT_FIRST_VA_p365, mdy(3,1,2018));	

*censoring;
*date last (need same amount of time on either side of the index date (1 Mar 2020) so that
no issues with seasonality (i.e., 2 winters before vs 1 winter after). so cut off at 28 Feb 2022;
DT_LAST = min(of DT_DEATH, DT_LAST_VA + (1.5*365), mdy(2,28,2022));

*survival time;
st_days = DT_LAST-DT_BASELINE;

*outcome;
if DT_DEATH ne . then DIED = 1; else DIED = 0;

*correct for censoring;
if DT_DEATH ne . and DT_DEATH > DT_LAST then DIED = 0;

format dt_: mmddyy8.;
length dt_: 4.;
run;
proc sort data= DCNP.cohort;
by scrssn_n;
run;





**** RUN SOME CHECKS *****;
ods graphics on ;
ods html path="<redacted-sensitive information>";
ods graphics / MAXOBS=7329144;
proc sgplot data=DCNP.cohort ;
where DT_BASELINE ;
histogram DT_BASELINE  /binwidth=1 ;
run;
proc sgplot data=DCNP.cohort;
where DT_LAST_VA ;
histogram DT_LAST_VA  /binwidth=1 ;
run;
proc sgplot data=DCNP.cohort;
where DT_DEATH ;
histogram DT_DEATH  /binwidth=1 ;
run;





