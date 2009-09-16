#!/usr/bin/env perl

use strict;
use Test::More;
use feature ':5.10';
use utf8;
eval "use Test::Spelling";
plan skip_all => "Test::Spelling required for testing POD spelling" if $@;

add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__DATA__
Lenz's
DSN
SSL
UTF
YAML
plugins
