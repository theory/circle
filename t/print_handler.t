#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

#use Test::More tests => 1;
use Test::More 'no_plan';

my $CLASS;
BEGIN {
    $CLASS = 'App::Circle::Bot::Handler::Print';
    use_ok $CLASS or die;
}

open my $fh, '>', \my $buf or die 'Cannot open string file handle';

ok my $h = App::Circle::Bot::Handler::Print->new( fh => $fh ),
    'Construct a new print handler';
isa_ok $h, 'App::Circle::Bot::Handler::Print';
isa_ok $h, 'App::Circle::Bot::Handler';

