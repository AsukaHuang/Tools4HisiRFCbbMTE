#!/usr/bin/perl 
package flowInfo;
sub new{
    my $class = shift;
    my $self = {
        _testsuit => shift,
        _flowNo => shift,
        _burst=> shift,
        _sheet=> "",
        _cell=> 0,
    };
    bless $self, $class;
    return $self;
}
sub get_flowNo {
    my( $self ) = @_;
    return $self->{_flowNo};
}
sub get_suitName {
    my( $self ) = @_;
    return $self->{_testsuit};
}
sub get_burstName {
    my( $self ) = @_;
    return $self->{_burst};
}
sub get_sheet {
    my( $self ) = @_;
    return $self->{_sheet};
}
sub get_cell {
    my( $self ) = @_;
    return $self->{_cell};
}
sub set_sheet {
    my( $self,$sheet) = @_;
    $self->{_sheet} = $sheet;
}
sub set_cell {
    my( $self,$cell) = @_;
    $self->{_cell} = $cell;
}
1;
