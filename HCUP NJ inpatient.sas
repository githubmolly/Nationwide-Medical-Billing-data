libname AHA 'R:\Data\Open\AHA';
libname NJ 'R:\Data\Encrypted\HCUP\NJ';
libname markt 'R:\Core\DataCore\PanT\Value\Office of Value Management\Data Request\Vijay Nair\20150918_NJ 2013 HCUP';

%macro HCUP_MARKT_MERGE(state,year);
	PROC SQL;
		CREATE TABLE work.AHA AS
		SELECT A.DSHOSPID,
				A.AHAID,
				B.MNAME,
				B.MLOCZIP
		FROM &state..&state._sidc_2012_ahal AS A LEFT JOIN AHA.PUBAS11 AS B
		ON A.AHAID=B.ID;
	QUIT;

	DATA work.HCUP_&state.&year._v1(keep=age pstate pcity zip dshospid hospst atype hcup_ed mdc newdrg drg pr1 pr2 pay1 pay2) ;
		SET &state..&state._sidc_&year._core(where=(mdc=8 and atype=3 and hcup_ed=0));
		pcity=zipcity(zip);
		newdrg=cats(put(drg,z3.));
		label pcity='Patient city';
	RUN;

	PROC SQL;
	CREATE TABLE work.HCUP_&state.&year._v2 AS
	SELECT A.age,
			A.pcity,
			A.pstate,
			A.zip,
			A.ATYPE,
			A.HCUP_ED,
			A.MDC,
			A.NEWDRG,
			A.DRG,
			A.PR1,
			A.PAY1,
			A.PAY2,
			A.hospst,
			A.DSHOSPID,
			B.AHAID,
			B.MNAME,
			B.MLOCZIP
	FROM work.HCUP_&state.&year._v1 AS A JOIN work.AHA AS B 
	ON A.DSHOSPID=B.DSHOSPID;
	QUIT;

%MEND;

%MACRO HCUP_MARKT_FORMAT(STATE,YEAR);
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

	DATA markt.HCUP_&state.&year. work.HCUP_&state.&year._excel(drop=atype HCUP_ED pay1 pay2 DRG) ;
		length zip atypedesc pay1desc pay2desc pstate$ 30;
		length pr1 $ 10;
		retain AGE PCITY PSTATE ZIP ATYPE ATYPEdesc MDC NEWDRG DRG PR1 PAY1 PAY1desc PAY2 PAY2desc HOSPST DSHOSPID AHAID MNAME MLOCZIP;
		SET work.HCUP_&state.&year._v2;
		label age="Patient age in years at admission"
			pr1="Principal ICD 9"
			newdrg="DRG in effect on discharge data(HCFA DRG)"
			atypedesc="Admission Type Description"
			pay1desc="Primary Payor Description"
			pay2desc="Secondary Payor Description";

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

PROC EXPORT	DATA=work.HCUP_&state.&year._excel
	OUTFILE="R:\Core\DataCore\PanT\Value\Office of Value Management\Data Request\Vijay Nair\20150918_NJ 2013 HCUP\HCUP_&state.&year._inpatient.xlsx"
	DBMS=excel
	label 
	REPLACE;
RUN;
%mend;

%HCUP_MARKT_MERGE(NJ,2013);
%HCUP_MARKT_FORMAT(NJ,2013);
%HCUP_MARKT_OUTPUT(NJ,2013);

PROC FREQ DATA=MARKT.HCUP_NJ2010;
/*TABLE AGE PCITY PSTATE ZIP ATYPEDESC MDC HCUP_ED NEWDRG PR1 PAY1DESC PAY2DESC DSHOSPID AHAID MNAME MLOCZIP HOSPST/NOCOL NOROW NOPERCENT MISSING;*/
TABLE PSTATE/NOCOL NOROW NOPERCENT MISSING;
RUN;

/*libname myxls 'D:\Health Services\Yile\MARKT HCUP\finaldataset.xlsx';*/
/*DATA myxls.nj2012_hcup; */
/*	set markt.HCUP_NJ2012_FINAL; */
/*RUN;*/
/*libname myxls clear;*/
