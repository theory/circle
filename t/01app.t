#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;
use Test::More tests => 2;

BEGIN { use_ok 'Catalyst::Test', 'App::Circle' }

ok( request('/')->is_success, 'Request should succeed' );
