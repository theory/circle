#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Test::More tests => 13;

BEGIN {
    use_ok 'App::Circle';
    use_ok 'App::Circle::Model::DBI';
}

ok my $dbi = App::Circle->model('DBI'), 'Get model';
isa_ok $dbi, 'App::Circle::Model::DBI';
isa_ok $dbi, 'Catalyst::Model::DBI';

# Make sure we can connect.
ok $dbi->connect, 'Connect';
isa_ok my $dbh = $dbi->dbh, 'DBI::db', 'Should be able to get a dbh';

# What are we connected to, and how?
is $dbh->{Username}, 'postgres', 'Should be connected as "postgres"';
is $dbh->{Name}, 'dbname=circle_test',
    'Should be connected to "circle_test"';
ok !$dbh->{PrintError}, 'PrintError should be disabled';
ok !$dbh->{RaiseError}, 'RaiseError should be disabled';
ok $dbh->{AutoCommit}, 'AutoCommit should be enabled';
isa_ok $dbh->{HandleError}, 'CODE', 'There should be an error handler';
