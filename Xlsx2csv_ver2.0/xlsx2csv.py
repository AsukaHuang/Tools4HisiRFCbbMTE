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
import xlrd
import xlwt
import collections
from numbers import Number
#import arial10

__version__ = "0.1.0"

#sheet define
g_mapSht={}
g_listSht=["g_sheetRX","g_sheetTX","g_sheetBandDef",
        #Band Definition Col
        "g_bdband","g_bdTXMin","g_bdTXMax","g_bdRXMin","g_bdRXMax","g_bdDup",
        #RX Col
        "g_rxblkBegin","g_rxblkEnd","g_rxpll","g_rxbb",
        "g_rxstpType","g_rxstpPwr1","g_rxstpDltFrq1","g_rxstpPwr2","g_rxstpDltFrq2","g_rxstpGainRF","g_rxstpGainVGA","g_rxstpIFMode",
        #RX Row
        "g_rxport","g_rxband","g_lastrxRow",
        #TX Col
        "g_txblkBegin","g_txblkEnd","g_txstand1","g_txstand2",
        "g_txItem1","g_txItem2","g_txstpinPwr","g_txstpDltFrq","g_txstpBandwidth","g_txstpAttnBB","g_txstpAttnRF",
        #TX Row
        "g_txport","g_txband","g_lasttxRow"]

#band definitions
g_mapBandDef={}
g_mapBandDef={}
g_maprx={}
g_maptx={}



##p----warning-----
def ALERT_MESSAGE(message):
    win32api.MessageBox(0,message,"Alart:",win32con.MB_ICONINFORMATION)

class clsBand:
    def __init__(self, ary):
        self.band       = ary[0]
        self.txmin      = ary[1]
        self.txmid      = (ary[1]+ary[2])/2
        self.txmax      = ary[2]
        self.rxmin      = ary[3]
        self.rxmid      = (ary[3]+ary[4])/2
        self.rxmax      = ary[4]
        self.dup        = ary[5]
    def getTXAry(self):
        return (self.txmin, self.txmid, self.txmax)

    def getTXFreq(self,opt):
        if opt == "M":
            return self.txmid
        elif opt == "L":
            return self.txmin
        elif opt == "H":
            return self.txmax
        elif opt == "3LO":
            return self.txmid*3

    def getRXAry(self):
        return (self.rxmin, self.rxmid, self.rxmax)

    def getRXMid(self):
        return self.rxmid

    def getDup(self):
        return self.dup

#sub get_txFreqMode {###PERL
#    my( $self,$freq ) = @_;
#    if($freq ~~ $self->{_tx_min}){
#        return "L"
#    }elsif($freq ~~ $self->{_tx_max}){
#        return "H"
#    }elsif($freq ~~ $self->{_tx_mid}){
#        return "M"
#    }
#    print "Error TX Freq:",$freq," in Band",$self->{_band},"\n";
#    return "NA";
#}


class clsRX:
    def __init__(self, testType, band):
        self.testType = testType
        self.band = band
        self.stpType    = []
        self.stpPwr1    = []
        self.stpDltFrq1 = []
        self.stpPwr2    = []
        self.stpDltFrq2 = []
        self.stpGainRF  = []
        self.stpGainVGA = []
        self.stpIFMode  = []
        self.stpFrq1 = []
        self.stpFrq2 = []

    def addStep(self,ary):
        stpType = re.sub(r"\/","-",ary[0])
        self.stpType.append(stpType)
        self.stpPwr1.append(ary[1])
        if ary[1]==ary[3]:
            self.stpPwr2.append("")
        else:
            self.stpPwr2.append(ary[3])

        dltFrq1 = ary[2]
        dltFrq2 = ary[4]
        if dltFrq1=="":
            dltFrq1=0
            dltFrq2=0
        
        if not isinstance(dltFrq1,Number):
            m1=re.search(r'Df_dup',dltFrq1)
            if m1:
                d=re.sub(r'Df_dup',"%s"%g_mapBandDef[self.band].getDup(),dltFrq1)
                dltFrq1 = eval(d)
        if not isinstance(dltFrq2,Number):
            m2=re.search(r'Df_dup',dltFrq2)
            if m2:
                d=re.sub(r'Df_dup',"%s"%g_mapBandDef[self.band].getDup(),dltFrq2)
                dltFrq2 = eval(d)
        sdltFrq1=""
        if dltFrq1!=0:
            sdltFrq1="%se6"%dltFrq1
            if re.search(r'IIP2',ary[0]):
                sdltFrq1="%se6"%(abs(dltFrq1-dltFrq2))
            elif re.search(r'IIP3',ary[0]):
                d1 = abs(dltFrq1*2-dltFrq2)
                d2 = abs(dltFrq2*2-dltFrq1)
                sdltFrq1="%se6"%(d1 if d1<d2 else d2)
        self.stpDltFrq1.append(sdltFrq1)
        self.stpDltFrq2.append(dltFrq2)

        self.stpGainRF.append(int(ary[5]))
        self.stpGainVGA.append(int(ary[6]))
        stpIFMode = re.sub(r"\/","-",ary[7])
        self.stpIFMode.append(stpIFMode)
        if self.band not in g_mapBandDef.keys():
            ALERT_MESSAGE("band"+band+"not defined in Band definition table")
            sys.exit(2)
        if re.search(r'IIP',self.testType):
            stpFrq1 = "%se6"%(g_mapBandDef[self.band].getRXMid()-dltFrq1)
            stpFrq2 = "%se6"%(g_mapBandDef[self.band].getRXMid()-dltFrq2)
            self.stpFrq1.append(stpFrq1)
            self.stpFrq2.append(stpFrq2)
        else:
            stpFrq1 = "%se6"%(g_mapBandDef[self.band].getRXMid()+dltFrq1)
            self.stpFrq1.append(stpFrq1)
            self.stpFrq2.append("")

    def getSteps(self):
        burst = len(self.stpType)

        return (burst,
                self.stpType,
                self.stpIFMode,
                self.stpPwr1,
                self.stpPwr2,
                self.stpFrq1,
                self.stpFrq2,
                self.stpDltFrq1,
                self.stpGainRF,
                self.stpGainVGA)

class clsTX:
    def __init__(self, testType, band,inPwr):
        self.testType = testType
        self.band = band
        self.inPwr = inPwr
        self.stpOpt1    = [] #Freq
        self.stpOpt2    = [] #Attn+filter
        self.stpMRg    = [] #RF OUT
        self.stpFrq    = [] #RF OUT
        self.stpBB    = [] #BB IN
        self.stpAttnBB    = [] #Attn BB
        self.stpAttnRF    = [] #Attn RF

    def addStep(self,ary):
        stand=ary[2]
        bb=0
        if stand =="2G":
            bb=0.1
        elif stand=="3G":
            bb=0.96
        elif stand=="4G":
            bb=4.5
        else:
            ALERT_MESSAGE("Error standard setting:"+stand)
            sys.exit(2)

        f = "M"
        frq="%se6"%(g_mapBandDef[self.band].getTXFreq("M")+bb)
        if re.search(r'(3LO)',ary[0]):
            f="3LO"
            frq="%se6"%(g_mapBandDef[self.band].getTXFreq("3LO")-bb)
            if float(frq)>7e9:
                return

        attn = "MAX"
        mRg = 8
        m1 = re.search(r'(Max|Mid|Min|1dBm|2dBm|\d+dB)$',ary[1])
        if m1:
            attn = m1.group(1)
            if m1.group(1)=="Min":
                mRg=-20
        self.stpOpt1.append(f)
        self.stpOpt2.append(attn)
        self.stpMRg.append(mRg)
        self.stpFrq.append(frq)
        self.stpBB.append("%se6"%bb)
        self.stpAttnBB.append(ary[3])
        rf=ary[4]
        rf=re.sub(r'\s*,\s*','_',"%s"%rf)
        self.stpAttnRF.append(rf)

    def getSteps(self):
        burst = len(self.stpOpt1)

        return (burst,
                self.inPwr,
                self.stpOpt1,
                self.stpOpt2,
                self.stpMRg,
                self.stpFrq,
                self.stpBB,
                self.stpAttnBB,
                self.stpAttnRF)

def getInt(s):
    try:
        int(s)
        return int(s)
    except ValueError:
        return -999
def getDouble(s):
    try:
        float(s)
        return int(s)
    except ValueError:
        return -999

#-----not use
class FitSheetWrapper(object):
    """Try to fit columns to max size of any entry.
    To use, wrap this around a worksheet returned from the 
    workbook's add_sheet method, like follows:

        sheet = FitSheetWrapper(book.add_sheet(sheet_name))

    The worksheet interface remains the same: this is a drop-in wrapper
    for auto-sizing columns.
    """
    def __init__(self, sheet):
        self.sheet = sheet
        self.widths = dict()

    def write(self, r, c, label='', *args, **kwargs):
        self.sheet.write(r, c, label, *args, **kwargs)
        width = arial10.fitwidth(label)
        if width > self.widths.get(c, 0):
            self.widths[c] = width
            self.sheet.col(c).width = width

    def __getattr__(self, attr):
        return getattr(self.sheet, attr)




#----- def subrontine
def getsetup(setupFile):
    i = file(setupFile)
    ilines= i.readlines()
    i.close()
    for line in ilines:
        m= re.search(r'(\w+)\s*=\s*"(.*)"',line)
        if m and m.group(1) in g_listSht:
            if(m.group(1) == 'g_rxport' or m.group(1) == 'g_lastrxRow' or m.group(1) == 'g_rxband'or
                    m.group(1) == 'g_txport' or m.group(1) == 'g_lasttxRow' or m.group(1) == 'g_txband'):
                if m.group(2) == "":
                    g_mapSht[m.group(1)] = 0
                else:
                    g_mapSht[m.group(1)] = int(m.group(2))-1
            else:
                g_mapSht[m.group(1)] = m.group(2)
    print "setup file Process Done"

#xlsx column Alphabit 2 numeric
def col2n(col):
    num = 0
    if col =="":
        return 0
    for c in col:
        if c in string.ascii_letters:
            num = num*26+(ord(c.upper())-ord('A'))+1
    return num-1

def rdBdDef(ixlsx):
    rbook=xlrd.open_workbook(ixlsx[0])
    #wbook=xlwt.Workbook(ixlsx[0])
    global g_mapSht
    global g_mapBandDef
    sht=rbook.sheet_by_name(g_mapSht["g_sheetBandDef"])
    #sht = FitSheetWrapper(wbook.add_sheet(g_mapSht["g_sheetBandDef"]))
    for i in xrange(sht.nrows):
        row=sht.row(i)
        if len(row)<col2n(g_mapSht['g_bdDup']):
            continue
        band = sht.cell_value(i,col2n(g_mapSht['g_bdband']))
        txmin = sht.cell_value(i,col2n(g_mapSht['g_bdTXMin']))
        txmax = sht.cell_value(i,col2n(g_mapSht['g_bdTXMax']))
        rxmin = sht.cell_value(i,col2n(g_mapSht['g_bdRXMin']))
        rxmax = sht.cell_value(i,col2n(g_mapSht['g_bdRXMax']))
        dup = sht.cell_value(i,col2n(g_mapSht['g_bdDup']))
        flag = True
        for num in [band,txmin,txmax,rxmin,rxmax,dup]:
            if getDouble(num)==-999:
                flag = False
                break
            #else:
            #    print "row=",i,"    a1=",num
        if flag:    
            g_mapBandDef[int(band)] = clsBand((int(band),txmin,txmax,rxmin,rxmax,dup))
    if not g_mapBandDef:
        ALERT_MESSAGE("band definition Parse Error. Check Setting or xlsx file")
        sys.exit(2)
    print "getBandDef:",g_mapBandDef.keys()



def cvtRX(orx, ixlsx):
    def getRF(i,o=0):
        m = re.search(r'(Gain \(eDSDS\)|EVM|IIP|Gain|NF|Noise Figure|Image Rejection|IR|USNR|Filter|DC offset)',i,re.I) 
        if m:
            if o==0:
                if re.search(r'SC_Cal$',i,re.I):
                    return "IIP_CAL"
                i = m.group(1)
            i=re.sub(r'\(eDSDS\)',"eDSDS",i)
            i=re.sub(r'Gain Step',"GSTEP",i)
            i=re.sub(r'LNA\s*',"",i)
            i=re.sub(r'\s*dB$',"dB",i)
            i=re.sub(r'Gain',"GAIN",i)
            i=re.sub(r'\s*FDD\s*'," ",i)
            i=re.sub(r'Noise Figure',"NF",i)
            i=re.sub(r'Image Rejection',"IR",i)
            i=re.sub(r'Filter( Selectivity)*',"FILT",i)
            i=re.sub(r'DC offset',"DCOS",i)
            i=re.sub(r'\s+',"_",i)
            i=re.sub(r'GAIN_All_max',"GMAX",i)
            i=re.sub(r'In_Band',"IB",i)
            i=re.sub(r'RMS_EVM',"EVMrms",i)
            i=re.sub(r'0.5\*Dup',"HDUP",i)
            i=re.sub(r'2\*Dup',"2DUP",i)
            return i
        else:
            return ""
    def getIFMode(i):
        i=re.sub(r'\s*FDD\s*'," ",i)
        i=re.sub(r'\s+',"_",i)
        return i
        
    #read xlsx
    global g_mapSht
    global g_mapBandDef
    global g_maprx
    book=xlrd.open_workbook(ixlsx[0],formatting_info=True)
    sht=book.sheet_by_name(g_mapSht["g_sheetRX"])
    if(col2n(g_mapSht['g_rxpll'])>sht.ncols or 
            col2n(g_mapSht['g_rxbb'])>sht.ncols or
            col2n(g_mapSht['g_rxblkEnd'])>sht.ncols):
        ALERT_MESSAGE("rx sheet column setting Error.")
        sys.exit(2)
    bbAry = []
    if(col2n(g_mapSht['g_rxbb'])>0):
        bbAry = sht.col_values(col2n(g_mapSht['g_rxbb']))

    pllAry = sht.col_values(col2n(g_mapSht['g_rxpll']))
    stpTypeAry = sht.col_values(col2n(g_mapSht['g_rxstpType']))
    stpPwr1 = sht.col_values(col2n(g_mapSht['g_rxstpPwr1']))
    stpDltFrq1 = sht.col_values(col2n(g_mapSht['g_rxstpDltFrq1']))
    stpPwr2 = sht.col_values(col2n(g_mapSht['g_rxstpPwr2']))
    stpDltFrq2 = sht.col_values(col2n(g_mapSht['g_rxstpDltFrq2']))
    stpGainRF = sht.col_values(col2n(g_mapSht['g_rxstpGainRF']))
    stpGainVGA = sht.col_values(col2n(g_mapSht['g_rxstpGainVGA']))
    stpIFMode = sht.col_values(col2n(g_mapSht['g_rxstpIFMode']))
    for icol in range(col2n(g_mapSht['g_rxblkBegin']),col2n(g_mapSht['g_rxblkEnd'])+1):
        col=sht.col(icol)
        port = col[g_mapSht['g_rxport']].value
        band = getInt(col[g_mapSht['g_rxband']].value)
        bb = ""
        if len(bbAry)==0:
            m= re.search(r'\w+(A|B|C|D)$',port)
            if m:
                bb=m.group(1)
        if band==-999:
            ALERT_MESSAGE("band in RX def error. Check Setting or xlsx file 1:"+col[g_mapSht['g_rxband']].value)
            sys.exit(2)

        for irow in xrange(g_mapSht['g_rxband']+1,g_mapSht['g_lastrxRow']+1 if len(col)>g_mapSht['g_lastrxRow'] and g_mapSht['g_lastrxRow']!=0 else len(col)):
            testType=getRF(stpTypeAry[irow])
            if(col[irow].value=='x'and len(testType)):
                testType_CAL9=""
                if testType=="IIP_CAL":
                    testType="IIP_CAL3"
                    testType_CAL9="IIP_CAL9"
                xfx= sht.cell_xf_index(irow,1) #"B" =GREEN?
                xf=book.xf_list[xfx]
                bgx=xf.background.pattern_colour_index
                if bgx == 50: #green!!!!
                    if testType=="IIP_CAL3":
                        testType_CAL9 = testType_CAL9+"_NOLNA"
                    testType = testType+"_NOLNA"
                #print "row:",irow,";colour=",bgx

                if len(bbAry)>0:
                    bb = bbAry[irow]
                if len(bb)!=1:
                    ALERT_MESSAGE("base band selector error.Row:",irow)
                    sys.exit(2)
                if re.search(r'IIP',getRF(stpTypeAry[irow],1),re.I):
                    if re.search(r'cdma2k',getRF(stpTypeAry[irow],1),re.I): #skip cdma2k iip
                        continue
                    elif re.search(r'_Cal$',getRF(stpTypeAry[irow],1),re.I) and not re.search(r'3G_SC',getRF(stpTypeAry[irow],1),re.I): #skip NOT 3GSC IIP2 CAL
                        continue
                if(re.search(r'EVM',getRF(stpTypeAry[irow],1),re.I) and
                        not(re.search(r'3G_SC',getRF(stpTypeAry[irow],1),re.I))): #skip not 3G_SC EVM
                    continue
                if (port,band) in g_maprx.keys():
                    if not testType in g_maprx[(port,band)][2].keys(): # new test type
                        g_maprx[(port,band)][2][testType]=clsRX(testType,band)
                else: #new port+band
                    g_maprx[(port,band)] = (int(pllAry[irow]),bb,{testType:clsRX(testType,band)}) 
                if testType_CAL9 !="":
                    g_maprx[(port,band)][2][testType_CAL9]=clsRX(testType_CAL9,band)
                #add step
                g_maprx[(port,band)][2][testType].addStep((getRF(stpTypeAry[irow],1), 
                #g_maprx[(port,band)][2][testType].addStep((stpTypeAry[irow], 
                     stpPwr1[irow],
                     stpDltFrq1[irow],
                     stpPwr2[irow],
                     stpDltFrq2[irow],
                     stpGainRF[irow],
                     stpGainVGA[irow],
                     getIFMode(stpIFMode[irow])))
                if testType_CAL9 !="":
                    g_maprx[(port,band)][2][testType_CAL9].addStep((getRF(stpTypeAry[irow],1), 
                    #g_maprx[(port,band)][2][testType].addStep((stpTypeAry[irow], 
                         stpPwr1[irow],
                         stpDltFrq1[irow],
                         stpPwr2[irow],
                         stpDltFrq2[irow],
                         stpGainRF[irow],
                         stpGainVGA[irow],
                         getIFMode(stpIFMode[irow])))

        #print port,"    ",int(band)
    if(not len(g_maprx.keys())):
        print "RX Definition is empty"
#    else:
#        print "RXRF_LB1A:band8:pll",g_maprx[("RXRF_LB1A",8)][0],"GSTEP2:",g_maprx[("RXRF_LB1A",8)][2]["GAIN"].getStep(2)

##  Gen csv
    outFile = file(orx, "w")
    outFile.write("//  TRX,  INT,   STRING, STRING,      INT,double,#   STRING,   int,  string_Ary, string_Ary, double_Ary, double_Ary,double_Ary,double_Ary,double_Ary,string\n")
    outFile.write("//RX|TX,mBand,port_name,BB_Path,RXPLL_sel,inLoss,#  test_Type, burst, type,  ifmode,      pow1,       pow2,     freq1,     freq2,  baseband, mGainReg,,\n")
    for (port,band) in g_maprx.keys():
        outFile.write("RX,%s,%s,%s,%s,0\n"%(band,port,g_maprx[(port,band)][1],g_maprx[(port,band)][0]))
        for testType in sorted(g_maprx[(port,band)][2].keys()):
            (burst,stpType,ifmode,pwr1,pwr2,frq1,frq2,bbfrq,gainRF,gainVGA)=g_maprx[(port,band)][2][testType].getSteps()
            outFile.write(",,,,,,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n"%(testType,burst,
                stpType[0],
                ifmode[0],
                pwr1[0],
                pwr2[0],
                frq1[0],
                frq2[0],
                bbfrq[0],
                gainRF[0],
                gainVGA[0]))
            for i in range(1,burst):
                outFile.write(",,,,,,,,%s,%s,%s,%s,%s,%s,%s,%s,%s\n"%(
                    stpType[i],
                    ifmode[i],
                    pwr1[i],
                    pwr2[i],
                    frq1[i],
                    frq2[i],
                    bbfrq[i],
                    gainRF[i],
                    gainVGA[i]))


    outFile.write("$end\n")
    outFile.close()
#    inFile = file(ixlsx[0])
#    inlines = inFile.readlines()
#    inFile.close()

def cvtTX(otx, ixlsx):
    def getStand(i):
        m=re.search(r'(\d+G)',i)
        if m:
            return m.group(1)
        else:
            return "BREAK"
    def getRF(i1,i2,o=0):
        if (i1=="Carrier Rejection" or i1=="Sideband Rejection" or re.search(r'Current',i1) or re.search(r'FDD DC',i2)or re.search(r'TDD',i2) or re.search(r'40MHz',i2))  :
            return "CONTINUE"
        elif re.search(r'CW',i2):
            if (i1=="Output Power" or i1=="3LO"):
                return "POWER"
            elif re.search(r'HD',i1):
                return "HD"
            else:
                print "r1::",i1,":",i2
                return "NULL"
        elif re.search(r'GMSK',i2):
            if re.search(r'RMS Phase Error',i1):
                return "PE"
            else:
                return "CONTINUE"
        elif re.search(r'8PSK',i2):
            if re.search(r'RMS EVM',i1):
                return "EVM"
            else:
                return "CONTINUE"
        elif re.search(r'FDD SC',i2):
            if re.search(r'FDD SC',i2):
                if re.search(r'RMS EVM',i1):
                    return "EVM"
                elif re.search(r'ACLR1',i1):
                    return "ACLR"
                else:
                    return "CONTINUE"
            else:
                return "CONTINUE"
        elif re.search(r'(\S+)MHz$',i2):
            i2 = re.sub(r'\.',"p",i2)
            #if re.search(r'10MHz',i2):
            if re.search(r'RMS EVM',i1):
                return "EVM_"+i2
            elif re.search(r'ACLR UTRA1',i1):
                return "ACLR_"+i2
            else:
                return "CONTINUE"
            #else:
            #    return "CONTINUE"
        elif re.search(r'BB Attn (\d+)dB',i2) or re.search(r'RF Step (\d+)',i2):
            return "POWER_APC"
        else:
            print "get TXRF Fail::",i1,":",i2
            return "NULL"
#        m = re.search(r'( \(eDSDS\)|EVM|IIP|Gain|NF|Noise Figure|Image Rejection|IR|USNR|Filter|DC offset)',i,re.I) 
#        if m:
#            if o==0:
#                i = m.group(1)
#            i=re.sub(r'Gain Step',"GSTEP",i)
#            i=re.sub(r'LNA\s*',"",i)
#            i=re.sub(r'\s*dB$',"dB",i)
#            i=re.sub(r'Gain',"GAIN",i)
#            i=re.sub(r'\s*FDD\s*'," ",i)
#            i=re.sub(r'Noise Figure',"NF",i)
#            i=re.sub(r'Image Rejection',"IR",i)
#            i=re.sub(r'Filter( Selectivity)*',"FILT",i)
#            i=re.sub(r'DC offset',"DCOS",i)
#            i=re.sub(r'\s+',"_",i)
#            i=re.sub(r'GAIN_All_max',"GMAX",i)
#            i=re.sub(r'In_Band',"IB",i)
#            i=re.sub(r'RMS_EVM',"EVMrms",i)
#            i=re.sub(r'0.5\*Dup',"HDUP",i)
#            i=re.sub(r'2\*Dup',"2DUP",i)
#            return i
#        else:
#            return ""
    def getIFMode(i):
        i=re.sub(r'\s*FDD\s*'," ",i)
        i=re.sub(r'\s+',"_",i)
        return i

    #read xlsx
    global g_mapSht
    global g_mapBandDef
    global g_maptx
    book=xlrd.open_workbook(ixlsx[0],formatting_info=True)
    sht=book.sheet_by_name(g_mapSht["g_sheetTX"])
    if(col2n(g_mapSht['g_txstpAttnRF'])>sht.ncols or 
            col2n(g_mapSht['g_txstpBandwidth'])>sht.ncols or
            col2n(g_mapSht['g_txblkEnd'])>sht.ncols):
        ALERT_MESSAGE("tx sheet column setting Error.")
        sys.exit(2)

    txstand1Ary = sht.col_values(col2n(g_mapSht['g_txstand1']))
    txstand2Ary = sht.col_values(col2n(g_mapSht['g_txstand2']))
    txItem1Ary = sht.col_values(col2n(g_mapSht['g_txItem1']))
    txItem2Ary = sht.col_values(col2n(g_mapSht['g_txItem2']))
    txstpinPwrAry = sht.col_values(col2n(g_mapSht['g_txstpinPwr']))
    txstpinPwrAry=map((lambda x: re.sub(r'\*',"","%s"%x)),txstpinPwrAry)
    #txstpDltFrqAry = sht.col_values(col2n(g_mapSht['g_txstpDltFrq']))
    txstpBandwidthAry = sht.col_values(col2n(g_mapSht['g_txstpBandwidth']))
    txstpAttnBBAry = sht.col_values(col2n(g_mapSht['g_txstpAttnBB']))
    txstpAttnBBAry=map((lambda x: re.sub(r'\*',"","%s"%x)),txstpAttnBBAry)
    txstpAttnRFAry = sht.col_values(col2n(g_mapSht['g_txstpAttnRF']))
    txstpAttnRFAry=map((lambda x: re.sub(r'Step ',"","%s"%x)),txstpAttnRFAry)
    txstpAttnRFAry=map((lambda x: re.sub(r'\*',"","%s"%x)),txstpAttnRFAry)
    for icol in range(col2n(g_mapSht['g_txblkBegin']),col2n(g_mapSht['g_txblkEnd'])+1):
        col=sht.col(icol)
        port = col[g_mapSht['g_txport']].value
        phase8_flag=""
        if re.search(r'8 phase',port):
            port = re.sub(r'\(8 phase\)',"",port)
            phase8_flag="_8PHASE"
        band = getInt(col[g_mapSht['g_txband']].value)
        if band==-999:
            ALERT_MESSAGE("band in TX def error. Check Setting or xlsx file 1:"+col[g_mapSht['g_rxband']].value)
            sys.exit(2)
        for irow in xrange(g_mapSht['g_txband']+1,g_mapSht['g_lasttxRow']+1 if len(col)>g_mapSht['g_lasttxRow'] and g_mapSht['g_lasttxRow']!=0 else len(col)):
            stand=getStand(txstand1Ary[irow])
            if stand == "BREAK":
                break
            testType=getRF(txItem1Ary[irow],txItem2Ary[irow])
            #print stand,band,port,":",testType,":",txstpAttnBBAry[irow]
            if testType=="CONTINUE":
                continue
            if(col[irow].value=='x'and len(testType)):
                testType = testType+phase8_flag
                #print "testType:",testType
                if (stand,band,port) in g_maptx.keys():
                    if not testType in g_maptx[(stand,band,port)].keys(): # new test type
                        g_maptx[(stand,band,port)][testType]=clsTX(testType,band,int(float(txstpinPwrAry[irow])))
                else: #new stand+port+band
                    g_maptx[(stand,band,port)] = {testType:clsTX(testType,band,int(float(txstpinPwrAry[irow])))} 
                    #add step
                g_maptx[(stand,band,port)][testType].addStep((txItem1Ary[irow],txItem2Ary[irow],stand,int(float(txstpAttnBBAry[irow])),txstpAttnRFAry[irow])) 
                #g_maprx[(port,band)][2][testType].addStep((stpTypeAry[irow], 
    if(not len(g_maptx.keys())):
        print "TX Definition is empty"
                    
    outFile = file(otx, "w")
    outFile.write("//  TRX,STRING,  INT,STRING,#   STRING,     double,   INT,STRING_Ary,STRING_Ary,double_Ary,double_Ary,double_Ary,STRING_Ary,\n")
    outFile.write("//RX|TX,mStand,mBand, mPort,#test_Type,input_mVrms,mBurst,     mFreq,     mMode, measPower,      frq1,   BB_freq,mGainReg,,\n")
    for (stand,band,port) in g_maptx.keys():
        outFile.write("TX,%s,%s,%s,\n"%(stand,band,port))
        for testType in sorted(g_maptx[(stand,band,port)].keys()):
            (burst,inPwr,stpOpt1,stpOpt2,stpMRg,stpFrq,stpBB,stpAttnBB,stpAttnRF)=g_maptx[(stand,band,port)][testType].getSteps()
            outFile.write(",,,,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n"%(testType,inPwr,burst,
                stpOpt1[0],
                stpOpt2[0],
                stpMRg[0],
                stpFrq[0],
                stpBB[0],
                stpAttnBB[0],
                stpAttnRF[0]))
            for i in range(1,burst):
                outFile.write(",,,,,,,%s,%s,%s,%s,%s,%s,%s,\n"%(
                    stpOpt1[i],
                    stpOpt2[i],
                    stpMRg[i],
                    stpFrq[i],
                    stpBB[i],
                    stpAttnBB[i],
                    stpAttnRF[i]))


    outFile.write("$end\n")
    outFile.close()

def genAnaSet(oAna, ixlsx):
    outFile = file(oAna, "w")
    outFile.write("""hp93000,analog_control,0.2

RFCBB_tml.CBB_Setup_tml "DebugMode"="2", "ClearFlag"="YES"
RFCBB_tml.RF_DATA_Defination "ExternalON"="0" 

""")

    for (port,band) in g_maprx.keys():
        for testType in sorted(g_maprx[(port,band)][2].keys()):
            outFile.write('RFCBB_tml.RX_ana.RX_ana_tml "TestType"="%s","Port"= "%s","Band" = "%s"\n'%(testType,port,band))

    for (stand,band,port) in g_maptx.keys():
        for testType in sorted(g_maptx[(stand,band,port)].keys()):
            outFile.write('RFCBB_tml.TX_ana.TX_ana_tml "TestType"="%s", "Standard"= "%s",   "Port"="%s",       "Band" = "%s"\n'%(testType,stand,port,band))

    outFile.write("\n")
    outFile.close()


if __name__ == '__main__':
#    global g_splitIQ
#    global g_setBin
    print "testplan xlsx Script version:",__version__ 
    print "Start Analyzing"
    try:
        opts, args = getopt.getopt(sys.argv[1:], 'd:i:s:',["sbin","iq"])
    except getopt.GetoptError, err:
        print str(err)
        sys.exit(2)

    pathname = os.path.abspath('.')
    infile = os.path.abspath('./foo')
    setupFile = os.path.abspath('./foo')
    orx = "def_rx.csv"
    otx = "def_tx.csv"
    oAna = "ana.txt"

    for o, a in opts:
        if o == "-d":
            pathname = os.path.abspath(a)
        elif o == "-i":
            infile = a
        elif o == "-s":
            setupFile = a
        #elif o == "-o":
        #    #outfile = os.path.abspath(a)
        #    outfile = a
        #elif o == "--iq":
        #    g_splitIQ = True
        #elif o == "--sbin":
        #    g_setBin = True


    def xlsx_infilter(fname):
        return (re.match(r'%s$'%infile, fname) != None)


    infiles = filter(xlsx_infilter,
                   os.listdir(pathname))

    if len(infiles) == 0:
        print "error: no files. please check the xlsx_filter"       
        sys.exit()

    join_path = lambda f: os.path.join(pathname, f)
    getsetup(join_path(setupFile))
    rdBdDef(map(join_path, infiles))
    cvtRX(join_path(orx), map(join_path, infiles))
    cvtTX(join_path(otx), map(join_path, infiles))
    genAnaSet(join_path(oAna), map(join_path, infiles))
    print "Done"
