#!/usr/bin/env #perl -w

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 97;
#use Test::More 'no_plan';
use YAML::Syck;
use Test::MockModule;
use File::Spec::Functions 'catfile';

my $CLASS;
BEGIN {
    $CLASS = 'App::Circle::Bot::Handler::Log';
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

#############################################################################
my $bot = App::Circle::Bot->new(host => 'localhost');

eval { $CLASS->new( bot => $bot ) };
ok my $err = $@, 'Should have an exception';
like $err, qr/Missing required "dbi" configuration/,
    'Should have error for missing DBI config';

# Load the test config.
my $file   = catfile qw(conf test.yml);
my $config = LoadFile $file;
$bot = App::Circle::Bot->new( %{ delete $config->{irc}}, config => $config );

# Instantiate the object.
ok my $log = $CLASS->new( bot => $bot, ),
    'Construct a new log handler';
isa_ok $log, $CLASS;
isa_ok $log, 'App::Circle::Bot::Handler';
is $log->bot, $bot, 'The bot should be set';

# Make sure that things are set up.
isa_ok $log->conn, 'DBIx::Connector', 'Connection attribute';
isa_ok my $dbh = $log->conn->dbh, 'DBI::db', 'The DBH';
ok $log->conn->connected, 'We should be connected to the database';

# What are we connected to, and how?
is $dbh->{Username}, 'postgres', 'Should be connected as "postgres"';
is $dbh->{Name}, 'dbname=circle_test',
    'Should be connected to "circle_test"';
ok !$dbh->{PrintError}, 'PrintError should be disabled';
ok !$dbh->{RaiseError}, 'RaiseError should be disabled';
ok $dbh->{AutoCommit}, 'AutoCommit should be enabled';
isa_ok $dbh->{HandleError}, 'CODE', 'The error handler';

#############################################################################
# Have the bot do some logging, yay!
$dbh->begin_work;
END { $dbh->rollback if $dbh }

$dbh->do('ALTER SEQUENCE events_id_seq RESTART 1');
ok !$log->_add_event('public', '#perl', 'theory', 'hello'),
    'Add a event';

# Check that it was inserted.
my $sth = $dbh->prepare(q{
    SELECT host, channel, nick, event, body, target
      FROM events
      WHERE ID = ?
});

ok my @row = $dbh->selectrow_array($sth, undef, 1), 'Should fetch the new row';
is_deeply \@row, ['irc.perl.org', '#perl', 'theory', 'public', 'hello', undef],
    'Should have expected data';

# Do some logging for multiple channels.
ok !$log->_add_event(quit => ['#perl', '#pgtap', '#pg'], 'theory'),
    'Add events for three channels at once';

for my $spec (
    [ 2, '#perl'  ],
    [ 3, '#pgtap' ],
    [ 4, '#pg'    ],
) {
    ok my @row = $dbh->selectrow_array($sth, undef, $spec->[0]),
        qq{Should fetch "quit $spec->[1]" row};
    is_deeply \@row, ['irc.perl.org', $spec->[1], qw(theory quit), '', undef ],
        qq{Should have expected data for "part $spec->[1]" row};
}

# Test for target.
ok !$log->_add_event(kick => '#perl', 'theory', 'Bad manners', 'CanyonMan'),
    'Add kick event with target';
ok @row = $dbh->selectrow_array($sth, undef, 5), 'Should fetch the kick event';
is_deeply \@row, ['irc.perl.org', '#perl', 'theory', 'kick', 'Bad manners', 'CanyonMan'],
    'Should have data with target';

# Test for null channel.
ok !$log->_add_event(private => undef, 'theory', 'Sup?', 'circlebot'),
    'Add private message event with no channel';
ok @row = $dbh->selectrow_array($sth, undef, 6), 'Should fetch the private message event';
is_deeply \@row, ['irc.perl.org', undef, 'theory', 'private', 'Sup?', 'circlebot'],
    'Should have data with NULL channel';

# Okay, now make sure that _add_event() is calling the add_event()
# database function, which we test elsewhere.
my (@expect, $msg);
my $mocker = Test::MockModule->new(ref $dbh, no_auto => 1);
my $tester = sub {
    shift;
    if (defined $msg) {
        is_deeply \@_, \@expect, $msg;
    } else {
        fail 'There should be no database call here';
    }
    return;
};
$mocker->mock( do => $tester);

my $sql = 'SELECT add_event(?, ?, ?, ?, ?, ?, ?)';
@expect = ($sql, undef, 'irc.perl.org', '#pgtap', 'josh', 'public', undef, 'cries', 1);
$msg = 'Should have proper call to the add_event() database function';
ok !$log->_add_event('public', '#pgtap', 'josh', 'cries', undef, 1),
    'Add an emote message event';

# Make sure it works with an array reference of channels.
$expect[0] = 'SELECT add_event(?, ?::citext[], ?, ?, ?, ?, ?)';
$expect[3] = ['#pgtap', '#perl'];
$msg = 'Should have proper call to the add_event() with array of channels';
ok !$log->_add_event('public', ['#pgtap', '#perl'], 'josh', 'cries', undef, 1),
    'Add a message with an array of channels';

# Try it without an emote.
$sql = 'SELECT add_event(?, ?, ?, ?, ?, ?, ?)';
@expect = ($sql, undef, 'irc.perl.org', '#pgtap', 'josh', 'public', undef, 'hi', 0);
$msg = 'Should have proper call to the add_event() without emote';
ok !$log->_add_event('public', '#pgtap', 'josh', 'hi', undef, 0),
    'Add an emote message event';

##############################################################################
# Okay, _add_event is tested, so we can just mock it to test all the methods
# that call it.

$mocker = Test::MockModule->new($CLASS);
$mocker->mock(_add_event => $tester );

##############################################################################
# Test on_disconnect().
@expect = ('disconnect', ['#perl', '#pgtap'], 'circle' );
$msg    = 'on_disconnect should do the proper logging';
ok !$log->on_disconnect({ channels => ['#perl', '#pgtap'], nick => 'circle' }),
    'Disconnect';

##############################################################################
# Test on_error().
@expect = ('error', ['#perl', '#pgtap'], 'circle', 'oops' );
$msg    = 'on_error should do the proper logging';
ok !$log->on_error({ channels => ['#perl', '#pgtap'], nick => 'circle', body => 'oops' }),
    'Error';

##############################################################################
# Test on_public().
@expect = ('public', '#perl', 'theory', 'whatever', undef, undef);
$msg    = 'on_public() should do proper logging';
ok !$log->on_public({ channel => '#perl', nick => 'theory', body => 'whatever' }),
    'Say something';

# Test it with a recipient.
$expect[3] = 'circle: whatever';
$expect[4] = 'circle';
$msg        = 'on_public() should manage a receipient';
ok !$log->on_public({ channel => '#perl', nick => 'theory', body => 'circle: whatever', to => 'circle' }),
    'Address the bot';

# Test it when its /me, an emote.
$expect[3] = 'smiles';
$expect[5] = 1;
$expect[4] = undef;
$msg        = 'on_public() should manage an emote message';
ok !$log->on_public({ channel => '#perl', nick => 'theory', body => 'smiles', emoted => 1 }),
    '/msg the bot';

##############################################################################
# Test on_private().
@expect = ('private', undef, qw(theory hey circle), undef);
$msg    = 'on_private() should do proper logging';
ok !$log->on_private({ to => 'circle', nick => 'theory', body => 'hey' }),
    '/msg something';

$msg .= ' array of recipients';
ok !$log->on_private({ to => ['circle'], nick => 'theory', body => 'hey' }),
    '/msg something';

# Test it when its /me, an emote.
$expect[3] = 'smiles';
$expect[5] = 1;
$msg        = 'on_private() should manage an emote message';
ok !$log->on_private({ to => 'circle', nick => 'theory', body => 'smiles', emoted => 1 }),
    '/msg the bot';

##############################################################################
# Test on_join().
@expect = ('join', '#perl', 'theory');
$msg    = 'on_join() should do proper logging';
ok !$log->on_join({ channel => '#perl', nick => 'theory' }), 'Join';

##############################################################################
# Test on_part().
@expect = ('part', '#perl', 'theory', undef);
$msg    = 'on_part() should do proper logging';
ok !$log->on_part({ channel => '#perl', nick => 'theory' }), 'Part';

$expect[3] = 'later';
$msg    = 'on_part() should do proper logging with body';
ok !$log->on_part({ channel => '#perl', nick => 'theory', body => 'later' }),
    'Part with body';

##############################################################################
# Test on_kick().
@expect = ('kick',  '#perl', 'TimToady', q{Because he's evil, of course!}, 'DrEvil');
$msg    = 'on_kick() should kick it live!';
ok !$log->on_kick({
    channel => '#perl',
    nick    => 'TimToady',
    target  => 'DrEvil',
    body    => "Because he's evil, of course!",
}), 'Kick DrEvil';

##############################################################################
# Test on_nick()
my @channels = ('#perl', '#pgtap', '#parrot');
@expect   = ('nick', \@channels, 'TimToady', undef, 'Larry');
$msg      = 'on_nick() should log it';
ok !$log->on_nick({ nick => 'TimToady', from => 'TimToady', to => 'Larry', channels => \@channels }),
    'Change nicks';

@channels = ('#perl');
$msg      ='on_nick() should log for one channel';
ok !$log->on_nick({ nick => 'TimToady', from => 'TimToady', to => 'Larry', channels => \@channels }),
    'Change nick again';

@channels = ();
@expect   = ();
$msg = undef;
ok !$log->on_nick({ from => 'Fred', to => 'Barney' }),
    'Change nick with no common channels';
ok !$log->on_nick({ from => 'Fred', to => 'Barney', channels => [] }),
    'Change nick with empty channels';

##############################################################################
# Test on_quit().
@expect = ('quit', ['#perl', '#pgtap'], 'theory', undef);
$msg    = 'on_quit() should do proper logging';
ok !$log->on_quit({ channels => ['#perl', '#pgtap'], nick => 'theory' }), 'Quit';

$expect[3] = 'later';
$msg    = 'on_quit() should do proper logging with body';
ok !$log->on_quit({ channels => ['#perl', '#pgtap'], nick => 'theory', body => 'later' }),
    'Quit with body';

##############################################################################
# Test on_away().
$expect[0] = 'away';
pop @expect;
$msg    = 'on_away() should do proper logging';
ok !$log->on_away({ channels => ['#perl', '#pgtap'], nick => 'theory' }), 'Away';

##############################################################################
# Test on_back().
$expect[0] = 'back';
$msg    = 'on_back() should do proper logging';
ok !$log->on_back({ channels => ['#perl', '#pgtap'], nick => 'theory' }), 'Back';

##############################################################################
# Test on_topic().
@expect = ('topic', '#perl', 'theory', 'Piss off!');
$msg    = 'on_topic() should do proper logging';
ok !$log->on_topic({ channel => '#perl', nick => 'theory', body => 'Piss off!' }),
    'Change the topic';

# XXX Update to handle checking for existing topic when at is set.
ok !$log->on_topic({ channel => '#perl', nick => 'theory', body => 'Piss off!', at => 1254511369 }),
    'Change the topic with at';

##############################################################################
# Test on_chan_mode().
@expect = ('chan_mode', '#perl', 'theory', '+s', undef);
$msg    = 'on_chan_mode() should do proper logging';
ok !$log->on_chan_mode({ channel => '#perl', nick => 'theory', mode => '+s' }),
    'Change the channel mode';

# Pass an arg with a mode that effects a user.
$expect[3] = '+o larry';
$expect[4] = 'larry';
$msg    = 'on_chan_mode() that /ops user should do proper logging';
ok !$log->on_chan_mode({ channel => '#perl', nick => 'theory', mode => '+o', arg => 'larry' }),
    'Change the channel mode';

# Pass an arg for a mode that does not effect a user.
$expect[3] = '+k sekret';
$expect[4] = undef;
$msg    = 'on_chan_mode() that sets a password should do proper logging';
ok !$log->on_chan_mode({ channel => '#perl', nick => 'theory', mode => '+k', arg => 'sekret' }),
    'Change the channel mode';

##############################################################################
# Test on_shutdown().
my $poe_mock = Test::MockModule->new('POE::Component::IRC::State');
$poe_mock->mock( nick_name => 'circlebot' );
$poe_mock->mock( channels  => { '#perl' => 1 } );
$bot->irc_client(bless { } => 'POE::Component::IRC::State');
@expect = (shutdown => [ '#perl' ], 'circlebot');
ok !$log->on_shutdown({ requestor => 'someone' }), 'Shutdown';

##############################################################################
# Test no-op callbacks.
@expect   = ();
$msg = undef;
ok !$log->on_connect({ nick => 'Fred', body => 'Welcome' }),
    'on_connect should return false and do nothing';
ok !$log->on_user_mode({ nick => 'Fred', mode => '+i' }),
    'on_user_mode should return false and do nothing';
ok !$log->on_invite({ nick => 'Fred', channel => '#perl' }),
    'on_invite should return false and do nothing';
ok !$log->on_whois({ nick => 'Fred', user => 'Frederick' }),
    'on_whois should return false and do nothing';
ok !$log->on_whowas({ nick => 'Fred', user => 'Frederick' }),
    'on_whowas should return false and do nothing';
ok !$log->on_names({ names => { '#perl' => { Larry => [] } } }),
    'on_names should return false and do nothing';
ok !$log->on_notice({ nick => 'Fred', targets => ['theory'], body => 'Hello' }),
    'on_notice should return false and do nothing';
