#!perl -T

use Test::More tests => 7;

BEGIN {
    use_ok( 'MTK::MYB::Cmd::Command::cnc' ) || print "Bail out!
";
    use_ok( 'MTK::MYB::Cmd::Command::cnccleanup' ) || print "Bail out!
";
    use_ok( 'MTK::MYB::Cmd::Command::cncconfigcheck' ) || print "Bail out!
";
    use_ok( 'MTK::MYB::CNC::Job' ) || print "Bail out!
";
    use_ok( 'MTK::MYB::CNC::Plugin' ) || print "Bail out!
";
    use_ok( 'MTK::MYB::CNC::Worker' ) || print "Bail out!
";
    use_ok( 'MTK::MYB::CNC' ) || print "Bail out!
";
}

diag( "Testing MTK::MYB::CNC $MTK::MYB::CNC::VERSION, Perl $], $^X" );
