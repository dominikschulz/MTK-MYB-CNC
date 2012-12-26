#perl
use strict;
use warnings;
use feature ':5.10';

use Test::More;
use Config::Yak;
use Log::Tree;
use Test::MockObject::Universal;

use MTK::MYB::CNC;

unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

my $Config = Config::Yak::->new({ locations => [], });
my $Logger = Test::MockObject::Universal->new();
$Logger = Log::Tree::->new('test-plugins-myb');

my $MYB = MTK::MYB::CNC::->new({
    'config'    => $Config,
    'logger'    => $Logger,
});

is_deeply([$MYB->_plugin_base_class()],[qw(MTK::MYB::Plugin MTK::MYB::CNC::Plugin)],'Got corrent plugin base classes');

my @got_pnames = grep { $_ ne 'MTK::MYB::Plugin::Reporter' } map { ref($_) } @{$MYB->plugins()};
my @expect_pnames = map { 'MTK::MYB::Plugin::'.$_ } qw(MyCnf ListBackupDir Zabbix DotMyCnf DebianCnf LegacyConfig);
is_deeply(\@got_pnames,\@expect_pnames,'Got ordered plugins');
$MYB = undef;

$MYB = MTK::MYB::CNC::->new({
    'config'    => $Config,
    'logger'    => $Logger,
});
$Config->set('MTK::MYB::Plugin::DebianCnf::Priority',9);
@expect_pnames = map { 'MTK::MYB::Plugin::'.$_ } qw(MyCnf DebianCnf ListBackupDir Zabbix DotMyCnf LegacyConfig);
@got_pnames = grep { $_ ne 'MTK::MYB::Plugin::Reporter' } map { ref($_) } @{$MYB->plugins()};
is_deeply(\@got_pnames,\@expect_pnames,'Got ordered plugins');

done_testing();

1;
