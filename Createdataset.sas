libname out 'R:\Core\DataCore\GeY\SAS_Projects\Common Care Rating\Dataset';

libname workbook excel 'R:\Core\DataCore\GeY\SAS_Projects\Data Quality Assurance\Code library.xlsx';

data out.diag_hipfx;
set workbook.'Diag_hipfx$'n;
run;

data out.Diag_cancer;
set workbook.'Diag_cancer$'n;
run;

data out.Diag_HAI;
set workbook.'Diag_HAI$'n;
run;

libname workbook clear;
