#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

#use Test::More tests => 7;
use Test::More 'no_plan';
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
    _dbi
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
is $bot->_dbi, $dbi, 'Custom attribute should be set';

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
ok $bot->_add_message(qw(say perl theory hello)),
    'Add a message';

# Check that it was inserted.
ok my @row = $dbh->selectrow_array(
    'SELECT server, channel, nick, command, body
       FROM messages
       WHERE ID = 1'
), 'Should fetch the new row';

is_deeply \@row, [qw(irc.perl.org perl theory say hello)],
    'Should have expected data';

# Okay, now make sure that _add_message() is calling the add_message()
# database function, which we test elsewhere.
my (@expect, $msg);
my $mocker = Test::MockModule->new(ref $dbh, no_auto => 1);
my $tester = sub {
    shift;
    is_deeply \@_, \@expect, $msg;
};
$mocker->mock( do => $tester);

my $sql = 'SELECT add_message(?, ?, ?, ?, ?)';
@expect = ($sql, undef, qw(irc.perl.org pgtap josh emote cries));
$msg = 'Should have proper call to the add_message() database function';

ok $bot->_add_message(qw(emote pgtap josh cries)),
    'Add another message';

##############################################################################
# Okay, _add_message is tested, so we can just mocke it to test all the
# methods that call it.

$mocker = Test::MockModule->new($CLASS);
$mocker->mock(_add_message => $tester );

# Test said().
@expect = qw(say perl theory whatever);
$msg = 'said() should do proper logging';

ok $bot->said({ channel => 'perl', who => 'theory', body => 'whatever' }),
    'Say something';

# Test it with an addres.
$expect[-1] = 'circle: whatever';
$msg = 'said() should manage an address';
ok $bot->said({ channel => 'perl', who => 'theory', body => 'whatever', address => 'circle' }),
    'Address the bot';

# Test it when it's a /msg.
ok !$bot->said({ channel => 'perl', who => 'theory', body => 'whatever', address => 'msg' }),
    '/msg the bot'

