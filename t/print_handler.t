#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
#use utf8;

#use Test::More tests => 1;
use Test::More 'no_plan';
use Test::MockModule;

my $CLASS;
BEGIN {
    $CLASS = 'App::Circle::Bot::Handler::Print';
    use_ok $CLASS or die;
    use_ok 'App::Circle::Bot' or die;
}

can_ok $CLASS, qw(
    new
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
    on_shutdown
    on_invite
    on_notify
);

my $bot = App::Circle::Bot->new(server => 'localhost');
my $mock = Test::MockModule->new('App::Circle::Bot');
my $is_op;
$mock->mock(is_channel_operator => sub { $is_op });

# Output sent to the file handle will be encoded to UTF-8, so we need
# to not `use utf8` here.
open my $fh, '>', \my $buf or die 'Cannot open string file handle';
binmode $fh, ':utf8';

sub output() {
    my $ret = $buf;
    $buf =~ s/.+//ms;
    seek $fh, 0, 0;
    return $ret;
}

my $time;
BEGIN {
    my $core_time = CORE::time;
    *CORE::GLOBAL::time = sub () { $time };
    $time = sprintf '%02d:%02d', (localtime($core_time))[2,1]
}

is App::Circle::Bot::Handler::Print::_t, $time, '_t should work';

ok my $h = App::Circle::Bot::Handler::Print->new( fh => $fh, bot => $bot ),
    'Construct a new print handler';
isa_ok $h, 'App::Circle::Bot::Handler::Print';
isa_ok $h, 'App::Circle::Bot::Handler';
is $h->fh, $fh, 'The file handle should be set';

# on_connect.
ok !$h->on_connect({ nick => 'fred', body => 'Welcome' }),
    'on_connect should return false';
is output, "$time -!- Circle: Connected to localhost\n$time -!- Welcome\n",
    'on_connect should have printed the right stuff';

my %msg = (
    nick    => 'fred',
    mask    => '~bknight@example.com',
    channel => '#perl',
    body    => 'Howdy',
);

# on_public
ok !$h->on_public({ %msg, to => 'bob' }), 'on_public should return false';
is output, "$time < fred/#perl> Howdy\n", 'on_public should output message';
$is_op = 1;
ok !$h->on_public({ %msg, to => 'bob' }), 'on_public should return false again';
is output, "$time <\@fred/#perl> Howdy\n", 'on_public should output op message';

# on_private
delete $msg{channel};
ok !$h->on_private({ %msg }), 'on_private should return false';
is output, "$time \[fred(bknight\@example.com)] Howdy\n", 'on_private should output message';

# on_emote
$msg{channel} = '#pgtap';
$msg{body}    = 'smiles';
ok !$h->on_emote({ %msg }), 'on_emote should return false';
is output, "$time * fred/#pgtap smiles\n", 'on_emote should output message';

# on_join
$msg{body} = undef;
ok !$h->on_join({ %msg }), 'on_join should return false';
is output, "$time -!- fred \[~bknight\@example.com] has joined #pgtap\n",
    'on_join should output message';

# on_part
ok !$h->on_part({ %msg }), 'on_part should return false';
is output, "$time -!- fred \[~bknight\@example.com] has left #pgtap\n",
    'on_part should output message';
$msg{body} = 'Later!';
ok !$h->on_part({ %msg }), 'on_part should return false again';
is output, "$time -!- fred \[~bknight\@example.com] has left #pgtap [Later!]\n",
    'on_part should output message with body';

# on_kick
$msg{body} = 'Beat it!';
$msg{target} = 'DrEvil';
ok !$h->on_kick({ %msg }), 'on_kick should return false';
is output, "$time -!- DrEvil was kicked from #pgtap by fred [Beat it!]\n",
    'on_kick should output message';
delete $msg{body};
ok !$h->on_kick({ %msg }), 'on_kick should return false again';
is output, "$time -!- DrEvil was kicked from #pgtap by fred\n",
    'on_kick should output message without reason';

# on_nick
delete $msg{body};
delete $msg{channel};
$msg{from} = $msg{nick};
$msg{to} = 'freddy';
$msg{channels} = ['#perl', '#pgtap'];
ok !$h->on_nick({ %msg }), 'on_nick should return false';
is output, "$time -!- fred is now known as freddy\n",
    'on_nick should output message';

# on_quit.
delete $msg{from};
delete $msg{to};
delete $msg{channels};
ok !$h->on_quit({ %msg }), 'on_quit should return false';
is output, "$time -!- fred \[~bknight\@example.com] has quit\n",
    'on_quit should output message';
$msg{body} = 'Outta here!';
ok !$h->on_quit({ %msg }), 'on_quit should return false again';
is output, "$time -!- fred \[~bknight\@example.com] has quit [Outta here!]\n",
    'on_quit should output message with body';

# on_away
$msg{body} = 'BBL';
$msg{channels} = ['#perl', '#pgtap'];
ok !$h->on_away({ %msg }), 'on_away should return false';
is output, "$time -!- fred \[~bknight\@example.com] is away [BBL]\n",
    'on_away should output message';

# on_back
delete $msg{body};
ok !$h->on_back({ %msg }), 'on_back should return false';
is output, "$time -!- fred \[~bknight\@example.com] is back\n",
    'on_back should output message';

# on_topic
delete $msg{channels};
$msg{channel} = '#pgtap';
$msg{body} = 'Ask ask';
ok !$h->on_topic({ %msg }), 'on_topic should return false';
is output, "$time -!- fred changed the topic of #pgtap to: Ask ask\n",
    'on_topic should output message';

# on_names
my $perl = {
    larry     => [],
    damian    => [],
    chromatic => ['o'],
    allison   => ['v'],
    CanyonMan => [qw(h o v)],
};
my $pgtap = {
    theory => [qw(o v)],
    selena => [],
    josh   => [],
};

ok !$h->on_names({ names => {
    '#pgtap' => { %{ $pgtap } },
    '#perl'  => { %{ $perl  } },
} }), 'on_names should return false';
is output,
    "$time Circle: #pgtap: Total of 3 [1 ops, 0 halfops, 1 voices, 2 normal]\n"
  . "$time Circle: #perl: Total of 5 [2 ops, 1 halfops, 2 voices, 2 normal]\n",
    'on_names should output mesasge';

# on_chan_mode
delete $msg{body};
$msg{mode} = '+o';
$msg{arg}  = 'larry';
ok !$h->on_chan_mode({ %msg }), 'on_chan_mode should return false';
is output, "$time -!- mode/#pgtap [+o larry] by fred\n",
    'on_chan_mode should output message';
delete $msg{arg};
$msg{mode} = '+i';
ok !$h->on_chan_mode({ %msg }), 'on_chan_mode should return false again';
is output, "$time -!- mode/#pgtap [+i] by fred\n",
    'on_chan_mode should output message without arg';

# on_user_mode
$msg{mode} = '+i';
ok !$h->on_user_mode({ %msg }), 'on_user_mode should return false';
is output, "$time -!- mode/fred [+i]\n", 'on_user_mode should output message';

