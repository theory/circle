#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 18;
#use Test::More 'no_plan';
use Test::MockModule;
my $CLASS;

BEGIN {
    $CLASS = 'App::Circle::Bot';
    use_ok $CLASS or die;
}

can_ok $CLASS, qw(
    run
    new
    _config
    _pod2usage
    said
    emoted
    chanjoin
    chanquit
    chanpart
    _channels_for_nick
    userquit
    topic
    nick_change
    kicked
    help
);

##############################################################################
# Test options.

my %defaults = (
    version  => undef,
    man      => undef,
    help     => undef,
    config   => undef,
    verbose  => 0,
    version  => undef,
    man      => undef,
    help     => undef,
    config   => undef,
    ssl      => undef,
    charset  => 'UTF-8',
    nick     => 'circle',
    port     => 6667,
    username => undef,
    password => undef,
    server   => 'localhost',
);

DEFAULTS: {
    local @ARGV = qw(--channel perl);
    ok my $opts = $CLASS->_config, 'Should get default opts';
    is_deeply $opts, {
        %defaults,
        channels => ['perl'],
    }, 'Should have proper default config';
}

BASIC: {
    local @ARGV = qw(
        --host foo
        --port 6669
        --username me
        --password you
        --channel perl
        --nick hairy
        --encoding latin-1
        --ssl
        --verbose
     );

    ok my $opts = $CLASS->_config, 'Should get basic opts';
    is_deeply $opts, {
        %defaults,
        server   => 'foo',
        port     => 6669,
        username => 'me',
        password => 'you',
        channels => ['perl'],
        nick     => 'hairy',
        charset  => 'latin-1',
        ssl      => 1,
        verbose  => 1,
    }, 'Should have basic configuration';
}

SHORTOPTS: {
    local @ARGV = qw(
        -h foo
        -p 6669
        -U me
        -P you
        -c perl
        -n hairy
        -e latin-1
        -V
     );

    ok my $opts = $CLASS->_config, 'Should get short opts';
    is_deeply $opts, {
        %defaults,
        server   => 'foo',
        port     => 6669,
        username => 'me',
        password => 'you',
        channels => ['perl'],
        nick     => 'hairy',
        charset  => 'latin-1',
        verbose  => 1,
    }, 'Should have short configuration';
}

USAGE: {
    # Set up tests for call to _pod2usage().
    my (@want, $desc);
    my $mocker = Test::MockModule->new($CLASS);
    $mocker->mock(_pod2usage => sub {
        shift;
        is_deeply \@_, \@want, $desc;
        die; # So nothing else runs in _config.
    });

    # --man
    local @ARGV = ('--man');
    @want = ('-sections' => '.+', '-exitval' => 0);
    $desc = 'Should have proper pod2usage call for --man';
    eval { $CLASS->_config };

    # -M
    @ARGV = ('-M');
    $desc = 'Should have proper pod2usage call for -M';
    eval { $CLASS->_config };

    # --help
    @ARGV = ('--help');
    @want = ('-exitval' => 0);
    $desc = 'Should have proper pod2usage call for --help';
    eval { $CLASS->_config };

    # --H
    @ARGV = ('-H');
    @want = ('-exitval' => 0);
    $desc = 'Should have proper pod2usage call for -H';
    eval { $CLASS->_config };

    # no host
    @ARGV = ('-h', '');
    @want = ('-message' => 'Missing required --host option');
    $desc = 'Should have proper pod2usage for missing host';
    eval { $CLASS->_config };

    # no port
    @ARGV = ('-p', '');
    @want = ('-message' => 'Missing required --port option');
    $desc = 'Should have proper pod2usage for missing port';
    eval { $CLASS->_config };

    # no channel
    @ARGV = ('-c', '');
    @want = ('-message' => 'Missing required --channel option');
    $desc = 'Should have proper pod2usage for missing channel';
    eval { $CLASS->_config };
}


NICKS: {
    local @ARGV = qw(--nick foo -n bar --nick baz -c perl);
    ok my $opts = $CLASS->_config, 'Should get nick opts';
    is_deeply $opts, {
        %defaults,
        channels => ['perl'],
        nick     => 'foo',
        alt_nicks => [qw(bar baz)],
    }, 'Should have proper nick config';
}

CHANNELS: {
    local @ARGV = qw(--channel foo -c bar --channel baz -c perl);
    ok my $opts = $CLASS->_config, 'Should get channel opts';
    is_deeply $opts, {
        %defaults,
        channels => [qw(foo bar baz perl)],
    }, 'Should have proper channel config';
}
