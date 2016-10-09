@echo off
Rem The use of this perl file is:
Rem
Rem	map2TPlan.pl $path $tpfile,$xlsfile
Rem	if $path is ignored£¬the target path will automatically be set to current path
Rem	if $tpfile is ignored£¬the target file name will automatically be set to RF_com_Defination_h.txt
Rem	if $xlsfile is ignored£¬the target file name will automatically be set to new_sTplan.xlsx
Rem map2TPlan.pl D:\RF6362Script\AllScript\CBBCodeGen\Result RF_com_Defination_h.txt  planSpreadSheet
perl map2TPlan.pl Result RF_com_Defination.h h2csv_oldx4 def_rx,def_tx
pause
