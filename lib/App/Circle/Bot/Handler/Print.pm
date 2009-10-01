package App::Circle::Bot::Handler::Print;

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Class::XSAccessor accessors => { map { $_ => $_ } qw(
   fh
) };

use parent 'App::Circle::Bot::Handler';

sub _t () {
    sprintf '%02d:%02d', (localtime)[2,1];
}

sub new {
    my $self = shift->SUPER::new(@_);
    unless ($self->fh) {
        # Clone STDOUT and tell it to use UTF-8;
        open my $stdout, ">&STDOUT" or die "Can't dup STDOUT: $!\n";
        binmode $stdout, ':utf8';
        $self->fh($stdout);
    }
    $self;
}

sub on_connect {
    my ($self, $p) = @_;
    say { $self->fh } _t, ' -!- Circle: Connected to ', $self->bot->host, $/,
        _t, " -!- $p->{body}";
    return;
}

sub on_disconnect {
    my ($self, $p) = @_;
    say { $self->fh } _t, ' -!- Circle: Disconnected from ', $self->bot->host;
    return;
}

sub on_error {
    my ($self, $p) = @_;
    say { $self->fh } _t, ' -!- Circle: Error from ', $self->bot->host,
        ": $p->{body}";
    return;
}

sub on_public {
    my ($self, $p) = @_;
    my $op = $self->bot->is_channel_operator($p->{channel}, $p->{nick})
        ? '@' : ' ';
    say { $self->fh } _t, " <$op$p->{nick}/$p->{channel}> $p->{body}";
    return;
}

sub on_private {
    my ($self, $p) = @_;
    (my $who = $p->{mask}) =~ s/^~//;
    say { $self->fh } _t, " [$p->{nick}($who)] $p->{body}";
    # When circle sends a /msg: _t, " [msg/$to_nick] $body";
    return;
}

sub on_emote {
    my ($self, $p) = @_;
    say { $self->fh } _t, " * $p->{nick}/$p->{channel} $p->{body}";
    return;
}

sub on_join {
    my ($self, $p) = @_;
    say { $self->fh } _t,
        " -!- $p->{nick} [$p->{mask}] has joined $p->{channel}";
    return;
}

sub on_part {
    my ($self, $p) = @_;
    my $body = defined $p->{body} ? " [$p->{body}]" : '';
    say { $self->fh } _t,
        " -!- $p->{nick} [$p->{mask}] has left $p->{channel}$body";
    return;
}

sub on_kick {
    my ($self, $p) = @_;
    my $body = defined $p->{body} ? " [$p->{body}]" : '';
    say { $self->fh } _t,
        " -!- $p->{target} was kicked from $p->{channel} by $p->{nick}$body";
    return;
}

sub on_nick {
    my ($self, $p) = @_;
    say { $self->fh } _t, " -!- $p->{nick} is now known as $p->{to}";
    return;
}

sub on_quit {
    my ($self, $p) = @_;
    # 10:52 -!- woggle [~somebody@t10.RIC.Berkeley.EDU] has quit [Quit: leaving]
    my $body = defined $p->{body} ? " [$p->{body}]" : '';
    say { $self->fh } _t, " -!- $p->{nick} [$p->{mask}] has quit$body";
    return;
}

sub on_away {
    my ($self, $p) = @_;
    my $body = defined $p->{body} ? " [$p->{body}]" : '';
    say { $self->fh } _t, " -!- $p->{nick} [$p->{mask}] is away$body";
    return;
}

sub on_back {
    my ($self, $p) = @_;
    say { $self->fh } _t, " -!- $p->{nick} [$p->{mask}] is back";
    return;
}

sub on_topic {
    my ($self, $p) = @_;
    say { $self->fh } _t,
        " -!- $p->{nick} changed the topic of $p->{channel} to: $p->{body}";
    return;
}

sub on_names {
    my ($self, $p) = @_;
    my $names = $p->{names};
    for my $chan (keys %{ $names }) {
        my %counts;
        for my $modes (values %{ $names->{$chan} }) {
            $counts{total}++;
            if (@{ $modes }) {
                $counts{$_}++ for @{ $modes };
            } else {
                $counts{normal}++;
            }
        }
        $counts{$_} ||= 0 for qw(o v h total normal);
        say { $self->fh } _t,  " Circle: $chan: Total of $counts{total} ",
            "[$counts{o} ops, $counts{h} halfops, $counts{v} voices, ",
            "$counts{normal} normal]";
    }
    return;
}

sub on_chan_mode {
    my ($self, $p) = @_;
    my $arg = defined $p->{arg} ? " $p->{arg}" : '';
    say { $self->fh } _t,
        " -!- mode/$p->{channel} [$p->{mode}$arg] by $p->{nick}";
    return;
}

sub on_user_mode {
    my ($self, $p) = @_;
    say { $self->fh } _t, " -!- mode/$p->{nick} [$p->{mode}]";
    return;
}

sub on_invite {
    my ($self, $p) = @_;
    say { $self->fh } _t, " -!- $p->{nick} has invited you to join $p->{channel}";
    return;
}

sub on_whois {
    _who(@_, 'WHOIS');
}

sub on_whowas {
    _who(@_, 'WHOWAS');
}

sub _who {
    my ($self, $p, $event) = @_;
    $p->{channels} = join( ', ', @{ $p->{channels} } ) || 'none'
        if exists $p->{channels};
    no warnings 'uninitialized';
    print { $self->fh } _t, " -!- $event $p->{nick}:\n",
        map { "      -!- $_: $p->{$_}\n" } sort keys %{ $p };
    return;
}

sub on_ison {
    my ($self, $p) = @_;
    my $nick = $self->bot->irc_client->nick_name;
    say { $self->fh } _t, ' -!- ISON: ', _nicklist($p->{nicks}, $nick);
    return;
}

sub on_notice {
    my ($self, $p) = @_;
    my $nick = $self->bot->irc_client->nick_name;
    my $to = _nicklist($p->{targets}, $nick);
    say { $self->fh } _t, " -!- $p->{nick} has sent a notice to $to: $p->{body}";
    return;
}

sub on_shutdown {
    my ($self, $p) = @_;
    say { $self->fh } _t, " -!- Circle: Shutdown requested by $p->{requestor}";
    return;
}

sub _nicklist {
    my ($list, $nick) = @_;
    my $last = @{ $list } > 1 ? pop @{ $list } : undef;
    my $to = join ', ', map { $_ eq $nick ? 'you' : $_  } @{ $list };
    return $to unless $last;
    $last = 'you' if $last eq $nick;
    $to .= ',' if @{ $list } > 1;
    return "$to and $last";
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

=item C<on_ison>

=item C<on_shutdown>

=item C<on_invite>

=item C<on_notice>

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
