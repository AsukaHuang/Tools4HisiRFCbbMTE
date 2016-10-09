#!/usr/bin/perl

use File::Basename;


##--sbin :set soft bin
##--iq :split I Q

system("python testTableCleaner.py -d Import -i Hi6351V100_A10.csv -o Hi6351V100_A10_new.csv --sbin");
system("pause");
