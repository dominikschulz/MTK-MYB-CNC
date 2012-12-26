package MTK::MYB::CNC::Worker;
# ABSTRACT: CNC MYB worker

use 5.010_000;
use mro 'c3';
use feature ':5.10';

use Moose;
use namespace::autoclean;

# use IO::Handle;
# use autodie;
# use MooseX::Params::Validate;

use MTK::MYB::Codes;

extends 'MTK::MYB::Worker';

has 'curl_exitcodes' => (
    'is'      => 'ro',
    'isa'     => 'HashRef',
    'lazy'    => 1,
    'builder' => '_init_curl_exitcodes',
);

sub _init_curl_exitcodes {
    my $self = shift;

    my %codes = (
        0 => 'OK',
        1 => 'Unsupported protocol. This build of curl has no support for this protocol.',
        2 => 'Failed to initialize.',
        3 => 'URL malformed. The syntax was not correct.',
        5 => "Couldn't resolve proxy.  The  given  proxy  host  could  not  be resolved.",
        6 => "Couldn't resolve host. The given remote host was not resolved.",
        7 => 'Failed to connect to host.',
        8 => "FTP  weird  server  reply.  The  server  sent data curl couldn't parse.",
        9 =>
"FTP access denied. The server denied login or denied  access  to the  particular  resource or directory you wanted to reach. Most often you tried to change to a directory that doesn't  exist  on the server.",
        11 => "FTP  weird PASS reply. Curl couldn't parse the reply sent to the PASS request.",
        13 => "FTP weird PASV reply, Curl couldn't parse the reply sent to  the PASV request.",
        14 => "FTP  weird  227  format.  Curl  couldn't  parse the 227-line the server sent.",
        15 => "FTP can't get host. Couldn't resolve the host IP we got  in  the 227-line.",
        17 => "FTP  couldn't  set  binary.  Couldn't  change transfer method to binary.",
        18 => "Partial file. Only a part of the file was transferred.",
        19 => "FTP couldn't download/access the given file, the RETR (or  simi‐lar) command failed.",
        21 => "FTP quote error. A quote command returned error from the server.",
        22 =>
"HTTP  page  not  retrieved.  The  requested url was not found or returned another error with the HTTP error  code  being  400  or above. This return code only appears if -f/--fail is used.",
        23 => "Write  error.  Curl couldn't write data to a local filesystem or similar.",
        25 => "FTP couldn't STOR file. The server denied  the  STOR  operation, used for FTP uploading.",
        26 => "Read error. Various reading problems.",
        27 => "Out of memory. A memory allocation request failed.",
        28 => "Operation  timeout.  The  specified  time-out period was reached according to the conditions.",
        30 => "FTP PORT failed. The PORT command failed. Not  all  FTP  servers support  the  PORT  command,  try  doing  a  transfer using PASV instead!",
        31 => "FTP couldn't use REST. The REST command failed. This command  is used for resumed FTP transfers.",
        33 => "HTTP range error. The range 'command' didn't work.",
        34 => "HTTP post error. Internal post-request generation error.",
        35 => "SSL connect error. The SSL handshaking failed.",
        36 => "FTP  bad  download  resume. Couldn't continue an earlier aborted download.",
        37 => "FILE couldn't read file. Failed to open the file. Permissions?",
        38 => "LDAP cannot bind. LDAP bind operation failed.",
        39 => "LDAP search failed.",
        41 => "Function not found. A required LDAP function was not found.",
        42 => "Aborted by callback. An application told curl to abort the oper‐ation.",
        43 => "Internal error. A function was called with a bad parameter.",
        45 => "Interface  error.  A  specified  outgoing interface could not be used.",
        47 => "Too many redirects. When following redirects, curl hit the maxi‐mum amount.",
        48 => "Unknown TELNET option specified.",
        49 => "Malformed telnet option.",
        51 => "The peer's SSL certificate or SSH MD5 fingerprint was not ok.",
        52 => "The  server  didn't  reply anything, which here is considered an error.",
        53 => "SSL crypto engine not found.",
        54 => "Cannot set SSL crypto engine as default.",
        55 => "Failed sending network data.",
        56 => "Failure in receiving network data.",
        58 => "Problem with the local certificate.",
        59 => "Couldn't use specified SSL cipher.",
        60 => "Peer certificate cannot be authenticated with known CA  certifi‐cates.",
        61 => "Unrecognized transfer encoding.",
        62 => "Invalid LDAP URL.",
        63 => "Maximum file size exceeded.",
        64 => "Requested FTP SSL level failed.",
        65 => "Sending the data requires a rewind that failed.",
        66 => "Failed to initialise SSL Engine.",
        67 => "The  user  name, password, or similar was not accepted and curl failed to log in.",
        68 => "File not found on TFTP server.",
        69 => "Permission problem on TFTP server.",
        70 => "Out of disk space on TFTP server.",
        71 => "Illegal TFTP operation.",
        72 => "Unknown TFTP transfer ID.",
        73 => "File already exists (TFTP).",
        74 => "No such user (TFTP).",
        75 => "Character conversion failed.",
        76 => "Character conversion functions required.",
        77 => "Problem with reading the SSL CA cert (path? access rights?).",
        78 => "The resource referenced in the URL does not exist.",
        79 => "An unspecified error occurred during the SSH session.",
        80 => "Failed to shut down the SSL connection.",
        82 => "Could not load CRL file,  missing  or  wrong  format.",
        83 => "Issuer check failed",
    );

    return \%codes;
}

sub uid {
    my $self = shift;

    return $self->parent()->ftp_uid();
}

sub gid {
    my $self = shift;

    return $self->parent()->ftp_gid();
}

sub type {
    return 'cnc';
}

sub _prepare {
    my $self = shift;
    my $host = shift;
    my $dbms = shift;

    # turn of ssh host key checking
    $self->sys()->ssh_hostkey_check(0);

    my $server_address = $self->config()->get_scalar('MTK::MYB::CNC::ServerAddress');

    if ( !$server_address ) {
        $self->logger()->log(
            message =>
              'No server address given. You need to set THIS hosts external (wrt. your backup nodes) address to the key MTK::MYB::CNC::ServerAddress',
            level => 'error',
        );
        return;
    }

    if ( !$host ) {
        $self->logger()->log( message => "No host given! Impossible to continue.", level => 'error', );
        return;
    }

    if ( !$dbms ) {
        $self->logger()->log( message => "No dbms given! Impossible to continue.", level => 'error', );
        return;
    }

    # check if pw-less ssh access works
    if ( !$self->sys()->run_remote_cmd( $host, '/bin/true' ) ) {

        # report an error is pw-less ssh access does not work
        my $msg = 'Password-less SSH access to ' . $host . ' does not work. Public Keys setup ok? Aborting!';
        $self->logger()->log( message => $msg, level => 'error', );
        $self->status()->global( MTK::MYB::Codes::get_status_code('SSH-ERROR') );
        $self->_report();
        return;
    }
    else {
        $self->logger()->log( message => 'Password-less SSH access to '.$host.' is OK', level => 'debug', );
    }

    # check ftp connection via ssh
    # lftp -u $dbms,$config->{$dbms}{'ftp-password'} $config->{'default'}{'server-address'} -e "quit"
    my $rv = $self->sys()->run_remote_cmd( $host, $self->_get_ftp_cmd_test($dbms), { ReturnRV => 1, } );
    if ( defined($rv) && $rv == 0 ) {
        $self->logger()->log( message => 'FTP access from ' . $host . ' is OK', level => 'debug', );
    }
    else {

        # report an error if ftp-access from client does not work
        my $addn_error_msg = '';
        if ( $self->parent()->ftp_helper() eq 'curl' ) {
            my $error_msg = $self->curl_exitcodes()->{$rv} || 'n/a';
            $addn_error_msg = 'Curl exited with Code ' . $rv . ' which means: "' . $error_msg . '". ';
        }
        my $msg = 'FTP access from ' . $host . ' to ' . $server_address . ' does not work. ' . $addn_error_msg . ' Is lftp/curl installed? Aborting!';
        $self->logger()->log( message => $msg, level => 'error', );
        $self->status()->global( MTK::MYB::Codes::get_status_code('FTP-ERROR') );
        $self->_report();
        return;
    }

    return 1;
}

sub _binlog_archive {
    my $self = shift;

    my $host = $self->hostname();
    $self->logger()->log( message => 'binlog_archive processing '.$host, level => 'debug', );

    # Create final archive destination
    my $local_archive_dir = $self->dir_binlogs();

    # Create temporary transfer destination
    my $local_copy_dir = $self->fs()->makedir( $self->fs()->filename( $self->dir_progress(), 'binlogs' ), { Uid => $self->uid(), Gid => $self->gid(), } );

    # The binlogs must first be copied to the inprogress dir - since only this
    # directory is being exported by the ftpd - and the copied
    # to their final destination.

    # get remote log-bin setting
    my $cmd = 'egrep "log(_|-)bin" /etc/mysql/my.cnf | cut -d"=" -f2';
    my $remote_log_bin = $self->sys()->run_remote_cmd( $host, $cmd, { CaptureOutput => 1, Chomp => 1, } );
    my $remote_source_dir = File::Basename::dirname($remote_log_bin);

    # default = 10 years
    my $holdbacktime_binlog = $self->config()->get('MTK::MYB::Rotations::Binlogs') || 3650;

    if ($remote_source_dir) {
        $self->logger()->log( message => 'Using Remote Binlog Source Directory :' . $remote_source_dir, level => 'debug', );
    }
    else {
        $self->logger()->log( message => 'Remote Binlog Source Directory not set! Returning.', level => 'error', );
        return;
    }

    # make sure the temporary copy directory is defined and exists
    if ( $local_copy_dir && -d $local_copy_dir && $local_copy_dir ne '/' ) {
        $self->logger()->log( message => 'Using local copy directory: ' . $local_copy_dir, level => 'debug', );
    }
    else {
        $local_copy_dir ||= '';    # prevents an undefinedness warning
        $self->logger()->log( message => 'Local copy directory not defined or not accessible: ' . $local_copy_dir, level => 'error', );
        return;
    }

    # make sure the final archive destination exists
    if ( $local_archive_dir && -d $local_archive_dir ) {
        $self->logger()->log( message => 'Using local archive directory: ' . $local_archive_dir, level => 'debug', );
    }
    else {
        $local_archive_dir ||= '';    # prevents an undefinedness warning
        $self->logger()->log( message => 'Local archive driectory not defined or not accessible: ' . $local_archive_dir, level => 'error', );
        return;
    }

    my ( $sec, $min, $hour, $dayofmonth, $month, $year, $dayofweek, $dayofyear, $summertime ) = localtime(time);
    $year += 1900;
    $month++;

    # Remove old (expired) archived binlogs [local]
    foreach my $file ( glob( $local_archive_dir . '/mysql-bin.*' ) ) {
        $self->logger()->log( message => 'Binlogarchive-Expire - File '.$file.' is ' . sprintf( '%.2f', -M $file ) . ' days old.', level => 'debug', );
        if ( -M $file > $holdbacktime_binlog ) {
            $self->logger()->log(
                message => 'Binlogarchive-Expire - File ' . $file . ' is too ' . sprintf( '%.2f', -M $file ) . ' old. Removing.',
                level   => 'debug',
            );
            $cmd = 'rm -f '.$file;
            $self->logger()->log( message => $cmd, level => 'debug', );
            $self->sys()->run_cmd($cmd) unless $self->dry();
        }
    }

    # Archive new binlogs [remote]
    if ( $remote_source_dir && $remote_source_dir ne q{/} ) {
        $self->logger()->log( message => 'Continuing w/ remote binlog search path '.$remote_source_dir, level => 'debug', );
    }
    else {
        $self->logger()->log( message => 'Invalid remote binlog search path: '.$remote_source_dir, level => 'error', );
        return;
    }

    $cmd = 'find ' . $remote_source_dir . ' -type f -name "mysql-bin.*"';
    my $out = $self->sys()->run_remote_cmd( $host, $cmd, { CaptureOutput => 1, Timeout => 1200, Chomp => 1, } );

    $out ||= '';    # prevent definedness warnings
    foreach my $binlog_file ( split /\n/, $out ) {
        $self->logger()->log( message => 'Examining Binlog File: ' . $binlog_file, level => 'debug', );

        my @srcpath = split /\//, $binlog_file;
        my $dst = $srcpath[-1] . $self->packer()->ext();
        if ( !-e $dst || -M $dst < 1 ) {
            if ( !-e $dst ) {
                $self->logger()->log( message => $binlog_file.' not present, creating '.$dst, level => 'debug', );
            }
            else {
                $self->logger()->log( message => $binlog_file.' not up-to-date, overwriting '.$dst, level => 'debug', );
            }
            $cmd = $self->_get_cmd_prefix();
            $cmd .= $self->packer()->cmd();
            $cmd .= q{ } . $binlog_file;
            $cmd .= q{ | };
            $cmd .= $self->_get_cmd_prefix() . $self->_get_ftp_cmd_stdin( 'binlogs', $dst );
            $self->logger()->log( message => 'CMD: ' . $cmd, level => 'debug', );
            $self->sys()->run_remote_cmd( $host, $cmd, {} );
        }
        else {
            $self->logger()->log( message => 'Binlogfile at ' . $dst . ' present and uptodate, skipping.', level => 'debug', );
        }
    }

    # move archived binlogs from the incoming copy directory to their permanent storage location
    $cmd = q{mv -f }.$local_copy_dir.q{/* }.$local_archive_dir.q{/};
    if ( $self->sys()->run_cmd( $cmd, { Timeout => 3600, } ) ) {
        $self->logger()
          ->log( message => 'Moved binlogs from transfer directory at '.$local_copy_dir.' to final archive destination at '.$local_archive_dir, level => 'debug', );
        $cmd = q{rm -rf }.$local_copy_dir.q{/};
        if ( $self->sys()->run_cmd( $cmd, { Timeout => 3600, } ) ) {
            $self->logger()->log( message => 'Removed temporary transfer directory ' . $local_copy_dir, level => 'debug', );
        }
        else {
            $self->logger()->log( message => 'Failed to remove temporary transfer directory ' . $local_copy_dir, level => 'error', );
        }
    }
    else {
        $self->logger()->log(
            message => 'Failed to move binlogs from transfer directory at '.$local_copy_dir.' to final archive destination at '.$local_archive_dir,
            level   => 'error',
        );
    }

    # remove old binlogs [remote]
    $cmd = $self->_get_cmd_prefix();
    $cmd .= '/usr/bin/find ' . $remote_source_dir . ' -type f -regex ".*mysql-bin.[0-9].*" -mtime +10 -print0 | /usr/bin/xargs -0 rm -f';
    $self->logger()->log( message => $cmd, level => 'debug', );
    if ( $self->sys()->run_remote_cmd( $host, $cmd, ) ) {
        $self->logger()->log( message => 'Removed old binlogs on remote host '.$host, level => 'debug', );
        return 1;
    }
    else {
        $self->logger()->log( message => 'Failed to remove old binlogs on remote host '.$host, level => 'debug', );
        return;
    }
}

sub _get_cmd_suffix {
    my $self    = shift;
    my $db      = shift;
    my $table   = shift;
    my $type    = shift;
    my $destdir = shift;
    my $file    = shift;

    my $cmd = ' | ' . $self->_get_cmd_prefix() . $self->_get_ftp_cmd_base('--ftp-create-dirs -T -');
    if ( $self->parent()->ftp_helper() eq 'curl' ) {
        $cmd .= q{/} . $type . q{/} . $db . q{/} . $file . $self->packer()->ext();
    }
    else {
        $cmd .= ' -e "cd ' . $type . '; cd ' . $db . '; put /dev/stdin -o ' . $file . $self->packer()->ext() . '; quit"';
    }

    return $cmd;
}

sub _get_ftp_cmd_base {
    my $self = shift;
    my $opts = shift || '';

    my $dbms = $self->dbms();

    my $password       = $self->config()->get( 'MTK::MYB::DBMS::' . $dbms . '::Password' );
    my $server_address = $self->config()->get('MTK::MYB::CNC::ServerAddress');
    my $ftp_cmd_base;

    if ( $self->parent()->ftp_helper() eq 'curl' ) {
        $ftp_cmd_base = '/usr/bin/curl ' . $opts . ' -s -4 -u ' . $dbms . q{:} . $password . ' ftp://' . $server_address . q{:} . $self->parent()->ftp_port();
    }
    else {
        $ftp_cmd_base = '/usr/bin/lftp ' . $opts . q{ -p } . $self->parent()->ftp_port() . q{ -u } . $dbms . q{,"} . $password . q{" } . $server_address;
    }

    return $ftp_cmd_base;
}

sub _get_ftp_cmd_stdin {
    my $self      = shift;
    my $dest_dir  = shift;
    my $dest_file = shift;

    if ( $self->parent()->ftp_helper() eq 'curl' ) {
        return $self->_get_ftp_cmd_base('--ftp-create-dirs -T -') . q{/} . $dest_dir . q{/} . $dest_file;
    }
    else {
        return $self->_get_ftp_cmd_base() . ' -e "cd ' . $dest_dir . '; put /dev/stdin -o ' . $dest_file . '; quit"';
    }
}

sub _get_ftp_cmd_test {
    my $self = shift;

    if ( $self->parent()->ftp_helper() eq 'curl' ) {
        return $self->_get_ftp_cmd_base() . q{/};
    }
    else {
        return $self->_get_ftp_cmd_base() . '-e "quit"';
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

MTK::MYB::CNC::Worker - The Workhorse for the centralized (CNC) MySQLBackup

=head1 SYNOPSIS

    use MTK::MYB::CNC::Worker;
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
    $Worker->run();
    
=head1 DESCRIPTION

This class implements the business logic of the CNC MySQL Backup solution. It
extends MTK::MYB::Worker and overrides some of its methods.

=method run

Once the class has been set up call this method to start the backup process.

=method type

This method is primarily usefull for subclassing this class. It is used to
dynamically determine the exact subtype of itself. Of course this
could as well be done by using ISA and/or ref. Howevery this way is more
straight forward and easier to implement.

=method uid

The ftp uid.

=method gid

The ftp gid.

=head1 ACKNOWLEDGEMENT

This module was originally developed for eGENTIC Systems. With approval from eGENTIC Systems,
this module was generalized and published, for which the authors would like to express their
gratitude.

=cut
