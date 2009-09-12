#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 6;
#use Test::More 'no_plan';
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
    dsn
);

ok my $bot = $CLASS->new, 'Instantiate plain bot';
isa_ok $bot, $CLASS;
isa_ok $bot, 'Bot::BasicBot';

# Try some custom attributes.
ok $bot = $CLASS->new( dsn => 'dbi:Pg:dbname=circle' ),
    'Pass custom attributes';
