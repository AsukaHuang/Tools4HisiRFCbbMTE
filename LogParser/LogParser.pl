#	#/usr/bin/perl -w
#
#	The use of this perl file is:
#
#
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

my $version = "0.1.0";

#use suitRXInfo;

$::RD_HINT = 1;
$::RD_WARN = 1;
$::RD_ERRORS = 1;
#
use resultInfo;
#
sub usage {
    print "*************** COMMAND SYNTAX ERROR ******************************\n";
    print "    Not enough argument\n";
    print "    Usage\n";
    print "  	logFileFolder excelFileName \n";
    print "*******************************************************************\n\n";
}
our $DEBUG_PARSER = 0;
my %logHash;
my $removeName = ""; 
my $counterParse=1;
my $LogFileNumber=0;
{
    my $argc = @ARGV; 
    if ($argc < 2) {
        usage();
        exit(1);
    }
    my ($logPath,$excelFile) = @ARGV;
    my $tempPath = $logPath;
    $tempPath =~ s/\\Import\\/\\temp\\/;
    if(!(-e $tempPath)){ mkdir $tempPath or die;}
    my @loglist = glob "$logPath*.edf";
    $LogFileNumber = @loglist;
    print "Parsing Start, please wait\n";
    my @csvAry = map{&parseLog($_)} @loglist;
    $excelFile = getcwd()."\\".$excelFile;
    $excelFile =~ s/\//\\/g;
    &assembleCSV($excelFile,$logPath);
}
sub parseLog{
    my $fileName = shift;
    my $key = "";
    unless(/$removeName(\S+)\.edf$/){ die "Error Log name get: $fileName\n";}
    else{$key=$1;}
    my $text = read_file($fileName);
    unless($text =~ /(Testflow started on\s*.*?\s*Testflow ended)/s){
        die "No tbody block!\n";
    }else{
        my $block_text = $1;
        my $grammar = read_file("log.prd");
        my $parser = Parse::RecDescent->new($grammar);
        my $tree = $parser->bodySession($block_text);
        unless ($tree) {    
            print STDERR "Error: unable to parse Log!\n";
            die;
        }
        if ($DEBUG_PARSER) {
            print Dumper($tree);
        }
        my $analyze_tree = ();
        $analyze_tree = sub {
            my ($t, $flag) = @_;
            my @logAry;
            $flag //= "";
            for my $statement (@$t) {    ## first level
                if($statement =~ /^(0|1)$/){next;}
                for my $resultblock (@$statement) {    ## first level
                    push @logAry, new resultInfo($resultblock->{site},
                                $resultblock->{TNum},
                                $resultblock->{Test},
                                $resultblock->{TestSuite},
                                $resultblock->{p_f},
                                $resultblock->{Pin},
                                $resultblock->{LoLim},
                                $resultblock->{Measure},
                                $resultblock->{HiLim},
                                $resultblock->{TestFunc},
                                $resultblock->{VectLabel});
                }

            }
            print "parse $counterParse/$LogFileNumber: $key done\n";
            $counterParse++;
            return \@logAry;
        };
        $logHash{$key}=&$analyze_tree($tree, "");
        return &genMeas($fileName,$key);
    }
}
sub genMeas {
    my $filename = shift;
    my $key = shift;
    $filename =~ s/edf$/csv/;
    $filename =~ s/\\Import\\/\\temp\\/;
    my $pureFileName ="";
    if($key =~ /\\(\w+)$/){
        $pureFileName = $1;
    }else{
        $pureFileName = $key;
    }
    my $str="$pureFileName,\n";
    map{$str.=($_->get_subject('Measure')).",\n"}@{$logHash{$key}};
    open(TESTITEMS, ">$filename") or die ("unable to write $filename\n");
    print TESTITEMS $str;
    close(TESTITEMS);
    return $filename;
}
sub assembleCSV {
    my ($excelFile,$csvPath) = @_;
    $csvPath =~ s/\\Import\\/\\temp\\/;
    my @csvlist = glob "$csvPath*.csv";
    for my $file (@csvlist) {
        unless ($file =~ /\.csv$/) {
            die "$file is not xls or csv file\n";
        }
    }
    my $excel = Win32::OLE->new('Excel.Application', 'Quit');   
    $excel->{DisplayAlerts} = 'False';  
    my $target_book = $excel->Workbooks->Add;               # open new file
    my $counter = 0;
    for my $csvfile (@csvlist) {
        my $filename = abs_path($csvfile);
        $filename =~/\/$removeName(\w+)\.csv$/;
        my $sheet_names=$1;

        my $book = $excel->Workbooks->Open($filename, 0, 'True');

        for (my $num = 1; $num <= $book->Worksheets->Count; $num++) {
            $counter ++;; 
            $book->Worksheets($num)->Copy($target_book->Worksheets($counter));

#        my $new_sheet = "";
#        if ($xlsfile =~ /\.xls$/) {
#            $new_sheet = $bookname."\.".$sheetname;
#        } else {    ## csv
#            $new_sheet = $bookname;
#        }
#        $target_book->Worksheets($counter) ->{Name} = $new_sheet;

            $target_book->Worksheets($counter) ->{Name} = $sheet_names;
        }
        $book->Close;
    } # for
    for my $i (1,2,3) {
        $target_book->Worksheets($counter+1)->Delete;       # delete 3 default empty sheets
    }
    $target_book->Worksheets->Add({before => $target_book->Worksheets(1)});
    $target_book->Worksheets(1) ->{Name} = "Summary";
    $counter ++; 


    my $colitr =1;
    my $rowRange=0;

    my $writeCol=sub{
        my $key = shift;
        my $targetName = shift;
        $target_book->Worksheets("Summary")->Cells(1,$colitr)->{'Value'}=$targetName;
        my $rowitr=2;
        for my $itrResult (@{$logHash{$key}}){
            $target_book->Worksheets("Summary")->Cells($rowitr,$colitr)->{'Value'}=$itrResult->get_subject($targetName);
            $rowitr++;
        }
        return $rowitr;
    };
    for my $key(sort keys %logHash){
        &$writeCol($key,'site'); $colitr++;
        &$writeCol($key,'TNum'); $colitr++;
        &$writeCol($key,'Test'); $colitr++;
        &$writeCol($key,'TestSuite'); $colitr++;
        &$writeCol($key,'p_f'); $colitr++;
        &$writeCol($key,'Pin'); $colitr++;
        &$writeCol($key,'TestFunc'); $colitr++;
        &$writeCol($key,'VectLabel'); $colitr++;
        &$writeCol($key,'LoLim'); $colitr++;
        $rowRange = &$writeCol($key,'HiLim'); $colitr++;
        last;
    }
    for(my $i=2;$i<=$counter;$i++){
            $target_book->Worksheets(2)->Columns(1)->Copy($target_book->Worksheets("Summary")->Columns($colitr++));
            $target_book->Worksheets(2)->Delete;       # delete 3 default empty sheets
    }


    $target_book->SaveAs($excelFile);
    $target_book->Close;
    print "Assemble done\n";
}


