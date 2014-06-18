#!/usr/bin/perl

use lib 'lib', 't/lib';

use Test::Roo;

use Log::DWIM;
use Capture::Tiny ':all';
use Path::Tiny;

my $LONG_PREFIX = '^\d{4}/\d\d/\d\d \d\d:\d\d:\d\d \[\d+\]';

test 'can log4j subs' => sub {
    can_ok shift(), qw(TRACE DEBUG INFO WARN ERROR);
};

before each_test => sub {
    init_logging( log_level => "debug" );
};

test 'trace output' => sub {
    init_logging( log_level => "trace" );
    like capture_stderr { TRACE "foo" }, qr{$LONG_PREFIX TRACE.*foo\n$};
};

test 'debug output' => sub {
    like capture_stderr { DEBUG "foo" }, qr/^\d\d\:\d\d DEBUG> foo\n$/;
};

test 'info output' => sub {
    like capture_stderr { INFO "foo" }, qr/^\d\d\:\d\d INFO > foo\n$/;
};

test 'warn output' => sub {
    like capture_stderr { WARN "foo" }, qr/^\d\d\:\d\d WARN > foo\n$/;
};

test 'CORE::warn output' => sub {
    like capture_stderr { warn "foo" }, qr/^\d\d\:\d\d WARN > foo\n$/;
};

test 'error output' => sub {
    like capture_stderr { ERROR "foo" }, qr/^\d\d\:\d\d ERROR> foo\n$/;
};

test 'trace level' => sub {

    init_logging( log_level => "trace" );

    like capture_stderr { TRACE("foo") }, qr{$LONG_PREFIX TRACE.*foo\n$};
    like capture_stderr { DEBUG("foo") }, qr{$LONG_PREFIX DEBUG.*foo\n$};
    like capture_stderr { INFO "foo" },  qr{$LONG_PREFIX INFO.*foo\n$};
    like capture_stderr { WARN "foo" },  qr{$LONG_PREFIX WARN.*foo\n$};
    like capture_stderr { ERROR "foo" }, qr{$LONG_PREFIX ERROR.*foo\n$};
};

test 'debug level' => sub {

    init_logging( log_level => "debug" );

    ok !capture_stderr { TRACE "foo" };
    ok capture_stderr  { DEBUG "foo" };
    ok capture_stderr  { INFO "foo" };
    ok capture_stderr  { WARN "foo" };
    ok capture_stderr  { ERROR "foo" };
};

test 'info level' => sub {

    init_logging( log_level => "info" );

    ok !capture_stderr { TRACE "foo" };
    ok !capture_stderr { DEBUG "foo" };
    ok capture_stderr  { INFO "foo" };
    ok capture_stderr  { WARN "foo" };
    ok capture_stderr  { ERROR "foo" };
};

test 'warn level' => sub {

    init_logging( log_level => "warn" );

    ok !capture_stderr { TRACE "foo" };
    ok !capture_stderr { DEBUG "foo" };
    ok !capture_stderr { INFO "foo" };
    ok capture_stderr  { WARN "foo" };
    ok capture_stderr  { ERROR "foo" };
};

test 'error level' => sub {

    init_logging( log_level => "error" );

    ok !capture_stderr { TRACE "foo" };
    ok !capture_stderr { DEBUG "foo" };
    ok !capture_stderr { INFO "foo" };
    ok !capture_stderr { WARN "foo" };
    ok capture_stderr  { ERROR "foo" };
};

# TODO
# test 'core die logging' => sub {

# throws_ok { die "foo" } qr/(?ms)FxxAAL.*foo.*\n.*at xxx.t line/;
# };

test 'log to file' => sub {

    my $tmp_file = Path::Tiny->tempfile;

    init_logging(
        log_level      => "fatal",
        file_log_level => "debug",
        file           => $tmp_file,
    );

    INFO "test";

    like $tmp_file->slurp,
        qr/[\d\/\s\:]+ \[\d+\] INFO .+main::__ANON__> test\n/;
};

run_me;
done_testing;
