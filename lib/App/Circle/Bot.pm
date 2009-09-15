package App::Circle::Bot;

use strict;
use warnings;
use feature ':5.10';
use utf8;
use Bot::BasicBot '0.81';
use Exception::Class::DBI '1.00';
use DBI;
use parent 'Bot::BasicBot';

=head1 Name

App::Cicle::Root - App::Circle IRC Bot

=head1 Synopsis

  use App::Circle::Bot;
  App::Circle::Bot->run;

=head1 Usage

  circle --config conf/prod.yml

=head1 Description

The App::Circle IRC bot.

=head1 Options

  -c --config FILE  YAML configuration file. Required.
  -V --verbose      Incremental verbosity mode.
  -H --help         Print a usage statement and exit.
  -M --man          Print the complete documentation and exit.
  -v --version      Print the version number and exit.

=head2 Configuration File

The configuration file specified via C<--config> is in YAML format. Here's a simple
example:

  ---
  irc:
    host: example.com
    port: 6666
    join: postgresql
    nick: fred
    username: bobby
    password: ybbob
    encoding: big-5
    ssl: 1
  Model::DBI:
    dsn: dbi:Pg:dbname=circle
    username: circle
    password: elcric

There are two top-level keys, C<irc> and C<Model::DBI>, and each contains a
list of its own configuration keys:

=over

=item C<irc>

Configuration for the IRC server.

=over

=item C<nick>

  nick: fred

  # - or -
  nick:
    - lucy
    - dezi
    - alice

Nickname to use on the IRC server. May be specified as a single value or as a
list. In the case of a list, the first value will be preferred, and the other
values used as alternates. Equivalent to C<--nick>

=item C<join>

  join: #perl

  # - or -
  join:
    - #perl
    - #postgresql
    - #dbi

One or more IRC channels to join. May be specified as a scalar value for just
one channel, or as a list for multiple channels. Equivalent to C<--join>

=item C<host>

  host: irc.freenode.net

The IRC server to connect to. Equivalent of C<--host>.

=item C<port>

  port: 6669

The port to connect to the IRC server. Equivalent of C<--port>.

=item C<username>

  username: fred

Username to use when connecting to the IRC server. Equivalent to C<--username>.

=item C<password>

  password: s3kr3t

Password to use to authenticate to the IRC server. Equivalent to C<--password>.

=item C<ssl>

  ssl: Y

Connect to the server via SSL. Defaults to false. Equivalent to C<--ssl>.

=item C<encoding>

  encoding: Latin-1

IRC has no defined character set for putting high-bit chars into channel.
Circle assumes UTF-8, but in case your channel thinks differently, the bot can
be told about different encodings. Equivalent to C<--encoding>.

=back

=item C<Model::DBI>

Configuration for the database.

=over

=item C<dsn>

  dsn: dbi:Pg:dbname=circle

DSN to use to connect to the database. Consult the L<DBI|DBI> and
L<DBD::Pg|DBD::Pg> documentation for complete details. Required.

=item C<username>

  username: circle

The username to use when connecting to the database server. Optional. Defaults
to the value of the C<$PGUSER> environment variable or to OS username.

=item C<password>

  password: elcric

Password to use when authenticating to the database server. Required if
C<username> needs a password to authenticate to the server.

=back

=back

=cut

sub _config {
    my $self = shift;

    my $opts = $self->_getopt;
    my $file = $opts->{config} or $self->_pod2usage(
        '-message' => 'Missing required --config option'
    );

    require YAML::Syck;
    my $config = YAML::Syck::LoadFile($file);

    # Take care of the Bot configuration.
    my $irc = $config->{irc} or $self->_pod2usage(
        '-message' => "Missing required irc configuration in $file"
    );

    for my $k ( keys %{ $irc } ) {
        # Perform transformations.
        given ($k) {
            when ('join') {
                $irc->{channels} = ref $irc->{$k}
                    ?   delete $irc->{$k}
                    : [ delete $irc->{$k} ];
            }
            when ('host')     { $irc->{server}  = delete $irc->{$k} }
            when ('encoding') { $irc->{charset} = delete $irc->{$k} }
        }
    }

    # Modify nicks.
    if (ref $irc->{nick}) {
        my @nicks = @{ $irc->{nick} };
        $irc->{nick} = shift @nicks;
        $irc->{alt_nicks} = \@nicks if @nicks;
    }

    # Set default values.
    for my $spec (
        [ server  => 'localhost' ],
        [ port    => 6667        ],
        [ nick    => 'circle'    ],
        [ charset => 'UTF-8'     ],
        [ verbose => 0           ],
    ) {
        $irc->{$spec->[0]} = $spec->[1] unless exists $irc->{ $spec->[0] };
    }

    # Check required options.
    for my $spec ( [host => 'server'], 'port', [join => 'channels'] ) {
        my ($opt, $key) = ref $spec ? @{ $spec } : ($spec, $spec);
        next if $irc->{$key};
        $self->_pod2usage(
            '-message' => "Missing required irc/$opt configuration in $file"
        );
    }

    # Now handle the DBI configuration.
    my $dbi = $config->{dbi} or $self->_pod2usage(
        '-message' => "Missing required irc configuration in $file"
    );

    $self->_pod2usage(
        '-message' => "Missing required dbi/dsn configuration in $file"
    ) unless $dbi->{dsn};

    # Return the configuration.
    return ( %{ $irc }, dbi => $dbi, verbose => $opts->{verbose} || 0 );
}

=head3 C<go>

  App::Circle::Bot->go;

Runs the bot, processing command-line options in C<@ARGV>, reading the
configuration file, and then running the bot. Used on the C<circle_bot>
application.

=cut

sub go {
    my $class = shift;
    $class->new( $class->_config )->run;
}

=head3 C<dbh>

  my $dbh = $bot->dbh;

Returns a database handle connected to the database server. Used by the
logging methods.

=cut

# Set up a callback to delete the AutoCommit attribute when the connection is
# reused. This keeps connect_cached from breaking transactions.

my $cb = {
    'connect_cached.reused' => sub { delete $_[4]->{AutoCommit} },
};

sub dbh {
    my $self = shift;
    DBI->connect_cached( @{ $self->{dbi} }{qw(dsn username password)}, {
        PrintError     => 0,
        RaiseError     => 0,
        HandleError    => Exception::Class::DBI->handler,
        AutoCommit     => 1,
        pg_enable_utf8 => 1,
        Callbacks      => $cb
    });
}

sub _add_message {
    my ($self, $command, $channel, $who, $body) = @_;
    my $cast = ref $channel ? '::citext[]' : '';
    $self->dbh->do(
        "SELECT add_message(?, ?$cast, ?, ?, ?)",
        undef,
        $self->server, $channel, $who, $command, $body || '',
    );
}

=head3 C<said>

  $bot->said({ channel => 'perl', who => 'TimToady', body => 'Hi' });

Called when a user sends a regular message to a channel. Logs the the message
to the database as a "say" message.

=cut

sub _body {
    my $e = shift;
    my $addr = $e->{address} || return $e->{body};
    return undef if $addr eq 'msg';
    return "$addr: $e->{body}";
}

sub said {
    my ($self, $e) = @_;
    my $body = _body($e) or return;
    $self->_add_message( say => @{ $e }{qw(channel who)}, $body );
}

=head3 C<emoted>

  $bot->emoted({ channel => 'perl', who => 'TimToady', body => 'smiles' });

Called when a user emotes on a channel. Logs that activity to the database as
an "emote" message.

=cut

sub emoted {
    my ($self, $e) = @_;
    my $body = _body($e) or return;
    $self->_add_message( emote => @{ $e }{qw(channel who)}, $body );
}

=head3 C<chanjoin>

  $bot->chanjoin({ channel => 'perl', who => 'TimToady' });

Called when a user joins a channel. Logs it to the database as a "join"
message.

=cut

sub chanjoin {
    my ($self, $e) = @_;
    $self->_add_message( join => @{ $e }{qw(channel who)} );
}

=head3 C<chanpart>

  $bot->chanpart({ channel => 'perl', who => 'TimToady' });

Called when a user leaves a channel. Logs it to the database as a "part"
message.

=cut

sub chanpart {
    my ($self, $e) = @_;
    $self->_add_message( part => @{ $e }{qw(channel who)} );
}

sub _channels_for_nick {
    my ($self, $nick) = @_;
    my $chans = $self->{channel_data};
    grep { $chans->{$_}{$nick} } keys %{ $chans };
}

=head3 C<userquit>

  $bot->userquit({ who => 'TimToady' });

Called when a user quits. For each channel that both the user and the bot are
on, a "part" message will be logged for the user.

=cut

sub userquit {
    my ($self, $e) = @_;
    my @channels = $self->_channels_for_nick or return;
    $self->_add_message( part => \@channels, $e->{who} );
}

=head3 C<topic>

  $bot->topic({ channel => 'perl', who => 'TimToady', topic => 'Welcome!' });

Called when the topic is set on a channel. Logs it to the database as a
"topic" message.

=cut

sub topic {
    my ($self, $e) = @_;
    $self->_add_message( topic => @{ $e }{qw(channel who topic)} );
}

=head3 C<nick_change>

  $bot->nick_change({ from => 'TomToady', to => 'Larry' });

Called when a user changes her nick, to log that activity to the database as a
"nick" message for the old nickname. The new nickname is stored as the body of
the message.

=cut

sub nick_change {
    my ($self, $e) = @_;
    my @channels = $self->_channels_for_nick or return;
    $self->_add_message( nick => \@channels, @{ $e }{qw(from to)} );
}

=head3 C<kicked>

  $bot->kicked({
      channel => 'perl',
      who     => 'TimToady',
      kicked  => 'DrEvil',
      reason  => "Because he's evil, of course!",
  });

Called when a user is kicked from a channel. Logs it to the database as a
"kick" message with the body C<"$kicked: $reason">.

=cut

sub kicked {
    my ($self, $e) = @_;
    my $body = "$e->{kicked}: $e->{reason}";
    $self->_add_message( kick => @{ $e }{qw(channel who)}, $body );
}

=head3 C<help>

  $bot->help({
      channel => 'perl',
      who     => 'TimToady',
      body    => 'help',
      address => 'circle',
  });

Called when a user appears to ask the bot for help. This method replies to the
user, but does no logging (the logging of the help message is already handled
by C<said>).

=cut

sub help {
    my ($self, $e) = @_;
    return qq{$e->{who}: I'm the Circle logging bot. More info when I know more.};
}

sub _getopt {
    my $self = shift;
    require Getopt::Long;
    Getopt::Long::Configure( qw(bundling) );

    my %opts;
    Getopt::Long::GetOptions(
        'config|c=s' => \$opts{config},
        'verbose|V+' => \$opts{verbose},
        'help|H'     => \$opts{help},
        'man|M'      => \$opts{man},
        'version|v'  => \$opts{version},
    ) or $self->_pod2usage;

    # Handle documentation requests.
    $self->_pod2usage(
        ( $opts{man} ? ( '-sections' => '.+' ) : ()),
        '-exitval' => 0,
    ) if $opts{help} or $opts{man};

    # Handle version request.
    if ($opts{version}) {
        require File::Basename;
        print File::Basename::basename($0), ' (', __PACKAGE__, ') ',
            __PACKAGE__->VERSION, $/;
        exit;
    }

    return \%opts;
}

sub _pod2usage {
    shift;
    require Pod::Usage;
    Pod::Usage::pod2usage(
        '-verbose'  => 99,
        '-sections' => '(?i:(Usage|Options))',
        '-exitval'  => 1,
        '-input'    => __FILE__,
        @_
    );
}

1;

__END__

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
