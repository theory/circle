#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 27;
#use Test::More 'no_plan';

my $CLASS;
BEGIN {
    $CLASS = 'App::Circle::Bot::Handler';
    use_ok $CLASS or die;
}

my @meths = qw(
    on_connect
    on_disconnect
    on_error
    on_public
    on_private
    on_emote
    on_join
    on_part
    on_kick
    on_nick
    on_quit
    on_topic
    on_away
    on_back
    on_names
    on_user_mode
    on_chan_mode
    on_whois
    on_whowas
    on_ison
    on_shutdown
    on_invite
    on_notice
);

can_ok $CLASS, 'new', @meths;

ok my $h = $CLASS->new, 'Construct a new handler';
isa_ok $h, 'App::Circle::Bot::Handler';

for my $meth (@meths) {
    ok !$h->$meth, "$meth should return false";
}
