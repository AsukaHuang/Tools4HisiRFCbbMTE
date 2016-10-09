#	#/usr/bin/perl -w
#
#	The use of this perl file is:
#
#	map2TPlan.pl $path $tpfile,$xlsfile
#	if $path is ignored£¬the target path will automatically be set to current path
#	if $tpfile is ignored£¬the target file name will automatically be set to RF_com_Defination_h.txt
#	if $xlsfile is ignored£¬the target file name will automatically be set to new_sTplan.xlsx
#
#use 5.012;
use strict;
use autodie;
use File::Slurp;
use Cwd;
use Storable qw(dclone);
use File::Basename;
use Parse::RecDescent;
use Data::Dumper;

my $version = "0.1.1";

my %rxStruct=( ##dummy declare
    port => "",
    band => -1,
    bbPath => "",
    pllSel => "",
    inLoss => 0,   #block end
    testType => "", #0
    burst => 0,
    stepType => (),
    ifMode => (),
    pow1 => (),
    pow2 => (),
    freq1 => (),
    freq2 => (),
    bbfreq => (),
    gainReg => ()
);
my %txStruct=(
    stand => "",
    band => -1,
    port => "",
    testType => "",
    inVrms => 0,
    burst => 0,
    freqMode => (),
    gainMode => (),
    measPow => (),
    freq => (),
    bbfreq => (),
    gainReg => ()
);


our $DEBUG_PARSER = 0;
our @aryRXSuit;
our @aryTXSuit;
my @rxStructInfo;
my @txStructInfo;
my %rxMap;    #hash
my %txMap;
my @rxkeyAry; #key
my @txkeyAry;
## rx key: mBand port_name
## tx key: mBand mStand
{
    my $argc = @ARGV; 
    if ($argc < 4) {
        usage();
        exit(1);
    }
    my $genPath = $ARGV[0];
    my $headFileName = $ARGV[1];
    my $opt = $ARGV[2];

    my ($path,$tpfilePath,$csvPathAry)= &getFilename($genPath,$headFileName,$ARGV[3]);

    print "\nversion=",$version;
    if($opt eq "h2csv"){
        print "\nh2csv Start\n";
        &parse_header($tpfilePath,"suit.prd");
        &sheetProcess($csvPathAry,$opt);
        print "h2csv Done :)\n";
    }elsif($opt eq "h2csv_oldx4"){
        print "\nh2csv Start\n";
        &parse_header_x4($tpfilePath,"suit_oldx4.prd");
        &sheetProcess($csvPathAry,$opt);
        print "h2csv Done :)\n";
    }else{
        if($opt eq "csv2h"){
            print "\ncsv2h Start\n";
            &sheetProcess($csvPathAry,$opt);
            &write_header($tpfilePath);
            print "\ncsvh2 Done\n";
        }else{
            print "option: ",$opt," is illegal";
        }
    }

}

sub getFilename{
    my $absCWD = getcwd();
    $absCWD =~ s/\//\\/g;
    if(!defined $_[0]){
        $_[0] = $absCWD."\\Result\\";
    }else{
    	$_[0] = $absCWD."\\".$_[0]."\\";
    }
    if(!defined $_[1]){
    	$_[1] = $_[0]."RF_map.h";
    }else{
    	$_[1] = $_[0].$_[1];
    }
    my $folder = $_[0];
    my @csvFiles = split(",",$_[2]);
    my @tmpAry = map($folder.$_.".csv",@csvFiles);
    return ($_[0],$_[1],\@tmpAry);
}

sub write_header{
    my $filename = shift;

#    sub getStructDef{
#        my $member =shift;
#        my $type = $member->{type};
#        if($member->{attr}){
#            my @tempType = split('_',$member->{type});
#            $type = $tempType[0];
#        }
#        return '    '.$type.' '.$member->{name}.";\n";
#    };
    sub getMap{

        my $suitAry =shift;
        my $trx =shift;
        my %suit = %$suitAry;
#        print "aaaaaa:$suitAry->{stand}\n";
#        print "aaaaaa:$suitAry->{band}\n";
#        print "aaaaaa:$suitAry->{port}\n";
#        print "aaaaaa:$suitAry->{testType}\n";
#        print "aaaaaa:$suitAry->{freqMode}\n";
#        print "aaaaaa:$suitAry->{measPow}\n";
        my $a2l=sub{
            my $src = shift;
            my $opt = shift;
            my @des = @$src;
            if($opt){ #2 string
                @des = map("\"$_\"",@des);
            }
            return "{".join(",",@des)."}";
        };
        if($trx eq "TX"){
            return "{\"$suitAry->{stand}\",$suitAry->{band},\"$suitAry->{port}\",\"$suitAry->{testType}\",$suitAry->{inVrms},$suitAry->{burst},".&$a2l($suitAry->{freqMode},1).",".&$a2l($suitAry->{gainMode},1).",".&$a2l($suitAry->{measPow},0).",".&$a2l($suitAry->{freq},0).",".&$a2l($suitAry->{bbfreq},0).",".&$a2l($suitAry->{gainReg},1)."},\n";
        }else{ #RX
            return "{$suitAry->{band},\"$suitAry->{port}\",\"$suitAry->{bbPath}\",$suitAry->{pllSel},$suitAry->{inLoss},\"$suitAry->{testType}\",$suitAry->{burst},".&$a2l($suitAry->{stepType},1).",".&$a2l($suitAry->{ifMode},1).",".&$a2l($suitAry->{pow1},0).",".&$a2l($suitAry->{pow2},0).",".&$a2l($suitAry->{freq1},0).",".&$a2l($suitAry->{freq2},0).",".&$a2l($suitAry->{bbfreq},0).",".&$a2l($suitAry->{gainReg},1)."},\n";
        }
    }

    my @wlines=();

    push @wlines,'
//definition Start
typedef struct RX_Pow_frq_mapping_s{
    int mBand;
    STRING port_name;
    STRING BB_Path;
    int RXPLL_sel;
    double inLoss;

    STRING test_Type;
    //STRING Freq_List;
    int mBurst;
    STRING mIFMode[Burst_Num_Max];
    STRING mType[Burst_Num_Max];
    double pow1[Burst_Num_Max];
    double pow2[Burst_Num_Max];
    double frq1[Burst_Num_Max];
    double frq2[Burst_Num_Max];
    double BB_FrqOut[Burst_Num_Max];
    STRING mGainReg[Burst_Num_Max];
}RX_Pow_frq_mapping_t;
';
    {
        push @wlines,"const RX_Pow_frq_mapping_t RX_PowFre_Mapping[]={\n";
        push @wlines,map(&getMap($_,"RX"),@aryRXSuit);
        $wlines[$#wlines] =~ s/,$//;
        push @wlines,"};\n\n";
    }
    push @wlines,'
typedef struct TX_Pow_frq_mapping_s{
    STRING mStand;
    int mBand;
    STRING mPort;

    STRING test_Type;
    double input_mVrms;
    int mBurst;
//    STRING FreqList_Name;
    STRING mFreq[Burst_Num_Max];
    STRING mMode[Burst_Num_Max];
    double measPower[Burst_Num_Max];
    double frq1[Burst_Num_Max];
    double BB_freq[Burst_Num_Max];
    STRING mGainReg[Burst_Num_Max];
}TX_Pow_frq_mapping_t;
const TX_Pow_frq_mapping_t TX_PowFreq_Mapping[]={
';

    {
        push @wlines,map(&getMap($_,"TX"),@aryTXSuit);
        $wlines[$#wlines] =~ s/,$//;
        push @wlines,"};\n";
    }

    push @wlines,"//definition Stop\n\n";

    my $newline = join '',@wlines;
    if(-f $filename){
        my $text = read_file($filename);
        my $parseRule = '(\/\/definition Start.+\/\/definition Stop)';
        unless($text =~ m/$parseRule/s){
            die "No tbody block!\n";
        }else{
            $text =~ s/$parseRule/$newline/s;
            $text =~ s/\\n//s;
            open(FILE, ">", $filename);
            print FILE $text;
            close FILE
        }
    }else{
        open(FILE, ">", $filename);
        print FILE @wlines;
        close FILE
    }
}
sub checkKey{
    my ($tmpStructinfo, $tmpKeyAry) = @_;
    my $allFlag = 0;
    for my $keyname (@$tmpKeyAry){
        my $flag = 0;
        for my $itrStruct (@$tmpStructinfo){
            if($itrStruct->{name} eq $keyname){
                $flag = 1;
                last;
            }
        }
        $allFlag += $flag;
    }
    return $allFlag;
};
sub parse_header{
    my $filename = shift;
    my $prdName = shift;
    my $text = read_file($filename);
    my $parseRule = '(\/\/definition Start.+\/\/definition Stop)';
    unless($text =~ m/$parseRule/s){
        die "No tbody block!\n";
    }else{
        my $block_text = $1;
        my $grammar = read_file($prdName);
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
            my ($bodySession, $flag) = @_;
            $flag //= "";
            my $counter =0;

            # -------------rxStruct
#            my $rxStructAry=$bodySession->{rxStruct};
#            for my $memberDeclare (@$rxStructAry){
#                unless($memberDeclare->{name}eq""){
#                    my $attr = 1;
#                    if($memberDeclare->{ary}eq"false"){
#                        $attr = 0;
#                    }
#                    my $member = {
#                        type =>$memberDeclare->{type}, 
#                        name =>$memberDeclare->{name}, 
#                        attr =>$attr,
#                        value => undef
#                    };
#                    push(@rxStructInfo, $member);
#                }
#            }

            my $rxSuits=$bodySession->{rxMap};
            for my $singleSuit (@$rxSuits){
#                my @stepType = split(",",$singleSuit->[10]);
#                my @ifMode = split(",",$singleSuit->[9]);
#                my @gainReg = split(",",$singleSuit->[11]);
                my %tmpSuitHash = (    
                    band => $singleSuit->[0],
                    port => $singleSuit->[1],
                    bbPath => $singleSuit->[2],
                    pllSel => $singleSuit->[3],
                    inLoss => $singleSuit->[4],   #block end
                    testType => $singleSuit->[5], #0
                    burst => $singleSuit->[6],
                    stepType => $singleSuit->[7],
                    ifMode => $singleSuit->[8],
                    pow1 => $singleSuit->[9],
                    pow2 => $singleSuit->[10],
                    freq1 => $singleSuit->[11],
                    freq2 => $singleSuit->[12],
                    bbfreq => $singleSuit->[13],
                    gainReg => $singleSuit->[14],
                );

                my $tmpSuitMap;
                if($rxMap{$singleSuit->[0]}{$singleSuit->[1]}){
                    $tmpSuitMap=$rxMap{$singleSuit->[0]}{$singleSuit->[1]};
                }
                push(@$tmpSuitMap,\%tmpSuitHash);
                $rxMap{$singleSuit->[0]}{$singleSuit->[1]} = \@$tmpSuitMap;

            }

#            # -------------txStruct
#            my $txStructAry=$bodySession->{txStruct};
#            for my $memberDeclare (@$txStructAry){
#                unless($memberDeclare->{name}eq""){
#                    my $attr = 1;
#                    if($memberDeclare->{ary}eq"false"){
#                        $attr = 0;
#                    }
#                    my $member = {
#                        type =>$memberDeclare->{type}, 
#                        name =>$memberDeclare->{name}, 
#                        attr =>$attr,
#                        value => undef
#                    };
#                    push(@txStructInfo, $member);
#                }
#            }

            my $txSuits=$bodySession->{txMap};
            for my $singleSuit (@$txSuits){
#                my @freqMode = split(",",$singleSuit->[10]);
#                my @gainMode = split(",",$singleSuit->[11]);
#                my @gainReg = split(",",$singleSuit->[12]);

                my %tmpSuitHash=(
                    stand => $singleSuit->[0],
                    band => $singleSuit->[1],
                    port => $singleSuit->[2],
                    testType => $singleSuit->[3],
                    inVrms => $singleSuit->[4],
                    burst => $singleSuit->[5],
                    freqMode => $singleSuit->[6],
                    gainMode => $singleSuit->[7],
                    measPow => $singleSuit->[8],
                    freq => $singleSuit->[9],
                    bbfreq => $singleSuit->[10],
                    gainReg => $singleSuit->[11]
                );
                my $tmpSuitMap;
                if($txMap{$singleSuit->[0]}{$singleSuit->[1]}){
                    $tmpSuitMap=$txMap{$singleSuit->[0]}{$singleSuit->[1]};
                }
                push(@$tmpSuitMap,\%tmpSuitHash);
                $txMap{$singleSuit->[0]}{$singleSuit->[1]} = \@$tmpSuitMap;
            }
#            #  check tx
#            foreach my $band (keys %txMap){
#                foreach my $port (keys %{$txMap{$band}}){
#                    print $band,",",$port,"\n";
#                    my $suitlist = $txMap{$band}{$port};
#                    foreach my $suit (@$suitlist){
#                        my @element = @$suit;
#                        print $element[0]->{value},",";
#                    }
#                    print "\n--------------------\n";
#                }
#            }

        };
        &$analyze_tree($tree, "");
    }
    print "Parse header done\n"
}
sub parse_header_x4{
    my $filename = shift;
    my $prdName = shift;
    my $text = read_file($filename);
    my $parseRule = '(\/\/definition Start.+\/\/definition Stop)';
    unless($text =~ m/$parseRule/s){
        die "No tbody block!\n";
    }else{
        my $block_text = $1;
        my $grammar = read_file($prdName);
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
            my ($bodySession, $flag) = @_;
            $flag //= "";
            my $counter =0;

            # -------------rxStruct
#            my $rxStructAry=$bodySession->{rxStruct};
#            for my $memberDeclare (@$rxStructAry){
#                unless($memberDeclare->{name}eq""){
#                    my $attr = 1;
#                    if($memberDeclare->{ary}eq"false"){
#                        $attr = 0;
#                    }
#                    my $member = {
#                        type =>$memberDeclare->{type}, 
#                        name =>$memberDeclare->{name}, 
#                        attr =>$attr,
#                        value => undef
#                    };
#                    push(@rxStructInfo, $member);
#                }
#            }

            my $rxSuits=$bodySession->{rxMap};
            for my $singleSuit (@$rxSuits){
                my @stepType = split(",",$singleSuit->[10]);
                my @ifMode = split(",",$singleSuit->[9]);
                my @gainReg = split(",",$singleSuit->[11]);
                my $bb2e6 = sub{
                    my @src = @_;
                    my $array = $src[0];
                    my @des;
                    for my $eachBB (@$array){
#                        my $sBB=$eachBB*1e6;
                        my $sBB="$eachBB"."e6";
                        push(@des,$sBB);
                    } 
                    my @dummyAry;
                    push(@dummyAry,\@des);
                    return @dummyAry;
#                    if($size==1){
#                        print "lallala:".$src[0]."\n";
#                        push(@des,$src[0]);
#                        return $src;
#                    }else{
#                        #                    my @array = @$src;

#    #                    print $des[0];
#                        return @des;
#                    }
                };
                my $freqValid = sub{
                    my @src = @_;
                    my $array = $src[0];
                    my @des;
                    for my $eachBB (@$array){
                        my $sBB=$eachBB;
                        if($eachBB<200e6){
                            $sBB=undef;
                        }
#                        my $sBB=$eachBB*1e6;
                        push(@des,$sBB);
                    } 
                    my @dummyAry;
                    push(@dummyAry,\@des);
                    return @dummyAry;
                };
                my %tmpSuitHash = (    
                    testType => $singleSuit->[0], #0
                    port => $singleSuit->[1],
                    band => $singleSuit->[2],
                    burst => $singleSuit->[4],
                    pow1 => $singleSuit->[5],
                    freq1 => &$freqValid($singleSuit->[6]),
                    freq2 => &$freqValid($singleSuit->[7]),
                    #freq1 => $singleSuit->[6],
                    #freq2 => $singleSuit->[7],
                    bbfreq => &$bb2e6($singleSuit->[8]),
                    ifMode => \@ifMode,
                    stepType => \@stepType,
                    gainReg =>  \@gainReg,
                    bbPath => $singleSuit->[12],
                    pllSel => $singleSuit->[13],
                    inLoss => 0,   #block end
                    #inLoss => $singleSuit->[13],   #block end
                );

                my $tmpSuitMap;
                if($rxMap{$singleSuit->[2]}{$singleSuit->[1]}){
                    $tmpSuitMap=$rxMap{$singleSuit->[2]}{$singleSuit->[1]};
                }
                push(@$tmpSuitMap,\%tmpSuitHash);
                $rxMap{$singleSuit->[2]}{$singleSuit->[1]} = \@$tmpSuitMap;

            }

#            # -------------txStruct
#            my $txStructAry=$bodySession->{txStruct};
#            for my $memberDeclare (@$txStructAry){
#                unless($memberDeclare->{name}eq""){
#                    my $attr = 1;
#                    if($memberDeclare->{ary}eq"false"){
#                        $attr = 0;
#                    }
#                    my $member = {
#                        type =>$memberDeclare->{type}, 
#                        name =>$memberDeclare->{name}, 
#                        attr =>$attr,
#                        value => undef
#                    };
#                    push(@txStructInfo, $member);
#                }
#            }

            my $txSuits=$bodySession->{txMap};
            for my $singleSuit (@$txSuits){
                my @freqMode = split(",",$singleSuit->[10]);
                my @gainMode = split(",",$singleSuit->[11]);
                my @gainReg = split(",",$singleSuit->[12]);

                my %tmpSuitHash=(
                    testType => $singleSuit->[0],
                    stand => $singleSuit->[1],
                    band => $singleSuit->[2],
                    port => $singleSuit->[3],
                    burst => $singleSuit->[5],
                    inVrms => $singleSuit->[6],
                    measPow => $singleSuit->[7],
                    freq => $singleSuit->[8],
                    bbfreq => $singleSuit->[9],
                    freqMode => \@freqMode,
                    gainMode => \@gainMode,
                    gainReg => \@gainReg
                );
                my $tmpSuitMap;
                if($txMap{$singleSuit->[1]}{$singleSuit->[2]}){
                    $tmpSuitMap=$txMap{$singleSuit->[1]}{$singleSuit->[2]};
                }
                push(@$tmpSuitMap,\%tmpSuitHash);
                $txMap{$singleSuit->[1]}{$singleSuit->[2]} = \@$tmpSuitMap;
            }
#            #  check tx
#            foreach my $band (keys %txMap){
#                foreach my $port (keys %{$txMap{$band}}){
#                    print $band,",",$port,"\n";
#                    my $suitlist = $txMap{$band}{$port};
#                    foreach my $suit (@$suitlist){
#                        my @element = @$suit;
#                        print $element[0]->{value},",";
#                    }
#                    print "\n--------------------\n";
#                }
#            }

        };
        &$analyze_tree($tree, "");
    }
    print "Parse header done\n"
}

sub sheetProcess{
    my $csvPathAry = shift;
    my @tempcsvPath = @$csvPathAry;
    my $opt = shift;

    sub wSpreadsheet{
    

        my $getmaxLine=sub{
            my $tmpburst=0;
            for my $each (@_){
                unless($each){
                    next;
                }
                my $size = @$each;
                if($size> $tmpburst){
                    $tmpburst = $size;
                }
            }
            return $tmpburst;
        };
        my $writeSheetRX=sub{
            my $file = shift;
            my $trxAttr = shift;

            my @wline;
            push(@wline,'//  TRX,  INT,   STRING, STRING,      INT,double,#   STRING,   int, double_Ary, double_Ary,double_Ary,double_Ary,double_Ary,STRING,string
//RX|TX,mBand,port_name,BB_Path,RXPLL_sel,inLoss,#  test_Type, burst,       pow1,       pow2,     freq1,     freq2,  baseband, mType,mGainReg,,
,
');

            foreach my $port (keys %rxMap){
                foreach my $band (keys %{$rxMap{$port}}){ #block
                    my $suitlist = $rxMap{$port}{$band};
                    my $index=0;
                    foreach my $eachsuit (@$suitlist){
                        my %suit = %$eachsuit;
                        if($index==0){
                            my $blockLine = $trxAttr.",".$suit{band}.",".$suit{port}.",".$suit{bbPath}.",".$suit{pllSel}.",".$suit{inLoss}."\n";
                            $index++;
                            push(@wline,$blockLine);  #block
                        }
                        my $burstMax = &$getmaxLine($suit{stepType},$suit{ifMode},$suit{pow1},$suit{freq1},$suit{freq2},$suit{bbfreq},$suit{gainReg});
                        for(my $itr=0;$itr<$burstMax;$itr++){
                            my $blockLine = ",,,,,,,,";
                            if($itr==0){
                                $blockLine= ",,,,,,".$suit{testType}.",".$suit{burst}.",";  ## suite 1stline
                            }
                            my $line =$blockLine.$suit{stepType}[$itr].",".$suit{ifMode}[$itr].",".$suit{pow1}[$itr].",".$suit{pow2}[$itr].",".$suit{freq1}[$itr].",".$suit{freq2}[$itr].",".$suit{bbfreq}[$itr].",".$suit{gainReg}[$itr]."\n";
                            push(@wline,$line);
                        }
                    }
                }
            }
            push(@wline,"\$end,\n");
            open (DST, ">$file");
            print DST @wline; 
            close DST;

        };
        my $writeSheetTX=sub{
            my $file = shift;
            my $trxAttr = shift;

            my @wline;
            push(@wline,'//  TRX,STRING,  INT,STRING,#   STRING,     double,   INT,STRING_Ary,STRING_Ary,double_Ary,double_Ary,double_Ary,STRING_Ary,
//RX|TX,mStand,mBand, mPort,#test_Type,input_mVrms,mBurst,     mFreq,     mMode, measPower,      frq1,   BB_freq,mGainReg,
,
');

            foreach my $stand (keys %txMap){
                foreach my $band (keys %{$txMap{$stand}}){ #block
                    my $suitlist = $txMap{$stand}{$band};
                    my $index=0;
                    foreach my $eachsuit (@$suitlist){
                        my %suit = %$eachsuit;
                        if($index==0){
                            my $blockLine = $trxAttr.",".$stand.",".$band.",".$suit{port}.",\n";
                            $index++;
                            push(@wline,$blockLine);  #block
                        }
                        my $burstMax = &$getmaxLine($suit{freqMode},$suit{gainMode},$suit{measPow},$suit{freq},$suit{bbfreq},$suit{gainReg});

#                        print "freqMode = $suit{freqMode}\n";
#                        print "gainMode = $suit{gainMode}\n";
#                        print "measPow = $suit{measPow}\n";
#                        print "freq = $suit{freq}\n";
#                        print "bbfreq = $suit{bbfreq}\n";
#                        print "gainReg = $suit{gainReg}\n";
                        for(my $itr=0;$itr<$burstMax;$itr++){
                            my $blockLine = ",,,,,,,";
                            if($itr==0){
                                $blockLine= ",,,,".$suit{testType}.",".$suit{inVrms}.",".$suit{burst}.",";  ## suite 1stline
                            }

                            my $line =$blockLine.$suit{freqMode}[$itr].",".$suit{gainMode}[$itr].",".$suit{measPow}[$itr].",".$suit{freq}[$itr].",".$suit{bbfreq}[$itr].",".$suit{gainReg}[$itr]."\n";
                            push(@wline,$line);
                        }
                    }
                }
            }
            push(@wline,"\$end,\n");
            open (DST, ">$file");
            print DST @wline; 
            close DST;
        };

        &$writeSheetRX($tempcsvPath[0],"RX");
        &$writeSheetTX($tempcsvPath[1],"TX");
        
    }
    sub rSpreadsheet{
        my @text = read_file(shift);
        my $rmCmt = sub{
            my $line =shift;
            $line =~ s/\s+//g;
            $line =~ s/#[\w\.]*,/,/g;
            $line =~ s/\/\/.+//g;
            my @lines = split(",",$line);
            return @lines;
        };

        sub getCsvCol{
            my @ary = @_;
            my $size = @ary;
            unless($size){
                return 0;
            }
            while($ary[$size-1] eq ""){
                $size--;
                last;
            }
            return $size;
        };
#        sub getkey{
#            my $clnLine = sub{
#                my $line =shift;
#                $line =~ s/\/\///g;
#                $line =~ s/\s+//g;
#                $line =~ s/#//g;
#                return $line;
#            };
#
#
#            my $lines = shift; 
#            my $trx = shift; 
#            my @lineAry = @$lines;
#            my @type = split(",",&$clnLine($lineAry[0]));
#            my @typeName = split(",",&$clnLine($lineAry[1]));
#            my @tempInfo=();
#            for my $idxCol (1..&getAttr(\@type)){
#                unless($type[$idxCol] eq "" or $typeName[$idxCol] eq ""){
#                    my $attr = 0;
#                    if($type =~ m/_Ary/){
#                        $attr = 1;
#                    }
#                    my $member = {
#                        type =>$type, 
#                        name =>$attrName, 
#                        attr =>$attr,
#                        value => undef
#                    };
#                    push(@tempInfo, $member);
#                }else{
#                    die $trx," attribute line blank:Col:",$idxCol;
#                }
#            }
#            if($trx eq "RX"){
#                unless(&checkKey(\@tempInfo,\@rxkeyAry)){
#                    die "rx key is not suitable:",@rxkeyAry;
#                }
#            }else{
#                unless(&checkKey(\@tempInfo,\@txkeyAry)){
#                    die "rx key is not suitable:",@txkeyAry;
#                }
#            }
#            return @tempInfo;
#        };
        sub getSuit{
            my @csv = @_;
            my %refStruct;

            my $trx = "";
            my $saveSuit=sub{
                my $tmpSuit = shift;
                my $tmp = dclone(\%$tmpSuit);
                my %tmpStruct = %$tmp;
                if($trx eq "RX"){
                    push(@aryRXSuit,\%tmpStruct);
                }else{
                    push(@aryTXSuit,\%tmpStruct);
                }
            };
            my $pushValue=sub{
                my $name = shift;
                my $value = shift;
                my $flag = shift;
                if($flag){ #clear
                    my @tmpAry = ();
                    unless($value eq ""){
                        push(@tmpAry,$value);
                    }
                    $refStruct{$name} =\@tmpAry;
                }else{
                    unless($value eq ""){
                        my $ary = $refStruct{$name};
                        push(@$ary,$value);
                    }
                }
             
            };
            for my $idxRow (0..@csv){
                my @val = &$rmCmt($csv[$idxRow]);
                unless(&getCsvCol(@val)){ #next line
                    next;
                }
                if($val[0] eq "\$end"){
                    unless($trx eq ""){ # not first line
                        &$saveSuit(\%refStruct);
                    }
                    last;
                }
                unless($val[0] eq ""){
                    unless($trx eq ""){ # not first line
                        &$saveSuit(\%refStruct);
                    }
                    $trx = $val[0];
                    if($trx eq "RX"){
                        my $tmp = dclone(\%rxStruct);
                        %refStruct = %$tmp;
                        if(&getCsvCol(@val) != 6){
                            die "Col Error:",$idxRow;
                        }
                        $refStruct{band} =$val[1];
                        $refStruct{port} =$val[2];
                        $refStruct{bbPath}=$val[3];
                        $refStruct{pllSel}=$val[4];
                        $refStruct{inLoss}=$val[5];
                    }else{
                        my $tmp = dclone(\%txStruct);
                        %refStruct = %$tmp;
                        if(&getCsvCol(@val) != 4){
                            die "Col Error:",$idxRow;
                        }
                        $refStruct{stand}=$val[1];
                        $refStruct{band} =$val[2];
                        $refStruct{port} =$val[3];
                    }
                }else{
                    if($trx eq ""){
                        die "Missing Block definition before Col:",$idxRow;
                    }
                    if($trx eq "RX"){
                        unless($val[6] eq ""){
                            unless($refStruct{testType} eq ""){
                                &$saveSuit(\%refStruct);
                            }
                            $refStruct{testType} =$val[6];
                            $refStruct{burst}   =$val[7];

                            &$pushValue("stepType",$val[8],1);
                            &$pushValue("ifMode",$val[9],1);
                            &$pushValue("pow1",$val[10],1);
                            &$pushValue("pow2",$val[11],1);
                            &$pushValue("freq1",$val[12],1);
                            &$pushValue("freq2",$val[13],1);
                            &$pushValue("bbfreq",$val[14],1);
                            &$pushValue("gainReg",$val[15],1);

                        }else{
                            if($refStruct{testType}eq ""){
                                die "Missing TestType before Col:",$idxRow;
                            }
                            &$pushValue("stepType",$val[8],0);
                            &$pushValue("ifMode",$val[9],0);
                            &$pushValue("pow1",$val[10],0);
                            &$pushValue("pow2",$val[11],0);
                            &$pushValue("freq1",$val[12],0);
                            &$pushValue("freq2",$val[13],0);
                            &$pushValue("bbfreq",$val[14],0);
                            &$pushValue("gainReg",$val[15],0); 
                        }
                    }else{ # tx
                        unless($val[4] eq ""){
#                            if(&getCsvCol(@val) != 13){
#                                die "Col Error:",$idxRow;
#                            }
                            unless($refStruct{testType} eq ""){
                                &$saveSuit(\%refStruct);
                            }

                            $refStruct{testType} =$val[4];
                            $refStruct{inVrms}   =$val[5];
                            $refStruct{burst}    =$val[6];

                            &$pushValue("freqMode",$val[7],1);
                            &$pushValue("gainMode",$val[8],1);
                            &$pushValue("measPow",$val[9],1);
                            &$pushValue("freq",$val[10],1);
                            &$pushValue("bbfreq",$val[11],1);
                            &$pushValue("gainReg",$val[12],1);
     
                        }else{
#                            if(&getCsvCol(@val) != 13){
#                                die "Col Error:",$idxRow;
#                            }
                            if($refStruct{testType}eq ""){
                                die "Missing TestType before Col:",$idxRow;
                            }
                            &$pushValue("freqMode",$val[7],0);
                            &$pushValue("gainMode",$val[8],0);
                            &$pushValue("measPow",$val[9],0);
                            &$pushValue("freq",$val[10],0);
                            &$pushValue("bbfreq",$val[11],0);
                            &$pushValue("gainReg",$val[12],0);
                        }
                    }
                }
            }
        };
        #       &getSuit($rxtext);
        &getSuit(@text);
#        @aryTXSuit= &getSuit($srcSheet_TX,\@txStructInfo);
#        print "TXDone\n";
    };
#
    if($opt eq "h2csv"||$opt eq "h2csv_oldx4"){
           &wSpreadsheet();
    }else{
        #&rSpreadsheet($csvPathAry->[1]);
        map(&rSpreadsheet($_),@$csvPathAry);
    }
}







#system "pause\n";
