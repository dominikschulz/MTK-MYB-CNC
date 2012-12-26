package MTK::MYB::Cmd::Command::cnc;
# ABSTRACT: CNC Mysqlbackup command

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
use Linux::Pidfile;
use MTK::MYB::CNC;

# extends ...
extends 'MTK::MYB::Cmd::Command';
# has ...
has '_pidfile' => (
    'is'    => 'ro',
    'isa'   => 'Linux::Pidfile',
    'lazy'  => 1,
    'builder' => '_init_pidfile',
);
# with ...
# initializers ...
sub _init_pidfile {
    my $self = shift;

    my $PID = Linux::Pidfile::->new({
        'pidfile'   => $self->config()->get('MTK::MYB::Pidfile', { Default => '/var/run/myb.pid', }),
        'logger'    => $self->logger(),
    });

    return $PID;
}

# your code here ...
sub execute {
    my $self = shift;

    $self->_pidfile()->create() or die('Script already running.');

    my $MYB = MTK::MYB::CNC::->new({
        'config'    => $self->config(),
        'logger'    => $self->logger(),
    });

    my $status = $MYB->run();

    $self->_pidfile()->remove();

    return $status;
}

sub abstract {
    return 'Run the CNC variant of Mysqlbackup to perform remote backups';
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

MTK::MYB::Cmd::Command::cnc - CNC Mysqlbackup command

=method abstract

Workaround.

=method execute

Run the cnc backup.

=head1 ACKNOWLEDGEMENT

This module was originally developed for eGENTIC Systems. With approval from eGENTIC Systems,
this module was generalized and published, for which the authors would like to express their
gratitude.

=cut
