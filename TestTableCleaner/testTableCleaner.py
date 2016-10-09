import sys
import os
import getopt
import re
import shutil
import string
import copy
import csv
import operator, functools, itertools
import xml.etree.ElementTree as ET
from subprocess import call
import win32con,win32gui,win32api
import collections

__version__ = "0.1.4"

##p----warning-----
def alert_message(message):
    win32api.MessageBox(0,message,"NICONICONI",win32con.MB_ICONINFORMATION)

class tableClass:
    def __init__(self, ary):
#    def __init__(self, SuitName,TestName,TestNumber,
#            FT_Lsl,FT_Lsl_typ,FT_Usl_typ,FT_Usl,FT_Units,
#            QA_Lsl,QA_Lsl_typ,QA_Usl_typ,QA_Usl,QA_Units,
#            Bin_s_num,Bin_s_name,Bin_h_num,Bin_h_name,
#            Bin_type, Bin_reprobe, Bin_overon,
#            Test_remarks):
        self.SuitName       = ary[0]
        self.TestName       = ary[1]
        self.TestNumber     = ary[2]
        self.FT_Lsl         = ary[3]
        self.FT_Lsl_typ     = ary[4]
        self.FT_Usl_typ     = ary[5]
        self.FT_Usl         = ary[6]
        self.FT_Units       = ary[7]
        self.QA_Lsl         = ary[8]
        self.QA_Lsl_typ     = ary[9]
        self.QA_Usl_typ     = ary[10]
        self.QA_Usl         = ary[11]
        self.QA_Units       = ary[12]
        self.Bin_s_num      = ary[13]
        self.Bin_s_name     = ary[14]
        self.Bin_h_num      = ary[15]
        self.Bin_h_name     = ary[16]
        self.Bin_type       = ary[17]
        self.Bin_reprobe    = ary[18]
        self.Bin_overon     = ary[19]
        self.Test_remarks   = ary[20]
    def __eq__(self, other):
        if self.SuitName != other.SuitName:
            return False
        if self.TestName != other.TestName:
            return False
        return True
    def __ne__(self, other):
        return (not self.__eq__(other))
    def getAry(self):
        return (self.SuitName, self.TestName, self.TestNumber,
                self.FT_Lsl, self.FT_Lsl_typ, self.FT_Usl_typ, self.FT_Usl, self.FT_Units,
            self.QA_Lsl, self.QA_Lsl_typ, self.QA_Usl_typ, self.QA_Usl, self.QA_Units,
            self.Bin_s_num, self.Bin_s_name, self.Bin_h_num, self.Bin_h_name,
            self.Bin_type, self.Bin_reprobe, self.Bin_overon,
            self.Test_remarks)

class tempClass:
    def __init__(self, SuitName,TestName,TestNumber):
        self.SuitName       = SuitName
        self.TestName       = TestName
        self.TestNumber     = TestNumber


g_OSBinID=2000
g_DCBinID=3000
g_OTBinID=4000
g_RXBinID=5000
g_TXBinID=6000
g_binMap = {}
g_IDMap = {}
g_TestIDPool=[]

g_splitIQ = False
g_setBin = False

g_maxLine=50000
#def write(fh, l):
#    f = lambda o: "%s" % o
#    fh.write(','.join(map(f, l)))
#    fh.write("\n")
def write(fh, l):
    f = lambda o: "%s" % o
    fh.write(','.join(map(f, l.getAry())))
def read(ls):
    return map(lambda l: tableClass(l.split(',')), ls)

def addIDandBin(a):
    global g_OSBinID
    global g_DCBinID
    global g_OTBinID
    global g_RXBinID
    global g_TXBinID
    global g_binMap 
    global g_IDMap

    global g_setBin

    if g_setBin:
        if re.match(r'^RX_',a.SuitName):
            a.Bin_h_num = '5'
            a.Bin_h_name = 'RX_FAILED'

            if re.match(r'\w*GAIN',a.SuitName):
                if re.match(r'^GSTEP\w+',a.TestName) and not re.search(r'42DB',a.TestName):
                    a.Bin_s_name = a.SuitName + '_GSTEP_FAILED'
                else:
                    a.Bin_s_name = a.SuitName + '_GAIN_FAILED'
            elif re.match(r'\w*FILT',a.SuitName):
                a.Bin_s_name = a.SuitName +'_'+ a.TestName+ '_FAILED'
            elif re.match(r'\w*IIP',a.SuitName):
                if re.match(r'\w*IIP2',a.TestName) or re.match(r'IM2',a.TestName):
                    a.Bin_s_name = a.SuitName + '_IIP2_FAILED'
                elif re.match(r'\w*IIP3',a.TestName):
                    a.Bin_s_name = a.SuitName + '_IIP3_FAILED'
                else:
                    print str("Error IIP TestName:"+a.TestName)
                    sys.exit(2)
            else:
                a.Bin_s_name = a.SuitName +'_FAILED'

            if a.Bin_s_name not in g_binMap:
                g_binMap[a.Bin_s_name] = g_RXBinID
                g_RXBinID+=1

        elif re.match(r'^TX_',a.SuitName):
            a.Bin_h_num = '6'
            a.Bin_h_name = 'TX_FAILED'
            if re.match(r'\w*POWER',a.SuitName):
                if re.match(r'^M_',a.TestName):
                    a.Bin_s_name = a.SuitName + '_M_FAILED'
                else:
                    a.Bin_s_name = a.SuitName + '_FAILED'
            else:
                a.Bin_s_name = a.SuitName + '_FAILED'
            if a.Bin_s_name not in g_binMap:
                g_binMap[a.Bin_s_name] = g_TXBinID
                g_TXBinID+=1
        elif re.match(r'^DC_\w+_VCOM',a.SuitName) or a.SuitName=="CHIP_ID_READ" or a.SuitName=="IIHL":
            a.Bin_h_num = '3'
            a.Bin_h_name = 'DC_FAILED'
            a.Bin_s_name = a.SuitName + '_FAILED'
            if a.Bin_s_name not in g_binMap:
                g_binMap[a.Bin_s_name] = g_DCBinID
                g_DCBinID+=1
        elif re.match(r'^OS_',a.SuitName) or a.SuitName=="FC_LBID_READ":
            a.Bin_h_num = '2'
            a.Bin_h_name = 'OS_FAILED'
            a.Bin_s_name = a.SuitName + '_FAILED'
            if a.Bin_s_name not in g_binMap:
                g_binMap[a.Bin_s_name] = g_OSBinID
                g_OSBinID+=1
        else:
            a.Bin_h_num = '4'
            a.Bin_h_name = 'OTHER_FAILED'
            a.Bin_s_name = a.SuitName + '_FAILED'
            if a.Bin_s_name not in g_binMap:
                g_binMap[a.Bin_s_name] = g_OTBinID
                g_OTBinID+=1

        a.Bin_s_num = g_binMap[a.Bin_s_name]
    else:
        a.Bin_s_num = int(a.Bin_s_num)
    if a.Bin_s_num not in g_IDMap:
        g_IDMap[a.Bin_s_num] = a.Bin_s_num*10000;
    a.TestNumber = g_IDMap[a.Bin_s_num]
    if a.TestNumber not in g_TestIDPool:
        g_TestIDPool.append(a.TestNumber)
    else:
        print "Error Dup TestID for ",a.SuitName,":",a.TestName
    g_IDMap[a.Bin_s_num]+=1
    
def inFileProcess(inlines):
    global g_splitIQ

    if not len(inlines)>2:
        print str("no elements in test table")
        sys.exit(2)
    inlines=map(lambda x:re.sub(r'"',"",x),inlines)
    inlines=filter(lambda x:not re.match(r'^\s*$',x),inlines)
    lists=read(inlines[2:])
    lists = filter(lambda x:x.SuitName!="" and x.TestName!="",lists) #clr blank
    clnlists =[]
    for idx in xrange(len(lists)): #rm dup
        if lists[idx] not in lists[idx+1:]:
            clnlists.append(lists[idx])
    idx=0
    if g_splitIQ:
        while 1:
            a=clnlists[idx]
            if (re.match(r'^RX_',a.SuitName) and (not(re.match(r'\w*EVM',a.SuitName) or re.match(r'\w*IR',a.SuitName) or re.match(r'\w*IIP_CAL',a.SuitName)or re.match(r'\w*_IDD$',a.SuitName)))) or ( re.match(r'^DC_\w+_VCOM',a.SuitName)):
                if not re.match(r'(\w|-)*(_I|_Q)$',a.TestName):
                    newa=copy.copy(a)
                    a.TestName = a.TestName+"_I"
                    newa.TestName = newa.TestName+"_Q"
                    clnlists.insert(idx+1,newa)
            idx+=1
            if not (idx<len(clnlists)):
                break
            if idx>g_maxLine:
                break
    map(addIDandBin,clnlists)
    return clnlists


def chkOFtestID(outlines):
    getID = lambda x:x.split(',')
    map(getID,outlines[2:])
def clean(outFileName, inFileName):
    inFile = file(inFileName[0])
    inlines = inFile.readlines()
    inFile.close()
    clnlists=inFileProcess(inlines)

##    for each in clnlists:
##        print each.SuitName
##    if len(lists) != len(set(lists)): #not hashable
#
    outFileName = re.sub(r'.csv$', "", outFileName)
    outFile = file("%s.csv" % outFileName, "w")
    outFile.write(inlines[0])
    outFile.write(inlines[1])
    wf = lambda x:write(outFile,x)
    map(wf,clnlists)
    outFile.close()



#
#
#    print "%s.csv" % filename

if __name__ == '__main__':
#    global g_splitIQ
#    global g_setBin
    print "csv cleaner ver:",__version__ 
    print "Start Analyzing"
    try:
        opts, args = getopt.getopt(sys.argv[1:], 'd:o:i:',["sbin","iq"])
    except getopt.GetoptError, err:
        print str(err)
        sys.exit(2)

    pathname = os.path.abspath('.')
    infile = os.path.abspath('./foo')
    outfile = os.path.abspath('./foo')

    for o, a in opts:
        if o == "-d":
            pathname = os.path.abspath(a)
        elif o == "-i":
            infile = a
        elif o == "-o":
            #outfile = os.path.abspath(a)
            outfile = a
        elif o == "--iq":
            g_splitIQ = True
        elif o == "--sbin":
            g_setBin = True


    def csv_infilter(fname):
        return (re.match(r'%s$'%infile, fname) != None)


    infiles = filter(csv_infilter,
                   os.listdir(pathname))

    if len(infiles) == 0:
        print "error: no files. please check the csv_filter"       
        sys.exit()

    join_path = lambda f: os.path.join(pathname, f)
#    csv_list = map(lambda f: os.path.basename(f), files)
#    clean(outfile, map(join_path, files), dut_list, datacolumn)
    clean(join_path(outfile), map(join_path, infiles))
    print "Done"
