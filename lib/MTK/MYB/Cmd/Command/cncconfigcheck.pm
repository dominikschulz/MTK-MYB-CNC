package MTK::MYB::Cmd::Command::cncconfigcheck;
# ABSTRACT: cnc mysqlbackup config check

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
use MTK::MYB::CNC;

# extends ...
extends 'MTK::MYB::Cmd::Command::configcheck';
# has ...
# with ...
# initializers ...
sub _init_myb {
    my $self = shift;

    my $MYB = MTK::MYB::CNC::->new({
        'config'    => $self->config(),
        'logger'    => $self->logger(),
    });

    return $MYB;
}

# your code here ...
sub _check_basics {
    my $self = shift;

    # do we actually do some backups?
    my $dump_table = $self->myb()->config()->get('MTK::MYB::DumpTable');
    my $copy_table = $self->myb()->config()->get('MTK::MYB::CopyTable');

    if(!$dump_table && !$copy_table) {
        say 'ERROR - DumpTable and CopyTable set to false. Not doing any backups!';
        return;
    }

    my $ftpsrv = $self->myb()->config()->get('MTK::MYB::CNC::serveraddress');
    my $ftpuid = $self->myb()->config()->get('MTK::MYB::CNC::ftp-uid');
    my $ftpgid = $self->myb()->config()->get('MTK::MYB::CNC::ftp-gid');
    my $ftpprt = $self->myb()->config()->get('MTK::MYB::CNC::ftp-gid');

    if($ftpsrv) {
        if($ftpsrv =~ m/^\d+\.\d+\.\d+\.\d+$/ || $ftpsrv =~ m/^[0-9a-f:]+$/) {
            say 'OK - ServerAddress defined: '.$ftpsrv;
        } else {
            say 'ERROR - ServerAddress is no valid IPv4 or IPv6 address: '.$ftpsrv;
            return;
        }
    } else {
        say 'ERROR - No FTP server address defined!';
        return;
    }

    if(!$ftpuid) {
        say 'ERROR - No FTP server UID defined!';
        return;
    }

    if(!$ftpgid) {
        say 'ERROR - No FTP server GID defined!';
        return;
    }

    if(!$ftpprt || $ftpprt !~ m/^\d+$/ || $ftpprt < 1 || $ftpprt > 65534) {
        say 'ERROR - No valid FTP port defined!';
        return;
    }

    return 1;
}

sub _check_dbms_ssh_connection {
    my $self = shift;
    my $dbms = shift;

    my $hostname = $self->config()->get( 'MTK::MYB::DBMS::' . $dbms . '::Hostname' );

    if ( $self->myb()->sys()->run_remote_cmd( $hostname, '/bin/true' ) ) {
        return 1;
    } else {
        return;
    }
}

sub _check_dbms_ftp {
    my $self = shift;
    my $dbms = shift;

    my $hostname = $self->config()->get( 'MTK::MYB::DBMS::' . $dbms . '::Hostname' );

    # check ftp binary via ssh
    my $rv = $self->myb()->sys()->run_remote_cmd( $hostname, '/usr/bin/curl --help', { ReturnRV => 1, } );
    if ( defined($rv) && $rv == 0 ) {
        return 1;
    }
    else {
        return;
    }
}

sub _check_dbms {
    my $self = shift;
    my $dbms = shift;

    my $hostname = $self->config()->get( 'MTK::MYB::DBMS::' . $dbms . '::Hostname' );

    # check db connection
    if($self->_check_dbms_dbh_connection($dbms)) {
        say ' OK - DBH connection working for '.$dbms;
    } else {
        say ' ERROR - DBH connection failed! Check connection credentials for '.$dbms;
        return;
    }

    # check if pw-less ssh access works
    if($self->_check_dbms_ssh_connection($dbms)) {
        say ' OK - SSH access working to '.$dbms;
    } else {
        say ' ERROR - SSH access failed! Check your public key setup for '.$dbms;
        say '  HINT: ssh-copy-id -i '.$hostname;
        return;
    }

    # check ftp binary via ssh (can't check connection w/o ftp server ...)
    if($self->_check_dbms_ftp($dbms)) {
        say ' OK - FTP binary found on '.$dbms;
    } else {
        say ' ERROR - FTP binary not found on '.$dbms;
        say q{  HINT: ssh }.$hostname.q{ 'apt-get install curl'};
        return;
    }

    return 1;
}

sub _dbms_list {
    my $self = shift;
    my $dbms_ref = $self->myb()->config()->get('MTK::MYB::DBMS');

    # we do not want localhost as an DBMS for CNC
    if($dbms_ref && ref($dbms_ref) eq 'HASH') {
        delete $dbms_ref->{'localhost'};
    }

    return $dbms_ref;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

MTK::MYB::Cmd::Command::cncconfigcheck - cnc mysqlbackup config check

=method abstract

A descrition of this command.

=method execute

Run this command.

=head1 ACKNOWLEDGEMENT

This module was originally developed for eGENTIC Systems. With approval from eGENTIC Systems,
this module was generalized and published, for which the authors would like to express their
gratitude.

=cut
