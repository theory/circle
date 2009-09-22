package App::Circle::Bot::Handler::Print;

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Class::XSAccessor accessors => { map { $_ => $_ } qw(
   fh
) };

use parent 'App::Circle::Bot::Handler';

sub new {
    my $self = shift->SUPER::new(@_);
    unless ($self->fh) {
        # Clone STDERR and tell it to use UTF-8;
        open my $stdout, ">&STDOUT" or die "Can't dup STDOUT: $!\n";
        binmode $stdout, ':utf8';
        $self->fh($stdout);
    }
    $self;
}

sub on_connect {
    my ($self, $p) = @_;
    say $self->bot->server, " says: $p->{body}";
}

sub on_public {
    my ($self, $p) = @_;
    say { $self->fh } "$p->{channel}/$p->{nick}: $p->{body}";
}

sub on_private {
    my ($self, $p) = @_;
    say { $self->fh } "$p->{nick}: $p->{body}";
}

sub on_emote {
    my ($self, $p) = @_;
    say { $self->fh } "* $p->{nick} $p->{body}";
}

sub on_join {
    my ($self, $p) = @_;
    say { $self->fh }
        "    $p->{nick} joined $p->{channel} on ",
        $self->bot->server;
}

sub on_part {
    my ($self, $p) = @_;
    say { $self->fh }
        "    $p->{nick} left $p->{channel} on ",
        $self->bot->server;
}

sub on_kick {
    my ($self, $p) = @_;
    say { $self->fh }
        "    $p->{nick} kicked $p->{who} from $p->{channel}: $p->{body}";
}

sub on_nick {
    my ($self, $p) = @_;
    say { $self->fh } "    $p->{nick} is now known as $p->{to}";
}

sub on_quit {
    my ($self, $p) = @_;
    say { $self->fh } "    $p->{nick} quit: $p->{body}";
}

sub on_away {
    my ($self, $p) = @_;
    say { $self->fh } "    $p->{nick} is away from ",
        join ', ', @{ $p->{channels} };
}

sub on_back {
    my ($self, $p) = @_;
    say { $self->fh } "    $p->{nick} is back from ",
        join ', ', @{ $p->{channels} };
}

sub on_topic {
    my ($self, $p) = @_;
    say { $self->fh } "    $p->{nick} set the topic to “$p->{body}”";
}

sub on_names {
    my ($self, $p) = @_;
    my $names = $p->{names};
    for my $chan (keys %{ $names }) {
        say { $self->fh } "    $chan members: ",
            join ', ', keys %{ $names->{$chan} };
    }
}

sub on_chan_mode {
    my ($self, $p) = @_;
    # say { $self->fh } "    $p->{nick} set $p->{body} ",
    #     ( defined ? $p->{target} "on $p->{target}" : '' ),
    #     "in $p->{channel}";
}

sub on_user_mode {
    my ($self, $p) = @_;
    # say { $self->fh } "    $p->{nick} set $p->{body}";
}

1;
__END__

=head1 Name

App::Cicle::Bot::Handler::Print - App::Circle IRC event print handler

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
