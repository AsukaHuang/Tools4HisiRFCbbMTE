@echo off
Rem The use of this perl file is:
Rem
Rem May encounter Errors unless all the packages required are installed.
Rem	vectorParse.pl vecterHtml suitHtml excelFile BurstClassify
perl vectorParse.pl .\Import\VectorBurstSetups.htm .\Import\Tests1.htm vectorInfo Gain,IIP,NF,IR,FILT,EVM,TX_Power Import\System_Data_Log_Stream.tsum.csv -v
pause
