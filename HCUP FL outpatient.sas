libname AHA 'D:\Health Services\SAS Dataset\AHA';
libname FL 'D:\Health Services\SAS Dataset\FL';
libname NJ 'D:\Health Services\SAS Dataset\NJ';
libname markt 'D:\Health Services\Yile\MARKT HCUP\dataset';
options mprint;

%macro HCUP_MARKT_MERGE(state,year);
	PROC SQL;
		CREATE TABLE work.AHA AS
		SELECT A.DSHOSPID,
				A.AHAID,
				B.MNAME,
				B.MLOCZIP
		FROM &state..&state._sasdc_&year._ahal AS A LEFT JOIN AHA.PUBAS11 AS B
		ON A.AHAID=B.ID;
	QUIT;

	proc import datafile='D:\Health Services\Yile\MARKT HCUP\McKinsey HCPCS Codes_No Minor.xlsx'
	  out=MARKT.CPTlist dbms=EXCEL replace;
	  range='A5:C852';
	  getnames=YES;
	RUN;

	DATA MARKT.CPTLIST (keep=cpt);
		SET MARKT.CPTLIST;
	cpt=strip(put(hcpcs_code,5.));
	run;

	PROC sql noprint;
	select distinct cats('"',cpt,'"')
	into :cptlist separated by ' '
	from MARKT.CPTLIST;
	%let cptcount=&sqlobs;
	%let cpt=35;
	QUIT;

	DATA work.HCUP_&state.&year._v1(keep=age pstate pcity zip dshospid hospst pr1 pay1 nummatchcpt firstcptpos numCPT cpt1-cpt&cpt.) ;
		SET &state..&state._sasdc_&year._core(where=(hcup_ed=0));
		array a_cpt{1:&cpt.} cpt1-cpt&cpt.;
		array a_cptlist{&cptcount} $ _temporary_ (&cptlist);
		j=1;
		nummatchcpt=0;*# of CPTS matches with Mckinsey CPTs list;	
		firstcptpos=0;*The position of first matched CPT; 
		numCPT=0;*# of CPT a discharge has in total;
		_output=0;
		
		do until (j ge &cpt.);
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

%MACRO HCUP_MARKT_FORMAT(STATE,YEAR);
	%let cpt=35;
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

	run;

	OPTIONS FMTSEARCH=(work.HCUP&year.FMT);

	DATA markt.HCUP_&state.&year._outpatient work.HCUP_&state.&year._outpatient_excel(drop=pay1) ;
		length zip pay1desc pstate$ 30;
		length pr1 $ 10;
		retain AGE PCITY PSTATE ZIP PR1 PAY1 PAY1desc HOSPST DSHOSPID AHAID MNAME MLOCZIP cpt1-cpt&cpt.;
		SET work.HCUP_&state.&year._v2;
		label age="Patient age in years at admission"
			pr1="Principal ICD 9"
			pay1desc="Primary Payor Description"
			numCPT="# of CPT has in total"
			firstcptpos="The position of first matched CPT"
			nummatchcpt="# of CPTS matches with Mckinsey CPTs list";

		AGE=INPUT(AGE,AGEFMT.);
		ZIP=PUT(ZIP,ZIPFMT.);
		PSTATE=PUT(PSTATE,PSTATEFMT.);
		PR1=PUT(PR1,PR1FMT.);
		pay1desc=PUT(PAY1, PAY1FMT.);		
		MLOCZIP=SUBSTR(MLOCZIP,1,5);
	RUN;
%MEND;


%MACRO HCUP_MARKT_OUTPUT(STATE,YEAR);

PROC EXPORT	DATA=work.HCUP_&state.&year._outpatient_excel
	OUTFILE="D:\Health Services\Yile\MARKT HCUP\HCUP_&state.&year._outpatient.xlsx"
	DBMS=excel
	label 
	REPLACE;
RUN;
%mend;

%HCUP_MARKT_MERGE(FL,2012);
%HCUP_MARKT_FORMAT(FL,2012);
%HCUP_MARKT_OUTPUT(FL,2012);

PROC FREQ DATA=MARKT.Hcup_fl2012_outpatient;
TABLE AGE PCITY PSTATE ZIP PR1 pay1desc DSHOSPID AHAID MNAME MLOCZIP HOSPST nummatchcpt firstcptpos numCPT/NOCOL NOROW NOPERCENT MISSING;
/*TABLE pay2desc/NOCOL NOROW NOPERCENT MISSING;*/
RUN;

/*libname myxls 'D:\Health Services\Yile\MARKT HCUP\finaldataset.xlsx';*/
/*DATA myxls.nj2012_hcup; */
/*	set markt.HCUP_NJ2012_FINAL; */
/*RUN;*/
/*libname myxls clear;*/


