#	#/usr/bin/perl -w
#
#	The use of this perl file is:
#
#
#perl2exe_include Data::Dumper
#perl2exe_include File::Slurp
#perl2exe_include "D:/Scripts/vector_parse/1_15/html.prd"
#perl2exe_include "D:/Scripts/vector_parse/1_15/suit.prd"
#0.1.8 process Sequence for SMT8

use 5.012;
use strict;
use warnings;
use autodie;
use File::Slurp;
use Parse::RecDescent;
use Data::Dumper;
use Cwd qw/abs_path getcwd/;
use Try::Tiny;
use File::Basename;
use Win32::OLE qw(in with);
use Win32::OLE::Const 'Microsoft Excel';
$Win32::OLE::Warn = 3;                                # die on errors...

my $version = "0.1.8"; 

#use suitRXInfo;

$::RD_HINT = 1;
$::RD_WARN = 1;
$::RD_ERRORS = 1;
#
use vecInfo;
use flowInfo;
#perl2exe_include "D:/Scripts/vector_parse/1_15/vecInfo.pm"
#perl2exe_include "D:/Scripts/vector_parse/1_15/flowInfo.pm"
#
sub usage {
    print "*************** COMMAND SYNTAX ERROR ******************************\n";
    print "    Not enough argument\n";
    print "    Usage\n";
    print "  	vecFile excelname suitFile1...\n";
    print "*******************************************************************\n\n";
}
my %wtHash=(19=>1); #unit = uS
my %convName=("d2s_SSI_W_" => "W_", "d2s_SSI_R_" => "R_","SSI_WAIT_1mS" => "Wait_1mS", "d2s_SSI_Wait_" => "Wait_");
our $DEBUG_PARSER = 0;
our %burstHash;
our %suitHash;
our $itrParser =0;
our $doVecProcess = 0;
{
    my $argc = @ARGV; 
    if ($argc < 3) {
        usage();
        exit(1);
    }
    my $vecFile = $ARGV[0];
    my $excelFile = getcwd()."\\".$ARGV[1];
    my @arySuitFile;
    for my $i (3.. $argc) {
        push(@arySuitFile,$ARGV[$i-1]);
    }
    
    my $csvFile = getcwd()."\\allburst.csv";
    $excelFile =~ s/\//\\/g;
    print "will gen::",$excelFile,"\n";
    for my $fname(@arySuitFile){
        print "ParseSuite:",$fname,"\n";
        &parse_suit($fname);
    }
    &parse_html($vecFile);
    if($doVecProcess==1){
        &patNameConv();
    }
    unless($ARGV[-1]eq"-v" or $ARGV[-1]eq"-s"){
        &writeExcel($excelFile,$csvFile);
    }else{
        my $opt = "s";
        if($ARGV[-1] =~ m/-v/i){
            $opt = "v";
        }else{
            if($ARGV[-1] =~ m/-s/i){
            }else{
                die "ERROR Option of data log!!";
            }
        }
        &writeExcelWithData($ARGV[4],$opt);
    }
#    &linker($excelFile,\@burstClass);
}
sub patNameConv{
    my $convWT = sub{
        my $mainPat = shift;
        my $cycle=0;
        if($mainPat =~ /Wait_(\d+)Cycles/){
            $cycle = $1;
        }else{
            die $mainPat," is not supported";
        }
        my $periodC;
        my $periodT;
        foreach(keys(%wtHash)){
            $periodC = $_;
            $periodT = $wtHash{$_};
        }
        my $time = $cycle/$periodC*$periodT;
        my $unit ="uS";
        if( $time>1000){
            $unit = "mS";
            $time = $time/1000.0;
        }
        my $newCommand = sprintf "Wait_%2.1f%s",$time,$unit;
        return $newCommand;
    };
    my $convRule=sub{
        my $burstName = shift;
        my @burstAry = $burstHash{$burstName}->get_mainAry();
        for my $value(@burstAry){
            for my $keyConv (keys(%convName)){
                if($value ~~ /$keyConv/){
                    $value =~ s/$keyConv/$convName{$keyConv}/;
                    if($keyConv eq "d2s_SSI_Wait_"){
                        $value = &$convWT($value);
                    }
                }
            }
        }
        $burstHash{$burstName}->set_mainAry(\@burstAry);
    };
    for my $key (keys(%burstHash)) {
        &$convRule($key);
    }
}

sub parse_html {
    my $filename = shift;
    my $text = read_file($filename);
    unless($text =~ /(<tbody>\s*.*?\s*<\/tbody>)/s){
        die "No tbody block!\n";
    }
    else{
        my $block_text = $1;
        my $grammar = read_file("html.prd");
        my $parser = Parse::RecDescent->new($grammar);
        my $tree = $parser->bodySession($block_text);
        unless ($tree) {    
            print STDERR "Error: unable to parse html!\n";
            die;
        }
        if ($DEBUG_PARSER) {
            print Dumper($tree);
        }
        my $analyze_tree = ();
        $analyze_tree = sub {
            my ($t, $flag) = @_;
            $flag //= "";
            for my $statement (@$t) {    ## first level
                $burstHash{$statement ->{burst}}=new vecInfo($statement ->{burst},\@{$statement ->{main}});
#                print $burstHash{$statement ->{burst}}->get_mainAry(),"\n";
            }
        };
        &$analyze_tree($tree, "");
    }
    print "Parse burst(VectorBurstSetups.htm) done\n"
}
sub parse_suit {
    my $filename = shift;
    my $text = read_file($filename);
    unless($text =~ /(<\/thead>\s*.*?\s*<table class=tab>)/s or $text =~ /(<\/thead>\s*.*?\s*<\/table>)/s){
        die "No tbody block!\n";
    }
    else{
        my $block_text = $1;
        my $grammar = read_file("suit.prd");
        my $parser = Parse::RecDescent->new($grammar);
        my $tree = $parser->bodySession($block_text);
        unless ($tree) {    
            print STDERR "Error: unable to parse Test suit!\n";
            die;
        }
        if ($DEBUG_PARSER) {
            print Dumper($tree);
        }
        my $analyze_tree = ();
        $analyze_tree = sub {
            my ($t, $flag) = @_;
            $flag //= "";
            for my $statement (@$t) {    ## first level
                $suitHash{$statement->{suit}}=new flowInfo($statement->{suit},$itrParser++,$statement->{burst});
            }
        };
        &$analyze_tree($tree, "");
    }
    print "Parse suit done\n"
}

sub writeExcel {
    my $filename = shift;
    my $csvname = shift;
    #my $burstClass = shift;
    #my @burstClassAry = @{$burstClass};

    my $textCSV="";
    
    #print (1..$#burstClassAry);
    my $excel = Win32::OLE->GetActiveObject('Excel.Application') || Win32::OLE->new('Excel.Application', 'Quit');  
    $excel->{DisplayAlerts} = 'False';  

    my $subAddRFE = sub{
        my @veList = @_;
        my $size = @veList;
        my $itr = 0;
        for my $value (reverse(@veList)){
            if($value eq "DGT_TRIG"){
                splice(@veList,$size-$itr,0,"RFE_TRIG");
                last;
            }else{
                $itr++;
            }
        }
        return @veList;
    };
    my $wExcel = sub{
        my $suitsheet = shift;
        my $tmpVL = shift;
        my @veList = @$tmpVL;
        my $itrRow = shift;
        for my $value (@veList){
            $suitsheet->Cells($itrRow++,3)->{'Value'}=$value;
        }
        return $itrRow;
    };


    my $target_book = $excel->Workbooks->Add;              # open excel file
#    $target_book->Worksheets->Add({after => $target_book->Worksheets($target_book->Worksheets->{count}),
#                                   Count =>($#burstClassAry-3+1+1+1)});
#
#    my $itr=1;
#    my @sheetAry = map { $target_book->Worksheets($itr++)->{Name}=$_; } ("TestSuit", @burstClassAry,"Etc");
    $target_book->Worksheets(1)->{Name}="TestSuit";
    $target_book->Worksheets(2)->{Name}="allBurst";
    {
        my $suitsheet=$target_book->Worksheets("TestSuit");        
        my $itrRow=2;
        $suitsheet->Cells(1,1)->{'Value'}="TestSuit";
        my $interlacingNum = 0;
        foreach my $key(sort {$suitHash{$a}->get_flowNo()<=>$suitHash{$b}->get_flowNo()} keys %suitHash){
            $suitsheet->Cells($itrRow,1)->{'Value'}=$key;
            my $burstName = $suitHash{$key}->get_burstName();
            $suitsheet->Cells($itrRow,2)->{'Value'}=$burstName;
            if(($burstName eq "dummy") or ($burstName eq "")){ next;}
            if($burstName ~~ %burstHash){
                my $grpStartRow = $itrRow;
                my $preVec = "";
                my @veList;
                foreach ($burstHash{$burstName}->get_mainAry()){
                    if($doVecProcess==1){
                        my @regValue = split("_",$_);
                        if (@regValue>3){
                            $suitsheet->Cells($itrRow,3)->{'Value'}=$_;
                            #print $_,"\n";
                            #die @regValue;
                        }else{
                            $suitsheet->Cells($itrRow,3)->{'Value'}=$regValue[0];
                            $suitsheet->Cells($itrRow,4)->{'Value'}=$regValue[1];
                            if(@regValue==3){
                                $suitsheet->Cells($itrRow,5)->{'Value'}=$regValue[2];

                                # write:
                                if($regValue[0] eq "W"){
                                    my $addr = $regValue[1];
                                    my $data = $regValue[2];
                                    $addr =~ s/0x//;
                                    $data =~ s/0x//;
                                    $addr = $addr."h";
                                    $data = $data."h";
                                    $textCSV .=$regValue[0].",".$addr.",".$data.",\n";
                                }
                            }
                        }
                        $itrRow++;
                    }else{
                        if($_ eq "RFE_TRIG"){
                            if($burstName =~/^TX_\w+/){
                                $preVec = $_;
                                next;
                            }elsif($burstName =~/^RX_IIP\w+/ or $burstName =~/^RX_FILT\w+/){
                                @veList=&$subAddRFE(@veList);
                                next;
                            }
                        }
                        if($_ eq "AWG_TRIG"){
                            $preVec = $_;
                            next;
                        }
                        if($_ eq "RF_END_TRIG" or $interlacingNum>0){
                            if($interlacingNum>0){
                                $interlacingNum--;
                            }else{
                                $interlacingNum=3;
                            }
                            #$preVec = "";
                            next;
                        }
                        if($preVec =~ /\w+_TRIG/ and $_ =~ /\w*Wait_.*/i){ #remove delay time after trigger
                            next;
                        }else{
                            push(@veList,$_)
                        }
                        $preVec = $_;
                    }
                }
                if($doVecProcess==0){
                    $itrRow = &$wExcel($suitsheet,\@veList,$itrRow);
                }
                #my $grpStopRow = $itrRow;
#                my $grpVector = sub{
#                    $suitsheet->Rows($grpStartRow:$grpStopRow)->Select();
#                    $Selection->Subtotal GroupBy:=1, Function:=xlSum, TotalList:=Array(2), _
#                        Replace:=True, PageBreaks:=False, SummaryBelowData:=True
#                }
                $itrRow++;
            }
        }
    }#main sheet
#
##    my $Range = $target_book->Worksheets(1)->Range("A1:${last_col}3");
#    my $writeVector=sub{
#        my $sheetName = shift;
#        my $sheet=$target_book->Worksheets($sheetName);
#        my $key = shift;
#        my $getUsedColum =sub{
#            if($sheet->UsedRange->Find({What => "*", 
#                             SearchDirection => xlPrevious, 
#                                 SearchOrder => xlByColumns})){
#                return $sheet->UsedRange->Find({What => "*", 
#                             SearchDirection => xlPrevious, 
#                                 SearchOrder => xlByColumns})-> {Column};
#            }else{
#                return 0;
#            }
#        };
#        my $colVec= &$getUsedColum($sheetName)+1;
#        if($colVec == 1){
#            $target_book->Worksheets($sheetName) ->Cells(1,$colVec)->{'Value'}="TestSuitName";
#            $target_book->Worksheets($sheetName) ->Cells(2,$colVec)->{'Value'}="BurstName";
#            $target_book->Worksheets($sheetName) ->Cells(3,$colVec)->{'Value'}="MainList";
#            $colVec ++;
#        }
#        $target_book->Worksheets($sheetName) ->Cells(1,$colVec)->{'Value'}=$key;
#        $target_book->Worksheets($sheetName) ->Cells(2,$colVec)->{'Value'}=$suitHash{$key}->get_burstName();
#        for(my $irow=3;$irow<=$burstHash{$suitHash{$key}->get_burstName()}->get_mainArySize()+2;$irow++){
#            $target_book->Worksheets($sheetName) ->Cells($irow,$colVec)->{'Value'}=($burstHash{$suitHash{$key}->get_burstName()}->get_mainAry())[$irow-3];
#        }
#        return $colVec;
#    };
#
#    for my $key (sort keys(%suitHash)) {
#        if(($suitHash{$key}->get_burstName() eq "dummy") or ($suitHash{$key}->get_burstName() eq "")){ next;}
#        my $etcFlag = 1;
#        my $celNo = 0;
#        foreach my $vecClass (@burstClassAry){
#            if($suitHash{$key}->get_burstName() ~~ /$vecClass/i){
#                $celNo =&$writeVector($vecClass,$key);
#                $etcFlag = 0;
#                $suitHash{$key}->set_sheet($vecClass);
#                last;
#            }
#        }
#        if(($etcFlag)and($suitHash{$key}->get_burstName() ~~ %burstHash)){
#            $celNo =&$writeVector("Etc",$key);
#            $suitHash{$key}->set_sheet("Etc");
#        }
#        $suitHash{$key}->set_cell($celNo);
#    }
#
    open(FILE, ">", $csvname);
    if(not($textCSV eq "")){
        print FILE $textCSV;
        close FILE;
    }
    print "Excel Generation done\n";

    $target_book->SaveAs($filename);
    $target_book->Close;
}


sub writeExcelWithData {
    my $filename = shift;
    my $opt = shift; ##  v s
    
    my $excel = Win32::OLE->GetActiveObject('Excel.Application') || Win32::OLE->new('Excel.Application', 'Quit');  
    $excel->{DisplayAlerts} = 'False';  

    my $target_book = $excel->Workbooks->Open(getcwd()."\\".$filename);              # open excel file

    my $suitsheet=$target_book->Worksheets(1);        
    my $getUsedRow =sub{
        if($suitsheet->UsedRange->Find({What => "*", 
                         SearchDirection => xlPrevious, 
                             SearchOrder => xlByRows})){
            return $suitsheet->UsedRange->Find({What => "*", 
                         SearchDirection => xlPrevious, 
                             SearchOrder => xlByRows})-> {Row};
        }else{
            return 0;
        }
    };
    my $getUsedColum =sub{
        if($suitsheet->UsedRange->Find({What => "*", 
                         SearchDirection => xlPrevious, 
                             SearchOrder => xlByColumns})){
            return $suitsheet->UsedRange->Find({What => "*", 
                         SearchDirection => xlPrevious, 
                             SearchOrder => xlByColumns})-> {Column};
        }else{
            return 0;
        }
    };
    if($opt eq "s"){
        my $startRow=&$getUsedRow();
        my $endColum=&$getUsedColum();
#        my $getTestSuitName =sub{
#            $suitsheet->Cells(1,1)->{'Value'}="TestSuit";
#            if($suitsheet->UsedRange->Find({What => "*", 
#                             SearchDirection => xlPrevious, 
#                                 SearchOrder => xlByColumns})){
#                return $suitsheet->UsedRange->Find({What => "*", 
#                             SearchDirection => xlPrevious, 
#                                 SearchOrder => xlByColumns})-> {Column};
#            }else{
#                return 0;
#            }
#        };
        my $exSuit = "";
        for(my $itrColum=1;$itrColum<$endColum;$itrColum++){
            my $itrRow=1;
            if(my $cellValue = $suitsheet->Cells($itrRow,$itrColum)->{'Value'}){
                my @tempAry = split(":",$cellValue);
                my $tempArySize = @tempAry;
                if($tempArySize<1){ print $suitsheet->Cells($itrRow,$itrColum)," is illegal\n"; next;}
                my $testSuit = $tempAry[0];
                if($exSuit ~~ $testSuit){ next;}
                else{
                    $exSuit = $testSuit;
                    unless($testSuit ~~ %suitHash){ next;}
                    my $burstName = $suitHash{$testSuit}->get_burstName();
                    if(($burstName eq "dummy") or ($burstName eq "")){ next;}
                    if($burstName ~~ %burstHash){
                        $itrRow = $startRow+1;
                        foreach ($burstHash{$burstName}->get_mainAry()){
                            $suitsheet->Cells($itrRow,$itrColum)->{'Value'}=$_;
                            $itrRow++;
                        }
                    }
                    
                }
                #print "\ntes=", $testSuit;
            }
        }
    }else{
        my $startColum=&$getUsedColum();
        my $endRow=&$getUsedRow();
        my $exSuit = "";
        for(my $itrRow=1;$itrRow<$endRow;$itrRow++){
            my $itrColum=1;
            if(my $cellValue = $suitsheet->Cells($itrRow,$itrColum)->{'Value'}){

                my @tempAry = split(":",$cellValue);
                my $tempArySize = @tempAry;
                if($tempArySize<1){ print $suitsheet->Cells($itrRow,$itrColum)," is illegal\n"; next;}
                my $testSuit = $tempAry[0];
                if($exSuit ~~ $testSuit){ next;}
                else{
                    $exSuit = $testSuit;
                    unless($testSuit ~~ %suitHash){ next;}
                    my $burstName = $suitHash{$testSuit}->get_burstName();
                    if(($burstName eq "dummy") or ($burstName eq "")){ next;}
                    if($burstName ~~ %burstHash){
                        $itrColum = $startColum+1;
                        foreach ($burstHash{$burstName}->get_mainAry()){
                            $suitsheet->Cells($itrRow,$itrColum)->{'Value'}=$_;
                            $itrColum++;
                        }
                    }
                    
                }
            }
        }
    }


#        $suitsheet->Cells(1,1)->{'Value'}="TestSuit";
#        $suitsheet->Cells(1,2)->{'Value'}="BurstName";
#        foreach my $key(sort {$suitHash{$a}->get_flowNo()<=>$suitHash{$b}->get_flowNo()} keys %suitHash){
#            $suitsheet->Cells($itrRow,1)->{'Value'}=$key;
#            my $burstName = $suitHash{$key}->get_burstName();
#            $suitsheet->Cells($itrRow,2)->{'Value'}=$burstName;
#            if(($burstName eq "dummy") or ($burstName eq "")){ next;}
#            if($burstName ~~ %burstHash){
#                my $grpStartRow = $itrRow;
#                foreach ($burstHash{$burstName}->get_mainAry()){
#                    my @regValue = split("_",$_);
#                    if (@regValue>3){
#                        print $_,"\n";
#                        die @regValue;
#                    }
#                    $suitsheet->Cells($itrRow,3)->{'Value'}=$regValue[0];
#                    $suitsheet->Cells($itrRow,4)->{'Value'}=$regValue[1];
#                    if (@regValue>3){
#                        die @regValue;
#                    }elsif(@regValue==3){
#                        $suitsheet->Cells($itrRow,5)->{'Value'}=$regValue[2];
#                    }
#                    $itrRow++;
#                }
#                my $grpStopRow = $itrRow;
#
#                $itrRow++;
#            }
#        }
#
##    my $Range = $target_book->Worksheets(1)->Range("A1:${last_col}3");
#    my $writeVector=sub{
#        my $sheetName = shift;
#        my $sheet=$target_book->Worksheets($sheetName);
#        my $key = shift;
#        my $getUsedColum =sub{
#            if($sheet->UsedRange->Find({What => "*", 
#                             SearchDirection => xlPrevious, 
#                                 SearchOrder => xlByColumns})){
#                return $sheet->UsedRange->Find({What => "*", 
#                             SearchDirection => xlPrevious, 
#                                 SearchOrder => xlByColumns})-> {Column};
#            }else{
#                return 0;
#            }
#        };
#        my $colVec= &$getUsedColum($sheetName)+1;
#        if($colVec == 1){
#            $target_book->Worksheets($sheetName) ->Cells(1,$colVec)->{'Value'}="TestSuitName";
#            $target_book->Worksheets($sheetName) ->Cells(2,$colVec)->{'Value'}="BurstName";
#            $target_book->Worksheets($sheetName) ->Cells(3,$colVec)->{'Value'}="MainList";
#            $colVec ++;
#        }
#        $target_book->Worksheets($sheetName) ->Cells(1,$colVec)->{'Value'}=$key;
#        $target_book->Worksheets($sheetName) ->Cells(2,$colVec)->{'Value'}=$suitHash{$key}->get_burstName();
#        for(my $irow=3;$irow<=$burstHash{$suitHash{$key}->get_burstName()}->get_mainArySize()+2;$irow++){
#            $target_book->Worksheets($sheetName) ->Cells($irow,$colVec)->{'Value'}=($burstHash{$suitHash{$key}->get_burstName()}->get_mainAry())[$irow-3];
#        }
#        return $colVec;
#    };
#
#    for my $key (sort keys(%suitHash)) {
#        if(($suitHash{$key}->get_burstName() eq "dummy") or ($suitHash{$key}->get_burstName() eq "")){ next;}
#        my $etcFlag = 1;
#        my $celNo = 0;
#        foreach my $vecClass (@burstClassAry){
#            if($suitHash{$key}->get_burstName() ~~ /$vecClass/i){
#                $celNo =&$writeVector($vecClass,$key);
#                $etcFlag = 0;
#                $suitHash{$key}->set_sheet($vecClass);
#                last;
#            }
#        }
#        if(($etcFlag)and($suitHash{$key}->get_burstName() ~~ %burstHash)){
#            $celNo =&$writeVector("Etc",$key);
#            $suitHash{$key}->set_sheet("Etc");
#        }
#        $suitHash{$key}->set_cell($celNo);
#    }
#
    print "Excel Generation done\n";

    $target_book->Save;
    $target_book->Close;
}


sub linker{
    my $filename = shift;
    my $burstClass = shift;
    my @burstClassAry = @{$burstClass};

    my $excel = Win32::OLE->new('Excel.Application', 'Quit');   
    $excel->{DisplayAlerts} = 'False';  
#    my $target_book = $excel->Workbooks->Open(abs_path($filename), 0, 'False');
    my $target_book = $excel->Workbooks->Open($filename, 0, 'False');
    my @sheetAry = map { $target_book->Worksheets($_); } ("TestSuit",@burstClassAry,"Etc");
    my $clinker = sub{
#        #get colum
#        my %burst_columidx = ();
#        for (my $col_idx = 1; $col_idx <= @sheetAry[1]->UsedRange->Colums->Count; $col_idx++) {
#            my $testsuite_name = $testitems_sheet->Cells($col_idx, 1)->{Value};
#            $testsuite_rowidx{$testsuite_name} = "$col_idx%d"1;
#        } # for
#    
#        print Dumper(\%testsuite_rowidx);
#
#
#
        $sheetAry[0]->Select();
        for (my $row_idx = 2; $row_idx <= $sheetAry[0]->UsedRange->Rows->Count; $row_idx++) {
            my $suit_name = $sheetAry[0]->Cells($row_idx, 1)->{'Value'};
            unless($suitHash{$suit_name}->get_cell()){ next;}
#            unless ($testsuite_name ~~ \%testsuite_rowidx) {
#                print STDERR "die $testsuite_name";
#            }
            my $link = sprintf "%s!R1C%s", $suitHash{$suit_name}->get_sheet(), $suitHash{$suit_name}->get_cell();
            $excel->ActiveSheet->Hyperlinks->Add($sheetAry[0]->Range("A$row_idx"),"", $link, $suit_name);
        } # for
    };
    &$clinker;
    $target_book->Save;
    $target_book->Close;
    print "Linker done\n";
}
#system "pause\n";
