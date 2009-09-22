package App::Circle::Bot::Handler;

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Class::XSAccessor accessors => { map { $_ => $_ } qw(
    bot
) };

sub new {
    my $class = shift;
    bless {@_} => $class;
}

# event handlers.

sub on_connect    { }    # irc_001
sub on_disconnect { }    # irc_disconnected
sub on_error      { }    # irc_error, irc_socketerror
sub on_public     { }    # irc_public
sub on_private    { }    # irc_msg
sub on_emote      { }    # irc_ctcp_action
sub on_join       { }    # irc_join
sub on_part       { }    # irc_part
sub on_kick       { }    # irc_kick
sub on_nick       { }    # irc_nick
sub on_quit       { }    # irc_quit
sub on_topic      { }    # irc_topic, irc_332/irc_333
sub on_away       { }    # irc_user_away
sub on_back       { }    # irc_user_back
sub on_names      { }    # irc_353/irc_356
sub on_user_mode  { }    # irc_user_mode
sub on_chan_mode  { }    # irc_chan_mode

sub on_whois      { }    # irc_whois
sub on_whowas     { }    # irc_whowas
sub on_shutdown   { }    # irc_shutdown
sub on_invite     { }    # irc_invite
sub on_notify     { }    # irc_notice

# irc_dcc_*

1;
__END__

=head1 Name

App::Cicle::Bot::Handler - App::Circle IRC event handler base class

=head1 Description

This is the base class for all App::Circle IRC bot event handlers. It defines
default implementations of all the supported event handlers that simply return
a false value. This effectively makes them no-ops that won't prevent other
handlers from executing.

=head1 Interface

=head2 Constructor

=head3 C<new>



=head2 Instance Accessors

=head3 C<bot>



=head2 Handlers

The handlers are:

=over

=item C<on_connect>

=item C<on_disconnect>

=item C<on_error>

=item C<on_public>

=item C<on_private>

=item C<on_emote>

=item C<on_join>

=item C<on_part>

=item C<on_kick>

=item C<on_nick>

=item C<on_quit>

=item C<on_topic>

=item C<on_away>

=item C<on_back>

=item C<on_names>

=item C<on_user_mode>

=item C<on_chan_mode>

=item C<on_whois>

=item C<on_whowas>

=item C<on_shutdown>

=item C<on_invite>

=item C<on_notify>

=back

=head1 Support

This code is stored in an open GitHub repository,
L<http://github.com/theory/circle/>. Feel free to fork and contribute!

Please file bug reports at L<http://github.com/theory/circle/issues>.

=head1 Author

David E. Wheeler <david@justatheory.com>

=head1 Copyright and License

Copyright (c) 2009 David E. Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

