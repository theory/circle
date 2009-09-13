#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 18;
#use Test::More 'no_plan';
use Test::MockModule;
use File::Spec::Functions 'catfile';
my $CLASS;

BEGIN {
    $CLASS = 'App::Circle::Bot';
    use_ok $CLASS or die;
}

can_ok $CLASS, qw(
    _getopt
    _config
    _pod2usage
);

##############################################################################
# Test options.

my %defaults = (
    version  => undef,
    man      => undef,
    help     => undef,
    config   => undef,
    verbose  => undef,
);

DEFAULTS: {
    ok my $opts = $CLASS->_getopt, 'Should get default opts';
    is_deeply $opts, {
        %defaults,
    }, 'Should have proper default config';
}

BASIC: {
    local @ARGV = qw(
        --verbose
     );

    ok my $opts = $CLASS->_getopt, 'Should get basic opts';
    is_deeply $opts, {
        %defaults,
        verbose  => 1,
    }, 'Should have basic configuration';
}

SHORTOPTS: {
    local @ARGV = qw(
        -V
     );

    ok my $opts = $CLASS->_getopt, 'Should get short opts';
    is_deeply $opts, {
        %defaults,
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
}


##############################################################################
# Test config.

%defaults = (
    server  => 'localhost',
    port    => 6667,
    charset => 'UTF-8',
    nick    => 'circle',
    verbose => 0,
    dbi     => {
        dsn => 'dbi:Pg:dbname=circle',
    }
);

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
        verbose  => 0,
        dbi      => { dsn => $defaults{dbi}{dsn}, username => 'larry', password => 'damian' },
    }, 'Should have basic config';
}

MULTIPLES: {
    local @ARGV = ('-V', '-V', '--config', catfile qw(t multiples.yml));
    ok my %config = $CLASS->_config, 'Should get multiples config';
    is_deeply \%config, {
        %defaults,
        channels  => [qw(perl postgresql dbi)],
        nick      => 'fred',
        alt_nicks => [qw(lucy alice dezi)],
        verbose   => 2,
    }, 'Should have proper multiples config';
}
