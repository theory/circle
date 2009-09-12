package App::Circle::Model::DBI;

use strict;
use warnings;
use feature ':5.10';
use utf8;

use parent 'Catalyst::Model::DBI';
use Exception::Class::DBI;

# All other configuration data in the configuration files.
__PACKAGE__->config(
    options => {
        PrintError     => 0,
        RaiseError     => 0,
        HandleError    => Exception::Class::DBI->handler,
        AutoCommit     => 1,
        pg_enable_utf8 => 1,
    },
);

1;

=head1 Name

App::Circle::Model::DBI - DBI Model Class

=head1 Synopsis

See L<App::Circle>

=head1 Description

DBI Model Class.

=head1 Author

David E. Wheeler <david@justatheory.com>

=head1 Copyright and License

Copyright (c) 2009 David E. Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

