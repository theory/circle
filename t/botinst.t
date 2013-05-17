#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 51;
#use Test::More 'no_plan';
use Test::MockModule;
use File::Spec::Functions 'catfile';

my $CLASS;
BEGIN {
    $CLASS = 'App::Circle::Bot';
    use_ok $CLASS or die;
}

# Class methods.
can_ok $CLASS, qw(
    go
    run
    new
);

# Accessors.
can_ok $CLASS, qw(
    real_name
    no_run
    kernel
    session
    irc_client
    nickname
    host
    port
    username
    password
    use_ssl
    allow_flood
    away_poll
    reconnect_in
    channels
    alt_nicks
    quit_message
    ignore_nicks
    encoding
    handlers
    tick_in
    _poe_name
    _poe_alias
    _buffer
);

# Methods
can_ok $CLASS, qw(
    yield
);

# Silence warning.
POE::Kernel->run;

##############################################################################
ok my $bot = $CLASS->new, 'Instantiate plain bot';
isa_ok $bot, $CLASS;

# Check default attributes.
is $bot->reconnect_in, 300,           'timeout should be 500';
is $bot->quit_message, 'Bye',         'quit_message should be "Bye"';
is $bot->encoding,     'UTF-8',       'encoding should be UTF-8';
is $bot->tick_in,      0,             'tick_in should be 0';
is $bot->away_poll,    60,            'away_poll should be 60';
ok $bot->_poe_name,                   '_poe_name should be set';
ok $bot->_poe_alias,                  '_poe_alias should be set';
is $bot->nickname,    'circlebot',    'nickname should be set';
is $bot->username,    'circlebot',    'username should be set to nick';
is $bot->real_name,   'circlebot bot','name should be set to "$nick bot"';

is_deeply $bot->ignore_nicks, [], 'ignore_nicks should be empty';
is_deeply $bot->alt_nicks,    [], 'alt_nicks should be empty';
is @{ $bot->handlers }, 1, 'Should have one default handler';
isa_ok $bot->handlers->[0], 'App::Circle::Bot::Handler::Print';

##############################################################################
# Test custom attributes.
my $config = { dbi => { dsn => 'dbi:Pg:dbname=foo' }, log => { dir => 'log' } };
ok $bot = $CLASS->new(
    real_name    => 'Larry Wall',
    no_run       => 1,
    nickname     => 'TimToady',
    host         => 'irc.perl.org',
    port         => 6669,
    username     => 'larry',
    password     => 'yrral',
    use_ssl      => 1,
    allow_flood  => 1,
    away_poll    => 5,
    reconnect_in => 15,
    channels     => [qw(perl parrot)],
    alt_nicks    => [qw(larry wallnut)],
    quit_message => 'Onion…',
    ignore_nicks => [qw(Damian chromatic)],
    encoding     => 'latin-1',
    handlers     => [qw(Print Log)],
    tick_in      => 12,
    config       => $config,
), 'Construct a custom bot';

is $bot->real_name,    'Larry Wall',   'real_name should be set';
is $bot->no_run,       1,              'no_run should be set';
is $bot->nickname,     'TimToady',     'nickname should be set';
is $bot->host,         'irc.perl.org', 'host should be set';
is $bot->port,         6669,           'port should be set';
is $bot->username,     'larry',        'username should be set';
is $bot->password,     'yrral',        'password should be set';
is $bot->use_ssl,      1,              'use_ssl should be set';
is $bot->allow_flood,  1,              'allow_flood should be set';
is $bot->away_poll,    5,              'away_poll should be set';
is $bot->reconnect_in, 15,             'reconnect_in should be set';
is $bot->quit_message, 'Onion…',      'quit_message should be set';
is $bot->encoding,     'latin-1',      'encoding should be set';
is $bot->tick_in,      12,             'tick_in should be set';

is_deeply $bot->channels,     [qw(perl parrot)],      'channels should be set';
is_deeply $bot->alt_nicks,    [qw(larry wallnut)],    'alt_nicks should be set';
is_deeply $bot->ignore_nicks, [qw(Damian chromatic)], 'ignore_nicks should be set';
is_deeply $bot->config,       $config,                'config should be set';
is_deeply $bot->config_for('dbi'), $config->{dbi},    'config_for(log) should work';
is_deeply $bot->config_for('log'), $config->{log},    'config_for(dbi) should work';

is @{ $bot->handlers }, 2, 'Should have one two handlers';
isa_ok $bot->handlers->[0], 'App::Circle::Bot::Handler::Print';
isa_ok $bot->handlers->[1], 'App::Circle::Bot::Handler::Log';

##############################################################################
# Test running it.
my $sess = Test::MockModule->new('POE::Session');
$sess->mock(create => sub {
    is_deeply \@_,  [ 'POE::Session', object_states => [
        $bot => {
            # POE stuff.
            _start           => '_start',
            _stop            => '_stop',
            _default         => '_unhandled',

            # Process signals.
            sig_hup          => 'sig_hup',

            # Server interactions.
            irc_001          => '_irc_001',
            irc_ping         => '_irc_ping',
            reconnect        => '_reconnect',
            irc_disconnected => '_irc_disconnected',
            irc_error        => '_irc_error',
            irc_socketerr    => '_irc_error',
            irc_391          => '_irc_391',
            _get_time        => '_get_time',
            tick             => '_tick',
            irc_shutdown     => '_irc_shutdown',

            # Conversation
            irc_msg          => '_irc_msg',
            irc_public       => '_irc_public',
            irc_ctcp_action  => '_irc_emote',

            # User actions.
            irc_join         => '_irc_join',
            irc_part         => '_irc_part',
            irc_kick         => '_irc_kick',
            irc_nick         => '_irc_nick',
            irc_quit         => '_irc_quit',
            irc_invite       => '_irc_invite',
            irc_notice       => '_irc_notice',

            # For stuff, to be messed with later.
            # fork_close       => '_fork_close_state',
            # fork_error       => '_fork_error_state',

            # Names stuff.
            irc_353          => '_irc_names',
            irc_366          => '_irc_names_end',
            irc_whois        => '_irc_whois',
            irc_whowas       => '_irc_whowas',
            irc_303          => '_irc_ison',

            # Topics stuff.
            irc_332          => '_irc_332',
            irc_333          => '_irc_333',
            irc_topic        => '_irc_topic',

            # Away stuff.
            irc_user_away    => '_irc_user_away',
            irc_user_back    => '_irc_user_back',

            # Mode stuff.
            irc_user_mode    => '_irc_user_mode',
            irc_chan_mode    => '_irc_chan_mode',

        }
    ]], 'Proper args should be passed to POE::Session->create';
});

my $kern = Test::MockModule->new('POE::Kernel');
$kern->mock( post => sub {
    shift;
    is_deeply \@_, [ $bot->_poe_name => register => 'all' ],
        'The proper args should be passed to $poe_kernel->post';
});
$kern->mock( run => sub { fail '$poe_kernel->run should not be called' });

ok $bot->run, 'Run the bot';

# Now make it run.
$bot->no_run(0);
$kern->mock( run => sub { pass '$poe_kernel->run should now be called' });
ok $bot->run, 'Run the bot again';
