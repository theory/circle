package App::Circle;

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use parent qw/Catalyst/;
use Catalyst (
    '-Debug',
    'ConfigLoader',
    'Static::Simple',
    'StackTrace',
    'Unicode',
    '-Log=warn,fatal,error',
);

our $VERSION = '0.03';

# Configure the application.
#
# Note that settings in circle.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name                   => 'Circle',
    default_view           => 'TD',
    'Plugin::ConfigLoader' => { file => 'conf/dev.yml' },
);

# Start the application
__PACKAGE__->setup();


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
