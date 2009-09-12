#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

#use Test::More tests => 18;
use Test::More 'no_plan';
use Test::MockModule;
use File::Spec::Functions 'catfile';
my $CLASS;

BEGIN {
    $CLASS = 'App::Circle::Bot';
    use_ok $CLASS or die;
}

can_ok $CLASS, qw(
    go
    run
    new
    _getopt
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
    verbose  => undef,
    version  => undef,
    man      => undef,
    help     => undef,
    config   => undef,
    ssl      => undef,
    charset  => undef,
    nick     => undef,
    port     => undef,
    username => undef,
    password => undef,
    server   => undef,
);

DEFAULTS: {
    local @ARGV = qw(--join perl);
    ok my $opts = $CLASS->_getopt, 'Should get default opts';
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
        --join perl
        --nick hairy
        --encoding latin-1
        --ssl
        --verbose
     );

    ok my $opts = $CLASS->_getopt, 'Should get basic opts';
    is_deeply $opts, {
        %defaults,
        server   => 'foo',
        port     => 6669,
        username => 'me',
        password => 'you',
        channels => ['perl'],
        nick     => ['hairy'],
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
        -j perl
        -n hairy
        -e latin-1
        -V
     );

    ok my $opts = $CLASS->_getopt, 'Should get short opts';
    is_deeply $opts, {
        %defaults,
        server   => 'foo',
        port     => 6669,
        username => 'me',
        password => 'you',
        channels => ['perl'],
        nick     => ['hairy'],
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
        die; # So nothing else runs in _getopt.
    });

    # --man
    local @ARGV = ('--man');
    @want = ('-sections' => '.+', '-exitval' => 0);
    $desc = 'Should have proper pod2usage call for --man';
    eval { $CLASS->_getopt };

    # -M
    @ARGV = ('-M');
    $desc = 'Should have proper pod2usage call for -M';
    eval { $CLASS->_getopt };

    # --help
    @ARGV = ('--help');
    @want = ('-exitval' => 0);
    $desc = 'Should have proper pod2usage call for --help';
    eval { $CLASS->_getopt };

    # --H
    @ARGV = ('-H');
    @want = ('-exitval' => 0);
    $desc = 'Should have proper pod2usage call for -H';
    eval { $CLASS->_getopt };

    # no host
    @ARGV = ('-h', '');
    @want = ('-message' => 'Missing required --host option');
    $desc = 'Should have proper pod2usage for missing host';
    eval { $CLASS->_getopt };

    # no port
    @ARGV = ('-p', '');
    @want = ('-message' => 'Missing required --port option');
    $desc = 'Should have proper pod2usage for missing port';
    eval { $CLASS->_getopt };

    # no channel
    @ARGV = ('-j', '');
    @want = ('-message' => 'Missing required --join option');
    $desc = 'Should have proper pod2usage for missing channel';
    eval { $CLASS->_getopt };
}


NICKS: {
    local @ARGV = qw(--nick foo -n bar --nick baz -j perl);
    ok my $opts = $CLASS->_getopt, 'Should get nick opts';
    is_deeply $opts, {
        %defaults,
        channels => ['perl'],
        nick     => [qw(foo bar baz)],
    }, 'Should have proper nick config';
}

CHANNELS: {
    local @ARGV = qw(--join foo -j bar --join baz -j perl);
    ok my $opts = $CLASS->_getopt, 'Should get channel opts';
    is_deeply $opts, {
        %defaults,
        channels => [qw(foo bar baz perl)],
    }, 'Should have proper channel config';
}

##############################################################################
# Test config.
delete $defaults{config};
$defaults{verbose} = 0;
$defaults{server} = 'localhost';
$defaults{port} = 6667;
$defaults{charset} = 'UTF-8';
$defaults{nick} = 'circle';

DEFAULTS: {
    local @ARGV = ('--config', catfile qw(t defaults.yml));
    ok my %config = $CLASS->_config, 'Should get default config';
    is_deeply \%config, {
        %defaults,
        channels => ['postgresql'],
    }, 'Should have basic config';
}

CONFIG: {
    local @ARGV = ('-c', catfile qw(t basic.yml));
    ok my %config = $CLASS->_config, 'Should get basic config';
    is_deeply \%config, {
        %defaults,
        server   => 'example.com',
        port     => 6666,
        username => 'bobby',
        password => 'ybbob',
        channels => ['postgresql'],
        nick     => 'fred',
        charset  => 'big-5',
        ssl      => 1,
        verbose  => 2,
    }, 'Should have basic config';
}

MULTIPLES: {
    local @ARGV = ('--config', catfile qw(t multiples.yml));
    ok my %config = $CLASS->_config, 'Should get multiples config';
    is_deeply \%config, {
        %defaults,
        channels  => [qw(perl postgresql dbi)],
        nick      => 'fred',
        alt_nicks => [qw(lucy alice dezi)],
    }, 'Should have proper multiples config';
}
