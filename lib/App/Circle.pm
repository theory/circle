package App::Circle;

use strict;
use warnings;
use feature ':5.10';
use utf8;

our $VERSION = '0.04';

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 NAME

App::Circle - IRC Logging app

=end comment

=head1 Name

App::Circle - IRC Logging app

=head1 Synopsis

    script/circle_server.pl

=head1 Description

This application logs the discussion on one or more IRC servers and channels
and provides a Web interface for reviewing and searching those logs.

=head1 Credits

Inspired by Moritz Lenz's F<ilbot>, L<http://moritz.faui2k3.org/en/ilbot>.
Thanks for the simple example that got me started!

=head1 Authors

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 Author

David E. Wheeler <david@justatheory.com>

=head1 Copyright and License

Copyright (c) 2009 David E. Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
