#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 58;
#use Test::More 'no_plan';
use Test::MockModule;
use File::Spec::Functions 'catfile';
use YAML::Syck;
my $CLASS;

BEGIN {
    $CLASS = 'App::Circle::Bot';
    use_ok $CLASS or die;
}

can_ok $CLASS, qw(
    go
    run
    dbh
    new
    said
    emoted
    chanjoin
    chanpart
    _channels_for_nick
    userquit
    topic
    nick_change
    kicked
    help
    _add_message
);

##############################################################################
ok my $bot = $CLASS->new, 'Instantiate plain bot';
isa_ok $bot, $CLASS;
isa_ok $bot, 'Bot::BasicBot';

# Try some custom attributes.
my $dbi = { dsn => 'dbi:Pg:dbname=circle' };
ok $bot = $CLASS->new( dbi => $dbi ),
    'Pass custom attributes';
is $bot->{dbi}, $dbi, 'Custom attribute should be set';

# Go ahead and load from the test config.
my $conf = LoadFile catfile qw(conf test.yml);
ok $bot = $CLASS->new( dbi => $conf->{'Model::DBI'} ), 'Create proper bot';

isa_ok my $dbh = $bot->dbh, 'DBI::db', 'Should be able to get a dbh';

# What are we connected to, and how?
is $dbh->{Username}, 'postgres', 'Should be connected as "postgres"';
is $dbh->{Name}, 'dbname=circle_test',
    'Should be connected to "circle_test"';
ok !$dbh->{PrintError}, 'PrintError should be disabled';
ok !$dbh->{RaiseError}, 'RaiseError should be disabled';
ok $dbh->{AutoCommit}, 'AutoCommit should be enabled';
isa_ok $dbh->{HandleError}, 'CODE', 'There should be an error handler';

##############################################################################
# Have the bot do some logging, yay!
$dbh->begin_work;
END { $dbh->rollback }
$dbh->do('ALTER SEQUENCE messages_id_seq RESTART 1');
ok !$bot->_add_message(qw(say perl theory hello)),
    'Add a message';

# Check that it was inserted.
my $sth = $dbh->prepare(q{
    SELECT server, channel, nick, command, body
      FROM messages
      WHERE ID = ?
});

ok my @row = $dbh->selectrow_array($sth, undef, 1), 'Should fetch the new row';
is_deeply \@row, [qw(irc.perl.org perl theory say hello)],
    'Should have expected data';

# Do some logging for multiple channels.
ok !$bot->_add_message(part => [qw(perl pgtap pg)], 'theory'),
    'Add messages for three channels at once';

for my $spec (
    [ 2, 'perl'  ],
    [ 3, 'pgtap' ],
    [ 4, 'pg'    ],
) {
    ok my @row = $dbh->selectrow_array($sth, undef, $spec->[0]),
        qq{Should fetch "part $spec->[1]" row};
    is_deeply \@row, ['irc.perl.org', $spec->[1], qw(theory part), '' ],
        qq{Should have expected data for "part $spec->[1]" row};
}

# Okay, now make sure that _add_message() is calling the add_message()
# database function, which we test elsewhere.
my (@expect, $msg);
my $mocker = Test::MockModule->new(ref $dbh, no_auto => 1);
my $tester = sub {
    shift;
    is_deeply \@_, \@expect, $msg;
    return;
};
$mocker->mock( do => $tester);

my $sql = 'SELECT add_message(?, ?, ?, ?, ?)';
@expect = ($sql, undef, qw(irc.perl.org pgtap josh emote cries));
$msg = 'Should have proper call to the add_message() database function';

ok !$bot->_add_message(qw(emote pgtap josh cries)),
    'Add another message';

##############################################################################
# Okay, _add_message is tested, so we can just mocke it to test all the
# methods that call it.

$mocker = Test::MockModule->new($CLASS);
$mocker->mock(_add_message => $tester );

##############################################################################
# Test said().
@expect = qw(say perl theory whatever);
$msg    = 'said() should do proper logging';
ok !$bot->said({ channel => 'perl', who => 'theory', body => 'whatever' }),
    'Say something';

# Test it with an addres.
$expect[-1] = 'circle: whatever';
$msg        = 'said() should manage an address';
ok !$bot->said({ channel => 'perl', who => 'theory', body => 'whatever', address => 'circle' }),
    'Address the bot';

# Test it when it's a /msg, there should be no logging.
ok !$bot->said({ channel => 'perl', who => 'theory', body => 'hi', address => 'msg' }),
    '/msg the bot';

##############################################################################
# Emote!
@expect = qw(emote perl theory smiles);
$msg    = 'emoted() should do proper logging';
ok !$bot->emoted({ channel => 'perl', who => 'theory', body => 'smiles' }),
    'Emote!';

# Emote with an address. Shouldn't happen, but whatever.
$expect[-1] = 'circle: smiles';
$msg        = 'emoted() should manage an address';
ok !$bot->emoted({ channel => 'perl', who => 'theory', body => 'smiles', address => 'circle' }),
    'Emote at the bot';

# Test it when it's a /msg, there should be no logging.
ok !$bot->emoted({ channel => 'perl', who => 'theory', body => 'smiles', address => 'msg' }),
    'Emote a /msg to the bot';

##############################################################################
# chanjoin()
@expect = qw(join perl fred);
$msg    = 'chanjoin() should do proper logging';
ok !$bot->chanjoin({ channel => 'perl', who => 'fred' }), 'Join';

##############################################################################
# chanpart()
@expect = qw(part perl fred);
$msg    = 'chanpart() should do proper logging';
ok !$bot->chanpart({ channel => 'perl', who => 'fred' }), 'Part';

##############################################################################
# userquit()
my @channels = qw(perl pgtap parrot);
$mocker->mock( _channels_for_nick => sub { @channels });
@expect = ('part', \@channels, 'larry');
$msg    = 'userquit() should part from all channels';
ok !$bot->userquit({ who => 'larry' }), 'Have larry quit';

@channels = ();
ok !$bot->userquit({ who => 'larry' }),
    'Should have no parts when no common channels';

@channels = qw(perl);
$msg      = 'userquit() should log one channel';
ok !$bot->userquit({ who => 'larry' }), 'Have larry quit again';

##############################################################################
# topic()
@expect = (qw(topic perl theory), 'Piss off!');
$msg    = 'topic() should do proper logging';
ok !$bot->topic({ channel => 'perl', who => 'theory', topic => 'Piss off!' }),
    'Change the topic';

$expect[2] = undef;
$msg       = 'topic() should work with an undef nick';
ok !$bot->topic({ channel => 'perl', topic => 'Piss off!' }),
    'Change the topic without a nick';

##############################################################################
# nick_change()
@channels = qw(perl pgtap parrot);
@expect   = ('nick', \@channels, 'TimToady', 'Larry');
$msg      = 'nick_change() should log it';
ok !$bot->nick_change({ from => 'TimToady', to => 'Larry' }), 'Change nicks';

@channels = qw(perl);
$msg      ='nick_change() should log one change';
ok !$bot->nick_change({ from => 'TimToady', to => 'Larry' }),
    'Change nick again';

@channels = ();
ok !$bot->nick_change({ from => 'Fred', to => 'Barney' }),
    'Change nick with no common channels';

##############################################################################
# kicked()
@expect = (qw(kick perl TimToady), q{DrEvil: Because he's evil, of course!});
$msg    = 'kicked() should kick it live!';
ok !$bot->kicked({
    channel => 'perl',
    who     => 'TimToady',
    kicked  => 'DrEvil',
    reason  => "Because he's evil, of course!",
}), 'Kick DrEvil';

##############################################################################
# help()
is $bot->help({
    channel => 'perl',
    who     => 'TimToady',
    body    => 'help',
    address => 'circle',
}), "TimToady: I'm the Circle logging bot. More info when I know more.", 'Ask for help';
