**********************************

Pull variables for cohort

cohort: VACS-National
started: 12 January 2022
Author: CTR

**********************************;




libname DCNP "<redacted-sensitive information>";
libname OUT "<redacted-sensitive information>";




*finder file;
data finder;
set DCNP.cohort_split (keep=scrssn scrssn_n patienticn DT_BASELINE);
run;
*this file has 2 records for most period, one for pre-pandemic follow-up and another for pandemic follow-up;
*DT_BASELINE updates for each record and is 1 March 2018 and 1 March 2020 for most people;
*essentially just need to pull variables for each of those records as they can time-update in the Cox model;




/**********************************************************/
/*     ONE RECORD PER PATIENT (Unique key = scrssn_n)     */
/**********************************************************/

*urban rural ;
/* 8 mins */
proc sql;
create table many as
select f.scrssn_n, GISURH
from finder f left join <redacted-sensitive information>SRC.CohortCrosswalk x on f.scrssn = x.scrssn
left join <redacted-sensitive information>SRC.spatient_spatientaddress a on x.patientsid = a.patientsid 
where GISURH <> '' and a.relationshiptopatient = 'SELF' and a.addresstype = 'Patient' 
order by f.scrssn_n;
quit;
proc print data = many (obs=300);
run;
proc freq data = many;
tables GISURH /missing;
run;
data DCNP.URBAN;
set many;
by scrssn_n;
if first.scrssn_n;
*create flag;
if GISURH = "U" or GISURH = "" then URBAN = 1;  *only .26% missing. 66% of sample are urban -- assume urban;
else URBAN = 0;
drop GISURH;
run;
proc print data = DCNP.URBAN (obs=30);
run;










/******************************************************************************/
/*     MULTIPLE RECORDS PER PATIENT (Unique key = scrssn_n + DT_BASELINE)     */
/******************************************************************************/


*state;
*grab sta3n closest to DT_BASELINE;
/* 2 hours */
proc sql;
create table sta3n as
select f.*, dx.sta3n, max(dx.RECDATETIME) as RECDATETIME format=datetime.
from finder f left join <redacted-sensitive information>DFT.FullVA_DX_Long_v dx on f.scrssn=dx.scrssn
where datepart(RECDATETIME) <= DT_BASELINE
group by f.scrssn_n, DT_BASELINE
order by f.scrssn_n, DT_BASELINE;
quit;
*grab closest to baseline;
data sta3n_prox;
set sta3n;
by scrssn_n DT_BASELINE;  **unique key is scrssn_n + DT_BASELINE (most have two records);
if last.DT_BASELINE;
run;
proc sort data = sta3n_prox;
by sta3n;
data sta3n_city;
merge sta3n_prox (in=a) DIM_RB02.sta3n (keep=sta3n  VISNFY17 RegionFY15 City StateSID  rename=(city=tcity));
by sta3n;
if a;
length CITY $30.;
CITY = upcase(tcity);
drop tcity;
run;
proc sort data = sta3n_city;
by StateSID;
data DCNP.sta3n_city_state ;
merge sta3n_city (in=a) DIM_RB02.state (keep=StateSID  StateAbbrev );
by StateSID;
if a;
length STATE $4. ;
STATE = upcase(StateAbbrev);
drop StateAbbrev;

DT_STA3N = datepart(RECDATETIME);
drop RECDATETIME;
format DT_: mmddyy8.;

*Census region;
length census $2.;
*West;
if STATE in("AK", "HI", "WA", "OR", "CA", "NV", "ID", "UT", "AZ", "MT", "WY", "CO", "NM") then census = "W";
*South;
else if STATE in("TX", "OK", "AR", "LA", "MS", "TN", "AL", "GA", "FL", "KY", "WV", "VA", "DE", "MD", "DC", "NC", "SC", "PR") then census = "S";
*Midwest;
else if STATE in("ND", "SD", "NE", "KS", "MN", "IA", "MO", "WI", "IL", "IN", "MI", "OH") then census = "MW";
*Northeast;
else if STATE in("PA", "NY", "NJ", "CT", "RI", "MA", "VT", "NH", "ME") then census = "NE";

run;
proc sort data = DCNP.sta3n_city_state;
by scrssn_n DT_BASELINE;
run;











*Charlson comorbidity index (CCI)
*only keep all Dx in the 2 years prior to baseline, cutting at 7 days before;
proc sql; /*4 hours*/
create table many as 
select b.scrssn_n, b.DT_BASELINE, datepart(a.recdatetime) as DT_DX, a.ICDCode as DX, INOTPT
from <redacted-sensitive information>DFT.FullVA_DX_Long_v a, finder b
where a.scrssn_n=b.scrssn_n and 
b.DT_BASELINE-(2*365) <= datepart(a.recdatetime) <= b.DT_BASELINE-7 and
(a.ICDCode like	'B%'	or
a.ICDCode like	'C%'	or
a.ICDCode like	'E%'	or
a.ICDCode like	'F0%'	or
a.ICDCode like	'G%'	or
a.ICDCode like	'H%'	or
a.ICDCode like	'I%'	or
a.ICDCode like	'J%'	or
a.ICDCode like	'K%'	or
a.ICDCode like	'M%'	or
a.ICDCode like	'N%'	or
a.ICDCode like	'P2%'	or
a.ICDCode like	'V43%'	or
a.ICDCode like	'Z%')
;
quit;
*Adhering strictly to Quan Medical Care 2005, using codes listed in Table 1 of paper;
data dg; 
set many; 

*initialize to zero for easier tabulation at end;
length MI CHF PVD CEVD DEM COPD RHEUM PUD MILDLD DIAB_NC DIAB_C PARA RD CANCER MSLD METS HIV 3.;   
array  cond (17) MI CHF PVD CEVD DEM COPD RHEUM PUD MILDLD DIAB_NC DIAB_C PARA RD CANCER MSLD METS HIV;
do I = 1 to 17;
COND(I) = 0;
end;
drop I;

*in order presented in Table 1;
*using their variable names;
/*pasted directly from paper*/
/*1. Myocardial infarction    I21.x, I22.x, I25.2*/
if substr(DX,1,3) in ('I21','I22') or substr(DX,1,5) in ('I25.2') then MI=1;

/*2. Congestive heart failure    I09.9, I11.0, I13.0, I13.2, I25.5, I42.0, I42.5–I42.9, I43.x, I50.x, P29.0*/
else if substr(DX,1,3) in ('I43','I50') or
	    substr(DX,1,5) in ('I09.9','I11.0','I13.0','I13.2','I25.5','I42.0', 'I42.5','I42.6','I42.7','I42.8','I42.9','P29.0') then CHF=1;
 
/*3. Peripheral vascular disease   I70.x, I71.x, I73.1, I73.8, I73.9, I77.1, I79.0, I79.2, K55.1, K55.8, K55.9, Z95.8, Z95.9*/
else if substr(DX,1,3) in ('I70','I71' ) or 
        substr(DX,1,5) in ('I73.1','I73.8','I73.9','I77.1','I79.0','I79.2',
			    		   'K55.1','K55.8','K55.9','Z95.8','Z95.9') then PVD=1;

/*4. Cerebrovascular disease   G45.x, G46.x, H34.0, I60.x–I69.x*/    
else if substr(DX,1,3) in ('G45','G46','I60','I61','I62','I63','I64','I65','I66','I67','I68','I69') or 
	    substr(DX,1,5) in ('H34.0') then CEVD=1;

/*5. Dementia  F00.x–F03.x, F05.1, G30.x, G31.1*/
if substr(DX,1,3) in ('F00','F01','F02','F03','G30') or 
   substr(DX,1,5) in ('F05.1','G31.1') then DEM=1;

/*6. Chronic pulmonary disease    I27.8, I27.9, J40.x–J47.x, J60.x–J67.x, J68.4, J70.1, J70.3*/
else if substr(DX,1,3) in ('J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63','J64','J65','J66','J67') or 
        substr(DX,1,5) in ('I27.8','I27.9', 'J68.4','J70.1','J70.3') then COPD=1;

/*7. *Rheumatic disease    M05.x, M06.x, M31.5, M32.x–M34.x, M35.1, M35.3, M36.0*/
else if substr(DX,1,3) in ('M05','M06','M32','M33','M34') or 
        substr(DX,1,5) in ('M31.5','M35.1', 'M35.3','M36.0') then RHEUM=1;

/* 8. Peptic ulcer K25.x–K28.x*/
else if substr(DX,1,3) in ('K25', 'K26','K27','K28') then PUD=1;


/*9. Mild liver B18.x, K70.0–K70.3, K70.9, K71.3–K71.5, K71.7, K73.x, K74.x, K76.0, K76.2–K76.4, K76.8, K76.9, Z94.4*/
else if substr(DX,1,3) in ('B18','K73','K74') or 
        substr(DX,1,5) in ('K70.0','K70.1','K70.2','K70.3','K70.9',
                           'K71.3','K71.4','K71.5','K71.7',
			     		   'K76.0','K76.2','K76.3','K76.4','K76.8','K76.9',
                           'Z94.4') then MILDLD=1;

/* 10.  Diabetes without chronic complication   E10.0, E10.1, E10.6, E10.8, E10.9,
												E11.0, E11.1, E11.6, E11.8, E11.9,
												E12.0, E12.1, E12.6, E12.8, E12.9,
												E13.0, E13.1, E13.6, E13.8, E13.9,
												E14.0, E14.1, E14.6, E14.8, E14.9*/

else if substr(DX,1,5) in ('E10.0','E10.1','E10.6','E10.8','E10.9',
                           'E11.0','E11.1','E11.6','E11.8','E11.9',
                           'E12.0','E12.1','E12.6','E12.8','E12.9',
			   			   'E13.0','E13.1','E13.6','E13.8','E13.9',
			    		   'E14.0','E14.1','E14.6','E14.8','E14.9') then DIAB_NC=1;

/* 11.  Diabetes with chronic complication   E10.2–E10.5, E10.7,
						 					 E11.2–E11.5, E11.7, 
						 					 E12.2–E12.5, E12.7, 
						   				     E13.2–E13.5, E13.7, 
						   					 E14.2–E14.5, E14.7*/
else if substr(DX,1,5) in ('E10.2','E10.3','E10.4','E10.5','E10.7',
                           'E11.2','E11.3','E11.4','E11.5','E11.7',
			   			   'E12.2','E12.3','E12.4','E12.5','E12.7',
			   			   'E13.2','E13.3','E13.4','E13.5','E13.7',
			   			   'E14.2','E14.3','E14.4','E14.5','E14.7') then DIAB_C=1;

/* 12. Hemiplegia or paraplegia G04.1, G11.4, G80.1, G80.2, G81.x, G82.x, G83.0–G83.4, G83.9*/
else if substr(DX,1,3) in ('G81','G82') or 
	    substr(DX,1,5) in ('G04.1','G11.4','G80.1','G80.2','G83.0','G83.1','G83.2','G83.3','G83.4','G83.9') then PARA=1;

/* 13. renal disease) /*I12.0, I13.1, N03.2–N03.7, N05.2–N05.7, N18.x, N19.x, N25.0, Z49.0–Z49.2, Z94.0, Z99.2*/
else if substr(DX,1,3) in ('N18','N19') or 
		substr(DX,1,5) in ('I12.0','I13.1',
		  		      	   'N03.2','N03.3','N03.4','N03.5','N03.6','N03.7'
			    	  	   'N05.2','N05.3','N05.4','N05.5','N05.6','N05.7',
		   	    	  	   'N25.0',
			    	  	   'Z49.0','Z49.1','Z49.2','Z94.0','Z99.2') then RD=1;

/* 14. Any malignancy,including lymphoma and leukemia, except malignant neoplasm of skin
C00.x–C26.x, C30.x–C34.x, C37.x–C41.x, C43.x, C45.x–C58.x, C60.x– C76.x, C81.x–C85.x, C88.x, C90.x–C97.x */
else if substr(DX,1,2) in ('C0') or
        substr(DX,1,3) in 
('C10','C11','C12','C13','C14','C15','C16','C17','C18','C19',
 'C20','C21','C22','C23','C24','C25','C26',
 'C30','C31','C32','C33','C34',            'C37','C38','C39',        
 'C40','C41',      'C43',      'C45','C46','C47','C48','C49',
 'C50','C51','C52','C53','C54','C55','C56','C57','C58',
 'C60','C61','C62','C63','C64','C65','C66','C67','C68','C69',
 'C70','C71','C72','C73','C74','C75','C76',/*C7A missing*/
       'C81','C82','C83','C84','C85',            'C88',
 'C90','C91','C92','C93','C94','C95','C96','C97')  then CANCER=1;

/* 15. Moderate or severe liver disease   I85.0, I85.9, I86.4, I98.2, K70.4, K71.1, K72.1, K72.9, K76.5, K76.6, K76.7*/
else if substr(DX,1,5) in ('I85.0','I85.9','I86.4','I98.2','K70.4','K71.1','K72.1','K72.9','K76.5','K76.6','K76.7') then MSLD=1;

/*16. Metastatic solid tumor    C77.x–C80.x*/  
else if substr(DX,1,3) in ('C77','C78','C79','C80') then METS=1;

*17. HIV/AIDS B20.x-B22.x, B24.x;
else if substr(DX,1,3) in ('B20','B21','B22','B24') then HIV=1;

format DT_: mmddyy10.;
length DT_: 4.;
if dt_dx ne . ; 
if DT_DX <= today();*do not pull from future;
run;
*get max of each one /*30 seconds*/;
proc means data = dg nway noprint;
class scrssn_n DT_BASELINE; /*most patients have 2 records.. unique key is scrssn + DT_BASELINE */
var MI CHF PVD CEVD DEM COPD RHEUM PUD MILDLD DIAB_NC DIAB_C PARA RD CANCER MSLD METS HIV;
output out=charlson (drop=_:) max=  charl_MI  charl_CHF  charl_PVD  charl_CEVD charl_DEM charl_COPD charl_RHEUM charl_PUD  charl_MILDLD
                                    charl_DIAB_NC charl_DIAB_C charl_PARA  charl_RD charl_CANCER  charl_MSLD charl_METS charl_HIV; 
run;
*apply weights and sum;
data DCNP.CCI (keep= scrssn_n DT_BASELINE charl: CCI  );
retain scrssn_n DT_BASELINE charl: CCI
length CCI charl_MI  charl_CHF  charl_PVD  charl_CEVD charl_DEM  charl_COPD charl_RHEUM charl_PUD
charl_MILDLD charl_DIAB_NC charl_DIAB_C charl_PARA charl_CANCER  charl_MSLD charl_METS charl_HIV 3.;
set charlson;
CCI = 0;  /*if none of the 17 conditions are present CCI will stay 0*/

*a bit clunky but very explicit;
*take higher of diabetes, liver, and cancer;
if charl_DIAB_C = 1 then CCI = CCI + 2;
	else if  charl_DIAB_NC = 1 then CCI = CCI + 1;
if charl_MSLD  = 1 then CCI = CCI + 3; 
	else if charl_MILDLD = 1 then CCI = CCI + 1;
if charl_METS = 1 then CCI = CCI + 6;
	else if charl_CANCER  = 1 then CCI = CCI + 2;

if charl_MI = 1 then CCI = CCI + 1;
if charl_CHF = 1 then CCI = CCI + 1;
if charl_PVD = 1 then CCI = CCI + 1;
if charl_CEVD = 1 then CCI = CCI + 1;
if charl_DEM = 1 then CCI = CCI + 1; 
if charl_COPD = 1 then CCI = CCI + 1;
if charl_RHEUM = 1 then CCI = CCI + 1;
if charl_PUD = 1 then CCI = CCI + 1;

if charl_PARA = 1 then CCI = CCI + 2;
if charl_RD = 1 then CCI = CCI + 2;

if charl_HIV = 1 then CCI = CCI + 6;
run;
proc freq data=DCNP.CCI;
tables CCI;
run;
proc print data=DCNP.CCI (obs=10) noobs;
run;
proc means data=DCNP.CCI n nmiss;
var CCI;
run;














******* VACS Index components *******;
*ALB;
/*30 mins*/
data one;
set <redacted-sensitive information>DFT.FullVA_Labs_All (/*firstobs=1 obs=1000*/ keep = scrssn PatientICN Sta3n TOPOGRAPHY LABCHEMTESTNAME LabChemTestSID LabChemSpecimenDateTime LabChemResultValue 
rename = (sta3n = xsta3n PatientICN = xPatientICN )
where =( datepart(LabChemSpecimenDateTime) >= mdy(1,1,2016) and   
(
LABCHEMTESTNAME like '%ALB%' and
LABCHEMTESTNAME not like '%MICRO%' and 
LABCHEMTESTNAME not like '%URINE%' and
LABCHEMTESTNAME not like '%RATIO%' and 
LABCHEMTESTNAME not like '%PREALBUMIN%' and
LABCHEMTESTNAME not like '%PRE-ALBUMIN%' and 
LABCHEMTESTNAME not like '%FRACTION%' and
LABCHEMTESTNAME not like '%GLOB%' and 
TOPOGRAPHY not like '%URINE%' 
)
));

scrssn_n = scrssn * 1;
length sta3n 3. PatientICN $12.   DT_LAB TIM_LAB 4.  NAME  SPECIMEN $40. RES_TEXT $50.;

STA3N = xsta3n;
PatientICN = xPatientICN;
NAME = upcase(LABCHEMTESTNAME);
SPECIMEN = upcase(substr(topography,1,30));
RES_TEXT = upcase(LABCHEMRESULTVALUE);

length DT_LAB TIM_LAB 4.;
DT_LAB = datepart(LabChemSpecimenDateTime);
/*done this way to avoid duplication by differences in seconds*/
HOUR = hour(timepart(LabChemSpecimenDateTime));
MIN = minute(timepart(LabChemSpecimenDateTime));
TIM_LAB = hms(HOUR, MIN, 0);
format DT_LAB mmddyy8. TIM_LAB HHMM.;
drop x: scrssn TOPOGRAPHY  LabChemSpecimenDateTime LabChemTestName  LABCHEMRESULTVALUE HOUR min;

run;
proc freq data = one;
tables NAME;
run;
data two;
set one ;
/*change this if necessary*/
where  anydigit(RES_TEXT,1) > 0 /*number in result, drops cancel*/
and 
SPECIMEN in (
'BLOOD',
'BLOOD*',
'BLOOD.',
'CC SERUM',
'MOFH SERUM',
'PLASMA',
'SER/PLA',
'SER/PLAS',
'SERUM',
'WS-PLASMA');
USE = 'Y';

*clean up names and remove goofy prefixes;
length new_name $50.;
new_name = strip(NAME);/*leading blanks*/;
NEW_NAME = compbl(NEW_NAME);	/*double blanks*/

 if substr(new_name,1,4) = 'ZZZZ' then new_name = substr(new_name,5,50);
else if substr(new_name,1,3) = 'ZZZ' then new_name = substr(new_name,4,50);
else if substr(new_name,1,2) = 'ZZ' then new_name = substr(new_name,3,50);
else if substr(new_name,1,1) = 'Z' then new_name = substr(new_name,2,50);
else if substr(new_name,1,2) = 'U-' then new_name = substr(new_name,3,50);
NEW_NAME = tranwrd(NEW_NAME, 'CBOC', ''); /*remove CBOC*/
NEW_NAME = tranwrd(NEW_NAME, '.', ''); /*remove .*/
NEW_NAME = tranwrd(NEW_NAME, '*', ''); /*remove **/
 if substr(new_name,1,1) = '~' then new_name = substr(new_name,2,50);
else if substr(new_name,1,1) = '-' then new_name = substr(new_name,2,50);
else if substr(new_name,1,1) = '_' then new_name = substr(new_name,2,50);
new_name = strip(NEW_NAME);/*leading blanks*/;
NEW_NAME = compbl(NEW_NAME);	/*double blanks*/

*unwanted tests - not foolproof need to examine;
if index(NEW_NAME,'%') > 0 or 
index(NEW_NAME,'ALLERGEN') > 0 or 
index(NEW_NAME,'BOUND') > 0 or 
index(NEW_NAME,'BUTALBITAL') > 0 or 
index(NEW_NAME,'CANDIDA')	> 0 or 
index(NEW_NAME,'CSF')	> 0 or 
index(NEW_NAME,'FRACT') > 0 or 
index(NEW_NAME,'HCV RNA') > 0 or 
index(NEW_NAME,'HEPATITIS') > 0
then USE = 'N';
*look for any hint of urine;
*name, specimen, (nothing in result);
if index(NEW_NAME,'UR ') > 0 or 
index(NEW_NAME,'UR-') > 0 or 
index(NEW_NAME,'URIN') > 0 or 
index(NEW_NAME,'UALBUMIN') > 0 or 
index(NEW_NAME,'ALBUMIN, U') > 0 or 
index(NEW_NAME,'ALBUMIN,U') > 0 or 

index(NEW_NAME,'ALBUMIN, 24') > 0 or 
index(NEW_NAME,'ALB-U') > 0 or
index(NEW_NAME,'24H') > 0
then USE = 'N';

run; 
proc sort nodupkey data = two;
where USE = 'Y';
by LabChemTestSID PatientICN sta3n DT_LAB TIM_LAB RES_TEXT;
run;
*get numeric result;
data three;
set two ;
where USE = 'Y' ;
drop USE;

*virtually no < or >;
NEW_TEXT = RES_TEXT;
NEW_TEXT = compress(NEW_TEXT, 'L');
NEW_TEXT = compress(NEW_TEXT, 'H');
NEW_TEXT = compress(NEW_TEXT, '<');
NEW_TEXT = compress(NEW_TEXT, '>');
NEW_TEXT = compress(NEW_TEXT, '(R)');
NEW_TEXT = tranwrd(NEW_TEXT, '..','.'); /*repair double ..*/
if index(RES_TEXT,'*') > 0 then NEW_TEXT = compress(RES_TEXT, '*');
RES_NUM = NEW_TEXT * 1;
if RES_NUM eq . then RES_NUM = substr(NEW_TEXT,1,3); 

run;

*QC names;
PROC IMPORT OUT= WORK.Lookup DATAFILE= "<redacted-sensitive information>/Labs/Code_and_lookups/Albumin_lookup.csv" 
            DBMS=CSV REPLACE;     GETNAMES=YES;     DATAROW=2; 
RUN;

*whats in the lookup?;
proc freq data = lookup ;
tables LAB_CODE PREF ;
run;

*apply lookup;
proc sql;
create table four as
select L.*, LAB_CODE, upcase(PREF) as PREF
from three L,  lookup D
where   L.LABCHEMTESTSID = D.LABCHEMTESTSID  /*and L.sta3n = D.sta3n*/ 
	and upcase(PREF) in("Y","N") ;
quit;

proc freq data = four ;
tables LAB_CODE PREF ;
run;

data prune;
set four;
if LAB_CODE in("ALB") then do;
	if RES_NUM < 0 or RES_NUM > 10 then delete;
end;
run;

*grab most recent lab to baseline;
%macro labsbl(lab);
proc sql;
create table many as
select a.scrssn_n, a.DT_BASELINE, b.DT_LAB as DT_LAB_&lab, b.RES_NUM as LAB_&lab, abs(DT_BASELINE-DT_LAB) as DIFF_LAB_&lab
from finder a, prune b
where a.scrssn_n=b.scrssn_n and DT_BASELINE-(2*365) <= DT_LAB <= DT_BASELINE and LAB_CODE = "&lab"
ORDER BY a.scrssn_n, a.DT_BASELINE, PREF desc, DIFF_LAB_&lab;
run;quit;
data lab_&lab ;
set many;
by scrssn_n DT_BASELINE;
if first.DT_BASELINE;
run;
%mend;
%labsbl(ALB);
data DCNP.LABS_ALB;
merge LAB_ALB  ;
by scrssn_n DT_BASELINE;
run;
proc print data = DCNP.LABS_ALB (obs=50) noobs;
run;
proc means data = DCNP.LABS_ALB n nmiss nolabels min p1 p99 max maxdec=1;
var LAB:;
run;












*ALT/AST;
data one;
set <redacted-sensitive information>DFT.FullVA_Labs_All (/*firstobs=1 obs=1000*/ keep = scrssn PatientICN Sta3n TOPOGRAPHY LABCHEMTESTNAME LabChemTestSID LabChemSpecimenDateTime LabChemResultValue 
rename = (sta3n = xsta3n PatientICN = xPatientICN )
where =( datepart(LabChemSpecimenDateTime) >= mdy(1,1,2016) and   
(
LABCHEMTESTNAME like '%ALT%' or
LABCHEMTESTNAME like '%AST%' or
LABCHEMTESTNAME like '%SGPT%' or
LABCHEMTESTNAME like '%SGOT%' or
LABCHEMTESTNAME like '%ASPARTATE' or
LABCHEMTESTNAME like 'ALANINE' or
LABCHEMTESTNAME like 'TRANSFERASE'
)
));

scrssn_n = scrssn * 1;
length sta3n 3. PatientICN $12.   DT_LAB TIM_LAB 4.  NAME  SPECIMEN $40. RES_TEXT $50.;

STA3N = xsta3n;
PatientICN = xPatientICN;
NAME = upcase(LABCHEMTESTNAME);
SPECIMEN = upcase(substr(topography,1,30));
RES_TEXT = upcase(LABCHEMRESULTVALUE);

length DT_LAB TIM_LAB 4.;
DT_LAB = datepart(LabChemSpecimenDateTime);
/*done this way to avoid duplication by differences in seconds*/
HOUR = hour(timepart(LabChemSpecimenDateTime));
MIN = minute(timepart(LabChemSpecimenDateTime));
TIM_LAB = hms(HOUR, MIN, 0);
format DT_LAB mmddyy8. TIM_LAB HHMM.;
drop x: scrssn TOPOGRAPHY  LabChemSpecimenDateTime LabChemTestName  LABCHEMRESULTVALUE HOUR min;

run;
proc freq data = one;
tables NAME;
run;
data two;
set one ;
/*change this if necessary*/
where  anydigit(RES_TEXT,1) > 0 /*number in result, drops cancel*/
and 
SPECIMEN in (
'SERUM',
'PLASMA',
'BLOOD',
'SER/PLA',
'BLOOD*',
'SER/PLAS',   
'WS-PLASMA',  
'BLOOD.',     
'CC SERUM',
'MOFH SERUM',
'MOFH BLOOD',
'HIBBING SERUM',
'VENOUS BLOOD',
'SERUM+PLASMA') ;
USE = 'Y';

*debulk unwanted tests, doesn't have to be perfect;
if index(NAME,'ALTERN')>0 or
   index(NAME,'ASTROVIRUS')>0 or
   index(NAME,'CAST')>0 or
   index(NAME,'COBALT')>0 or
   index(NAME,'BLAST')>0 or
   index(NAME,'EAST')>0 or
   index(NAME,'FASTING')>0 or
   index(NAME,'GAMMA')>0 or
   index(NAME,'GAST')>0 or
   index(NAME,'GLUTAMYL')>0 or
   index(NAME,'IGE')>0 or
   index(NAME,'IGG')>0 or
   index(NAME,'LAST')>0 or
   index(NAME,'PUBLIC HEALTH')>0 or
   index(NAME,'RALTEGRAVIR')>0 or
   index(NAME,'RAST')>0 or
   index(NAME,'RATIO')>0 or
   index(NAME,'THIOPURINE')>0 or
   index(NAME,'YEAST')>0 
      then LAB_CODE = 'XXX';
run; 

proc sort nodupkey data = two;
where USE = 'Y';
by LabChemTestSID PatientICN sta3n DT_LAB TIM_LAB RES_TEXT;
run;

*get numeric result;
data three;
set two ;
where USE = 'Y' and  LAB_CODE ne 'XXX';
drop USE;

UP_TEXT = RES_TEXT;
UP_TEXT = tranwrd(UP_TEXT,'< ','<');
UP_TEXT = tranwrd(UP_TEXT,'> ','>');
UP_TEXT = tranwrd(UP_TEXT,'(UL)','');

*some < or >;

if index(RES_TEXT, '<') > 0 then VAL = 'LT';
else if index(RES_TEXT, '>') > 0 then VAL = 'GT';
else VAL = 'EQ';

RES_NUM = RES_TEXT * 1;
*hard code most common, helps identify typos*;
     if UP_TEXT in ('<3','<3.','<3.0','<3.00') then RES_NUM = 3;
else if UP_TEXT in ('<4','<4.','<4.0','<4.00') then RES_NUM = 4;
else if UP_TEXT in ('<5','<5.','<5.0','<5.00','>5') then RES_NUM = 5;
else if UP_TEXT in ('<6','<6.','<6.0','<6.00') then RES_NUM = 6;
else if UP_TEXT in ('<7','<7.','<7.0','<7.00') then RES_NUM = 7;
else if UP_TEXT in ('<8','<8.','<8.0','<8.00') then RES_NUM = 8;
else if UP_TEXT in ('<9','<9.','<9.0','<9.00') then RES_NUM = 9;
else if UP_TEXT in ('<10','<10.0') then RES_NUM = 10;
else if UP_TEXT in ('>3039','<3039') then RES_NUM = 3039;
if RES_NUM = . then RES_NUM = UP_TEXT * 1;
if RES_NUM = . then RES_NUM = substr(UP_TEXT,2,5) * 1;

*don't worry about length not keeping it!;
YEAR = year(DT_LAB) ;
drop LAB_CODE;

run;

*QC names;
PROC IMPORT OUT= WORK.Lookup DATAFILE= "<redacted-sensitive information>/Labs/Code_and_lookups/ALT_AST_lookup.csv" 
            DBMS=CSV REPLACE;     GETNAMES=YES;     DATAROW=2; 
RUN;

*whats in the lookup?;
proc freq data = lookup ;
tables LAB_CODE PREF ;
run;

*apply lookup;
proc sql;
create table four as
select L.*, LAB_CODE, upcase(PREF) as PREF
from three L,  lookup D
where   L.LABCHEMTESTSID = D.LABCHEMTESTSID  /*and L.sta3n = D.sta3n*/ 
	and upcase(PREF) in("Y","N") ;
quit;

proc freq data = four ;
tables LAB_CODE PREF ;
run;

data prune;
set four;
if LAB_CODE in("ALT" "AST") then do;
	if RES_NUM < 0 or RES_NUM > 1000 then delete;
end;
run;

*grab most recent lab to baseline;
%macro labsbl(lab);
proc sql;
create table many as
select a.scrssn_n, a.DT_BASELINE, b.DT_LAB as DT_LAB_&lab, b.RES_NUM as LAB_&lab, abs(DT_BASELINE-DT_LAB) as DIFF_LAB_&lab
from finder a, prune b
where a.scrssn_n=b.scrssn_n and DT_BASELINE-(365*2) <= DT_LAB <= DT_BASELINE and LAB_CODE = "&lab"
ORDER BY a.scrssn_n, a.DT_BASELINE, PREF desc, DIFF_LAB_&lab;
run;quit;
data lab_&lab ;
set many;
by scrssn_n DT_BASELINE;
if first.DT_BASELINE;
run;
%mend;
%labsbl(ALT);
%labsbl(AST);
data DCNP.LABS_ALTAST;
merge LAB_ALT LAB_AST ;
by scrssn_n DT_BASELINE;
run;
proc print data = DCNP.LABS_ALTAST (obs=50) noobs;
run;
proc means data = DCNP.LABS_ALTAST n nmiss nolabels min max maxdec=1;
var LAB:;
run;














*CREAT;
data one;
set <redacted-sensitive information>DFT.FullVA_Labs_All (/*firstobs=1 obs=1000*/ keep = scrssn PatientICN Sta3n TOPOGRAPHY LABCHEMTESTNAME LabChemTestSID LabChemSpecimenDateTime LabChemResultValue 
rename = (sta3n = xsta3n PatientICN = xPatientICN )
where =( datepart(LabChemSpecimenDateTime) >= mdy(1,1,2016) and   
(
(LABCHEMTESTNAME like '%CREAT%' or LABCHEMTESTNAME like '%EGFR%') and
LABCHEMTESTNAME not like '%URIN%' and 
LABCHEMTESTNAME not like '%24 HR%' and 
LABCHEMTESTNAME not like '%RATIO%' and 
LABCHEMTESTNAME not like '%RECIP%' and 
TOPOGRAPHY not like '%URIN%' and 
TOPOGRAPHY not like '%24 HR%'
)
));

scrssn_n = scrssn * 1;
length sta3n 3. PatientICN $12.   DT_LAB TIM_LAB 4.  NAME  SPECIMEN $40. RES_TEXT $50.;

STA3N = xsta3n;
PatientICN = xPatientICN;
NAME = upcase(LABCHEMTESTNAME);
SPECIMEN = upcase(substr(topography,1,30));
RES_TEXT = upcase(LABCHEMRESULTVALUE);

length DT_LAB TIM_LAB 4.;
DT_LAB = datepart(LabChemSpecimenDateTime);
/*done this way to avoid duplication by differences in seconds*/
HOUR = hour(timepart(LabChemSpecimenDateTime));
MIN = minute(timepart(LabChemSpecimenDateTime));
TIM_LAB = hms(HOUR, MIN, 0);
format DT_LAB mmddyy8. TIM_LAB HHMM.;
drop x: scrssn TOPOGRAPHY  LabChemSpecimenDateTime LabChemTestName  LABCHEMRESULTVALUE HOUR min;

run;
proc freq data = one;
tables NAME;
run;
data two;
set one ;
/*change this if necessary*/
where  anydigit(RES_TEXT,1) > 0 /*number in result, drops cancel*/
and 
SPECIMEN in (
'SERUM',
'PLASMA',
'BLOOD',
'SER/PLA',
'BLOOD, VENOUS',
'BLOOD*',
'BLOOD.',
'VENOUS BLOOD',
'VENOUS BLD',
'BLOOD VENOUS',
'BLOOD (UNSPUN)',
'PLAS',
'WHOLE BLOOD',
'SER/PLAS'
) ;
USE = 'Y';

*debulk unwanted tests, doesn't have to be perfect;
if index(NAME,'BUN/CREA')> 0 or 
index(NAME,'KINASE') > 0 or
index(NAME,'PANCREA')> 0 or
index(NAME,'24HR')> 0 
then USE = 'N';

run; 

proc sort nodupkey data = two;
where USE = 'Y';
by LabChemTestSID PatientICN sta3n DT_LAB TIM_LAB RES_TEXT;
run;

*get numeric result;
data three;
set two ;
where USE = 'Y';
drop USE;

UP_TEXT = RES_TEXT;
UP_TEXT = tranwrd(UP_TEXT,'< ','<');
UP_TEXT = tranwrd(UP_TEXT,'> ','>');
UP_TEXT = tranwrd(UP_TEXT,'>= ','>');

*some < or >;
if index(RES_TEXT, '<') > 0 then VAL = 'LT';
else if index(RES_TEXT, '>') > 0 then VAL = 'GT';
else VAL = 'EQ';

RES_NUM = RES_TEXT * 1;
*hard code most common to avoid obvious data entry error;
if RES_TEXT in ('>60','>60.0','> 60','>=60','>=60.0','>61','>59','>660') then RES_NUM = 60; /*eGFR*/
else if   RES_TEXT in ('>20','>20.0','>22.6','>22.7') then RES_NUM = 20; /*creat*/
else if   RES_TEXT in ('>13','>13.0') then RES_NUM = 13; /*creat*/
else if   RES_TEXT in ('>15','>15.','>15.0','>14.0','>14.8', '>14.9','>16.4' ) then RES_NUM = 15; /*creat*/
else if   RES_TEXT in ('>25','>25.0','>25.00','> 25' ) then RES_NUM = 25; /*creat*/

else if   RES_TEXT in ('<0.2','<0.2','<0.02') then RES_NUM = .2; /*creat*/
 

if RES_NUM = . then RES_NUM = substr(UP_TEXT,2,5) * 1;

*don't worry about length not keeping it!;
YEAR = year(DT_LAB) ;

run;

*QC names;
PROC IMPORT OUT= WORK.Lookup DATAFILE= "<redacted-sensitive information>/Labs/Code_and_lookups/creat_lookup.csv" 
            DBMS=CSV REPLACE;     GETNAMES=YES;     DATAROW=2; 
RUN;

*whats in the lookup?;
proc freq data = lookup ;
tables LAB_CODE PREF ;
run;

*apply lookup;
proc sql;
create table four as
select L.*, LAB_CODE, upcase(PREF) as PREF
from three L,  lookup D
where   L.LABCHEMTESTSID = D.LABCHEMTESTSID  /*and L.sta3n = D.sta3n*/ 
	and upcase(PREF) in("Y","N") ;
quit;

proc freq data = four ;
tables LAB_CODE ;
run;

data prune;
set four;
if LAB_CODE in("CREAT") then do;
	if RES_NUM < 0 or RES_NUM > 30 then delete;
end;
run;

proc means data=four n nmiss min max maxdec=1;
var RES_NUM;
where LAB_CODE in("CREAT");
run;
proc means data=prune n nmiss min max maxdec=1;
var RES_NUM;
where LAB_CODE in("CREAT");
run;


*grab most recent lab to baseline;
%macro labsbl(lab);
proc sql;
create table many as
select a.scrssn_n, a.DT_BASELINE, b.DT_LAB as DT_LAB_&lab, b.RES_NUM as LAB_&lab, abs(DT_BASELINE-DT_LAB) as DIFF_LAB_&lab
from finder a, prune b
where a.scrssn_n=b.scrssn_n and DT_BASELINE-(365*2) <= DT_LAB <= DT_BASELINE and LAB_CODE = "&lab"
ORDER BY a.scrssn_n, a.DT_BASELINE, PREF desc, DIFF_LAB_&lab;
run;quit;
data lab_&lab ;
set many;
by scrssn_n DT_BASELINE;
if first.DT_BASELINE;
run;
%mend;
%labsbl(CREAT);
data DCNP.LABS_CREAT;
merge LAB_CREAT  ;
by scrssn_n DT_BASELINE;
run;
proc print data = DCNP.LABS_CREAT (obs=50) noobs;
run;
proc means data = DCNP.LABS_CREAT n nmiss nolabels min max maxdec=1;
var LAB:;
run;














*HGB;
data one;
set <redacted-sensitive information>DFT.FullVA_Labs_All (/*firstobs=1 obs=1000*/ keep = scrssn PatientICN Sta3n TOPOGRAPHY LABCHEMTESTNAME LabChemTestSID LabChemSpecimenDateTime LabChemResultValue 
rename = (sta3n = xsta3n PatientICN = xPatientICN )
where =( datepart(LabChemSpecimenDateTime) >= mdy(1,1,2016) and   
(
(LABCHEMTESTNAME like '%HGB%' or 
LABCHEMTESTNAME like '%HEMOGLOBIN%' or 
LABCHEMTESTNAME like '%THB%') and
LABCHEMTESTNAME not like '%A1C%' and 
LABCHEMTESTNAME not like '%GLYC%'
)
));

scrssn_n = scrssn * 1;
length sta3n 3. PatientICN $12.   DT_LAB TIM_LAB 4.  NAME  SPECIMEN $40. RES_TEXT $50.;

STA3N = xsta3n;
PatientICN = xPatientICN;
NAME = upcase(LABCHEMTESTNAME);
SPECIMEN = upcase(substr(topography,1,30));
RES_TEXT = upcase(LABCHEMRESULTVALUE);

length DT_LAB TIM_LAB 4.;
DT_LAB = datepart(LabChemSpecimenDateTime);
/*done this way to avoid duplication by differences in seconds*/
HOUR = hour(timepart(LabChemSpecimenDateTime));
MIN = minute(timepart(LabChemSpecimenDateTime));
TIM_LAB = hms(HOUR, MIN, 0);
format DT_LAB mmddyy8. TIM_LAB HHMM.;
drop x: scrssn TOPOGRAPHY  LabChemSpecimenDateTime LabChemTestName  LABCHEMRESULTVALUE HOUR min;

run;
proc freq data = one;
tables NAME;
run;
data two;
set one ;
/*change this if necessary*/
where  anydigit(RES_TEXT,1) > 0 /*number in result, drops cancel*/
and 
SPECIMEN in (
'BLOOD',
'ARTERIAL BLOOD',
'WHOLE BLOOD',
'VENOUS BLOOD',
'BLOOD, VENOUS',
'SERUM',
'ARTERIAL BLD',
'VENOUS BLD',
'BLOOD, ARTERIAL',
'BLOOD VENOUS',
'MIXED VENOUS BLOOD',
'MIXED VENOUS',
'MIXED VEN BLOOD',
'PERIPHERAL VENOUS',
'PLASMA',
'BLOOD UNSPECIFIED',
'MIXED VENOUS BLOOD',
'BLOOD MIXED ART/VE',
'WS-BLOOD',
'LC-BLO',
'CENTRAL LINE');

USE = 'Y';

*debulk unwanted tests, doesn't have to be perfect;
if
index (NAME, 'A1C') > 0 or
index (NAME, 'ABNORM') > 0 or
index (NAME, 'ACID') > 0 or
index (NAME, 'BARTS')> 0 or
index (NAME, 'CALC') > 0 or
index (NEW_NAME, 'DIS PAN')> 0 or
index (NAME, 'DONOR') > 0 or
index (NAME, 'ELECT') > 0 or
index (NAME, 'FETAL') > 0 or
index (NAME, 'FREE') > 0 or
index (NAME, 'GLYC') > 0 or
index (NAME, 'HCT')> 0 or
index (NAME, 'HGB PANEL') > 0 or
index (NAME, 'INTERP') > 0 or
index (NAME, 'MCH') > 0 or
index (NAME, 'MCV') > 0 or
index (NAME, 'MEAN') > 0 or
index (NAME, 'METH') > 0 or
index (NAME, 'OTHER') > 0 or
index (NAME, 'OPTHY') > 0 or
index (NAME, 'OXY') > 0 or
index (NAME, 'O2') > 0 or
index (NAME, 'PATH') > 0 or
index (NAME, 'PHENO') > 0 or
index (NAME, 'PLASMA') > 0 or
index (NAME, 'SERUM') > 0 or
index (NAME, 'REDUCED') > 0 or
index (NAME, 'SOL') > 0 or
index (NAME, 'SULF') > 0 or
index (NAME, 'RETIC') > 0 or
index (NAME, 'VARIANT') > 0  then USE = 'N';

run; 

proc sort nodupkey data = two;
where USE = 'Y';
by LabChemTestSID PatientICN sta3n DT_LAB TIM_LAB RES_TEXT;
run;

*get numeric result;
data three;
set two ;
where USE = 'Y';
drop USE;

UP_TEXT = RES_TEXT;
UP_TEXT = tranwrd(UP_TEXT,'< ','<');
UP_TEXT = tranwrd(UP_TEXT,'> ','>');
UP_TEXT = tranwrd(UP_TEXT,'>= ','>');

*some < or >;
if index(RES_TEXT, '<') > 0 then VAL = 'LT';
else if index(RES_TEXT, '>') > 0 then VAL = 'GT';
else VAL = 'EQ';

RES_NUM = RES_TEXT * 1;
if RES_NUM = . then RES_NUM = substr(UP_TEXT,2,5) * 1;

*don't worry about length not keeping it!;
YEAR = year(DT_LAB) ;

run;

*QC names;
PROC IMPORT OUT= WORK.Lookup DATAFILE= "<redacted-sensitive information>/Labs/Code_and_lookups/Hgb_A1C_Lookup.csv" 
            DBMS=CSV REPLACE;     GETNAMES=YES;     DATAROW=2; 
RUN;

*whats in the lookup?;
proc freq data = lookup ;
tables LAB_CODE PREF ;
run;

*apply lookup;
proc sql;
create table four as
select L.*, LAB_CODE, upcase(PREF) as PREF
from three L,  lookup D
where   L.LABCHEMTESTSID = D.LABCHEMTESTSID  /*and L.sta3n = D.sta3n*/ 
	and upcase(PREF) in("Y","N") ;
quit;

proc freq data = four ;
tables LAB_CODE PREF ;
run;

data prune;
set four;
if LAB_CODE in("HGB") then do;
	if RES_NUM < 4 or RES_NUM > 20 then delete;
end;
run;

*grab most recent lab to baseline;
%macro labsbl(lab);
proc sql;
create table many as
select a.scrssn_n, a.DT_BASELINE, b.DT_LAB as DT_LAB_&lab, b.RES_NUM as LAB_&lab, abs(DT_BASELINE-DT_LAB) as DIFF_LAB_&lab
from finder a, prune b
where a.scrssn_n=b.scrssn_n and DT_BASELINE-(365*2) <= DT_LAB <= DT_BASELINE and LAB_CODE = "&lab"
ORDER BY a.scrssn_n, a.DT_BASELINE, PREF desc, DIFF_LAB_&lab;
run;quit;
data lab_&lab ;
set many;
by scrssn_n DT_BASELINE;
if first.DT_BASELINE;
run;
%mend;
%labsbl(HGB);
data DCNP.LABS_HGB;
merge LAB_HGB  ;
by scrssn_n DT_BASELINE;
run;
proc print data = DCNP.LABS_HGB (obs=50) noobs;
run;
proc means data = DCNP.LABS_HGB n nmiss nolabels min max maxdec=1;
var LAB:;
run;















*PLT and WBC;
data one;
set <redacted-sensitive information>DFT.FullVA_Labs_All (/*firstobs=1 obs=1000*/ keep = scrssn PatientICN Sta3n TOPOGRAPHY LABCHEMTESTNAME LabChemTestSID LabChemSpecimenDateTime LabChemResultValue 
rename = (sta3n = xsta3n PatientICN = xPatientICN )
where =( datepart(LabChemSpecimenDateTime) >= mdy(1,1,2016) and
(
LABCHEMTESTNAME like '%PLATELET%' or
LABCHEMTESTNAME like '%PLT%' or 
LABCHEMTESTNAME like '%WBC%' or 
(LABCHEMTESTNAME like '%WHITE%' and LABCHEMTESTNAME like '%CELL%')
)
));

scrssn_n = scrssn * 1;
length sta3n 3. PatientICN $12.   DT_LAB TIM_LAB 4.  NAME  SPECIMEN $40. RES_TEXT $50.;

STA3N = xsta3n;
PatientICN = xPatientICN;
NAME = strip(upcase(LABCHEMTESTNAME));*remove leading blanks;
SPECIMEN = upcase(substr(topography,1,30));
RES_TEXT = upcase(LABCHEMRESULTVALUE);

length DT_LAB TIM_LAB 4.;
DT_LAB = datepart(LabChemSpecimenDateTime);
/*done this way to avoid duplication by differences in seconds*/
HOUR = hour(timepart(LabChemSpecimenDateTime));
MIN = minute(timepart(LabChemSpecimenDateTime));
TIM_LAB = hms(HOUR, MIN, 0);
format DT_LAB mmddyy8. TIM_LAB HHMM.;
drop x: scrssn TOPOGRAPHY  LabChemSpecimenDateTime LabChemTestName  LABCHEMRESULTVALUE HOUR min;
run;
data two;
set one ;

KEEP = 'Y';
*unwanted tests, flag here, drop next step;
*this is to debulk, fine tune later steps;
if 
   index(NAME,'AGG')>0 or
   index(NAME,'ANTI')>0 or
   index(NAME,'ASPIRIN')>0 or
   index(NAME,'CITRATE')>0 or
   index(NAME,'CLUMP')>0 or
   index(NAME,'COAST')>0 or
   index(NAME,'COBALT')>0 or
   index(NAME,'COVID')>0 or
   index(NAME,'CREAT')>0 or
    index(NAME,'ESTIMATE')>0 or
   index(NAME,'(ESTM')>0 or
   index(NAME,'FACTOR')>0 or
   index(NAME,'FRACTION')>0 or
   index(NAME,'FUNC')>0 or
   index(NAME,'GAMMA')>0 or
   index(NAME,'GIANT')>0 or
   index(NAME,'GLOBULIN')>0 or
   index(NAME,'GLUTAMYL')>0 or
   index(NAME,'GLYCO')>0 or
   index(NAME,'HEALTH')>0 or
   index(NAME,'HEPARIN')>0 or
   index(NAME,'HLA')>0 or
   index(NAME,'IGE')>0 or
   index(NAME,'IGG')>0 or
   index(NAME,'IGM')>0 or
   index(NAME,'IMM')>0 or
   index(NAME,'LARGE')>0 or
   index(NAME,'MORPH')>0 or
   index(NAME,'NEUTR')>0 or
   index(NAME,'PACK')>0 or
   index(NAME,'PLT AB')>0 or
   index(NAME,'PLATELET AB')>0 or
   index(NAME,'PLATELET ASSOC')>0 or
   index(NAME,'RATIO')>0 or
   index(NAME,'STAIN')>0 or
   index(NAME,'THIOPURINE')>0 or 
 
index(NAME,'%')> 0 or
index(NAME,'/100WBC')> 0 or
index(NAME,'ANTIBOD')> 0 or

index(NAME,'BASOPHIL')> 0 or
index(NAME,'BRONCH')> 0 or

index(NAME,'CAST')> 0 or
index(NAME,'CLOZAPINE')> 0 or
index(NAME,'CLOZARIL')> 0 or
index(NAME,'CLUMP')> 0 or
index(NAME,'CSF')> 0 or
index(NAME,'CYSTIN')> 0 or
index(NAME,'EOSIN')> 0 or
index(NAME,'FECAL')> 0 or
index(NAME,'FLUID')> 0 or
index(NAME,'GALACTOS')> 0 or

index(NAME,'HEXOSAMINIDASE')> 0 or
index(NAME,'HYPERSEG')> 0 or
index(NAME,'IMMUNO')> 0 or

index(NAME,'LYMPHS')> 0 or
index(NAME,'MANUAL UR')> 0 or
index(NAME,'MONOCYTE')> 0 or
index(NAME,'MORPH')> 0 or
index(NAME,'NEUTROPHIL')> 0 or
index(NAME,'NRBC/100')> 0 or

index(NAME,'NUC RBC')> 0 or
index(NAME,'NUCLEATED')> 0 or
index(NAME,'OTHER WBC')> 0 or
index(NAME,'PAROXYSMAL')> 0 or
index(NAME,'PERICARD')> 0 or
index(NAME,'PLEURAL')> 0 or
index(NAME,'PNH PANEL')> 0 or
index(NAME,'PNH,')> 0 or
index(NAME,'POC')> 0 or
index(NAME,'SEMEN')> 0 or
index(NAME,'SEMINAL')> 0 or
index(NAME,'SMEAR')> 0 or
index(NAME,'SMUDGE')> 0 or
 index(NAME,'SPERM')> 0 or

index(NAME,'STOOL')> 0 or
index(NAME,'SYNOVIAL')> 0 or

index(NAME,'UA WBC')> 0 or
index(NAME,'UR WHITE')> 0 or
index(NAME,'UR WBC')> 0 or   
index(NAME,'URINE')> 0 or
index(NAME,'WBC/HPF')> 0  or
index(NAME,'WBC UA TAMC')> 0 or
index(NAME,'WBC UR')> 0    
      then KEEP = 'N';
else if index(NAME,'WHITESBURG')> 0 then KEEP = 'X';
*override;
if NAME = 'ZZWBC-WHITESBURG' then KEEP = 'Y';
if LabChemTestSID = 1400009468   then KEEP = 'Y'; /*PLATELET-(NANTICOKE)  */


*delete junk;
*these must have a numeric result;
if anydigit(RES_TEXT) = 0 then delete;

else if 
index(NAME,'BIZARRE')>0 or 
index(NAME,'CALCIUM OX')>0 or 
index(NAME,'ESTM')>0 or 
index(NAME,'FCN SCREEN')>0 or 
index(NAME,'GENO')>0 or 
index(NAME,'GRANUL')>0 or 
index(NAME,'MANUAL')>0 or 
index(NAME,'MYAST')>0 or 
index(NAME,'SLIDE')>0 or
index(NAME,'SMEAR')>0 or 
index(NAME,'SUFFICIENCY')>0 or
(index(NAME,'PLATELET') >0  and index(NAME,'EST')>0 )or
(index(NAME,'PLATELET') >0  and index(NAME,'CONF')>0 )or
(index(NAME,'PLT') >0       and index(NAME,'EST')>0 ) or
(index(NAME,'PLT') >0       and index(NAME,'AVG')>0 ) or
(index(NAME,'PLT') >0       and index(NAME,'SCAN')>0 ) or
(index(NAME,'PLT') >0       and index(NAME,'LARG')>0 )
then delete;

if NAME = 'WBC SLIDE COMMENT' then delete;

*limited to specimens with at least 100 records, top 5 cover 99.5%;
if  SPECIMEN in (
'BLOOD',
'BLOOD 668',
'BLOOD FRANCISCAN',
'BLOOD(SO)',
'BLOOD, OTHER CELLS',
'BLOOD, WHOLE',
'BLOOD/WHOLE',
'BLOOD-C',
'HIBBING BLOOD',
'MOFH BLOOD',
'OPCC-BLOOD',
'PLASMA',
'SERUM',
'ST.JAMES BLOOD',
'UNKNOWN',
'VENOUS BLOOD',
'WHOLE BLOOD',
'WHOLE BLOOD-B',
'WS-BLOOD',
'ZZSERUM, EDTA BLOOD AND URINE',
'1 GREEN & 1 LAVENDER'
);
run; 
proc sort nodupkey data = two;
where KEEP = 'Y';
by LabChemTestSID scrssn_n sta3n DT_LAB TIM_LAB RES_TEXT;
run;

data three;
set two ;
where KEEP = 'Y';
drop KEEP;
run;


PROC IMPORT OUT= lookup DATAFILE= "<redacted-sensitive information>/Labs/Code_and_lookups/PLT_WBC_Lookup.csv" 
            DBMS=CSV REPLACE;     GETNAMES=YES;     DATAROW=2; 
RUN;

*whats in the lookup?;
proc freq data = lookup ;
tables LAB_CODE PREF ;
run;

*apply lookup;
proc sql;
create table four as
select L.*, LAB_CODE, upcase(PREF) as PREF
from three L,  lookup D
where   L.LABCHEMTESTSID = D.LABCHEMTESTSID  /*and L.sta3n = D.sta3n*/ 
	and upcase(PREF) in("Y","N") ;
quit;

proc freq data= four;
tables  LAB_CODE PREF*LAB_CODE  /list missing;
run;

*get numeric result;
data five;
set four ;
RES_NUM = RES_TEXT * 1;

if RES_NUM = . then do; 
	*make a copy of result;
	UP_TEXT = RES_TEXT;
	UP_TEXT = tranwrd(UP_TEXT, '> ','>');
	     if index (UP_TEXT, '<') then VAL = 'LT';
	else if index (UP_TEXT, '>') then VAL = 'GT';
	*start with most complex;
	UP_TEXT = tranwrd(UP_TEXT,'THOUS/CUMM','');
	UP_TEXT = tranwrd(UP_TEXT,'THOUS/MCL',''); 
	UP_TEXT = tranwrd(UP_TEXT,'THOU/CUMM','');
	UP_TEXT = tranwrd(UP_TEXT,'THOU/CMM','');
	UP_TEXT = tranwrd(UP_TEXT,'THOU/MM3','');
	UP_TEXT = tranwrd(UP_TEXT,'THOU/MM',''); 
	UP_TEXT = tranwrd(UP_TEXT,'THOU/UL','');
	UP_TEXT = tranwrd(UP_TEXT,'THOU/MCL',''); 
	UP_TEXT = tranwrd(UP_TEXT,'TH/MM3','');
	UP_TEXT = tranwrd(UP_TEXT,'TH/CUMM','');
	UP_TEXT = tranwrd(UP_TEXT,'K/UL','');

	UP_TEXT = compress(UP_TEXT,'L');
	UP_TEXT = compress(UP_TEXT,'H');

	if LAB_CODE = 'PLT' then do;
	UP_TEXT = compress(UP_TEXT,'(R)');
	UP_TEXT = compress(UP_TEXT,'V');
	UP_TEXT = compress(UP_TEXT,'!');
	UP_TEXT = compress(UP_TEXT,'<');
	UP_TEXT = compress(UP_TEXT,'>');
	if index(UP_TEXT, '*') > 0 then UP_TEXT = compress(UP_TEXT,'*');
	RES_NUM = UP_TEXT * 1;
	if LabChemTestSID = 1200098044 then RES_NUM = substr(UP_TEXT,1,3) * 1;
	if LabChemTestSID in (800021752 800072498 1000040035) then delete;

	end; /*PLT*/
	if LAB_CODE = 'WBC' then do;
	     if index(UP_TEXT,'<0.1') or index(UP_TEXT,'<.1') then RES_NUM = .1;
	else if index(UP_TEXT,'<0.2') or index(UP_TEXT,'<.2') then RES_NUM = .2;
	else if index(UP_TEXT,'<0.3') or index(UP_TEXT,'<.3') then RES_NUM = .3;
	else if index(UP_TEXT,'<0.4') or index(UP_TEXT,'<.4') then RES_NUM = .4;
	else if index(UP_TEXT,'<0.5') or index(UP_TEXT,'<.5') then RES_NUM = .5;



	*remove non-numeric bits;
	UP_TEXT = compress(UP_TEXT, '<');
	UP_TEXT = compress(UP_TEXT, '>');
	UP_TEXT = tranwrd(UP_TEXT, '..','.'); /*2 decimal pts*/
	UP_TEXT = tranwrd(UP_TEXT, '.,','.'); 
	UP_TEXT = tranwrd(UP_TEXT, ',.','.'); 
	UP_TEXT = tranwrd(UP_TEXT, './','.'); 
	UP_TEXT = tranwrd(UP_TEXT, '/.','.'); 
	UP_TEXT = tranwrd(UP_TEXT, ';','.'); 
	UP_TEXT = tranwrd(UP_TEXT, '.O','.0');/*upper case O to zero*/
	UP_TEXT = tranwrd(UP_TEXT, 'O.','0.');/*upper case O to zero*/

	RES_NUM = round(UP_TEXT * 1,.1);
	format RES_NUM 5.1;

	*whatever is left ;
	*remove non-numeric bits;
	UP_TEXT = compress(UP_TEXT, '<');
	UP_TEXT = compress(UP_TEXT, '>');
	UP_TEXT = tranwrd(UP_TEXT, '..','.'); /*2 decimal pts*/
	UP_TEXT = tranwrd(UP_TEXT, '.,','.'); 
	UP_TEXT = tranwrd(UP_TEXT, ',.','.'); 
	UP_TEXT = tranwrd(UP_TEXT, './','.'); 
	UP_TEXT = tranwrd(UP_TEXT, '/.','.'); 
	UP_TEXT = tranwrd(UP_TEXT, ';','.'); 
	UP_TEXT = tranwrd(UP_TEXT, '.O','.0');/*upper case O to zero*/
	UP_TEXT = tranwrd(UP_TEXT, 'O.','0.');/*upper case O to zero*/
	if RES_NUM = . then do;
	RES_NUM = round(UP_TEXT * 1,.1);
	format RES_NUM 5.1;
	end;
	if RES_NUM = . then do;
	DREGS = 'Y';
	*location of punctuation;
	LOC_DOT =  INDEX(UP_TEXT,'.');
	LOC_COM =  INDEX(UP_TEXT,',');
	LOC_NUM = anydigit(UP_TEXT, 1);
	LOC_PAREN = INDEX(UP_TEXT,'(');
	LOC_M = INDEX(UP_TEXT,'M');
	*length of text;
	LEN = length(UP_TEXT);

	*wrong units 4,400 or  10,500;
	if LEN >= 5 and LOC_COM in (2 3) then RES_NUM = substr(UP_TEXT,1,LOC_COM - 1) + substr(UP_TEXT,LOC_COM + 1, len)/1000;
	* comma in place of decimal 4,8;
	if LEN = 3 and LOC_DOT = 0 and LOC_COM = 2 then RES_NUM = substr(UP_TEXT,1,LOC_COM - 1) + substr(UP_TEXT,LOC_COM + 1, len)/10;   
	* comma in place of decimal 15,8;
	if LEN = 4 and LOC_DOT = 0 and LOC_COM = 3 then RES_NUM = substr(UP_TEXT,1,LOC_COM - 1) + substr(UP_TEXT,LOC_COM + 1, len)/10;   
	*stray comma at end 5.4,   ;
	if LOC_DOT = 2  and LOC_COM = 4 then RES_NUM = substr(UP_TEXT,1,LOC_DOT - 1) + substr(UP_TEXT,LOC_DOT + 1,1)/10;   
	*stray comma at end 3.78,   ;
	if LOC_DOT = 2  and LOC_COM = 5 then RES_NUM = substr(UP_TEXT,1,LOC_DOT - 1) + substr(UP_TEXT,LOC_DOT + 1,2)/10;   
	*stray comma at end 10.9,  ;
	if LOC_DOT = 3  and LOC_COM = 5 then RES_NUM = substr(UP_TEXT,1,LOC_DOT - 1) + substr(UP_TEXT,LOC_DOT + 1,1)/10;   
	*junk at end 8.4-  8.4.  8.5* ;
	if LEN = 4 and LOC_DOT = 2 and LOC_COM = 0 then RES_NUM = substr(UP_TEXT,1,1) + substr(UP_TEXT,3,1)/10;   
	*junk at end 11.7* 11.7. 11.73. ;
	if LEN in (5 6) and LOC_DOT = 3 and LOC_COM = 0 then RES_NUM = substr(UP_TEXT,1,2) + substr(UP_TEXT,4,1)/10;   
	*junk at end 3.4!L ;
	if LEN = 5 and LOC_DOT = 2 and LOC_COM = 0 then RES_NUM = substr(UP_TEXT,1,1) + substr(UP_TEXT,3,1)/10;   
	*junk at end 8.0(R) 14.6(R)   10.0 (D);
	if LEN = 6 and LOC_DOT = 2 and LOC_COM = 0 and LOC_PAREN = 4 then RES_NUM = substr(UP_TEXT,1,1) + substr(UP_TEXT,3,1)/10;   
	if LEN = 7 and LOC_DOT = 3 and LOC_COM = 0 and LOC_PAREN = 5 then RES_NUM = substr(UP_TEXT,1,2) + substr(UP_TEXT,4,1)/10;   
	if LEN = 8 and LOC_DOT = 3 and LOC_COM = 0 and LOC_PAREN = 6 then RES_NUM = substr(UP_TEXT,1,2) + substr(UP_TEXT,4,1)/10;   
	end; /*end of DREGS*/
	end; /*end of WBC*/
end; /*end of RES_NUM = . */

*clean up;
drop DREGS LEN LOC: UP_TEXT;
if RES_NUM > 1000 then RES_NUM = RES_NUM/1000;
run;

proc means data=five n min p1 p5 p25 median p75 p95 p99 max maxdec=1;
class LAB_CODE;
var RES_NUM;
run;

data prune;
set five;
if LAB_CODE in("PLT") then do;
	if RES_NUM < 1 or RES_NUM > 1000 then delete;
end;
if LAB_CODE in("WBC") then do;
	if RES_NUM < 0.1 or RES_NUM > 50 then delete;
end;
run;


*grab most recent lab to baseline;
%macro labsbl(lab);
proc sql;
create table many as
select a.scrssn_n, a.DT_BASELINE, b.DT_LAB as DT_LAB_&lab, b.RES_NUM as LAB_&lab, abs(DT_BASELINE-DT_LAB) as DIFF_LAB_&lab
from finder a, prune b
where a.scrssn_n=b.scrssn_n and DT_BASELINE-(365*2) <= DT_LAB <= DT_BASELINE and LAB_CODE = "&lab"
ORDER BY a.scrssn_n, a.DT_BASELINE, PREF desc, DIFF_LAB_&lab;
run;quit;
data lab_&lab ;
set many;
by scrssn_n DT_BASELINE;
if first.DT_BASELINE;
run;
%mend;
%labsbl(PLT);
%labsbl(WBC);
data DCNP.LABS_PLT_WBC;
merge LAB_PLT LAB_WBC;
by scrssn_n DT_BASELINE;
run;
proc print data = DCNP.LABS_PLT_WBC (obs=50) noobs;
run;
proc means data = DCNP.LABS_PLT_WBC n nmiss nolabels min max maxdec=1;
var LAB:;
run;












*BMI;
data vitals (keep=scrssn_n DT_VITAL VITAL RES_NUM);
set <redacted-sensitive information>DFT.FullVA_Vitals (keep=scrssn patienticn vitalresult  VitalResultNumeric VitalSignTakenDateTime VitalType rename=(VitalResultNumeric=RES_NUM) 
			where=(VitalType in("HEIGHT","WEIGHT")));
DT_VITAL = datepart(VitalSignTakenDateTime);
drop VitalSignTakenDateTime;
format DT_: mmddyy8.;

scrssn_n = scrssn*1;
drop scrssn;

length VITAL $6.;
if VitalType = "HEIGHT" then VITAL = "HGT";
else if VitalType = "WEIGHT" then VITAL = "WGT";

if upcase(vitalresult) in("+++","???","NAN","PASS","REFUSED","UNAVAILABLE") then delete;

*get rid of missings;
if RES_NUM ne .;

*get rid of implausible values;
if VITAL = "HGT" then do;
	if RES_NUM lt 50 or RES_NUM gt 80 then delete;
end;
if VITAL = "WGT" then do;
	if RES_NUM lt 50 or RES_NUM gt 700 then delete;
end;

run;
proc sort data = vitals;
by scrssn_n DT_VITAL;
run;
proc freq data = vitals;
tables vital;
run;
*ok with height and weight back a bit longer given not as regularly measured;
%macro bmibl(VITAL);
proc sql;
create table many as
select a.scrssn_n, a.DT_BASELINE, b.DT_VITAL as DT_VITAL_&VITAL, b.RES_NUM as VITAL_&VITAL, abs(DT_BASELINE-DT_VITAL) as DIFF_VITAL_&VITAL
from finder a, vitals b
where a.scrssn_n=b.scrssn_n and DT_BASELINE-(2*365) <= DT_VITAL <= DT_BASELINE and VITAL = "&VITAL"
ORDER BY a.scrssn_n, a.DT_BASELINE, DIFF_VITAL_&VITAL;
run;quit;
data VITAL_&VITAL ;
set many;
by scrssn_n DT_BASELINE;
if first.DT_BASELINE;
run;
%mend;
%bmibl(HGT);
%bmibl(WGT);
data DCNP.BMI;
merge  VITAL_HGT VITAL_WGT ;
by scrssn_n DT_BASELINE;
VITAL_BMI = (VITAL_WGT * .45359237)/((VITAL_HGT * .0254)*(VITAL_HGT* .0254));
DT_VITAL_BMI = max(DT_VITAL_WGT, DT_VITAL_HGT);
run;
proc means data = DCNP.BMI n nmiss nolabels min max maxdec=1;
var VITAL: ;
run;








*eGFR;
proc sort data = DCNP.cohort_split (keep=scrssn_n DT_BASELINE AGE_START SEX RACE7_SR rename=(AGE_START=AGE_BL)) out=finder_demog;
by scrssn_n DT_BASELINE;
run;
data DCNP.EGFR;
merge finder_demog (in=a) 
	  DCNP.LABS_CREAT (in=b keep=scrssn_n DT_BASELINE LAB_CREAT);
by scrssn_n DT_BASELINE;
if a and b;
*calculate eGFR using CKD epi equation;
if SEX = 0  then CKDfem_val=1.018; else CKDfem_val=1;
if RACE7_SR = "2_Black" then CKDblack_val=1.159; else CKDblack_val=1;
if SEX = 0 then sex_k_ckdepi=0.7; else sex_k_ckdepi=0.9;
if SEX = 0 then sex_a_ckdepi=-0.329; else sex_a_ckdepi=-0.411;
scrk=LAB_CREAT/sex_k_ckdepi;
min_scrk_1=min(1, scrk);
max_scrk_1=max(1, scrk);
eGFR=round(141*(min_scrk_1**sex_a_ckdepi)*(max_scrk_1**-1.209)*(0.993**AGE_BL)*(CKDfem_val)*(CKDblack_val),1);
*clean;
if eGFR lt 1  or egfr gt 220 then delete;
drop AGE_BL SEX RACE7_SR LAB_CREAT CKDfem_val CKDblack_val sex_k_ckdepi sex_a_ckdepi scrk min_scrk_1 max_scrk_1;
run;
proc print data = DCNP.EGFR (obs=50) noobs;
run;
proc means data = DCNP.EGFR n nmiss;
run;



*FIB-4;
data DCNP.FIB4;
merge finder_demog (in=a ) DCNP.LABS_ALTAST (in=b keep=scrssn_n DT_BASELINE LAB_ALT LAB_AST ) DCNP.LABS_PLT_WBC (in=c keep=scrssn_n DT_BASELINE LAB_PLT );
by scrssn_n DT_BASELINE;
if a and b and c;
*code to calculate FIB4 and eGFR;
FIB4 = round((AGE_BL * LAB_AST) / ( (LAB_PLT)*(sqrt(LAB_ALT))),.01);
keep scrssn_n DT_BASELINE FIB4;
run;
proc print data = DCNP.FIB4 (obs=50) noobs;
run;
proc means data = DCNP.FIB4 n nmiss;
run;


















**HIV and HCV;
proc sql; /*4 hours*/
create table many as 
select b.scrssn_n, b.DT_BASELINE, datepart(a.recdatetime) as DT_DX, a.ICDCode as DX, inotpt
from <redacted-sensitive information>DFT.FullVA_DX_Long_v a, finder b
where a.scrssn_n=b.scrssn_n and 
/*b.DT_BASELINE-(2*365) <= */ datepart(a.recdatetime) <= b.DT_BASELINE-7 and  /*grab ever before.. will limit down windows in later step */
(a.ICDCode like	'B%' or
a.ICDCode like	'042%'	or
a.ICDCode like	'V08%'	or
a.ICDCode like	'Z%')
;
quit;
data comorbs;
set many; 
format DT_DX mmddyy8.;

length cc $10.;

if substr(DX,1,3) in ('042', 'V08', 'B20', 'Z21') then cc='HIV'; /*looking ever prior, so need ICD9 and ICD10*/
if DX in ('B17.10' 'B17.11' 'B18.2' 'B19.20' 'B19.21' 'Z22.52')  then cc='HCV'; /*only look 2 years prior, so only need ICD10*/

if cc ne "";
run;
proc sort data=comorbs out=comorbsnodups nodupkey;
     by scrssn_n DT_BASELINE cc dt_dx inotpt;
run;
proc freq data = comorbsnodups;
tables cc  /missing;
run;
proc tabulate data = comorbsnodups;
var DT_DX;
table DT_DX, (min p5 p25 median p75 p95 max)*f=mmddyy8.;
run;
proc print data=comorbsnodups (obs=50);
run;

*in 2 years prior;
%macro comorbsnodups(COND);
proc SQL; 
create table many as
select scrssn_n, DT_BASELINE, DT_DX, INOTPT
from comorbsnodups
where DT_BASELINE-(2*365) <= DT_DX <= DT_BASELINE - 7 and cc= "&COND"
ORDER BY scrssn_n, DT_BASELINE, DT_DX;
quit;run;
data COND_&COND;
set many;
by scrssn_n DT_BASELINE;
if first.DT_BASELINE and (inotpt = 1 or not last.DT_BASELINE);  /*2OP/1IP*/
COND_&COND=1;
drop DT_DX INOTPT;
run;
%mend;
%comorbsnodups(HCV);

*ever before;
%macro comorbsnodups(COND);
proc SQL; 
create table many as
select scrssn_n, DT_BASELINE, DT_DX, INOTPT
from comorbsnodups
where DT_BASELINE-(2*365) <= DT_DX <= DT_BASELINE - 7 and cc= "&COND"
ORDER BY scrssn_n, DT_BASELINE, DT_DX;
quit;run;
data COND_&COND;
set many;
by scrssn_n DT_BASELINE;
if first.DT_BASELINE and (inotpt = 1 or not last.DT_BASELINE);  /*2OP/1IP*/
COND_&COND=1;
drop DT_DX INOTPT;
run;
%mend;
%comorbsnodups(HIV);
data DCNP.COMORBS;
merge  COND_HIV COND_HCV     ;
by scrssn_n DT_BASELINE;
run;
proc freq data = DCNP.COMORBS;
tables COND_:;
run;
proc print data = DCNP.COMORBS (obs=30) noobs;
run;














*VACS Index;
data index;
merge DCNP.cohort_split (in=a keep=scrssn_n DT_BASELINE AGE_START SEX RACE7_SR rename=(AGE_START=AGE_BL)) 
	  DCNP.LABS_ALB (in=b keep=scrssn_n DT_BASELINE LAB_ALB )
	  DCNP.LABS_ALTAST (in=i keep=scrssn_n DT_BASELINE LAB_ALT LAB_AST  )
	  DCNP.LABS_CREAT (in=k keep=scrssn_n DT_BASELINE LAB_CREAT   )
	  DCNP.LABS_HGB (in=l keep=scrssn_n DT_BASELINE LAB_HGB )
	  DCNP.LABS_PLT_WBC (in = h keep=scrssn_n DT_BASELINE LAB_PLT LAB_WBC)
	  DCNP.BMI (in=d keep=scrssn_n DT_BASELINE VITAL_BMI rename=(VITAL_BMI=BMI))
	  DCNP.EGFR (in=e keep=scrssn_n DT_BASELINE EGFR)
	  DCNP.FIB4 (in=f keep=scrssn_n DT_BASELINE FIB4)
	  DCNP.COMORBS (in=g keep=scrssn_n DT_BASELINE COND_HCV COND_HIV rename=(COND_HIV=HIV))
;
by scrssn_n DT_BASELINE;
if a;
if COND_HCV = . then COND_HCV = 0;
if HIV = . then HIV = 0;
run;
proc print data = index (obs=50) noobs;
run;


data index2;
set index;

*missing patterns;
if LAB_VL_LOG  ne .   then C1 = '1'; else C1 = '0';
if LAB_CD4 ne .   then C2 = '1'; else C2 = '0';
if LAB_ALB ne .   then C3 = '1'; else C3 = '0';
if LAB_ALT ne .   then C4 = '1'; else C4 = '0';
if LAB_AST ne .   then C5 = '1'; else C5 = '0';
if LAB_CREAT ne . then C6 = '1'; else C6 = '0';
if LAB_HGB ne .   then C7 = '1'; else C7 = '0';
if LAB_PLT ne .   then C8 = '1'; else C8 = '0';
if LAB_WBC  ne .  then C9 = '1'; else C9 = '0';
if BMI ne .   	  then C10 = '1'; else C10 = '0';
VCAAACHPWB = C1||C2||C3||C4||C5||C6||C7||C8||C9||C10;
xxAAACHPWB = 'x'||'x'||C3||C4||C5||C6||C7||C8||C9||C10;


*if missing only 1 lab, set missing lab to normal (except dont do anything CD4/VL);
length MeqN 3.;
MeqN = 0;
if HIV = 1 and VCAAACHPWB ne '1111111111' then do;
    if VCAAACHPWB = '1110111111' then LAB_ALT = 25;
    else if VCAAACHPWB = '1111011111' then LAB_AST = 25;
    else if VCAAACHPWB = '1101111111' then LAB_ALB = 4;
	else if VCAAACHPWB = '1111110111' then LAB_HGB = 14;
	else if VCAAACHPWB = '1111111011' then LAB_PLT = 200;
	else if VCAAACHPWB = '1111111101' then LAB_WBC = 5.5;
	else if VCAAACHPWB = '1111111110' then BMI = 25;
if VCAAACHPWB in ('1110111111','1111011111','1101111111','1111110111','1111111011','1111111101','1111111110') then MeqN = 1;
end;

if HIV = 0 and xxAAACHPWB ne 'xx11111111' then do;
    if xxAAACHPWB = 'xx10111111' then LAB_ALT = 25;
    else if xxAAACHPWB = 'xx11011111' then LAB_AST = 25;
    else if xxAAACHPWB = 'xx01111111' then LAB_ALB = 4;
	else if xxAAACHPWB = 'xx11110111' then LAB_HGB = 14;
	else if xxAAACHPWB = 'xx11111011' then LAB_PLT = 200;
	else if xxAAACHPWB = 'xx11111101' then LAB_WBC = 5.5;
	else if xxAAACHPWB = 'xx11111110' then BMI = 25;
if xxAAACHPWB in ('xx10111111','xx11011111','xx01111111','xx11110111','xx11111011','xx11111101','xx11111110') then MeqN = 1;
end;


*recalculate FIB4;
drop FIB4;
FIB4 = round((AGE_BL * LAB_AST) / ( (LAB_PLT)*(sqrt(LAB_ALT))),.01);

*calculate score for scenarios;
*code functional forms for continuous;
*_T means trimmed to remove extreme values
*_C means centered  This is important to do for a polynomial model to avoid collinearity

*********************************;
     if AGE_BL ne . and AGE_BL <30 then AGE_T = 30;
else if AGE_BL > 75 then AGE_T = 75;
else AGE_T = AGE_BL;

AGE_C = (AGE_T-50)/5;
AGE_CSQ = AGE_C**2;
AGE_CCU = AGE_C**3;


*********************************;
/*if LAB_CD4 ne . and LAB_CD4 < 10 then CD4_T = 10;*/
/*else if LAB_CD4 > 1000 then CD4_T = 1000;*/
/*else CD4_T = LAB_CD4;*/
/*if HIV = 0 then */
CD4_T = 1000;

CD4_C = log(1000-CD4_T+.1);
CD4_CSQ = CD4_C**2;
CD4_CCU = CD4_C**3;


*********************************;

/*if LAB_VL_LOG ne . and LAB_VL_LOG < 1.3 then VL_T = 1.3;*/
/*else if LAB_VL_LOG > 5 then VL_T = 5;*/
/*else VL_T = LAB_VL_LOG;*/
/*if HIV = 0 then */
VL_T = 1.3;

VL_C= (VL_T - 2);
VL_CSQ= VL_C**2;
VL_CCU= VL_C**3;

*********************************;
if LAB_HGB ne . and LAB_HGB <9 then HGB_T = 9;
else if LAB_HGB > 15 then HGB_T = 16;
else HGB_T  = LAB_HGB;

HGB_C = HGB_T-14;
HGB_CSQ= HGB_C**2;
HGB_CCU= HGB_C**3;

*********************************;

if FIB4 ne . and FIB4 < .5 then FIB4_T = .5;
else if FIB4 > 7.5 then FIB4_T = 7.5;
else FIB4_T = FIB4;

FIB4_C = FIB4_T;
FIB4_CSQ= FIB4_C**2;
FIB4_CCU= FIB4_C**3;

*********************************;

*if creatinine is only thing missing then set EGFR to normal;
if VCAAACHPWB = '1111101111' then EGFR = 90; /*HIV+*/
else if xxAAACHPWB = 'xx11101111' then EGFR = 90; /*Uninfected*/

if EGFR > 180 then EGFR_T = 180; else EGFR_T = EGFR;
EGFRX1 = EGFR_T/10;
if EGFR > 35 then EGFRX2 = (EGFR_T-35)/10; else EGFRX2 = 0;
if EGFR > 65 then EGFRX3 = (EGFR_T-65)/10; else EGFRX3 = 0;
if EGFR > 115 then EGFRX4 = (EGFR_T-115)/10; else EGFRX4 = 0;

*********************************;
if LAB_ALB ne . and LAB_ALB < 2 then ALB_T = 2;
else if LAB_ALB> 5 then ALB_T = 5;
else ALB_T = LAB_ALB;

ALB_C = ALB_T-4;
ALB_CSQ= ALB_C**2;
ALB_CCU= ALB_C**3;

*********************************;
if BMI ne . and BMI <15 then BMI_T = 15;
else if BMI > 35 then BMI_T = 35;
else BMI_T = BMI;

BMI_C = BMI_T-25;
BMI_CSQ= BMI_C**2;
BMI_CCU= BMI_C**3;

*********************************;
if LAB_WBC ne . and LAB_WBC < 2.5 then WBC_T = 2.5;
else if LAB_WBC > 11 then WBC_T = 11;
else WBC_T = LAB_WBC;

WBC_C = (WBC_T - 5.5);
WBC_CSQ = WBC_C**2;
WBC_CCU = WBC_C**3;

************************************;
*generate components of score;
*weights from VACS model;
COMP_AGE = (AGE_C *	0.05593) +(AGE_CSQ *	-0.00447) + (AGE_CCU *	0.00518);
comp_CD4 = (CD4_C *	-0.05608) +(CD4_CSQ *	-0.15344) + (CD4_CCU *	0.02352);
COMP_VL = (VL_C *	0.51329) + (VL_CSQ *	-0.42235) + (VL_CCU *	0.09798);
COMP_HGB = (HGB_C *	-0.13364) + (HGB_CSQ *	0.02601) + (HGB_CCU *	0.00456);
COMP_FIB4 = (FIB4_C *	0.22045) + (FIB4_CSQ *	-0.00875);
COMP_EGFR = (EGFRX1 *	-0.03075) + (EGFRX2 *	-0.07668) + (EGFRX3 *	0.10629) + (EGFRX4 *	0.1325);
COMP_HEPC = (COND_HCV *	0.34201);
COMP_ALB = (ALB_C *	-0.44289) + (ALB_CSQ *	0.10394) + (ALB_CCU *	0.02766);
COMP_BMI = (BMI_C *	-0.05452) + (BMI_CSQ *	0.00359);
COMP_WBC = (WBC_C *	0.1257) + (WBC_CSQ *	0.01985) + (WBC_CCU *	-0.00438);
CALC_XB = COMP_AGE + /*COMP_CD4 + COMP_VL +*/ COMP_HGB + COMP_FIB4 + COMP_EGFR + COMP_HEPC + COMP_ALB + COMP_BMI + COMP_WBC;  

*create score - normalized to 0 to 100 scale;
RANGE = 2.10 - (-3.25);  /*-3.25 is the actual minimum, 2.10 is min for 10th decile, also 97.5%*/
DIST = CALC_XB - (-3.25); 
SCORE = (DIST / RANGE)*100;
run;
proc freq data = index2 order=freq;
tables VCAAACHPWB /missing;
where HIV = 1;
title HIV+;
run;
proc freq data = index2 order=freq;
tables xxAAACHPWB /missing;
where HIV = 0;
title Uninfected;
run;
title;
proc print data = index2 (obs=50) noobs;
where SCORE = .;
*var param SET AGE	CD4	VL_LOG	HGB	FIB4	EGFR	HEPC	ALB	WBC	BMI  SCORE;
run;
proc means data = index2 n nmiss min p1 p5 p25 median p75 p95 p99 max maxdec=0;
var score;
run;
data DCNP.SCORE;
set index2 (keep=scrssn_n DT_BASELINE SCORE MeqN rename=(MeqN=SCORE_MEQN));
run;

proc means data = DCNP.SCORE n nmiss;
var SCORE;
run;
proc print data = DCNP.SCORE (obs=20) noobs;
run;






















