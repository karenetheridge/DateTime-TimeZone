#!/usr/bin/perl -w

use strict;

use DateTime::TimeZone::Local;
use DateTime::TimeZone::Local::Unix;
use File::Spec;
use Sys::Hostname;
use Test::More;

use lib File::Spec->catdir( File::Spec->curdir, 't' );

BEGIN { require 'check_datetime_version.pl' }

my @aliases = sort keys %{ DateTime::TimeZone::links() };
my @names = DateTime::TimeZone::all_names;

plan tests => @aliases + @names + 20;


{
    for my $alias ( sort @aliases )
    {
        local $ENV{TZ} = $alias;
        my $tz = eval { DateTime::TimeZone::Local->TimeZone() };
        isa_ok( $tz, 'DateTime::TimeZone' );
    }
}

{
    for my $name ( sort @names )
    {
        local $ENV{TZ} = $name;
        my $tz = eval { DateTime::TimeZone::Local->TimeZone() };
        isa_ok( $tz, 'DateTime::TimeZone' );
    }
}

{
    local $ENV{TZ} = 'this will not work';

    my $tz;
    eval { $tz = DateTime::TimeZone::Local::Unix->FromEnv() };
    is( $tz, undef,
        'invalid time zone name in $ENV{TZ} fails' );

    local $ENV{TZ} = '123/456';

    eval { $tz = DateTime::TimeZone::Local::Unix->FromEnv() };
    is( $tz, undef,
        'invalid time zone name in $ENV{TZ} fails' );
}

{
    local $ENV{TZ} = 'Africa/Kinshasa';

    my $tz;
    eval { $tz = DateTime::TimeZone::Local::Unix->FromEnv() };
    is( $tz->name(), 'Africa/Kinshasa', 'tz object name() is Africa::Kinshasa' );
}

SKIP:
{
    skip "/etc/localtime is not a symlink", 2
        unless -l '/etc/localtime';

    $^W = 0;
    local *DateTime::TimeZone::Local::Unix::_Readlink = sub { '/usr/share/zoneinfo/US/Eastern' };
    $^W = 1;

    my $tz;
    eval { $tz = DateTime::TimeZone::Local::Unix->FromEtcLocaltime() };
    is( $@, '', 'valid time zone name in /etc/localtime symlink should not die' );
    isa_ok( $tz, 'DateTime::TimeZone::America::New_York' );
}

SKIP:
{
    skip "cannot read /etc/sysconfig/clock", 2
        unless -r '/etc/sysconfig/clock' && -f _;

    $^W = 0;
    local *DateTime::TimeZone::Local::Unix::_ReadEtcSysconfigClock = sub { 'US/Eastern' };
    $^W = 1;

    my $tz;
    eval { $tz = DateTime::TimeZone::Local::Unix->FromEtcSysconfigClock() };
    is( $@, '', 'valid time zone name in /etc/sysconfig/clock should not die' );
    isa_ok( $tz, 'DateTime::TimeZone::America::New_York' );
}

SKIP:
{
    skip "cannot read /etc/default/init", 2
        unless -r '/etc/default/init' && -f _;

    local *DateTime::TimeZone::Local::_read_etc_default_init = sub { 'US/Eastern' };

    my $tz;
    eval { $tz = DateTime::TimeZone::Local::Unix->FromEtcDefaultInit() };
    is( $@, '', 'valid time zone name in /etc/default/init should not die' );
    isa_ok( $tz, 'DateTime::TimeZone::Australia::Melbourne' );
}

SKIP:
{
    skip "Cannot run these tests without explicitly knowing local time zone first (only runs on developers' machine)", 6
        unless hostname =~ /houseabsolute/ && -d '.svn';

    {
        local $ENV{TZ} = '';

        my $tz;
        eval { $tz = DateTime::TimeZone::Local->TimeZone() };
        is( $@, '', 'valid time zone name in /etc/localtime should not die' );
        isa_ok( $tz, 'DateTime::TimeZone::America::Chicago' );
    }

    {
        $^W = 0;
        local *DateTime::TimeZone::Local::Unix::FromEtcLocaltime = sub { undef };
        $^W = 1;

        my $tz;
        eval { $tz = DateTime::TimeZone::Local->TimeZone() };
        is( $@, '', 'valid time zone name in /etc/timezone should not die' );
        isa_ok( $tz, 'DateTime::TimeZone::America::Chicago' );
    }

    {
        # requires that /etc/default/init contain
        # TZ=Australia/Melbourne to work.
        $^W = 0;
        local *DateTime::TimeZone::Local::Unix::FromEtcLocaltime = sub { undef };
        local *DateTime::TimeZone::Local::Unix::FromEtcTimezone = sub { undef };
        local *DateTime::TimeZone::Local::Unix::FromEtcTIMEZONE = sub { undef };
        $^W = 1;

        my $tz;
        eval { $tz = DateTime::TimeZone::Local->TimeZone() };
        is( $@, '', '/etc/default/init contains TZ=Australia/Melbourne' );
        isa_ok( $tz, 'DateTime::TimeZone::Australia::Melbourne' );
    }
}

SKIP:
{
    skip "These tests are too dangerous to run on someone else's machine ;)", 4
        unless hostname =~ /houseabsolute|quasar/ && -d '.svn';

    skip "These tests can only be run if we can overwrite /etc/localtime", 4
        unless -w '/etc/localtime' && -l '/etc/localtime';

    my $tz_file = readlink '/etc/localtime';

    unlink '/etc/localtime' or die "Cannot unlink /etc/localtime: $!";

    require File::Copy;
    File::Copy::copy( '/usr/share/zoneinfo/Asia/Calcutta', '/etc/localtime' )
        or die "Cannot copy /usr/share/zoneinfo/Asia/Calcutta to '/etc/localtime': $!";

    {
        local $ENV{TZ} = '';

        require Cwd;
        my $cwd = Cwd::cwd();

        my $tz;
        eval { $tz = DateTime::TimeZone::Local->TimeZone() };
        is( $@, '', 'copy of zoneinfo file at /etc/localtime' );
        isa_ok( $tz, 'DateTime::TimeZone::Asia::Calcutta' );

        is( Cwd::cwd(), $cwd, 'cwd should not change after finding local time zone' );
    }

    {
        local $ENV{TZ} = '';

        # Make sure that a die handler does not break our use of die
        # to escape from File::Find::find()
        local $SIG{__DIE__} = sub { die 'haha'; };

        my $tz;
        eval { $tz = DateTime::TimeZone::Local->TimeZone() };
        isa_ok( $tz, 'DateTime::TimeZone::Asia::Calcutta' );
    }

    unlink '/etc/localtime' or die "Cannot unlink /etc/localtime: $!";
    symlink $tz_file, '/etc/localtime'
        or die "Cannot symlink $tz_file to '/etc/localtime': $!";
}

SKIP:
{
    skip "These tests only run on Win32", 1
        unless $^O =~ /win32/i;

    require DateTime::TimeZone::Local::Win32;

    my %Reg;
    Win32::TieRegistry->import( TiedHash => \%Reg );

    local $Reg{'HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation\\StandardName'}
        = 'Eastern Standard Time';

    my $tz;
    eval { $tz = DateTime::TimeZone::Local::Win32->FromRegistry() };
    isa_ok( $tz, 'DateTime::TimeZone::America::New_York' );
}

