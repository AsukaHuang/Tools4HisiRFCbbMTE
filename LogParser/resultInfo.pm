#!/usr/bin/perl 
use 5.010;
package resultInfo;
sub new{
    my $class = shift;
    my $self = {
        _Site => shift,
        _TNum  => shift,
        _Test  => shift,
        _TestSuite  => shift,
        _p_f  => shift,
        _Pin  => shift,
        _LoLim  => shift,
        _Measure  => shift,
        _HiLim  => shift,
        _TestFunc  => shift,
        _VectLabel  => shift,
        #_mainAry  => [split(/,/ ,shift)], #@
    };
    bless $self, $class;
    #print "_pow1=",@{$self->{_pow1}},"\n";
    return $self;
}
sub get_subject {
    my( $self, $subject ) = @_;
    given( $subject ) {
            when('site'){return $self->{_Site};}
            when('TNum'){return $self->{_TNum};}
            when('Test'){return $self->{_Test};}
            when('TestSuite'){return $self->{_TestSuite};}
            when('p_f'){return $self->{_p_f};}
            when('Pin'){return $self->{_Pin};}
            when('LoLim'){return $self->{_LoLim};}
            when('Measure'){return $self->{_Measure};}
            when('HiLim'){return $self->{_HiLim};}
            when('TestFunc'){return $self->{_TestFunc};}
            when('VectLabel'){return $self->{_VectLabel};}
            default {die "Error Subject: $subject\n";}
    }
}
sub get_site {
    my( $self ) = @_;
    return $self->{_Site};
}
sub get_TNum {
    my( $self ) = @_;
    return $self->{_TNum};
}
sub get_Test {
    my( $self ) = @_;
    return $self->{_Test};
}
sub get_TestSuite {
    my( $self ) = @_;
    return $self->{_TestSuite};
}
sub get_pf {
    my( $self ) = @_;
    return $self->{_p_f};
}
sub get_Pin {
    my( $self ) = @_;
    return $self->{_Pin};
}
sub get_LoLim {
    my( $self ) = @_;
    return $self->{_LoLim};
}
sub get_Measure {
    my( $self ) = @_;
    return $self->{_Measure};
}
sub get_HiLim {
    my( $self ) = @_;
    return $self->{_HiLim};
}
sub get_TestFunc {
    my( $self ) = @_;
    return $self->{_TestFunc};
}
sub get_VectLabel {
    my( $self ) = @_;
    return $self->{_VectLabel};
}
#sub set_mainAry {
#    my( $self,$newAry) = @_;
#    #print @$newAry;
#    $self->{_VectLabel} = $newAry;
#}
#sub get_mainArySize {
#    my( $self ) = @_;
#    my $length = @{$self->{_mainAry}};
#    return $length;
#}
1;
