package MTK::MYB::CNC;
# ABSTRACT: MTK-MYB CNC implementation

use 5.010_000;
use mro 'c3';
use feature ':5.10';

use Moose;
use namespace::autoclean;

# use IO::Handle;
# use autodie;
# use MooseX::Params::Validate;

use Crypt::PasswdMD5 qw();
use Data::Dumper;
use Data::Pwgen;
use MTK::MYB::CNC::Job;

extends 'MTK::MYB';

has 'ftp_helper' => (
    'is'      => 'ro',
    'isa'     => 'Str',
    'default' => 'curl',
);

has 'ftp_port' => (
    'is'      => 'ro',
    'isa'     => 'Int',
    'lazy'    => 1,
    'builder' => '_init_ftp_port',
);

has 'ftp_uid' => (
    'is'      => 'ro',
    'isa'     => 'Int',
    'lazy'    => 1,
    'builder' => '_init_ftp_uid',
);

has 'ftp_gid' => (
    'is'      => 'ro',
    'isa'     => 'Int',
    'lazy'    => 1,
    'builder' => '_init_ftp_gid',
);

has 'tempdir' => (
    'is'      => 'ro',
    'isa'     => 'File::Temp::Dir',
    'lazy'    => 1,
    'builder' => '_init_tempdir',
);

sub _plugin_base_class { return ('MTK::MYB::Plugin','MTK::MYB::CNC::Plugin') }

sub _init_tempdir {
    my $self = shift;

    my $Dir = File::Temp::->newdir();

    if ( $self->debug() ) {
        $Dir->unlink_on_destroy(0);
    }

    return $Dir;
}

sub _init_ftp_uid {
    my $self = shift;

    # Try different UIDs until we find one that exists on this host:
    # - ftp-uid should be configured in the config
    # - 34 is the user 'backup'
    # - 1 is the user 'daemon',
    # - 0 is the user 'root',
    my @uids = ( $self->config()->get('MTK::MYB::CNC::ftp-uid'), 34, 1, 0 );
    foreach my $uid (@uids) {
        if ( getpwuid($uid) ) {
            return $uid;
        }
    }

    return 0;
}

sub _init_ftp_gid {
    my $self = shift;

    # Try differents GIDs until we find one that exists on this host:
    # - ftp-gid should be configured in the config
    # - 34 is the group 'backup',
    # - 1 is the group 'daemon',
    # - 0 is the group 'root',
    my @gids = ( $self->config()->get('MTK::MYB::CNC::ftp-gid'), 34, 1, 0 );
    foreach my $gid (@gids) {
        if ( getgrgid($gid) ) {
            return $gid;
        }
    }

    return 0;
}

sub type {
    return 'cnc';
}

sub _prepare {
    my $self = shift;

    $self->SUPER::_prepare()
      or return;
    $self->_stop_ftpd();
    $self->_start_ftpd();
    return 1;
}

sub _cleanup {
    my $self = shift;
    my $ok   = shift;

    if ( $self->debug() ) {
        $self->logger()->log( message => "DEBUG-MODE enabled. Sleeping for 180s before performing cleanup", level => 'debug', );
        sleep 180;
    }

    $self->SUPER::_cleanup($ok);
    $self->_stop_ftpd();

    return 1;
}

sub _get_backup_host {
    my $self = shift;
    my $dbms = shift;

    # host MUST NOT be taken from the default!
    return $self->config()->get( 'MTK::MYB::DBMS::' . $dbms . '::Hostname' );
}

sub _get_job {
    my $self  = shift;
    my $vault = shift;

    my $Job = MTK::MYB::CNC::Job::->new(
        {
            'parent' => $self,
            'vault'  => $vault,
            'logger' => $self->logger(),
            'config' => $self->config(),
            'bank'   => $self->bank(),
        }
    );

    return $Job;
}

sub _init_ftp_port {
    my $self = shift;

    my $ftp_port = $self->config()->get('MTK::MYB::CNC::FtpPort') || 2334;

    return $ftp_port;
}

=head2 PURE-FTPD OPTIONS

This section describes the pure-ftpd options use below.

=over 4

=item -d -d

Turns on debug logging including responses.

=item -S ,<PORT>

Bind to the specified port. The colon is important!

=item -f none

Disable syslog logging. We use our own logfile for that.

=item -j

Auto-create any missing home directories.

=item -z

Allow access to hidden files.

=item -B

Daemonize

=item -H

Don't resolve host names.

=item -4

Use IPv4 only.

=item -c 250

Limit to 250 simultaneous clients.

=item -k 98

Disable uploads if the partition is more than 98% full.

=item -Y 0

Disable all TLS features.

=item -O clf:<LOGFILE>

Enable CLF-style logging to <LOGFILE>.

=item -l puredb:<PDBFILE>

Enable native PureDB authentication from <PDBFILE>.

=back

=cut

sub _start_ftpd {
    my $self = shift;

    my $cleanup = 1;
    if ( $self->debug() ) {
        $cleanup = 0;
    }

    my $tempdir = $self->tempdir()->dirname();

    my $passwdfile = $tempdir . '/pureftpd.passwd';
    if ( $self->_create_pdb($passwdfile) ) {
        $self->logger()->log( message => "Created password-db at $passwdfile", level => 'debug', );
    }
    else {
        $self->logger()->log( message => "Could not create password-db at $passwdfile", level => 'warning', );
        return;
    }

    my $ftp_port = $self->ftp_port();

    my $cmd = "/usr/sbin/pure-ftpd";
    if ( $self->debug() ) {
        $cmd .= " -d -d";
    }
    $cmd .= " -S ,$ftp_port -f none -j -z -B -H -4 -c 250 -k 98 -Y 0 -O clf:$tempdir/ftpd-transfer.log -l puredb:$tempdir/pureftpd.pdb";

    if ( $self->sys()->run_cmd($cmd) ) {
        $self->logger()->log( message => "pure-ftpd started w/ cmd: $cmd", level => 'debug', );
        sleep 15 if $self->config()->get('MTK::MYB::Debug');
        return 1;
    }
    else {
        $self->logger()->log( message => "pure-ftpd failed to start w/ cmd: $cmd", level => 'warning', );
        sleep 15 if $self->config()->get('MTK::MYB::Debug');
        return;
    }
}

#
sub _stash_xfer_log {
    my $self = shift;

    my $tempdir = $self->tempdir()->dirname();

    my $logfile = $tempdir . '/ftpd-transfer.log';
    if ( -e $logfile ) {
        my $target = '/var/log/mysqlbackup-cnc-xfer.log';
        my $cmd    = "cat $logfile >> $target";
        if ( $self->sys()->run_cmd($cmd) ) {
            $self->logger()->log( message => 'Saved pure-ftpd transfer log to ' . $target, level => 'debug', );
        }
        else {
            $self->logger()->log( message => 'Failed to save pure-ftpd transfer log to ' . $target, level => 'error', );
        }
    }
    else {
        $self->logger()->log( message => 'No pure-ftpd transfer log found at ' . $logfile, level => 'notice', );
    }

    my $pdb = $tempdir . '/pureftpd.pdb';
    if ( $self->debug() && -e $pdb ) {
        my $target = '/var/log/mysqlbackup-cnc-pdb-' . time() . '.log';
        my $cmd    = "mv $pdb $target";
        if ( $self->sys()->run_cmd($cmd) ) {
            $self->logger()->log( message => 'Saved pure-ftpd pdb to ' . $target, level => 'debug', );
        }
        else {
            $self->logger()->log( message => 'Failed to save pure-ftpd pdb to ' . $target, level => 'debug', );
        }
    }
    else {
        $self->logger()->log( message => 'Not in debug mode or no pure-ftpd pdb found at ' . $pdb, level => 'debug', );
    }

    return 1;
}

sub _stop_ftpd {
    my $self = shift;

    my ( $cmd, $pid );

    my $ftp_port = $self->ftp_port();

    $cmd = "netstat -nlp | grep pure-ftp | grep \":$ftp_port\" | grep -v grep | awk '{ print \$7; }' | cut -d'/' -f1";
    $self->logger()->log( message => "CMD: $cmd", level => 'debug', );
    $pid = $self->sys()->run_cmd( $cmd, { Chomp => 1, CaptureOutput => 1, } );
    if ( $pid && $pid =~ m/^\s*\d+\s*$/ ) {
        $cmd = "kill $pid >/dev/null 2>&1";
        $self->logger()->log( message => "CMD: $cmd", level => 'debug', );
        $self->sys()->run_cmd($cmd);
        $cmd = "kill -9 $pid >/dev/null 2>&1";
        $self->logger()->log( message => "CMD: $cmd", level => 'debug', );
        $self->sys()->run_cmd($cmd);
    }
    else {
        $self->logger()->log( message => "stop_ftpd - no valid pid found: $pid", level => 'notice', );
    }

    $cmd = "ps aux | grep pure-ftp | grep -v grep | awk '{ print \$2; }'";
    $self->logger()->log( message => "CMD: $cmd", level => 'debug', );
    $self->sys()->run_cmd( $cmd, { Chomp => 1, CaptureOutput => 1, } );

    $self->_stash_xfer_log();

    if ( $pid && $pid =~ m/^\s*\d+\s*$/ ) {
        $cmd = "kill $pid >/dev/null 2>&1";
        $self->logger()->log( message => "CMD: $cmd", level => 'debug', );
        $self->sys()->run_cmd($cmd);
        $cmd = "kill -9 $pid >/dev/null 2>&1";
        $self->logger()->log( message => "CMD: $cmd", level => 'debug', );
        $self->sys()->run_cmd($cmd);
        return 1;
    }
    else {
        $self->logger()->log( message => "stop_ftpd - no valid pid found: $pid", level => 'notice', );
        return;
    }
}

# create pure-db
sub _create_pdb {
    my $self       = shift;
    my $passwdfile = shift;

    my $dbms_ref = $self->config()->get('MTK::MYB::DBMS');

    if(!$dbms_ref || ref($dbms_ref) ne 'HASH') {
        $self->logger()->log( message => 'No DBMS found!', level => 'error', );
        return;
    }

    # DGR: Well, this is brief enough ;)
    ## no critic (RequireBriefOpen)
    if ( open( my $FH, ">", $passwdfile ) ) {
        my $ftp_uid = $self->ftp_uid();
        my $ftp_gid = $self->ftp_gid();

        # create a individual login for each instance
        foreach my $instance ( sort keys %{ $dbms_ref } ) {
            my $salt     = &Data::Pwgen::pwgen( 6,  'alphanum' );
            my $password = &Data::Pwgen::pwgen( 12, 'alphanum' );
            $self->config()->set( 'MTK::MYB::DBMS::' . $instance . '::Password', $password );
            my $crypt = Crypt::PasswdMD5::unix_md5_crypt( $password, $salt );
            my $datadir =
              $self->fs()->makedir( $self->fs()->filename( ( $self->bank(), $instance, 'daily', 'inprogress' ) ), { Uid => $ftp_uid, Gid => $ftp_gid } );

            #my $entry = $instance . ':' . $crypt . ':' . $ftp_uid . ':' . $ftp_gid . '::' . $datadir . '/' . $instance . '::::::::::::' . "\n";
            my $entry = $instance . ':' . $crypt . ':' . $ftp_uid . ':' . $ftp_gid . '::' . $datadir . '::::::::::::' . "\n";
            if ( print $FH $entry ) {
                $self->logger()->log( message => "Passwd-Entry: $entry - l/p: $instance/$password", level => 'debug', );
            }
            else {
                $self->logger()->log( message => "Could not write Passwd-Entry $entry to passwd-file $passwdfile", level => 'warning', );
            }
        }

        if ( !close($FH) ) {
            $self->logger()->log( message => "Could not close file $passwdfile", level => 'debug', );
        }
        ## use critic

        my $pdbfile = $passwdfile;
        $pdbfile =~ s/\.passwd$/.pdb/;
        my $cmd = "/usr/bin/pure-pw mkdb $pdbfile -f $passwdfile";

        if ( $self->sys()->run_cmd($cmd) ) {
            $self->logger()->log( message => "ok mkdb w/ CMD: $cmd", level => 'debug', );
            return 1;
        }
        else {
            $self->logger()->log( message => "failed mkdb w/ CMD: $cmd", level => 3 );
            return;
        }
    }
    else {
        $self->logger()->log( message => "Could not open passwdfile at $passwdfile for writing: $!", level => 'alert' );
        return;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

MTK::MYB::CNC - CNC implementation of mysqlbackup

=head1 RISKS

This section is included to help users of this tool to assess the risk associated
with using this tool. The two main categories adressed are those created the idea
implemented and those created by bugs. There may be other risks as well.

B<myb cnc> is mostly a read-only tool that will, however, lock your database server
for the duration of the backup. This will cause service interruptions as long as
you don't take precautions. Either point the script to an dedicated slave or
chose an idle time for running it.

=head1 SEE ALSO

L<MySQL Backup> may be better suited if you plan to back up only a small number
of hosts.

L<Percona XtraBackup|http://www.percona.com/software/percona-xtrabackup> is an
advanced approach for backing up InnoDB and XtraDB tables. It does provide little
advantage in terms of MyISAM backups.

L<Holland Backup|http://wiki.hollandbackup.org/> is an multi-db application
written in Python.

=method type

Always returns cnc.

=head1 ACKNOWLEDGEMENT

This module was originally developed for eGENTIC Systems. With approval from eGENTIC Systems,
this module was generalized and published, for which the authors would like to express their
gratitude.

=cut
