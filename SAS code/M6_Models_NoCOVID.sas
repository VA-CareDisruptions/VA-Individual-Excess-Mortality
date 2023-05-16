**********************************


Run models, excluding follow-up time once evidence of COVID-19

cohort: VACS-National
started: 7 November 2022
Author: CTR

**********************************;




libname DCNP "<redacted-sensitive information>";
libname OUT "<redacted-sensitive information>";









*merge in COVID info from Shared Data Resource;
*unique ID is patientICN;
data covid;
informat patienticn $10. CaseDefinition $21.;
length patienticn $10. CaseDefinition $21.;
format patienticn $10. CaseDefinition $21.;
set <redacted-sensitive information>SRC.ORDCOVID_CaseDetail (keep=patienticn CaseDefinition CaseDateTime);

length DT_COVID 4.;
DT_COVID = datepart(CaseDateTime);
format DT_COVID mmddyy10.;
drop CaseDateTime;

length COVID 3.;
if CaseDefinition = "VA Positive" then COVID = 1;
else if CaseDefinition = "VA Negative" then COVID = 0;
else if CaseDefinition = "VA Pending" then COVID = -1;
else if CaseDefinition = "VA Canc/Indeterminate" then COVID = -1;
drop CaseDefinition;
run;
proc sort data=covid;
by patienticn DT_COVID;
run;
data check;
set covid;
by patienticn;
if first.patienticn then i = 1;
else i + 1;
run;
proc freq data=check;
tables i;
run;
*one row per patient;
proc print data=covid (obs=100);
run;
proc freq data=covid;
tables COVID / list missing;
run;
data pos;
set covid;
where covid = 1;
run;
proc print data=pos (obs=50);
run;

















*merge onto main DB;
proc sort data=DCNP.go out=go_model;
by patienticn PERIOD;
run;
data combine;
merge go_model (in=a) pos (in=b);
by patienticn;
if a;

     if age_start_rnd                        < 45 then ageb = 1; 
else if age_start_rnd >=45 and age_start_rnd < 65 then ageb = 2; 
else if age_start_rnd >=65 and age_start_rnd < 75 then ageb = 3;  
else if age_start_rnd >=75 and age_start_rnd < 85 then ageb = 4;
else if age_start_rnd >=85                        then ageb = 5; 

run;
*update vars;
data go_model_covid;
set combine;
*can't have covid in pre pandemic period;
if PERIOD = 0 then do;
	COVID = .;
	DT_COVID = .;
end;
*if covid then maniuplate based on when the covid happened;
if PERIOD = 1 and COVID = 1 and DT_COVID <= DT_LAST then do;
	DIED_COVID = 0;
	DT_LAST_COVID = DT_COVID;	
end;
else do;
	DIED_COVID = DIED;
	DT_LAST_COVID = DT_LAST;
end;

*summary measures that need updating on all records;
risk_covid = DT_LAST_COVID - DT_BASELINE;
age_end_covid = (DT_LAST_COVID-DT_BIRTH)/365.242;
age_end_rnd_covid = round(age_end_covid,0.01);

*model will exclude those where age_start = age_end. add +0.01 (equivalent to about 4 days (0.01*365);
if age_start_rnd = age_end_rnd_covid then do;
	age_end_rnd_covid = age_end_rnd_covid + 0.01;
end;

drop st_days lrisk ;

format DT_: mmddyy8.;
run;
proc sort data=go_model_covid;
by scrssn_n PERIOD;
run;












*age-adjusted;
proc phreg data = go_model_covid ;
class PERIOD  /param=glm order=internal;/* 30 mins */
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD    ;
/*Independent effects*/
estimate 'Pan vs pre'   			PERIOD -1 1 /exp cl;
ods output Estimates=DCNP.model_m1_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;





* +Demographics; /* 2 hrs */
proc phreg data = go_model_covid ;
class PERIOD SEX RACE7_SR census_nomiss URBAN /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD SEX RACE7_SR census_nomiss URBAN  ;
/*Independent effects*/
estimate 'Pan vs pre'   			PERIOD -1 1 /exp cl;
estimate 'Women vs Men'   			SEX 1 -1 /exp cl;
estimate 'Black vs White'    		RACE7_SR -1 1 0 0 0 0 0 0 /exp cl;
estimate 'Hisp vs White'     		RACE7_SR -1 0 1 0 0 0 0 0 /exp cl;
estimate 'Asian vs White'    		RACE7_SR -1 0 0 1 0 0 0 0 /exp cl;
estimate 'AI/AN vs White'    		RACE7_SR -1 0 0 0 1 0 0 0 /exp cl;
estimate 'PI/NH vs White'    		RACE7_SR -1 0 0 0 0 1 0 0 /exp cl;
estimate 'Mixed vs White'    		RACE7_SR -1 0 0 0 0 0 1 0 /exp cl;
estimate 'Missing vs White'    		RACE7_SR -1 0 0 0 0 0 0 1 /exp cl;
estimate 'MW vs S'   				census_nomiss 1 0 -1 0 /exp cl;
estimate 'NE vs S'   				census_nomiss 0 1 -1 0 /exp cl;
estimate 'W vs S'    				census_nomiss 0 0 -1 1 /exp cl;
estimate 'Urban vs rural'   		URBAN -1 1 /exp cl;
ods output Estimates=DCNP.model_m2_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;






* +CCI and VACS Index; /* 3 hrs */
proc phreg data = go_model_covid ;
class PERIOD SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT  ;
/*Independent effects*/
estimate 'Pan vs pre'   			PERIOD -1 1 /exp cl;
estimate 'Women vs Men'   			SEX 1 -1 /exp cl;
estimate 'Black vs White'    		RACE7_SR -1 1 0 0 0 0 0 0 /exp cl;
estimate 'Hisp vs White'     		RACE7_SR -1 0 1 0 0 0 0 0 /exp cl;
estimate 'Asian vs White'    		RACE7_SR -1 0 0 1 0 0 0 0 /exp cl;
estimate 'AI/AN vs White'    		RACE7_SR -1 0 0 0 1 0 0 0 /exp cl;
estimate 'PI/NH vs White'    		RACE7_SR -1 0 0 0 0 1 0 0 /exp cl;
estimate 'Mixed vs White'    		RACE7_SR -1 0 0 0 0 0 1 0 /exp cl;
estimate 'Missing vs White'    		RACE7_SR -1 0 0 0 0 0 0 1 /exp cl;
estimate 'MW vs S'   				census_nomiss 1 0 -1 0 /exp cl;
estimate 'NE vs S'   				census_nomiss 0 1 -1 0 /exp cl;
estimate 'W vs S'    				census_nomiss 0 0 -1 1 /exp cl;
estimate 'Urban vs rural'   		URBAN -1 1 /exp cl;
estimate 'CCI 1 vs 0'    			CCI_CAT -1 1 0 0 0 0 /exp cl;
estimate 'CCI 2 vs 0'     			CCI_CAT -1 0 1 0 0 0 /exp cl;
estimate 'CCI 3 vs 0'    			CCI_CAT -1 0 0 1 0 0 /exp cl;
estimate 'CCI 4 vs 0'    			CCI_CAT -1 0 0 0 1 0 /exp cl;
estimate 'CCI 5+ vs 0'    			CCI_CAT -1 0 0 0 0 1 /exp cl;
estimate 'VACS Index 2nd vs 1st'	SCORE_CAT -1 1 0 0 0 /exp cl;
estimate 'VACS Index 3rd vs 1st'    SCORE_CAT -1 0 1 0 0 /exp cl;
estimate 'VACS Index 4th vs 1st'   	SCORE_CAT -1 0 0 1 0 /exp cl;
estimate 'VACS Index miss vs 1st'   SCORE_CAT -1 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m3_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;










* Age-adjusted, By age group; /* 1-3 hrs */
proc phreg data = go_model_covid ;
class PERIOD SEX /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|ageb0 PERIOD|ageb1 PERIOD|ageb2 PERIOD|ageb3 PERIOD|ageb4;
if age_start_rnd                        < 45 then ageb0 = 1; else ageb0 = 0;
if age_start_rnd >=45 and age_start_rnd < 65 then ageb1 = 1; else ageb1 = 0; 
if age_start_rnd >=65 and age_start_rnd < 75 then ageb2 = 1; else ageb2 = 0; 
if age_start_rnd >=75 and age_start_rnd < 85 then ageb3 = 1; else ageb3 = 0; 
if age_start_rnd >=85                        then ageb4 = 1; else ageb4 = 0; 

*Age bands;
estimate 'Pan vs pre - <45'     PERIOD -1 1 ageb0*PERIOD -1 1 /exp cl;
estimate 'Pan vs pre - 45-64'   PERIOD -1 1 ageb1*PERIOD -1 1 /exp cl;
estimate 'Pan vs pre - 65-74'   PERIOD -1 1 ageb2*PERIOD -1 1 /exp cl;
estimate 'Pan vs pre - 75-84'   PERIOD -1 1 ageb3*PERIOD -1 1 /exp cl;
estimate 'Pan vs pre - 85+'     PERIOD -1 1 ageb4*PERIOD -1 1 /exp cl;
ods output Estimates=DCNP.model_m5_v2_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By sex; /* 1-3 hrs */
proc phreg data = go_model_covid ;
class PERIOD SEX  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|SEX   ;
/*Interactive effects*/
*SEX;
estimate 'Pan vs pre - Men'   PERIOD -1 1 PERIOD*SEX 0 -1 0 1 /exp cl;
estimate 'Pan vs pre - Women' PERIOD -1 1 PERIOD*SEX -1 0 1 0 /exp cl;
ods output Estimates=DCNP.model_m6_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By race/ethnicity; /* 1-3 hrs */
proc phreg data = go_model_covid ;
class PERIOD RACE7_SR  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=   PERIOD|RACE7_SR   ;
/*Interactive effects*/
*RACE/ETHNICITY;
estimate 'Pan vs pre - White'   		PERIOD -1 1 PERIOD*RACE7_SR -1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - Black'   		PERIOD -1 1 PERIOD*RACE7_SR 0 -1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - Hisp'    		PERIOD -1 1 PERIOD*RACE7_SR 0 0 -1 0 0 0 0 0 0 0 1 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - Asian'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 -1 0 0 0 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - AI/AN'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 0 -1 0 0 0 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - PI/NH'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - Mixed'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - Missing'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m7_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;


* Age-adjusted, By census region; /* 1-3 hrs */
proc phreg data = go_model_covid ;
class PERIOD census_nomiss  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=   PERIOD|census_nomiss   ;
/*Interactive effects*/
*census_nomiss;
estimate 'Pan vs pre - MW'   PERIOD -1 1 PERIOD*census_nomiss -1 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - NE'   PERIOD -1 1 PERIOD*census_nomiss 0 -1 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - S'    PERIOD -1 1 PERIOD*census_nomiss 0 0 -1 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - W'    PERIOD -1 1 PERIOD*census_nomiss 0 0 0 -1 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m8_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By residence type; /* 1-3 hrs */
proc phreg data = go_model_covid ;
class PERIOD  URBAN /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|URBAN  ;
/*Interactive effects*/
*Urban;
estimate 'Pan vs pre - Urban'   PERIOD -1 1 PERIOD*URBAN 0 -1 0 1 /exp cl;
estimate 'Pan vs pre - Rural' 	PERIOD -1 1 PERIOD*URBAN -1 0 1 0 /exp cl;
ods output Estimates=DCNP.model_m9_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By CCI; /* 1-3 hrs */
proc phreg data = go_model_covid ;
class PERIOD CCI_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|CCI_CAT  ;
/*Interactive effects*/
*CCI_CAT;
estimate 'Pan vs pre - CCI 0'    PERIOD -1 1 PERIOD*CCI_CAT -1 0 0 0 0 0 1 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 1'    PERIOD -1 1 PERIOD*CCI_CAT 0 -1 0 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 2'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 -1 0 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 3'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 -1 0 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - CCI 4'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 0 -1 0 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - CCI 5+'   PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 0 0 -1 0 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m10_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By VACS Index; /* 1-3 hrs */
proc phreg data = go_model_covid ;
class PERIOD SCORE_CAT /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|SCORE_CAT  ;
/*Interactive effects*/
*SCORE_CAT;
estimate 'Pan vs pre - VACS Index 1st'    PERIOD -1 1 PERIOD*SCORE_CAT -1 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 2nd'    PERIOD -1 1 PERIOD*SCORE_CAT 0 -1 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 3rd'    PERIOD -1 1 PERIOD*SCORE_CAT 0 0 -1 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 4th'    PERIOD -1 1 PERIOD*SCORE_CAT 0 0 0 -1 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - VACS Index miss'   PERIOD -1 1 PERIOD*SCORE_CAT 0 0 0 0 -1 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m11_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;









* Fully-adjusted, By age group; /* 4.5 hrs */
proc phreg data = go_model_covid ;
class PERIOD SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|ageb0 PERIOD|ageb1 PERIOD|ageb2 PERIOD|ageb3 PERIOD|ageb4 SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT;
if age_start_rnd                        < 45 then ageb0 = 1; else ageb0 = 0;
if age_start_rnd >=45 and age_start_rnd < 65 then ageb1 = 1; else ageb1 = 0; 
if age_start_rnd >=65 and age_start_rnd < 75 then ageb2 = 1; else ageb2 = 0; 
if age_start_rnd >=75 and age_start_rnd < 85 then ageb3 = 1; else ageb3 = 0; 
if age_start_rnd >=85                        then ageb4 = 1; else ageb4 = 0; 

*Age bands;
estimate 'Pan vs pre - <45'     PERIOD -1 1 ageb0*PERIOD -1 1 /exp cl;
estimate 'Pan vs pre - 45-64'   PERIOD -1 1 ageb1*PERIOD -1 1 /exp cl;
estimate 'Pan vs pre - 65-74'   PERIOD -1 1 ageb2*PERIOD -1 1 /exp cl;
estimate 'Pan vs pre - 75-84'   PERIOD -1 1 ageb3*PERIOD -1 1 /exp cl;
estimate 'Pan vs pre - 85+'     PERIOD -1 1 ageb4*PERIOD -1 1 /exp cl;
ods output Estimates=DCNP.model_m5_full_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By sex; /* 4.5 hrs */
proc phreg data = go_model_covid ;
class PERIOD SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT  ;
/*Interactive effects*/
*SEX;
estimate 'Pan vs pre - Men'   PERIOD -1 1 PERIOD*SEX 0 -1 0 1 /exp cl;
estimate 'Pan vs pre - Women' PERIOD -1 1 PERIOD*SEX -1 0 1 0 /exp cl;
ods output Estimates=DCNP.model_m6_full_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By race/ethnicity; /* 4.5 hrs */
proc phreg data = go_model_covid ;
class PERIOD RACE7_SR SEX census_nomiss URBAN CCI_CAT SCORE_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=   PERIOD|RACE7_SR SEX census_nomiss URBAN CCI_CAT SCORE_CAT   ;
/*Interactive effects*/
*RACE/ETHNICITY;
estimate 'Pan vs pre - White'   		PERIOD -1 1 PERIOD*RACE7_SR -1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - Black'   		PERIOD -1 1 PERIOD*RACE7_SR 0 -1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - Hisp'    		PERIOD -1 1 PERIOD*RACE7_SR 0 0 -1 0 0 0 0 0 0 0 1 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - Asian'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 -1 0 0 0 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - AI/AN'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 0 -1 0 0 0 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - PI/NH'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - Mixed'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - Missing'   		PERIOD -1 1 PERIOD*RACE7_SR 0 0 0 0 0 0 0 -1 0 0 0 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m7_full_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By census region; /* 4.5 hrs */
proc phreg data = go_model_covid ;
class PERIOD census_nomiss SEX RACE7_SR URBAN CCI_CAT SCORE_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=   PERIOD|census_nomiss SEX RACE7_SR URBAN CCI_CAT SCORE_CAT   ;
/*Interactive effects*/
*census_nomiss;
estimate 'Pan vs pre - MW'   PERIOD -1 1 PERIOD*census_nomiss -1 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - NE'   PERIOD -1 1 PERIOD*census_nomiss 0 -1 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - S'    PERIOD -1 1 PERIOD*census_nomiss 0 0 -1 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - W'    PERIOD -1 1 PERIOD*census_nomiss 0 0 0 -1 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m8_full_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By residence type; /* 4.5 hrs */
proc phreg data = go_model_covid ;
class PERIOD  URBAN SEX RACE7_SR census_nomiss CCI_CAT SCORE_CAT /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|URBAN  SEX RACE7_SR census_nomiss CCI_CAT SCORE_CAT;
/*Interactive effects*/
*Urban;
estimate 'Pan vs pre - Urban'   PERIOD -1 1 PERIOD*URBAN 0 -1 0 1 /exp cl;
estimate 'Pan vs pre - Rural' 	PERIOD -1 1 PERIOD*URBAN -1 0 1 0 /exp cl;
ods output Estimates=DCNP.model_m9_full_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;












* Fully-adjusted, By CCI; /* 4.5 hrs */
proc phreg data = go_model_covid ;
class PERIOD CCI_CAT SEX RACE7_SR census_nomiss URBAN  SCORE_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|CCI_CAT SEX RACE7_SR census_nomiss URBAN  SCORE_CAT   ;
/*Interactive effects*/
*CCI_CAT;
estimate 'Pan vs pre - CCI 0'    PERIOD -1 1 PERIOD*CCI_CAT -1 0 0 0 0 0 1 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 1'    PERIOD -1 1 PERIOD*CCI_CAT 0 -1 0 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 2'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 -1 0 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 3'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 -1 0 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - CCI 4'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 0 -1 0 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - CCI 5+'   PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 0 0 -1 0 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m10_full_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By VACS Index; /* 4.5 hrs */
proc phreg data = go_model_covid ;
class PERIOD SCORE_CAT SEX RACE7_SR census_nomiss URBAN CCI_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|SCORE_CAT SEX RACE7_SR census_nomiss URBAN CCI_CAT  ;
/*Interactive effects*/
*SCORE_CAT;
estimate 'Pan vs pre - VACS Index 1st'    PERIOD -1 1 PERIOD*SCORE_CAT -1 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 2nd'    PERIOD -1 1 PERIOD*SCORE_CAT 0 -1 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 3rd'    PERIOD -1 1 PERIOD*SCORE_CAT 0 0 -1 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 4th'    PERIOD -1 1 PERIOD*SCORE_CAT 0 0 0 -1 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - VACS Index miss'   PERIOD -1 1 PERIOD*SCORE_CAT 0 0 0 0 -1 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m11_full_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;

















ods excel;
proc print data=DCNP.model_m1_covid;
title "Age-adjusted - censoring at Covid";
run;
proc print data=DCNP.model_m2_covid;
title "+ Demographics - censoring at Covid";
run;
proc print data=DCNP.model_m3_covid;
title "+ CCI and VACS Index - censoring at Covid";
run;
proc print data=DCNP.model_m5_v2_covid; 
title "Age-adjusted, By age group";
run;
proc print data=DCNP.model_m6_covid;
title "Age-adjusted, By sex";
run;
proc print data=DCNP.model_m7_covid;
title "Age-adjusted, By race/ethnicity";
run;
proc print data=DCNP.model_m8_covid;
title "Age-adjusted, By census region";
run;
proc print data=DCNP.model_m9_covid;
title "Age-adjusted, By residence type";
run;
proc print data=DCNP.model_m10_covid;
title "Age-adjusted, By CCI";
run;
proc print data=DCNP.model_m11_covid;
title "Age-adjusted, By VACS Index";
run;
proc print data=DCNP.model_m5_full_covid;
title "Fully-adjusted, By age group";
run;
proc print data=DCNP.model_m6_full_covid;
title "Fully-adjusted, By sex";
run;
proc print data=DCNP.model_m7_full_covid;
title "Fully-adjusted, By race/ethnicity";
run;
proc print data=DCNP.model_m8_full_covid;
title "Fully-adjusted, By census region";
run;
proc print data=DCNP.model_m9_full_covid;
title "Fully-adjusted, By residence type";
run;
proc print data=DCNP.model_m10_full_covid;
title "Fully-adjusted, By CCI";
run;
proc print data=DCNP.model_m11_full_covid;
title "Fully-adjusted, By VACS Index";
run;
proc print data=DCNP.CCI_est_p_unadj_covid ;
title "CCI components, age-adjusted";
run;
proc print data=DCNP.CCI_est_p_covid ;
title "CCI components, fully-adjusted";
run;
title;
ods excel close;
		
















**RUN INTERACTION MODEL WITH CCI GROUPS (REMOVING CCI FROM MODEL)** --3.5 hours each for adjusted;
**CCI - 17 domains individually modelled;
%let list= MI CHF PVD CEVD PARA DEM COPD RHEUM PUD DIAB_NC DIAB_C RD MILDLD MSLD HIV METS CANCER;
%macro charlmodels();
%let nwords=%sysfunc(countw(&list));
%do i = 1 %to &nwords;
	proc phreg data = go_model_covid ;
	class PERIOD SEX RACE7_SR census_nomiss URBAN SCORE_CAT charl_%scan(&list, &i) /param=glm order=internal;
	model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|charl_%scan(&list, &i) SEX RACE7_SR census_nomiss URBAN SCORE_CAT  ;
	estimate "&i._charl_%scan(&list, &i) 0" PERIOD -1 1 PERIOD*charl_%scan(&list, &i) -1 0 1 0 /exp cl;
	estimate "&i._charl_%scan(&list, &i) 1" PERIOD -1 1 PERIOD*charl_%scan(&list, &i) 0 -1 0 1 /exp cl;
	ods output Estimates=DCNP.m3_CCI_%scan(&list, &i)_est_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL))
				ModelANOVA=DCNP.m3_CCI_%scan(&list, &i)_p_covid (keep=Effect WaldChiSq ProbChiSq rename=(WaldChiSq=x2 ProbChiSq=p));
				;
	run;
%end;
%mend;
%charlmodels();
data DCNP.CCI_est_covid;
length Label $18.;
retain MODEL;
set DCNP.m3_CCI_MI_est_covid
	DCNP.m3_CCI_CHF_est_covid
	DCNP.m3_CCI_PVD_est_covid
	DCNP.m3_CCI_CEVD_est_covid
	DCNP.m3_CCI_PARA_est_covid
	DCNP.m3_CCI_DEM_est_covid
	DCNP.m3_CCI_COPD_est_covid
	DCNP.m3_CCI_RHEUM_est_covid
	DCNP.m3_CCI_PUD_est_covid
	DCNP.m3_CCI_DIAB_NC_est_covid
	DCNP.m3_CCI_DIAB_C_est_covid
	DCNP.m3_CCI_RD_est_covid
	DCNP.m3_CCI_MILDLD_est_covid
	DCNP.m3_CCI_MSLD_est_covid
	DCNP.m3_CCI_HIV_est_covid
	DCNP.m3_CCI_METS_est_covid
	DCNP.m3_CCI_CANCER_est_covid
;
if substr(Label,2,1) = "_" then Label = "0" || Label; 

length x MODEL $13.;
x = substr(Label,4,13);
MODEL = scan(x,1);
drop x;

if HR>=10 then HR_c = put(round(HR,0.01),5.2); else HR_c = put(round(HR,0.01),4.2);
if LCL>=10 then LCL_c = put(round(LCL,0.01),5.2); else LCL_c = put(round(LCL,0.01),4.2);
if UCL>=10 then UCL_c = put(round(UCL,0.01),5.2); else UCL_c = put(round(UCL,0.01),4.2);

HR_95CI = CATT(OF HR_c," (",LCL_c , "-",UCL_c , ")");
drop HR_c LCL_c UCL_c;

*renumber;
 /*    if index(MODEL,"MI ")>0 then Label = tranwrd(Label,"01_","01_");
else if index(MODEL,"CHF ")>0 then Label = tranwrd(Label,"02_","02_");
else if index(MODEL,"PVD ")>0 then Label = tranwrd(Label,"01_","03_");
else if index(MODEL,"CEVD ")>0 then Label = tranwrd(Label,"02_","04_");
else if index(MODEL,"PARA ")>0 then Label = tranwrd(Label,"03_","05_");
else if index(MODEL,"DEM ")>0 then Label = tranwrd(Label,"04_","06_");
else*/ if index(MODEL,"COPD ")>0 then Label = tranwrd(Label,"01_","07_");
else if index(MODEL,"RHEUM ")>0 then Label = tranwrd(Label,"02_","08_");
else if index(MODEL,"PUD ")>0 then Label = tranwrd(Label,"03_","09_");
else if index(MODEL,"DIAB_NC")>0 then Label = tranwrd(Label,"04_","10_");
else if index(MODEL,"DIAB_C ")>0 then Label = tranwrd(Label,"05_","11_");
else if index(MODEL,"RD ")>0 then Label = tranwrd(Label,"06_","12_");
else if index(MODEL,"MILDLD ")>0 then Label = tranwrd(Label,"07_","13_");
else if index(MODEL,"MSLD ")>0 then Label = tranwrd(Label,"01_","14_");
else if index(MODEL,"HIV ")>0 then Label = tranwrd(Label,"02_","15_");
else if index(MODEL,"METS ")>0 then Label = tranwrd(Label,"03_","16_");
else if index(MODEL,"CANCER ")>0 then Label = tranwrd(Label,"04_","17_");
run;
data DCNP.CCI_p_covid;
length Effect $20.;
retain MODEL ;
set DCNP.m3_CCI_MI_p_covid
	DCNP.m3_CCI_CHF_p_covid
	DCNP.m3_CCI_PVD_p_covid
	DCNP.m3_CCI_CEVD_p_covid
	DCNP.m3_CCI_PARA_p_covid
	DCNP.m3_CCI_DEM_p_covid
	DCNP.m3_CCI_COPD_p_covid
	DCNP.m3_CCI_RHEUM_p_covid
	DCNP.m3_CCI_PUD_p_covid
	DCNP.m3_CCI_DIAB_NC_p_covid
	DCNP.m3_CCI_DIAB_C_p_covid
	DCNP.m3_CCI_RD_p_covid
	DCNP.m3_CCI_MILDLD_p_covid
	DCNP.m3_CCI_MSLD_p_covid
	DCNP.m3_CCI_HIV_p_covid
	DCNP.m3_CCI_METS_p_covid
	DCNP.m3_CCI_CANCER_p_covid
;
where substr(Effect,1,12)="PERIOD*charl";

length MODEL $13.;
MODEL = substr(Effect,8,13);
run;
proc sort data=DCNP.CCI_est_covid; by MODEL; run;
proc sort data=DCNP.CCI_p_covid; by MODEL; run;
data DCNP.CCI_est_p_covid;
merge DCNP.CCI_est_covid DCNP.CCI_p_covid;
by MODEL;
if last.MODEL then do;
	Effect = "";
	x2 = .;
	p = .;
end;
run;
proc sort data=DCNP.CCI_est_p_covid;
by Label ;
run;
proc print data=DCNP.CCI_est_p_covid noobs;
run;













*AGE-ADJUSTED ONLY;
**RUN INTERACTION MODEL WITH CCI GROUPS (REMOVING CCI FROM MODEL)** --1.25 hours each for unadjusted;
**CCI - 17 domains individually modelled;
%let list= MI CHF PVD CEVD PARA DEM COPD RHEUM PUD DIAB_NC DIAB_C RD MILDLD MSLD HIV METS CANCER;
%macro charlmodels();
%let nwords=%sysfunc(countw(&list));
%do i = 1 %to &nwords;
	proc phreg data = go_model_covid ;
	class PERIOD /*SEX RACE7_SR census_nomiss URBAN SCORE_CAT*/ charl_%scan(&list, &i) /param=glm order=internal;
	model (age_start_rnd, age_end_rnd_covid)*DIED_COVID(0)=  PERIOD|charl_%scan(&list, &i) /*SEX RACE7_SR census_nomiss URBAN SCORE_CAT*/  ;
	estimate "&i._charl_%scan(&list, &i) 0" PERIOD -1 1 PERIOD*charl_%scan(&list, &i) -1 0 1 0 /exp cl;
	estimate "&i._charl_%scan(&list, &i) 1" PERIOD -1 1 PERIOD*charl_%scan(&list, &i) 0 -1 0 1 /exp cl;
	ods output Estimates=DCNP.m3_unadj_CCI_%scan(&list, &i)_est_covid (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL))
				ModelANOVA=DCNP.m3_unadj_CCI_%scan(&list, &i)_p_covid (keep=Effect WaldChiSq ProbChiSq rename=(WaldChiSq=x2 ProbChiSq=p));
				;
	run;
%end;
%mend;
%charlmodels();
data DCNP.CCI_est_unadj_covid;
length Label $18.;
retain MODEL;
set DCNP.m3_unadj_CCI_MI_est_covid
	DCNP.m3_unadj_CCI_CHF_est_covid
	DCNP.m3_unadj_CCI_PVD_est_covid
	DCNP.m3_unadj_CCI_CEVD_est_covid
	DCNP.m3_unadj_CCI_PARA_est_covid
	DCNP.m3_unadj_CCI_DEM_est_covid
	DCNP.m3_unadj_CCI_COPD_est_covid
	DCNP.m3_unadj_CCI_RHEUM_est_covid
	DCNP.m3_unadj_CCI_PUD_est_covid
	DCNP.m3_unadj_CCI_DIAB_NC_est_covid
	DCNP.m3_unadj_CCI_DIAB_C_est_covid
	DCNP.m3_unadj_CCI_RD_est_covid
	DCNP.m3_unadj_CCI_MILDLD_est_covid
	DCNP.m3_unadj_CCI_MSLD_est_covid
	DCNP.m3_unadj_CCI_HIV_est_covid
	DCNP.m3_unadj_CCI_METS_est_covid
	DCNP.m3_unadj_CCI_CANCER_est_covid
;
if substr(Label,2,1) = "_" then Label = "0" || Label; 

length x MODEL $13.;
x = substr(Label,4,13);
MODEL = scan(x,1);
drop x;

if HR>=10 then HR_c = put(round(HR,0.01),5.2); else HR_c = put(round(HR,0.01),4.2);
if LCL>=10 then LCL_c = put(round(LCL,0.01),5.2); else LCL_c = put(round(LCL,0.01),4.2);
if UCL>=10 then UCL_c = put(round(UCL,0.01),5.2); else UCL_c = put(round(UCL,0.01),4.2);

HR_95CI = CATT(OF HR_c," (",LCL_c , "-",UCL_c , ")");
drop HR_c LCL_c UCL_c;

*renumber those that need renumbering;
/*     if index(MODEL,"MI ")>0 then Label = tranwrd(Label,"01_","01_");
else if index(MODEL,"CHF ")>0 then Label = tranwrd(Label,"02_","02_");
else if index(MODEL,"PVD ")>0 then Label = tranwrd(Label,"01_","03_");
else if index(MODEL,"CEVD ")>0 then Label = tranwrd(Label,"02_","04_");
else if index(MODEL,"PARA ")>0 then Label = tranwrd(Label,"03_","05_");
else if index(MODEL,"DEM ")>0 then Label = tranwrd(Label,"04_","06_");
else if index(MODEL,"COPD ")>0 then Label = tranwrd(Label,"05_","07_");
else if index(MODEL,"RHEUM ")>0 then Label = tranwrd(Label,"06_","08_");
else if index(MODEL,"PUD ")>0 then Label = tranwrd(Label,"01_","09_");
else if index(MODEL,"DIAB_NC")>0 then Label = tranwrd(Label,"02_","10_");
else if index(MODEL,"DIAB_C ")>0 then Label = tranwrd(Label,"03_","11_");
else if index(MODEL,"RD ")>0 then Label = tranwrd(Label,"04_","12_");
else if index(MODEL,"MILDLD ")>0 then Label = tranwrd(Label,"05_","13_");
else if index(MODEL,"MSLD ")>0 then Label = tranwrd(Label,"06_","14_");
else if index(MODEL,"HIV ")>0 then Label = tranwrd(Label,"01_","15_");
else if index(MODEL,"METS ")>0 then Label = tranwrd(Label,"02_","16_");
else if index(MODEL,"CANCER ")>0 then Label = tranwrd(Label,"03_","17_");*/
run;
data DCNP.CCI_p_unadj_covid;
length Effect $20.;
retain MODEL ;
set DCNP.m3_unadj_CCI_MI_p_covid
	DCNP.m3_unadj_CCI_CHF_p_covid
	DCNP.m3_unadj_CCI_PVD_p_covid
	DCNP.m3_unadj_CCI_CEVD_p_covid
	DCNP.m3_unadj_CCI_PARA_p_covid
	DCNP.m3_unadj_CCI_DEM_p_covid
	DCNP.m3_unadj_CCI_COPD_p_covid
	DCNP.m3_unadj_CCI_RHEUM_p_covid
	DCNP.m3_unadj_CCI_PUD_p_covid
	DCNP.m3_unadj_CCI_DIAB_NC_p_covid
	DCNP.m3_unadj_CCI_DIAB_C_p_covid
	DCNP.m3_unadj_CCI_RD_p_covid
	DCNP.m3_unadj_CCI_MILDLD_p_covid
	DCNP.m3_unadj_CCI_MSLD_p_covid
	DCNP.m3_unadj_CCI_HIV_p_covid
	DCNP.m3_unadj_CCI_METS_p_covid
	DCNP.m3_unadj_CCI_CANCER_p_covid
;
where substr(Effect,1,12)="PERIOD*charl";

length MODEL $13.;
MODEL = substr(Effect,8,13);
run;
proc sort data=DCNP.CCI_est_unadj_covid; by MODEL; run;
proc sort data=DCNP.CCI_p_unadj_covid; by MODEL; run;
data DCNP.CCI_est_p_unadj_covid;
merge DCNP.CCI_est_unadj_covid DCNP.CCI_p_unadj_covid;
by MODEL;
if last.MODEL then do;
	Effect = "";
	x2 = .;
	p = .;
end;
run;
proc sort data=DCNP.CCI_est_p_unadj_covid;
by Label ;
run;
proc print data=DCNP.CCI_est_p_unadj_covid noobs;
run;


