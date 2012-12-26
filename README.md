This is the README file for MTK-MYB-CNC,
MTK-MYB CNC implementation.

## Description

MTK-MYB-CNC provides the MTK-MYB CNC implementation.

This allows a single host to backup any number of mysql servers
on the local network without having to maintain instances of a backup
script on these hosts. It only requires a single host to be configured
and maintained. The hosts being backed up only need curl installed
and they must be configured to allow password less ssh access
from the central backup instance.

The central host uses pure-ftpd to retrieve the backups from the
remote hosts. It connects to them via SSH and issues a mysqldump
command for each of the tables. The output from mysqldump is then
compressed on the fly and directly fed to STDIN of curl. So no
data is written to disk on the hosts being backed up. This is usually
the fastest and most convenient way to take backups from the backup hosts.

The backup hosts will be locked during the time of the backup, so these
should be replication slaves of a mysql master.

## Installation

This package uses Dist::Zilla.

Use

dzil build

to create a release tarball which can be
unpacked and installed like any other EUMM
distribution.

perl Makefile.PL

make

make test

make install

## Documentation

Please see perldoc MTK::MYB::CNC.
