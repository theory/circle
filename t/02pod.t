#!/usr/bin/env perl

use strict;
use warnings;
use feature ':5.10';
use utf8;
use Test::More;

eval "use Test::Pod 1.20";
plan skip_all => 'Test::Pod 1.20 required' if $@;

all_pod_files_ok();
