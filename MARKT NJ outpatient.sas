libname AHA 'R:\Data\Open\AHA';
libname NJ 'R:\Data\Encrypted\HCUP\NJ';
libname markt 'R:\Core\DataCore\PanT\Value\Office of Value Management\Data Request\Vijay Nair\20150918_NJ 2013 HCUP';
options mprint;

*******************************************************
*Before running the macro, the &cpt should be changed *
* to the total of cpts the database has. in %let cpt=?*
*and %macro HCUP_MARKT_FORMAT(STATE,YEAR)			  *
*******************************************************;


%macro HCUP_MARKT_MERGE(state,year,cpttotal);
*******************************************************
*merge state year aha dataset with general AHA dataset*
*******************************************************;
	PROC SQL;
		CREATE TABLE work.AHA AS
		SELECT A.DSHOSPID,
				A.AHAID,
				B.MNAME,
				B.MLOCZIP
		FROM &state..&state._sasdc_2012_ahal AS A LEFT JOIN AHA.PUBAS11 AS B
		ON A.AHAID=B.ID;
	QUIT;
*******************************************************
*import CPT code list and chage the format            *
*******************************************************;
	proc import datafile='R:\Core\DataCore\GeY\Projects\SAS_Projects\Value Proposition Project\HCUP_MARKT_2014\McKinsey HCPCS Codes_No Minor.xlsx'
	  out=MARKT.CPTlist dbms=EXCEL replace;
	  range='A5:C852';
	  getnames=YES;
	RUN;

	DATA MARKT.CPTLIST (keep=cpt);
		SET MARKT.CPTLIST;
	cpt=strip(put(hcpcs_code,5.));
	run;
*******************************************************
*Create macro variable for CPT list                   *
*******************************************************;
	PROC sql noprint;
	select distinct cats('"',cpt,'"')
	into :cptlist separated by ' '
	from MARKT.CPTLIST;
	%let cptcount=&sqlobs;
	QUIT;

	DATA work.HCUP_&state.&year._v1(keep=age pstate pcity zip dshospid hospst atype hcup_ed pr1 pay1 pay2 nummatchcpt firstcptpos numCPT cpt1-cpt&cpttotal.);
		SET &state..&state._sasdc_&year._core(where=(atype=3 and hcup_ed=0));
		array a_cpt{1:&cpttotal.} cpt1-cpt&cpttotal.;
		array a_cptlist{&cptcount} $ _temporary_ (&cptlist);
		j=1;
		nummatchcpt=0;*# of CPTS matches with Mckinsey CPTs list;	
		firstcptpos=0;*The position of first matched CPT; 
		numCPT=0;*# of CPT a discharge has in total;
		_output=0;
		
		do until (j ge &cpttotal.);
			if a_cpt[j]^='' then do;
				numCPT=numCPT+1;
				do t=1 to &cptcount;
					if a_cpt[j]=a_cptlist[t] then do;
						nummatchcpt=nummatchcpt+1;
						if _output=0 then firstcptpos=j;
						pcity=zipcity(zip);
						label pcity='Patient city';
						_output=1;
						leave;
					end;
				end;
			end;
			j+1;
		end;

		if _output=1 then output;	
	RUN;

	PROC SQL;
	CREATE TABLE work.HCUP_&state.&year._v2 AS
	SELECT A.*,
			B.AHAID,
			B.MNAME,
			B.MLOCZIP
	FROM work.HCUP_&state.&year._v1 AS A JOIN work.AHA AS B 
	ON A.DSHOSPID=B.DSHOSPID;
	QUIT;

%MEND;

%MACRO HCUP_MARKT_FORMAT(STATE,YEAR,cpttotal);
	PROC FORMAT LIBRARY=work.HCUP&year.FMT;
	inVALUE AGEFMT
	0-124= _SAME_
	other=.;

	VALUE $PSTATEFMT
	'Ot','A'="Others or Foreign Country";

	VALUE $ZIPFMT
	'C'="Canada"
	'M'="Mexico"
	'F'="other or unspecified foreign"
	'H'="Homeless"
	" ", "A", "B"="Missing"
	other=[$char5.]
	;
	
	VALUE ATYPEFMT
	1="Emergent"
	2="Urgent"
	3="Elective"
	4="Newborn"
	5="Trauma Center"
	OTHER="Missing"
	;

	VALUE $PR1FMT
	" ", "invl", "incn"='Missing';

	VALUE PAY1FMT
	1="Medicare"
	2="Medicaid"
	3="Private insurance"
	4="Self-pay"
	5="No charge"
	6="Other"
	.="Missing";

	VALUE PAY2FMT
	1="Medicare"
	2="Medicaid"
	3="Private insurance"
	4="Self-pay"
	5="No charge"
	6="Other"
	.=" ";

	run;

	OPTIONS FMTSEARCH=(work.HCUP&year.FMT);

	DATA markt.HCUP_&state.&year._outpatient work.HCUP_&state.&year._outpatient_excel(drop=pay1 pay2 atype hcup_ed) ;
		length zip pay1desc pay2desc pstate$ 30;
		length pr1 $ 10;
		retain AGE PCITY PSTATE ZIP ATYPEDESC PR1 PAY1 PAY1desc PAY2 PAY2desc HOSPST DSHOSPID AHAID MNAME MLOCZIP numCPT firstcptpos nummatchcpt cpt1-cpt&cpttotal.;
		SET work.HCUP_&state.&year._v2;
		label age="Patient age in years at admission"
			pr1="Principal ICD 9"
			pay1desc="Primary Payor Description"
			pay2desc="Secondary Payor Description"
			atypedesc="Admission Type"
			numCPT="# of CPT has in total"
			firstcptpos="The position of first matched CPT"
			nummatchcpt="# of CPTs matches with Mckinsey CPTs list";
			 

		AGE=INPUT(AGE,AGEFMT.);
		ZIP=PUT(ZIP,ZIPFMT.);
		PSTATE=PUT(PSTATE,PSTATEFMT.);
		ATYPEDESC=PUT(ATYPE,ATYPEFMT.);
		PR1=PUT(PR1,PR1FMT.);
		pay1desc=PUT(PAY1, PAY1FMT.);
		pay2desc=PUT(PAY2, PAY2FMT.);
			
		MLOCZIP=SUBSTR(MLOCZIP,1,5);
	RUN;
%MEND;


%MACRO HCUP_MARKT_OUTPUT(STATE,YEAR);

PROC EXPORT	DATA=work.HCUP_&state.&year._outpatient_excel
	OUTFILE="R:\Core\DataCore\PanT\Value\Office of Value Management\Data Request\Vijay Nair\20150918_NJ 2013 HCUP\HCUP_&state.&year._outpatient.xlsx"
	DBMS=excel
	label 
	REPLACE;
RUN;
%mend;

%HCUP_MARKT_MERGE(NJ,2013,50);
%HCUP_MARKT_FORMAT(NJ,2013,50);
%HCUP_MARKT_OUTPUT(NJ,2013);

PROC FREQ DATA=MARKT.Hcup_nj2012_outpatient;
TABLE AGE PCITY PSTATE ZIP ATYPEDESC PR1 pay1desc pay2desc DSHOSPID AHAID MNAME MLOCZIP HOSPST nummatchcpt firstcptpos numCPT/NOCOL NOROW NOPERCENT MISSING;
/*TABLE pay2desc/NOCOL NOROW NOPERCENT MISSING;*/
RUN;


DATA AHADATA;
SET AHA.PUBAS11;
if MNAME="Steven and Alexandra Cohen Children's Medical Center of New York" or
	MNAME="Syosset Hospital" or
	MNAME="Zucker Hillside Hospital" OR
	MNAME="South Oaks Hospital" then output;

RUN;

