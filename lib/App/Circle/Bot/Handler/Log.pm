package App::Circle::Bot::Handler::Log;

use strict;
use warnings;
use feature ':5.10';
use utf8;

use DBI;
use DBD::Pg;
use DBIx::Connection;
use Exception::Class::DBI;
use Class::XSAccessor accessors => { map { $_ => $_ } qw(
   conn
) };


use parent 'App::Circle::Bot::Handler';

sub new {
    my $self = shift->SUPER::new(@_);
    # Create a database connection and return.
    my $dbi = $self->bot->config_for('dbi')
        or die qq{Missing required "dbi" configuration\n};
    $self->conn(
        DBIx::Connection->new(@{ $dbi }{qw(dsn username password)}, {
            PrintError     => 0,
            RaiseError     => 0,
            HandleError    => Exception::Class::DBI->handler,
            AutoCommit     => 1,
            pg_enable_utf8 => 1,
        })
    );
    return $self;
}

sub _add_event {
    my ($self, $command, $channel, $who, $body, $target, $emote) = @_;
    my $cast = ref $channel ? '::citext[]' : '';

    # Let the database do all the work.
    $self->conn->do(sub {
        shift->do(
            "SELECT add_event(?, ?$cast, ?, ?, ?, ?, ?)",
            undef,
            $self->bot->host, $channel, $who, $command, $target, $body, $emote,
        );
    });

    # Always return false, so that other handlers will be run.
    return;
}

sub on_connect {
    my ($self, $p) = @_;
    # Not sure we'll ever need/want to log this.
    return;
}

sub on_disconnect {
    my ($self, $p) = @_;
    $self->_add_event( 'disconnect', $p->{channels}, $p->{nick} )
        if $p->{channels} && $p->{nick};
}

sub on_error {
    my ($self, $p) = @_;
    $self->_add_event( 'error', $p->{channels}, $p->{nick}, $p->{body} );
}

sub on_public {
    my ($self, $p) = @_;
    $self->_add_event( 'public', $p->{channel}, $p->{nick}, $p->{body}, $p->{to}, $p->{emoted} );
}

sub on_private {
    my ($self, $p) = @_;
    # Just assume that we're the only recipient, at least for now.
    my $to = ref $p->{to} ? $p->{to}[0] : $p->{to};
    $self->_add_event( 'private', undef, $p->{nick}, $p->{body}, $to, $p->{emoted} );
}

sub on_join {
    my ($self, $p) = @_;
    $self->_add_event( 'join', $p->{channel}, $p->{nick} );
}

sub on_part {
    my ($self, $p) = @_;
    $self->_add_event( 'part', $p->{channel}, $p->{nick}, $p->{body} );
}

sub on_kick {
    my ($self, $p) = @_;
    $self->_add_event( 'kick', $p->{channel}, $p->{nick}, $p->{body}, $p->{target} );
}

sub on_nick {
    my ($self, $p) = @_;
    $self->_add_event( 'nick', $p->{channels}, $p->{nick}, undef, $p->{to} )
        if $p->{channels} && @{ $p->{channels} };
}

sub on_quit {
    my ($self, $p) = @_;
    $self->_add_event( 'quit', $p->{channels}, $p->{nick}, $p->{body} );
}

sub on_away {
    my ($self, $p) = @_;
    $self->_add_event( 'away', $p->{channels}, $p->{nick} );
}

sub on_back {
    my ($self, $p) = @_;
    $self->_add_event( 'back', $p->{channels}, $p->{nick} );
}

sub on_topic {
    my ($self, $p) = @_;
    # XXX Add stuff to check when $p->{at} is true.
    $self->_add_event( 'topic', $p->{channel}, $p->{nick}, $p->{body} );
}

sub on_chan_mode {
    my ($self, $p) = @_;
    my $body = $p->{mode};
    my $target;
    if (defined $p->{arg}) {
        # http://www.gamersvault.net/forum/f201/irc-commands-modes-14101/
        $target = $p->{arg} if $body =~ /[ovhaq]/;
        $body = "$body $p->{arg}";
    }
    $self->_add_event( 'chan_mode', $p->{channel}, $p->{nick}, $body, $target );
}

sub on_user_mode {
    my ($self, $p) = @_;
    # Don't think we want to log this.
    # $self->_add_event( 'user_mode', undef, $p->{nick}, $p->{mode} );
    return;
}

sub on_invite {
    my ($self, $p) = @_;
    # Don't think we want to log this.
    # $self->_add_event( 'invite', $p->{channel}, $p->{nick} );
    return;
}

sub on_whois {
    my ($self, $p) = @_;
    # Not sure we'll ever need/want to log this.
    return;
}

sub on_whowas {
    my ($self, $p) = @_;
    # Not sure we'll ever need/want to log this.
    return;
}

sub on_names {
    # XXX Eventually add code to update the database so it always knows who's
    # present and can display such in the UI. Will need to add a poll for
    # this; don't think POE::Component::IRC::State does that.
    return;
}

sub on_ison {
    my ($self, $p) = @_;
    # Not sure we'll ever need/want to log this.
    return;
}

sub on_notice {
    my ($self, $p) = @_;
    # Not sure we'll ever need/want to log this.
    return;
}

sub on_shutdown {
    my ($self, $p) = @_;
    my $irc = $self->bot->irc_client;
    # XXX Not sure if we really need/want this.
    $self->_add_event( 'shutdown', [ keys %{ $irc->channels } ], $irc->nick_name );
}

1;
__END__

=head1 Name

App::Cicle::Bot::Handler::Log - App::Circle IRC event logging handler

=begin comment

=head1 Interface

=head2 Constructor

=head3 C<new>

=head2 Instance Methods

=head3 C<fh>

=head2 Handlers

The handlers are:

=over

=item C<on_connect>

=item C<on_disconnect>

=item C<on_error>

=item C<on_public>

=item C<on_private>

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

=item C<on_ison>

=item C<on_shutdown>

=item C<on_invite>

=item C<on_notice>

=item C<conn>

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
