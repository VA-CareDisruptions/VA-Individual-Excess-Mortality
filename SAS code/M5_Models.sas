**********************************


Run models

cohort: VACS-National
started: 12 January 2022
Author: CTR

**********************************;




libname DCNP "<redacted-sensitive information>";
libname OUT "<redacted-sensitive information>";





 
 

*temp dataset for modelling;
data go_model;
set DCNP.go ;
     if age_start_rnd                        < 45 then ageb = 1; 
else if age_start_rnd >=45 and age_start_rnd < 65 then ageb = 2; 
else if age_start_rnd >=65 and age_start_rnd < 75 then ageb = 3;  
else if age_start_rnd >=75 and age_start_rnd < 85 then ageb = 4;
else if age_start_rnd >=85                        then ageb = 5; 
run;


*age-adjusted;
proc phreg data = go_model ;
class PERIOD  /param=glm order=internal;/* 30 mins */
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD    ;
/*Independent effects*/
estimate 'Pan vs pre'   			PERIOD -1 1 /exp cl;
ods output Estimates=DCNP.model_m1 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* +Demographics; /* 2 hrs */
proc phreg data = go_model ;
class PERIOD SEX RACE7_SR census_nomiss URBAN /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD SEX RACE7_SR census_nomiss URBAN  ;
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
ods output Estimates=DCNP.model_m2 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;





* +CCI and VACS Index; /* 3 hrs */
proc phreg data = go_model ;
class PERIOD SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT  ;
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
ods output Estimates=DCNP.model_m3 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;









* Age-adjusted, By age group; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD SEX /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|ageb0 PERIOD|ageb1 PERIOD|ageb2 PERIOD|ageb3 PERIOD|ageb4;
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
ods output Estimates=DCNP.model_m5_v2 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By sex; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD SEX  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|SEX   ;
/*Interactive effects*/
*SEX;
estimate 'Pan vs pre - Men'   PERIOD -1 1 PERIOD*SEX 0 -1 0 1 /exp cl;
estimate 'Pan vs pre - Women' PERIOD -1 1 PERIOD*SEX -1 0 1 0 /exp cl;
ods output Estimates=DCNP.model_m6 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;


* Age-adjusted, By race/ethnicity; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD RACE7_SR  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=   PERIOD|RACE7_SR   ;
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
ods output Estimates=DCNP.model_m7 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By census region; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD census_nomiss  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=   PERIOD|census_nomiss   ;
/*Interactive effects*/
*census_nomiss;
estimate 'Pan vs pre - MW'   PERIOD -1 1 PERIOD*census_nomiss -1 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - NE'   PERIOD -1 1 PERIOD*census_nomiss 0 -1 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - S'    PERIOD -1 1 PERIOD*census_nomiss 0 0 -1 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - W'    PERIOD -1 1 PERIOD*census_nomiss 0 0 0 -1 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m8 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By residence type; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD  URBAN /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|URBAN  ;
/*Interactive effects*/
*Urban;
estimate 'Pan vs pre - Urban'   PERIOD -1 1 PERIOD*URBAN 0 -1 0 1 /exp cl;
estimate 'Pan vs pre - Rural' 	PERIOD -1 1 PERIOD*URBAN -1 0 1 0 /exp cl;
ods output Estimates=DCNP.model_m9 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By CCI; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD CCI_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|CCI_CAT  ;
/*Interactive effects*/
*CCI_CAT;
estimate 'Pan vs pre - CCI 0'    PERIOD -1 1 PERIOD*CCI_CAT -1 0 0 0 0 0 1 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 1'    PERIOD -1 1 PERIOD*CCI_CAT 0 -1 0 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 2'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 -1 0 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 3'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 -1 0 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - CCI 4'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 0 -1 0 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - CCI 5+'   PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 0 0 -1 0 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m10 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Age-adjusted, By VACS Index; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD SCORE_CAT /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|SCORE_CAT  ;
/*Interactive effects*/
*SCORE_CAT;
estimate 'Pan vs pre - VACS Index 1st'    PERIOD -1 1 PERIOD*SCORE_CAT -1 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 2nd'    PERIOD -1 1 PERIOD*SCORE_CAT 0 -1 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 3rd'    PERIOD -1 1 PERIOD*SCORE_CAT 0 0 -1 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 4th'    PERIOD -1 1 PERIOD*SCORE_CAT 0 0 0 -1 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - VACS Index miss'   PERIOD -1 1 PERIOD*SCORE_CAT 0 0 0 0 -1 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m11 (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;









* Fully-adjusted, By age group; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|ageb0 PERIOD|ageb1 PERIOD|ageb2 PERIOD|ageb3 PERIOD|ageb4 SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT;
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
ods output Estimates=DCNP.model_m5_full (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By sex; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT  ;
/*Interactive effects*/
*SEX;
estimate 'Pan vs pre - Men'   PERIOD -1 1 PERIOD*SEX 0 -1 0 1 /exp cl;
estimate 'Pan vs pre - Women' PERIOD -1 1 PERIOD*SEX -1 0 1 0 /exp cl;
ods output Estimates=DCNP.model_m6_full (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By race/ethnicity; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD RACE7_SR SEX census_nomiss URBAN CCI_CAT SCORE_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=   PERIOD|RACE7_SR SEX census_nomiss URBAN CCI_CAT SCORE_CAT   ;
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
ods output Estimates=DCNP.model_m7_full (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By census region; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD census_nomiss SEX RACE7_SR URBAN CCI_CAT SCORE_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=   PERIOD|census_nomiss SEX RACE7_SR URBAN CCI_CAT SCORE_CAT   ;
/*Interactive effects*/
*census_nomiss;
estimate 'Pan vs pre - MW'   PERIOD -1 1 PERIOD*census_nomiss -1 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - NE'   PERIOD -1 1 PERIOD*census_nomiss 0 -1 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - S'    PERIOD -1 1 PERIOD*census_nomiss 0 0 -1 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - W'    PERIOD -1 1 PERIOD*census_nomiss 0 0 0 -1 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m8_full (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By residence type; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD  URBAN SEX RACE7_SR census_nomiss CCI_CAT SCORE_CAT /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|URBAN  SEX RACE7_SR census_nomiss CCI_CAT SCORE_CAT;
/*Interactive effects*/
*Urban;
estimate 'Pan vs pre - Urban'   PERIOD -1 1 PERIOD*URBAN 0 -1 0 1 /exp cl;
estimate 'Pan vs pre - Rural' 	PERIOD -1 1 PERIOD*URBAN -1 0 1 0 /exp cl;
ods output Estimates=DCNP.model_m9_full (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By CCI; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD CCI_CAT SEX RACE7_SR census_nomiss URBAN  SCORE_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|CCI_CAT SEX RACE7_SR census_nomiss URBAN  SCORE_CAT   ;
/*Interactive effects*/
*CCI_CAT;
estimate 'Pan vs pre - CCI 0'    PERIOD -1 1 PERIOD*CCI_CAT -1 0 0 0 0 0 1 0 0 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 1'    PERIOD -1 1 PERIOD*CCI_CAT 0 -1 0 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 2'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 -1 0 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - CCI 3'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 -1 0 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - CCI 4'    PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 0 -1 0 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - CCI 5+'   PERIOD -1 1 PERIOD*CCI_CAT 0 0 0 0 0 -1 0 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m10_full (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;



* Fully-adjusted, By VACS Index; /* 1-3 hrs */
proc phreg data = go_model ;
class PERIOD SCORE_CAT SEX RACE7_SR census_nomiss URBAN CCI_CAT  /param=glm order=internal;
model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|SCORE_CAT SEX RACE7_SR census_nomiss URBAN CCI_CAT  ;
/*Interactive effects*/
*SCORE_CAT;
estimate 'Pan vs pre - VACS Index 1st'    PERIOD -1 1 PERIOD*SCORE_CAT -1 0 0 0 0 1 0 0 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 2nd'    PERIOD -1 1 PERIOD*SCORE_CAT 0 -1 0 0 0 0 1 0 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 3rd'    PERIOD -1 1 PERIOD*SCORE_CAT 0 0 -1 0 0 0 0 1 0 0 /exp cl;
estimate 'Pan vs pre - VACS Index 4th'    PERIOD -1 1 PERIOD*SCORE_CAT 0 0 0 -1 0 0 0 0 1 0 /exp cl;
estimate 'Pan vs pre - VACS Index miss'   PERIOD -1 1 PERIOD*SCORE_CAT 0 0 0 0 -1 0 0 0 0 1 /exp cl;
ods output Estimates=DCNP.model_m11_full (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL));
run;




















ods excel;
proc print data=DCNP.model_m1;
title "Age-adjusted";
run;
proc print data=DCNP.model_m2;
title "+ Demographics";
run;
proc print data=DCNP.model_m3;
title "+ CCI and VACS Index";
run;
proc print data=DCNP.model_m5_v2; 
title "Age-adjusted, By age group";
run;
proc print data=DCNP.model_m6;
title "Age-adjusted, By sex";
run;
proc print data=DCNP.model_m7;
title "Age-adjusted, By race/ethnicity";
run;
proc print data=DCNP.model_m8;
title "Age-adjusted, By census region";
run;
proc print data=DCNP.model_m9;
title "Age-adjusted, By residence type";
run;
proc print data=DCNP.model_m10;
title "Age-adjusted, By CCI";
run;
proc print data=DCNP.model_m11;
title "Age-adjusted, By VACS Index";
run;
proc print data=DCNP.model_m5_full;
title "Fully-adjusted, By age group";
run;
proc print data=DCNP.model_m6_full;
title "Fully-adjusted, By sex";
run;
proc print data=DCNP.model_m7_full;
title "Fully-adjusted, By race/ethnicity";
run;
proc print data=DCNP.model_m8_full;
title "Fully-adjusted, By census region";
run;
proc print data=DCNP.model_m9_full;
title "Fully-adjusted, By residence type";
run;
proc print data=DCNP.model_m10_full;
title "Fully-adjusted, By CCI";
run;
proc print data=DCNP.model_m11_full;
title "Fully-adjusted, By VACS Index";
run;
proc print data=DCNP.CCI_est_p_unadj ;
title "CCI components, age-adjusted";
run;
proc print data=DCNP.CCI_est_p ;
title "CCI components, fully-adjusted";
run;
title;
ods excel close;
		

*combine and put into HR (95% CI) format, then create table in Excel;









*************************************************************************************
				BY DIAGNOSTIC GROUP CATEGORIES (CCI)
************************************************************************************;






**RUN INTERACTION MODEL WITH CCI GROUPS (REMOVING CCI FROM MODEL)** --3.5 hours each for adjusted;
**CCI - 17 domains individually modelled;
%let list= MI CHF PVD CEVD PARA DEM COPD RHEUM PUD DIAB_NC DIAB_C RD MILDLD MSLD HIV METS CANCER;
%macro charlmodels();
%let nwords=%sysfunc(countw(&list));
%do i = 1 %to &nwords;
	proc phreg data = go_model ;
	class PERIOD SEX RACE7_SR census_nomiss URBAN SCORE_CAT charl_%scan(&list, &i) /param=glm order=internal;
	model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|charl_%scan(&list, &i) SEX RACE7_SR census_nomiss URBAN SCORE_CAT  ;
	estimate "&i._charl_%scan(&list, &i) 0" PERIOD -1 1 PERIOD*charl_%scan(&list, &i) -1 0 1 0 /exp cl;
	estimate "&i._charl_%scan(&list, &i) 1" PERIOD -1 1 PERIOD*charl_%scan(&list, &i) 0 -1 0 1 /exp cl;
	ods output Estimates=DCNP.model_m3_CCI_%scan(&list, &i)_est (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL))
				ModelANOVA=DCNP.model_m3_CCI_%scan(&list, &i)_p (keep=Effect WaldChiSq ProbChiSq rename=(WaldChiSq=x2 ProbChiSq=p));
				;
	run;
%end;
%mend;
%charlmodels();
data DCNP.CCI_est;
length Label $18.;
retain MODEL;
set DCNP.model_m3_CCI_MI_est
	DCNP.model_m3_CCI_CHF_est
	DCNP.model_m3_CCI_PVD_est
	DCNP.model_m3_CCI_CEVD_est
	DCNP.model_m3_CCI_PARA_est
	DCNP.model_m3_CCI_DEM_est
	DCNP.model_m3_CCI_COPD_est
	DCNP.model_m3_CCI_RHEUM_est
	DCNP.model_m3_CCI_PUD_est
	DCNP.model_m3_CCI_DIAB_NC_est
	DCNP.model_m3_CCI_DIAB_C_est
	DCNP.model_m3_CCI_RD_est
	DCNP.model_m3_CCI_MILDLD_est
	DCNP.model_m3_CCI_MSLD_est
	DCNP.model_m3_CCI_HIV_est
	DCNP.model_m3_CCI_METS_est
	DCNP.model_m3_CCI_CANCER_est
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
     if index(MODEL,"MI ")>0 then Label = tranwrd(Label,"01_","01_");
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
else if index(MODEL,"CANCER ")>0 then Label = tranwrd(Label,"03_","17_");
run;
data DCNP.CCI_p;
length Effect $20.;
retain MODEL ;
set DCNP.model_m3_CCI_MI_p
	DCNP.model_m3_CCI_CHF_p
	DCNP.model_m3_CCI_PVD_p
	DCNP.model_m3_CCI_CEVD_p
	DCNP.model_m3_CCI_PARA_p
	DCNP.model_m3_CCI_DEM_p
	DCNP.model_m3_CCI_COPD_p
	DCNP.model_m3_CCI_RHEUM_p
	DCNP.model_m3_CCI_PUD_p
	DCNP.model_m3_CCI_DIAB_NC_p
	DCNP.model_m3_CCI_DIAB_C_p
	DCNP.model_m3_CCI_RD_p
	DCNP.model_m3_CCI_MILDLD_p
	DCNP.model_m3_CCI_MSLD_p
	DCNP.model_m3_CCI_HIV_p
	DCNP.model_m3_CCI_METS_p
	DCNP.model_m3_CCI_CANCER_p
;
where substr(Effect,1,12)="PERIOD*charl";

length MODEL $13.;
MODEL = substr(Effect,8,13);
run;
proc sort data=DCNP.CCI_est; by MODEL; run;
proc sort data=DCNP.CCI_p; by MODEL; run;
data DCNP.CCI_est_p;
merge DCNP.CCI_est DCNP.CCI_p;
by MODEL;
if last.MODEL then do;
	Effect = "";
	x2 = .;
	p = .;
end;
run;
proc sort data=DCNP.CCI_est_p;
by Label ;
run;
proc print data=DCNP.CCI_est_p noobs;
run;













*AGE-ADJUSTED ONLY;
**RUN INTERACTION MODEL WITH CCI GROUPS (REMOVING CCI FROM MODEL)** --3.5 hours each for adjusted;
**CCI - 17 domains individually modelled;
%let list= MI CHF PVD CEVD PARA DEM COPD RHEUM PUD DIAB_NC DIAB_C RD MILDLD MSLD HIV METS CANCER;
%macro charlmodels();
%let nwords=%sysfunc(countw(&list));
%do i = 1 %to &nwords;
	proc phreg data = go_model ;
	class PERIOD /*SEX RACE7_SR census_nomiss URBAN SCORE_CAT*/ charl_%scan(&list, &i) /param=glm order=internal;
	model (age_start_rnd, age_end_rnd)*DIED(0)=  PERIOD|charl_%scan(&list, &i) /*SEX RACE7_SR census_nomiss URBAN SCORE_CAT*/  ;
	estimate "&i._charl_%scan(&list, &i) 0" PERIOD -1 1 PERIOD*charl_%scan(&list, &i) -1 0 1 0 /exp cl;
	estimate "&i._charl_%scan(&list, &i) 1" PERIOD -1 1 PERIOD*charl_%scan(&list, &i) 0 -1 0 1 /exp cl;
	ods output Estimates=DCNP.model_m3_unadj_CCI_%scan(&list, &i)_est (keep=Label ExpEstimate LowerExp UpperExp rename=(ExpEstimate=HR LowerExp=LCL UpperExp=UCL))
				ModelANOVA=DCNP.model_m3_unadj_CCI_%scan(&list, &i)_p (keep=Effect WaldChiSq ProbChiSq rename=(WaldChiSq=x2 ProbChiSq=p));
				;
	run;
%end;
%mend;
%charlmodels();
data DCNP.CCI_est_unadj;
length Label $18.;
retain MODEL;
set DCNP.model_m3_unadj_CCI_MI_est
	DCNP.model_m3_unadj_CCI_CHF_est
	DCNP.model_m3_unadj_CCI_PVD_est
	DCNP.model_m3_unadj_CCI_CEVD_est
	DCNP.model_m3_unadj_CCI_PARA_est
	DCNP.model_m3_unadj_CCI_DEM_est
	DCNP.model_m3_unadj_CCI_COPD_est
	DCNP.model_m3_unadj_CCI_RHEUM_est
	DCNP.model_m3_unadj_CCI_PUD_est
	DCNP.model_m3_unadj_CCI_DIAB_NC_est
	DCNP.model_m3_unadj_CCI_DIAB_C_est
	DCNP.model_m3_unadj_CCI_RD_est
	DCNP.model_m3_unadj_CCI_MILDLD_est
	DCNP.model_m3_unadj_CCI_MSLD_est
	DCNP.model_m3_unadj_CCI_HIV_est
	DCNP.model_m3_unadj_CCI_METS_est
	DCNP.model_m3_unadj_CCI_CANCER_est
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
else*/ if index(MODEL,"HIV ")>0 then Label = tranwrd(Label,"01_","15_");
else if index(MODEL,"METS ")>0 then Label = tranwrd(Label,"02_","16_");
else if index(MODEL,"CANCER ")>0 then Label = tranwrd(Label,"03_","17_");
run;
data DCNP.CCI_p_unadj;
length Effect $20.;
retain MODEL ;
set DCNP.model_m3_unadj_CCI_MI_p
	DCNP.model_m3_unadj_CCI_CHF_p
	DCNP.model_m3_unadj_CCI_PVD_p
	DCNP.model_m3_unadj_CCI_CEVD_p
	DCNP.model_m3_unadj_CCI_PARA_p
	DCNP.model_m3_unadj_CCI_DEM_p
	DCNP.model_m3_unadj_CCI_COPD_p
	DCNP.model_m3_unadj_CCI_RHEUM_p
	DCNP.model_m3_unadj_CCI_PUD_p
	DCNP.model_m3_unadj_CCI_DIAB_NC_p
	DCNP.model_m3_unadj_CCI_DIAB_C_p
	DCNP.model_m3_unadj_CCI_RD_p
	DCNP.model_m3_unadj_CCI_MILDLD_p
	DCNP.model_m3_unadj_CCI_MSLD_p
	DCNP.model_m3_unadj_CCI_HIV_p
	DCNP.model_m3_unadj_CCI_METS_p
	DCNP.model_m3_unadj_CCI_CANCER_p
;
where substr(Effect,1,12)="PERIOD*charl";

length MODEL $13.;
MODEL = substr(Effect,8,13);
run;
proc sort data=DCNP.CCI_est_unadj; by MODEL; run;
proc sort data=DCNP.CCI_p_unadj; by MODEL; run;
data DCNP.CCI_est_p_unadj;
merge DCNP.CCI_est_unadj DCNP.CCI_p_unadj;
by MODEL;
if last.MODEL then do;
	Effect = "";
	x2 = .;
	p = .;
end;
run;
proc sort data=DCNP.CCI_est_p_unadj;
by Label ;
run;
proc print data=DCNP.CCI_est_p_unadj noobs;
run;




























*get mortality rates pre and pandemic;
proc print data=DCNP.GO (obs=10) noobs;
run;
proc contents data=DCNP.GO ;
run;
proc freq data=DCNP.GO;
tables AGE_BL_CAT;
run;
data rates;
set DCNP.GO (keep=scrssn_n AGE_BL_CAT SEX RACE7_SR census_nomiss URBAN CCI_CAT SCORE_CAT DT_BASELINE DT_LAST DIED risk PERIOD charl_:);
py = risk/365.242;
*clean up;
length SEX_c $1. URBAN_c $5. AGEB $5.;

if SEX = 0 then SEX_c = "F";
else if SEX = 1 then SEX_c = "M";

if URBAN = 0 then URBAN_c = "RURAL";
else if URBAN = 1 then URBAN_c = "URBAN";

if AGE_BL_CAT in("18-24","25-34","35-44") then AGEB = "18-44";
else if AGE_BL_CAT in("45-54","55-64") then AGEB = "45-64";
else AGEB = AGE_BL_CAT;
run;
proc contents data=rates ;
run;
proc freq data=rates;
tables AGE_BL_CAT*AGEB/list;
run;



*OVERALL;
proc freq data = rates formchar="          ";
tables PERIOD*DIED /nocol norow nopercent out=freq_DIED (drop=percent);
run;
proc transpose data=freq_DIED out=count (drop=_:) prefix=DIED_;
by PERIOD; id DIED; var COUNT;
run;
proc means data = rates noprint nway;
class PERIOD;
var py ;
output out=py (drop=_:) sum=py;
run;
proc sort data=count;
by PERIOD;
proc sort data=py;
by PERIOD;
data DCNP.count_py;
merge count py;
by PERIOD;
rate1000 = (DIED_1/py)*1000;
run;
proc print data = DCNP.count_py noobs;
run;

*BY DEMOGRAPHICS, CCI, VACS Index;
%let list= SEX_c RACE7_SR census_nomiss URBAN_c CCI_CAT SCORE_CAT AGEB;
%macro rates_demog();
%let nwords=%sysfunc(countw(&list));
%do i = 1 %to &nwords;
proc freq data = rates formchar="          ";
tables %scan(&list, &i)*PERIOD*DIED /nocol norow nopercent out=freq_DIED (drop=percent);
run;
proc transpose data=freq_DIED out=count (drop=_:) prefix=DIED_;
by %scan(&list, &i) PERIOD; id DIED; var COUNT;
run;
proc means data = rates noprint nway;
class %scan(&list, &i) PERIOD;
var py ;
output out=py (drop=_:) sum=py;
run;
proc sort data=count;
by %scan(&list, &i) PERIOD;
proc sort data=py;
by %scan(&list, &i) PERIOD;
data DCNP.count_py_demog_%scan(&list, &i);
retain VAR YES_NO;
merge count py;
by %scan(&list, &i) PERIOD;
rate1000 = (DIED_1/py)*1000;
length VAR $13. YES_NO $17.;
YES_NO = %scan(&list, &i);
drop %scan(&list, &i);
VAR = "%scan(&list, &i)";
run;
%end;
%mend;
%rates_demog();
data DCNP.count_py_demog;
set DCNP.count_py_demog_AGEB
	DCNP.count_py_demog_SEX_c
	DCNP.count_py_demog_RACE7_SR
	DCNP.count_py_demog_census_nomiss
	DCNP.count_py_demog_URBAN_c
	DCNP.count_py_demog_CCI_CAT
	DCNP.count_py_demog_SCORE_CAT	
;
run;
proc print data = DCNP.count_py_demog noobs;
run;


*BY CCI DOMAIN;
%let list= MI CHF PVD CEVD PARA DEM COPD RHEUM PUD DIAB_NC DIAB_C RD MILDLD MSLD HIV METS CANCER;
%macro rates_charl();
%let nwords=%sysfunc(countw(&list));
%do i = 1 %to &nwords;
proc freq data = rates formchar="          ";
tables charl_%scan(&list, &i)*PERIOD*DIED /nocol norow nopercent out=freq_DIED (drop=percent);
run;
proc transpose data=freq_DIED out=count (drop=_:) prefix=DIED_;
by charl_%scan(&list, &i) PERIOD; id DIED; var COUNT;
run;
proc means data = rates noprint nway;
class charl_%scan(&list, &i) PERIOD;
var py ;
output out=py (drop=_:) sum=py;
run;
proc sort data=count;
by charl_%scan(&list, &i) PERIOD;
proc sort data=py;
by charl_%scan(&list, &i) PERIOD;
data DCNP.count_py_charl_%scan(&list, &i);
retain CHARL YES_NO;
merge count py;
by charl_%scan(&list, &i) PERIOD;
rate1000 = (DIED_1/py)*1000;
length CHARL $7. YES_NO 3.;
YES_NO = charl_%scan(&list, &i);
drop charl_%scan(&list, &i);
CHARL = "%scan(&list, &i)";
run;
%end;
%mend;
%rates_charl();
data DCNP.count_py_charl;
set DCNP.count_py_charl_MI
	DCNP.count_py_charl_CHF
	DCNP.count_py_charl_PVD
	DCNP.count_py_charl_CEVD
	DCNP.count_py_charl_PARA
	DCNP.count_py_charl_DEM
	DCNP.count_py_charl_COPD
	DCNP.count_py_charl_RHEUM
	DCNP.count_py_charl_PUD
	DCNP.count_py_charl_DIAB_NC
	DCNP.count_py_charl_DIAB_C
	DCNP.count_py_charl_RD
	DCNP.count_py_charl_MILDLD
	DCNP.count_py_charl_MSLD
	DCNP.count_py_charl_HIV
	DCNP.count_py_charl_METS
	DCNP.count_py_charl_CANCER
;
run;
proc print data = DCNP.count_py_charl noobs;
run;









ods excel;
proc print data = DCNP.count_py noobs;
title "Crude rates - overall";
run;
proc print data = DCNP.count_py_demog noobs;
title "Crude rates - demog, CCI, VACS Index";
run;
proc print data = DCNP.count_py_charl noobs;
title "Crude rates - CCI";
run;

title;
ods excel close;













