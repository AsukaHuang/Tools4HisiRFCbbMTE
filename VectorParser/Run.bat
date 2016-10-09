@echo off
Rem The use of this perl file is:
Rem
Rem May encounter Errors unless all the packages required are installed.
Rem	vectorParse.pl vecterHtml suitHtml excelFile BurstClassify
perl vectorParse.pl .\Import\VectorBurstSetups.htm HI6351RegList .\Import\Tests1.htm
pause
