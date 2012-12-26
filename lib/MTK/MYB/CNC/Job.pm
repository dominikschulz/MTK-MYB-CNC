package MTK::MYB::CNC::Job;
# ABSTRACT: MTK CNC MYB job

use 5.010_000;
use mro 'c3';
use feature ':5.10';

use Moose;
use namespace::autoclean;

# use IO::Handle;
# use autodie;
# use MooseX::Params::Validate;
# use Carp;
# use English qw( -no_match_vars );
# use Try::Tiny;

use MTK::MYB::CNC::Worker;

extends 'MTK::MYB::Job';

# has ...
# with ...
# initializers ...

sub _init_worker {
    my $self = shift;

    my $Worker = MTK::MYB::CNC::Worker::->new(
        {
            'config'  => $self->config(),
            'logger'  => $self->logger(),
            'parent'  => $self->parent(),
            'verbose' => $self->verbose(),
            'dry'     => $self->dry(),
            'bank'    => $self->bank(),
            'vault'   => $self->vault(),
        }
    );

    return $Worker;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

MTK::MYB::CNC::Job - MTK CNC MYB job

=head1 ACKNOWLEDGEMENT

This module was originally developed for eGENTIC Systems. With approval from eGENTIC Systems,
this module was generalized and published, for which the authors would like to express their
gratitude.

=cut
