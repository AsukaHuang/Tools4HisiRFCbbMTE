#!/usr/bin/perl 
package vecInfo;
sub new{
    my $class = shift;
    my $self = {
        _burstName => shift,
        _mainAry  => shift, #@
        #_mainAry  => [split(/,/ ,shift)], #@
    };
    bless $self, $class;
    #print "_pow1=",@{$self->{_pow1}},"\n";
    return $self;
}
sub get_burstName {
    my( $self ) = @_;
    return $self->{_burstName};
}
sub get_mainAry {
    my( $self ) = @_;
    return @{$self->{_mainAry}};
}
sub set_mainAry {
    my( $self,$newAry) = @_;
    #print @$newAry;
    $self->{_mainAry} = $newAry;
}
sub get_mainArySize {
    my( $self ) = @_;
    my $length = @{$self->{_mainAry}};
    return $length;
}
1;
