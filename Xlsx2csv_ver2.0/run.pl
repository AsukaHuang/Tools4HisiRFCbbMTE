#!/usr/bin/perl

use File::Basename;


##--sbin :set soft bin
##--iq :split I Q

system("python xlsx2csv.py -d Import -s setup.txt -i \"Hi6351 Test Plan v1.2.xls\" ");
system("pause");
