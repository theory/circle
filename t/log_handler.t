#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 1;
#use Test::More 'no_plan';

my $CLASS;
BEGIN {
    $CLASS = 'App::Circle::Bot::Handler::Log';
    use_ok $CLASS or die;
}
