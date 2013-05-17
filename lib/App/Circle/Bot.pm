package App::Circle::Bot;

use strict;
use warnings;
use feature ':5.10';
use utf8;

use Encode ();
use Encode::Detect::Detector ();
use POE::Kernel;
use POE::Session;
use POE::Wheel::Run;
use POE::Filter::Line;
use POE::Component::IRC::State;
use Unicode::Normalize 'NFC';
use Class::XSAccessor accessors => {
    map { $_ => $_ } qw(
        real_name
        no_run
        kernel
        session
        nickname
        host
        port
        username
        password
        use_ssl
        allow_flood
        away_poll
        reconnect_in
        channels
        alt_nicks
        quit_message
        ignore_nicks
        encoding
        handlers
        tick_in
        irc_client
        config
        _poe_name
        _poe_alias
        _buffer
    )
};

=encoding utf8

=head1 Name

App::Cicle::Bot - App::Circle IRC Bot

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
    join:
      - #perl
      - #pgtap
      - #ruby
    nickname: fred
    alt_nicks:
      - fred
      - freddy
      - frederick
    username: bobby
    password: ybbob
    encoding: big-5
    use_ssl: Y
    handlers:
      - Print
      - Log

The main bot settings go under the C<irc> top-level key. Other top-level keys
are are used for the configuration of one or more handlers. The list of the
supported configuration keys under the C<irc> key is the same as the list of
supported parameters to C<new()>.

=head1 Class Interface

=head2 Constructor

=head3 C<new>

  my $bot = App::Circle::Bot->new;
  my $bot = App::Circle::Bot->new( %params );

Constructs and returns a bot object, ready to be C<run>. The supported
parameters are:

=over

=item C<nickname>

  nickname => 'circle',

The nickname to use to use on the server. Defaults to "circlebot".

=item C<alt_nicks>

  alt_nicks => [qw(botty _circle)],

An array reference of alternate nicknames to fall back on in case C<nickname>
is already in use on the server.

=item C<real_name>

  real_name => 'Circle B. Ott',

An optional name to show as the "real name" for the bot.

=item C<host>

  host => 'irc.perl.org',

The hostname or address of the server to connect to. Defaults to C<localhost>,
which is probably not what you want.

=item C<port>

  port => 6667,

The port to connect to on the server. Defaults to the IRC standard port, 6667.

=item C<username>

  username => 'botty',

The username to use when connecting to the server. Defaults to the value of
the nickname.

=item C<password>

  password => '5up3rs3kr!t',

Password to use when connecting to the server. Required by some IRC servers.

=item C<use_ssl>

  use_ssl => 1,

Boolean to indicate whether or not to connect to the server via SSL. If true,
L<POE::Component::SSLify> will need to be installed on the system. Defaults to
false.

=item C<join>

  join => [ '#perl', '#pgtap', '#circle' ],

And array reference listing the names of the channels the bot should join on
the server.

=item C<allow_flood>

  allow_flood => 1,

When true, disables the bot's flood protection algorithms, allowing it to send
messages to an IRC server at full speed. Probably not a great idea. False by
default.

=item C<away_poll>

  away_poll => 30,

How often, in seconds, the bot should poll for away events. Defaults to 60
seconds.

=item C<reconnect_in>

  reconnect_in => 500,

How long, in seconds, the bot should wait to reconnect to the server if it
hasn't heard from the server. This is basically how long you want to wait
before reconnecting if the server looks like it's gone away. Defaults to 300
seconds.

=item C<quit_message>

  quit_message => 'Later dudes!',

Message the bot should leave when quitting the server. Defaults to "Bye".

=item C<encoding>

  encoding => 'Big5',

IRC has no defined character set for putting high-bit chars into channel.
Circle assumes UTF-8, but in case your channel thinks differently, you can let
the bot know it.

=item C<handlers>

  handlers => [qw(Log AnsweringService)],

A list of the handlers to handle IRC events. If none are specified, only the
<Print|App::Circle::Bot::Handler::Print> Handler will be used. The handlers
will run for each event in the order specified.

=item C<tick_in>

  tick_in => 5,

The amount of time until the next tick event should be called. Defaults to 0,
which disables the tick.

=item C<no_run>

  no_run => 1,

Pass a true value to prevent the bot from running when you call C<run()>. The
POE kernel will be configured and the session created, but the bot won't
connect to the server or handle any events.

=begin comment

Unimplemented.

=item C<ignore_nicks>

  ignore_nicks => [qw(DrEvil DrNo CanyonMan)],

A list of nicknames whose events should be completely ignored. Optional.

=end comment

=back

=cut

sub new {
    my $class = shift;
    my $self = bless {
        reconnect_in => 300,
        quit_message => 'Bye',
        encoding     => 'UTF-8',
        tick_in      => 0,
        away_poll    => 60,
        nickname     => 'circlebot',
        host         => 'localhost',
        port         => 6667,
        config       => {},
        @_,
    } => $class;

    # Handle channels.
    if (my $join = delete $self->{join}) {
        $self->channels( ref $join ? $join : [$join]);
    }

    my $nick = $self->nickname;
    $self->username(   $nick )                   unless $self->username;
    $self->real_name(  $nick . ' bot' )          unless $self->real_name;
    $self->_poe_name(  $nick . int rand 100000 ) unless $self->_poe_name;
    $self->_poe_alias( $nick . int rand 100000 ) unless $self->_poe_alias;
    $self->ignore_nicks([])                      unless $self->ignore_nicks;
    $self->alt_nicks([])                         unless $self->alt_nicks;
    $self->handlers(['Print'])                   unless $self->handlers;
    $self->irc_client(
        POE::Component::IRC::State->spawn( alias => $self->_poe_name )
    );

    for my $handler (@{ $self->handlers }) {
        $handler = __PACKAGE__ . "::Handler::$handler" unless $handler =~ /::/;
        eval "require $handler" or die $@;
        $handler = $handler->new( bot => $self );
    }

    return $self;
}

=head2 Class Methods

=head3 C<run>

  $bot->run;

Actually runs the bot, setting up the POE kernel and session and running it.
Unless the C<no_run> parameter is true, in which case it does everything but
run POE.

=cut

sub run {
    my $self = shift;

    # create the callbacks to the object states
    POE::Session->create(
        object_states => [
            $self => {
                # POE stuff.
                _start           => '_start',
                _stop            => '_stop',

                # Server interactions.
                irc_001          => '_irc_001',
                irc_ping         => '_irc_ping',
                reconnect        => '_reconnect',
                irc_disconnected => '_irc_disconnected',
                irc_error        => '_irc_error',
                irc_socketerr    => '_irc_error',
                irc_391          => '_irc_391',
                _get_time        => '_get_time',
                tick             => '_tick',
                irc_shutdown     => '_irc_shutdown',

                # Conversation
                irc_msg          => '_irc_msg',
                irc_public       => '_irc_public',
                irc_ctcp_action  => '_irc_emote',

                # User actions.
                irc_join         => '_irc_join',
                irc_part         => '_irc_part',
                irc_kick         => '_irc_kick',
                irc_nick         => '_irc_nick',
                irc_quit         => '_irc_quit',
                irc_invite       => '_irc_invite',
                irc_notice       => '_irc_notice',

                # For stuff, to be messed with later.
                # fork_close       => '_fork_close_state',
                # fork_error       => '_fork_error_state',

                # Names stuff.
                irc_353          => '_irc_names',
                irc_366          => '_irc_names_end',
                irc_whois        => '_irc_whois',
                irc_whowas       => '_irc_whowas',
                irc_303          => '_irc_ison',

                # Topics stuff.
                irc_332          => '_irc_332',
                irc_333          => '_irc_333',
                irc_topic        => '_irc_topic',

                # Away stuff.
                irc_user_away    => '_irc_user_away',
                irc_user_back    => '_irc_user_back',

                # Modes
                irc_user_mode    => '_irc_user_mode',
                irc_chan_mode    => '_irc_chan_mode',
            }
        ]
    );

    # and say that we want to recive said messages
    $poe_kernel->post( $self->_poe_name => register => 'all' );

    # run
    $poe_kernel->run() unless $self->no_run;
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

=head1 Instance Interface

=head2 Instance Methods

=head3 C<yield>

   $bot->yield( nick => 'bjørn' );

Recommended method for posting IRC events. It transparently encodes the
arguments to C<encoding> before passing them on to the IRC client. If for some
reason you don't want the arguments to be encoded (are you sending binary
data?), you can access the client directly like so:

  $bot->irc_client->yield( nick => 'fred' );

=cut

sub yield {
    my ($self, $to) = (shift, shift);
    $self->irc_client->yield( $to => $self->_encode( @_ ) );
}

=head3 C<config_for>

  my $config = $bot->config_for('dbi');

Returns the subset of C<config> found under the key passed  to the method.

=cut

sub config_for {
    my $self = shift;
    $self->config->{+shift};
}

=head2 Instance Accessors

=head3 C<real_name>



=head3 C<no_run>



=head3 C<kernel>



=head3 C<session>



=head3 C<nickname>



=head3 C<server>



=head3 C<port>



=head3 C<username>



=head3 C<password>



=head3 C<use_ssl>



=head3 C<allow_flood>



=head3 C<away_poll>



=head3 C<reconnect_in>



=head3 C<channels>



=head3 C<alt_nicks>



=head3 C<quit_message>



=head3 C<ignore_nicks>



=head3 C<encoding>



=head3 C<handlers>



=head3 C<tick_in>



=head3 C<irc_client>



=head3 C<config>



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
    my $irc = delete $config->{irc} or $self->_pod2usage(
        '-message' => "Missing required irc configuration in $file"
    );

    # Return the configuration.
    return ( %{ $irc }, config => $config, verbose => $opts->{verbose} || 0 );
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

sub _trim($) {
    $_[0] =~ s/^\s+//;
    $_[0] =~ s/\s+$//;
    $_[0];
}

# Not passed to handlers.
sub _start {
    my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
    $self->kernel( $kernel );
    $self->session( $session );

    # Make an alias for our session, to keep it from getting GC'ed.
    $kernel->alias_set( $self->_poe_alias );

    $kernel->delay( reconnect => 1  );
    $kernel->delay( tick      => 30 );
    return $self;
}

# Not passed to handlers.
sub _stop {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    $kernel->post( $self->_poe_name, 'quit', $self->_encode($self->quit_message) );
    $kernel->alias_remove( $self->_poe_alias );
    return $self;
}

# Not passed to handlers.
sub _reconnect {
    my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];

    my $poe_name = $self->_poe_name;
    $kernel->call( $poe_name => 'disconnect' );
    $kernel->call( $poe_name => 'shutdown' );
    $kernel->post( $poe_name => 'register', 'all' );

    $kernel->post($poe_name, connect => {
        Debug      => 0,
        Server     => $self->host,
        Port       => $self->port,
        Password   => $self->password,
        UseSSL     => $self->use_ssl,
        Flood      => $self->allow_flood,
        AwayPoll   => $self->away_poll,
        WhoJoiners => 0,
        $self->_encode(
            Nick     => $self->nickname,
            Username => $self->username,
            Poe_Name => $self->real_name,
        ),
    });

    $kernel->delay( reconnect => $self->reconnect_in );
    $kernel->delay( _get_time => 60 );
    return $self;
}

=head2 Implementing Event Handlers

Circle event handlers are implemented as subclasses of
L<App::Circle::Bot::Handler|App::Circle::Bot::Handler>. The implementation is
a layer over that provided by
L<POE::Component::IRC::State|POE::Component::IRC::State> so as to make things
simpler, and to handle decoding the content from IRC, so that you can always
be sure that the content is in Perl's internal C<utf8> form.

=head2 Event Handlers

Each event-handling method can expect a single argument to be passed: a hash
with data appropriate to the event. For example, the C<on_public> event will
be called something like this:

  $handler->on_public({
      nick    => 'bob',
      mask    => '~bknight@example.com',
      body    => 'Howdy',
      channel => '#perl',
      to      => undef,
  });

Thus the interface for all of the event handler methods is the same: only the
keys in the parameter hash vary.

The supported event-handler methods are:

=head3 C<on_connect>

Called after circle has connected to the IRC server and joined all the
channels. The parameters passed are:

=over

=item C<nick>

The circle bot's nickname. Will usually be the same as C<nick>, but might be
one of the C<alt_nicks>.

=item C<body>

The content of the welcome message from the IRC server, if any.

=back

=cut

sub _irc_001 {
    my ( $self, $kernel, $body) = @_[ OBJECT, KERNEL, ARG1 ];

    # ignore all messages from ourselves
#   $kernel->post( $self->_poe_name, 'ignore', $self->_encode($self->nickname) );

    # connect to the channel
    foreach my $channel ( @{ $self->channels } ) {
        $kernel->post( $self->_poe_name, 'join', $self->_encode($channel) );
    }

    $kernel->delay( tick => 5 );

    my @msg = $self->_decode(
        nick => $self->irc_client->nick_name,
        body => _trim $body,
    );

    for my $h (@{ $self->handlers }) {
        last if $h->on_connect({ @msg });
    }

    return $self;
}

=head3 C<on_public>

Called when a public message is sent to a channel. The parameters passed are:

=over

=item C<nick>

Nickname of the user who sent the message.

=item C<mask>

The hostmask for that user.

=item C<body>

The body of the message.

=item C<channel>

The channel to which the message was sent.

=item C<to>

If the message is addressed to someone on the channel, this parameter will be
set to the nick of that someone. For example, a message that says, "bob: hi",
the C<to> parameter will be set to "bob" if "bob" is on the channel at the
time the message is received.

=item C<emoted>

If set to a true value, the message was emoted (that is, the user sent it with
C</me>).

=back

=cut

sub _irc_public {
    my $self = shift;
    my %msg = $self->_msg(@_);
    $msg{to} = _to($self, \%msg);
    for my $h (@{ $self->handlers }) {
        last if $h->on_public({ %msg });
    }
    return $self;
}

=head3 C<on_private>

Called when a private message is sent to the bot. The parameters passed are:

=over

=item C<nick>

Nickname of the user who sent the message.

=item C<mask>

The hostmask for that user.

=item C<to>

Array reference of the nicks of the recipients of the private message. Usually
this will just be the bot's nickname.

=item C<body>

The body of the message.

=item C<emoted>

If set to a true value, the message was emoted (that is, the user sent it with
C</me>).

=back

=cut

sub _irc_msg {
    my $self = shift;
    my %msg = $self->_msg(@_);
    $msg{to} = delete $msg{channel};
    for my $h (@{ $self->handlers }) {
        last if $h->on_private({ %msg });
    }
    return $self;
}

sub _irc_emote {
    my $self = shift;
    my %msg = $self->_msg(@_);
    $msg{emoted} = 1;
    if ($msg{channel} =~ /^#/) {
        for my $h (@{ $self->handlers }) {
            last if $h->on_public({ %msg });
        }
    } else {
        $msg{to} = delete $msg{channel};
        for my $h (@{ $self->handlers }) {
            last if $h->on_private({ %msg });
        }
    }
    return $self;
}

# Not passed to handlers.
sub _irc_ping {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    $kernel->delay( reconnect => $self->reconnect_in );
    return $self;
}

=head3 C<on_disconnect>

Called when the bot is disconnected from the server. Circle will schedule
itself to try reconnecting in 30 seconds, and then call the C<on_disconnect>
handlers. The parameters passed are:

=over

=item C<nick>

The bot's own nickname at the time of the disconnect.

=item C<channels>

A list of the channels the bot was on. Useful for logging that the bot has
left (or been disconnected from ) those channels.

=back

=cut

sub _irc_disconnected {
    my ( $self, $kernel, $server, $nick_info )
        = @_[ OBJECT, KERNEL, ARG0, ARG1 ];

    $kernel->delay( reconnect => 30 );

    my $nick     = $self->_decode( $nick_info->{Nick} );
    my $channels = [ keys %{ $self->_decode( $_[ARG2] ) } ];
    for my $h (@{ $self->handlers }) {
        last if $h->on_disconnect({ nick => $nick, channels => $channels });
    }
    return $self;
}

=head3 C<on_error>

Called when the bot receives an error message or socket error message from the
server. Circle will schedule itself to try reconnecting in 30 seconds, and
then call the C<on_error> handlers. The parameters passed are:

=over

=item C<nick>

The bot's own nickname at the time of the disconnect.

=item C<channels>

A list of the channels the bot was on. Useful for logging that the bot has
left (or been disconnected from ) those channels.

=item C<body>

The body of the error message.

=back

=cut

sub _irc_error {
    my ( $self, $kernel, $nick_info ) = @_[ OBJECT, KERNEL, ARG1 ];

    my $err = $self->_decode( $_[ARG0] );
    $kernel->delay('reconnect', 30);

    my $nick     = $self->_decode( $nick_info->{Nick} );
    my $channels = [ keys %{ $self->_decode( $_[ARG2] ) } ];
    for my $h (@{ $self->handlers }) {
        last if $h->on_error({ nick => $nick, body => _trim $err, channels => $channels });
    }
    return $self;
}

=head3 C<on_join>

Called when a user joins a channel. If it's the bot itself that's joined the
channel, it will add the channel to the return value of C<channels()>. The
parameters passed to the handlers are:

=over

=item C<nick>

Nickname of the user who joined the channel.

=item C<mask>

The hostmask for that user.

=item C<channel>

The channel that the user joined.

=back

=cut

sub _irc_join {
    my ( $self, $kernel, $channel ) = @_[ OBJECT, KERNEL, ARG1 ];
    my %msg = _msg(@_);
    if ( $self->_decode( $self->irc_client->nick_name ) eq $msg{nick} ) {
        # We've joined the channel. Make a note of it.
        my $channels = $self->channels;
        push @{ $channels }, $channel
            unless grep { $_ eq $channel } @{ $channels };
    }

    for my $h (@{ $self->handlers }) {
        last if $h->on_join({ %msg });
    }
    return $self;
}

=head3 C<on_part>

Called when a user parts (leaves) a channel. If it's the bot itself that's
parted, it will remove the channel to the return value of C<channels()>. The
parameters passed to the handlers are:

=over

=item C<nick>

Nickname of the user who parted the channel.

=item C<mask>

The hostmask for that user.

=item C<channel>

The channel that the user parted.

=item C<body>

The parting message, if any.

=back

=cut

sub _irc_part {
    my ( $self, $kernel, $channel, $body ) = @_[ OBJECT, KERNEL, ARG1 ];
    my %msg = _msg(@_);
    if ( $self->_decode( $self->irc_client->nick_name ) eq $msg{nick} ) {
        # We've parted the channel. Make a note of it.
        $self->channels( [ grep { $_ ne $channel } @{ $self->channels } ] );
    }

    for my $h (@{ $self->handlers }) {
        last if $h->on_part({ %msg });
    }
    return $self;
}

=head3 C<on_kick>

Called when a user kicks another user from a channel. If it's the bot itself
that's kicked, it will remove the channel to the return value of
C<channels()>. The parameters passed to the handlers are:

=over

=item C<nick>

Nickname of the user who did the kicking.

=item C<mask>

The hostmask for that user.

=item C<target>

The nickname of the unfortunate soul who was kicked.

=item C<channel>

The channel from which the user was kicked.

=item C<body>

The body of the kick message, also known as the "reason" the user was kicked.
May be blank if no reason was given.

=back

=cut

sub _irc_kick {
    my ($self, $who, $channel, $target, $body) = @_[OBJECT, ARG0..ARG3];
    my ($nick, $mask) = split /!/ => $who;
    my %msg = $self->_decode(
        nick    => $nick,
        mask    => $mask,
        body    => _trim $body,
        channel => "$channel",
        target  => $target,
    );

    if ( $self->_decode( $self->irc_client->nick_name ) eq $msg{target} ) {
        # We've been kicked from the channel. Make a note of it.
        $self->channels( [ grep { $_ ne $channel } @{ $self->channels } ] );
    }

    for my $h (@{ $self->handlers }) {
        last if $h->on_kick({ %msg });
    }
    return $self;
}

=head3 C<on_nick>

Called when a user changes her nick. The parameters passed to the handlers
are:

=over

=item C<nick>

The user's old nickname.

=item C<from>

An alias for C<nick>.

=item C<mask>

The hostmask for that user.

=item C<to>

The user's new nickname.

=item C<channels>

An array reference of all of the channels common to the user and the bot.

=back

=cut

sub _irc_nick {
    my ($self, $who, $newnick, $channels) = @_[OBJECT, ARG0, ARG1, ARG2];
    my ($nick, $mask) = split /!/ => $who;
    my @msg = (
        nick     => $nick,
        mask     => $mask,
        from     => $nick,
        to       => $newnick,
        channels => $channels,
    );
    for my $h (@{ $self->handlers }) {
        last if $h->on_nick({ @msg });
    }
    return $self;
}

=head3 C<on_quit>

Called when a user quits IRC (or is C<KILL>ed). The parameters passed to the
handlers are:

=over

=item C<nick>

Nickname of the user who quit.

=item C<mask>

The hostmask for that user.

=item C<channels>

An array reference of all of the channels common to the user and the bot.

=item C<body>

The body of the clever, witty message the user left behind on the way out. May
be blank.

=back

=cut

sub _irc_quit {
    my ($self, $who, $body, $channels) = @_[OBJECT, ARG0, ARG1, ARG2];
    my ($nick, $mask) = split /!/ => $who;

    my @msg = $self->_decode(
        nick     => $nick,
        mask     => $mask,
        body     => _trim $body,
        channels => $channels,
    );

    for my $h (@{ $self->handlers }) {
        last if $h->on_quit({ @msg });
    }
    return $self;
}

=head3 C<on_invite>

Called when a user invites the bot to join a channel. The parameters passed to
the handlers are:

=over

=item C<nick>

Nickname of the user who invited the bot.

=item C<mask>

The hostmask for that user.

=item C<channel>

The channel to which the bot has been invited.

=back

=cut

sub _irc_invite {
    my ($self, $who, $channel) = @_[OBJECT, ARG0, ARG1];
    my ($nick, $mask) = split /!/ => $who;
    my @msg = $self->_decode(
        nick    => $nick,
        mask    => $mask,
        channel => $channel,
    );
    for my $h (@{ $self->handlers }) {
        last if $h->on_invite({ @msg });
    }
    return $self;
}

=head3 C<on_whois>

Called when the server responds to a C<WHOIS> command from the bot. The
parameters passed to the handlers are:

=over

=item C<nick>

The user's nickname.

=item C<user>

The user's username.

=item C<host>

The user's hostname.

=item C<real>

The user's real name.

=item C<idle>

The user's idle time in seconds.

=item C<signon>

The epoch time when the user signed on (will be C<undef> if the IRC server
doesn't include this information).

=item C<channels>

An array reference listing the visible channels the user is on; Each channel
name may be prefixed with "@", "+", and/or "%" depending on whether the user
is an operator, is voiced, or is a half-operator on the channel.

=item C<server>

The user's server (may not be useful on some networks).

=item C<oper>

Indicates whether or not the user is an IRCop; contains the IRC operator
string if they are, C<undef> if they aren't.

=item C<actually>

Some IRC servers report the user's actual IP address; for those servers, the
IP address will be under this key.

=item C<account>

On C<ircu> servers, if the user has registered with services, there will be an
"account" key.

=item C<identified>

On Freenode if the user has identified with C<NICKSERV>, this key will be set
to a true value.

=back

=cut

sub _irc_whois {
    my ($self, $who_data) = @_[OBJECT, ARG0];
    my @msg = $self->_decode( %{ $who_data } );
    for my $h (@{ $self->handlers }) {
        last if $h->on_whois({ @msg });
    }
    return $self;
}

=head3 C<on_whowas>

Called when the server responds to a C<WHOWAS> command from the bot. The
parameters passed to the handlers are the same as those for C<on_whois>, minus
a few keys.

=cut

sub _irc_whowas {
    my ($self, $who_data) = @_[OBJECT, ARG0];
    my @msg = $self->_decode( %{ $who_data } );
    for my $h (@{ $self->handlers }) {
        last if $h->on_whowas({ @msg });
    }
    return $self;
}

=head3 C<on_ison>

Called when the server responds to an C<ISON> command from the bot. The
parameters passed to the handlers are:

=over

=item C<nicks>

An array reference listing the subset of the nicknames queried in the
C<ISON> command that are actually logged into the server.

=back

=cut

sub _irc_ison {
    my ($self, $nicks) = @_[OBJECT, ARG1];
    my @nicks = $self->_decode(split /\s+/, $nicks);
    $nicks[0] =~ s/^\://;
    for my $h (@{ $self->handlers }) {
        last if $h->on_ison({ nicks => [ @nicks ] });
    }
    return $self;
}

=head3 C<on_topic>

Called when a user sets the topic on a channel. The parameters passed to the
handlers are:

=over

=item C<nick>

Nickname of the user who set the topic.

=item C<mask>

The hostmask for that user.

=item C<body>

The body of the new topic.

=item C<channel>

The channel on which the topic was set.

=item C<at>

The time at which the topic was set, in seconds from the epoch. This parameter
will only be set when Circle connects to a channel, not when someone has
actually just set the topic.

=back

=cut

sub _irc_topic {
    my $self = shift;
    my %msg = $self->_msg(@_);
    for my $h (@{ $self->handlers }) {
        last if $h->on_topic({ %msg });
    }
    return $self;
}

sub _irc_332 {
    my ($self, $raw) = @_[OBJECT, ARG1];
    my ($channel, $topic) = split /[ ]:/ => $raw, 2;
    $self->_buffer(_trim $topic);
    return $self;
}

sub _irc_333 {
    my ($self, $server, $raw) = @_[OBJECT, ARG0, ARG1];
    my ($channel, $who, $epoch) = split(/\s+/, $raw, 3);
    my ($nick, $mask) = split /!/ => $who;

    my @msg = $self->_decode(
        nick    => $nick,
        mask    => $mask,
        body    => _trim $self->_buffer,
        channel => $channel,
        at      => $epoch,
    );

    $self->_buffer(undef);

    for my $h (@{ $self->handlers }) {
        last if $h->on_topic({ @msg });
    }
    return $self;
}

=head3 C<on_user_mode>

Called when a the bot has set its own user mode and the server replies to
confirm such. The parameters passed to the handlers are:

=over

=item C<nick>

Nickname of the user who set the topic.

=item C<mask>

The hostmask for that user.

=item C<mode>

The mode the user set. See L<http://docs.dal.net/docs/modes.html> for a
description of user modes.

=back

=cut

sub _irc_user_mode {
    my ($self, $who, $mode) = @_[OBJECT, ARG0, ARG2];
    my ($nick, $mask) = split /!/ => $who;

    my @msg = $self->_decode(
        nick    => $nick,
        mask    => $mask,
        mode    => $mode,
    );

    for my $h (@{ $self->handlers }) {
        last if $h->on_user_mode({ @msg });
    }
    return $self;
}

=head3 C<on_chan_mode>

Called when a channel operator has changed the mode of a channel. The
parameters passed to the handlers are:

=over

=item C<nick>

Nickname of the user who set the topic.

=item C<mask>

The hostmask for that user.

=item C<channel>

The channel for which the mode was set.

=item C<mode>

The mode set for the channel. See L<http://docs.dal.net/docs/modes.html> for a
description of channel modes.

=item C<arg>

The argument for the mode change, if any. For example, if a user was voiced on
a channel, the C<mode> would be C<+v> and the C<arg> would be the nickname of
the newly-voiced user.

=back

=cut

sub _irc_chan_mode {
    my ($self, $who, $channel, $mode, $arg) = @_[OBJECT, ARG0..ARG3];
    my ($nick, $mask) = split /!/ => $who;

    my @msg = $self->_decode(
        channel => $channel,
        nick    => $nick,
        mask    => $mask,
        mode    => $mode,
        arg     => $arg,
    );

    for my $h (@{ $self->handlers }) {
        last if $h->on_chan_mode({ @msg });
    }
    return $self;
}

=head3 C<on_names>

Called when the bot has sent a C<NAMES> command to the IRC server and the
server has replied with the requested names. The parameters passed to the
handlers are:

=over

=item C<names>

A hash reference of the returned data. The keys are channel names and the
values are hash references with the names data for each channel. For these
values, the keys are the nicknames on the channels, and the values are array
references that may contain any of the following characters:

=over

=item C<o>

The user is an operator on the channel.

=item C<v>

The user is voiced on the channel.

=item C<h>

The user is a half-operator on the channel.

=back

So it might look something like this:

  names => {
      '#perl' => {
          TimToady => [qw( o v )], # operator, voiced
          allison  => [qw( h v )], # halfop, voiced
          CanonMan => [         ],
      },
      '#pgtap' => {
          theory   => [qw( o v )], # operator, voiced
          agliodbs => [qw( v   )], # voiced
          selena   => [qw( v h )], # voiced, halfop
          bob      => [         ],
          duncan   => [         ],
      },
  }

=back

=cut

sub _irc_names {
    my ($self, $body) = @_[OBJECT, ARG1];
    my (undef, $channel, @names) = $self->_decode( split /\s/, $body );
    $names[0] =~ s/^\://;

    # while we get names responses, build an 'in progress' list of people.
    my $names = $self->_buffer || $self->_buffer( {} );
    my $modes_for = $names->{$channel} ||= {};

    for my $nick (@names) {
        my @modes;
        if ($nick =~ s/^([@+%]{1,3})//) {
            for my $char (split '', $1) {
                push @modes, $char eq '@' ? 'o'
                           : $char eq '+' ? 'v'
                           : 'h';
            }
        }
        $modes_for->{$nick} = \@modes;
    }
    return $self;
}

sub _irc_names_end {
    my $self = $_[OBJECT];

    my $names = $self->_buffer;
    $self->_buffer(undef);

    for my $h (@{ $self->handlers }) {
        last if $h->on_names({ names => { %{ $names } } });
    }
    return $self;
}

=head3 C<on_away>

Called when a user has gone away. Note that how quickly and frequently Circle
notices that a user has gone away is determined by the C<away_poll> parameter
to C<new()>. The parameters passed to the handlers are:

=over

=item C<nick>

Nickname of the user who went away.

=item C<mask>

The hostmask for that user.

=item C<channels>

An array reference of the names of the channels common to both the user and
the bot.

=back

=cut

sub _irc_user_away {
    my $self = shift;
    my @msg = $self->_away_msg(@_);
    for my $h (@{ $self->handlers }) {
        last if $h->on_away({ @msg });
    }
    return $self;
}

=head3 C<on_back>

Called when a user is back from being away. Note that how quickly and
frequently Circle notices that a user has gone away or come back is determined
by the C<away_poll> parameter to C<new()>. The parameters passed to the
handlers are:

=over

=item C<nick>

Nickname of the user who has come back.

=item C<mask>

The hostmask for that user.

=item C<channels>

An array reference of the names of the channels common to both the user and
the bot.

=back

=cut

sub _irc_user_back {
    my $self = shift;
    my @msg = $self->_away_msg(@_);
    for my $h (@{ $self->handlers }) {
        last if $h->on_back({ @msg });
    }
    return $self;
}

=head3 C<on_notice>

Called when the bot has received a notice. The parameters passed to the
handlers are:

=over

=item C<nick>

Nickname of the user who sent the notice.

=item C<mask>

The hostmask for that user.

=item C<body>

The body of the notice.

=item C<targets>

An array reference of the nicknames to whom and/or channels to which the the
notice was sent.

=back

=cut

sub _irc_notice {
    my ($self, $who, $targets, $body) = @_[OBJECT, ARG0..ARG2];
    my ($nick, $mask) = split /!/ => $who;
    my @msg = $self->_decode(
        nick    => $nick,
        mask    => $mask,
        body    => _trim $body,
        targets => $targets,
    );
    for my $h (@{ $self->handlers }) {
        last if $h->on_notice({ @msg });
    }
    return $self;
}


# the server can tell us what it thinks the time is. We use this as
# a work-around for the 'broken' behaviour of freenode (it doesn't send
# ping messages)
# Not passed to handlers.
sub _get_time {
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->post( $self->_poe_name => 'time' );
    return $self;
}

# Not passed to handlers.
sub _irc_391 {
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->delay( reconnect => $self->reconnect_in );
    $kernel->delay( _get_time => $self->reconnect_in / 2 );
    return $self;
}

# Not passed to handlers.
sub _tick {
    my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
    my $delay = $self->tick_in;
    $kernel->delay( tick => $delay ) if $delay;
    return $self;
}

=head3 C<on_shutdown>

Called when the bot has been asked to shut down. The parameters passed to the
handlers are:

=over

=item C<requestor>

The session ID of the POE component that requested the shutdown.

=back

=cut

sub _irc_shutdown {
    my $self = $_[OBJECT];
    my $by   = $self->_decode($_[ARG0]);

    for my $h (@{ $self->handlers }) {
        last if $h->on_shutdown({ requestor => $by });
    }
    return $self;
}

sub _away_msg {
    my ($self, $who, $channels) = @_[OBJECT, ARG0, ARG1];
    my ($nick, $mask) = split /!/ => $who;
    return $self->_decode(
        nick     => $nick,
        mask     => $mask,
        channels => $channels,
    );
}

sub _msg {
    my ( $self, $kernel, $who, $to, $body ) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2 ];
    $kernel->delay( reconnect => $self->reconnect_in );
    my ($nick, $mask) = split /!/ => $who;
    ( $nick, $to, $body, $mask ) = $self->_decode( $nick, $to, $body, $mask );

    _trim $body if $body;

    return (
        nick    => $nick,
        mask    => $mask,
        body    => $body,
        channel => ref $to ? $to->[0] : $to,
    );
}

sub _to {
    my ($self, $msg) = @_;
    if (my ($maybe_nick) = $msg->{body} =~ /^([^-:,\s]+)(?:\s*[:,-]|\s|$)/) {
        return $self->irc_client->is_channel_member($msg->{channel}, $maybe_nick)
            ? $maybe_nick : undef;
    }
    return;
}

sub _decode {
    my $self = shift;
    my $encoding = lc $self->encoding;

    my @ret;
    for my $octets (@_) {
        eval {
            if (! defined $octets) {
                # Return undef unmolested.
                push @ret, $octets;
            } elsif (ref $octets eq 'ARRAY') {
                push @ret, [ $self->_decode(@{ $octets }) ];
            } elsif (ref $octets eq 'HASH') {
                push @ret, { $self->_decode(%{ $octets }) };
            } else {
                # Assemble a list of encodings to try.
                my @try = ($encoding, grep { $_ ne $encoding } qw(utf-8));
                if (my $enc = Encode::Detect::Detector::detect($octets) ) {
                    # Favor the Mozilla Universal character set detector.
                    unshift @try, $enc unless grep { $enc eq $_ } @try;
                }

                # Try to decode with each encoding until one works.
                my $utf8;
                for my $enc (@try) {
                    $utf8 = eval { Encode::decode( $enc, $octets, Encode::FB_CROAK ) };
                    last if not $@;
                }

                if ($@) {
                    # None of those worked, insert "\xHH" for malformed characters.
                    push @ret, NFC Encode::decode($encoding, $octets, Encode::FB_PERLQQ );
                } else {
                    push @ret, NFC $utf8;
                }
            }
        }
    }
    return wantarray ? @ret : $ret[0];
}

sub _encode {
    my $self = shift;
    my $encoding = $self->encoding;
    return Encode::encode($encoding, $_[0], Encode::FB_PERLQQ) unless wantarray;
    return map { Encode::encode($encoding, $_, Encode::FB_PERLQQ) } @_;
}

sub _random_nick {
    my @things = ( 'a' .. 'z' );
    return join( '', ( map { @things[ rand @things ] } 0 .. 4 ), 'bot' );
}

1;

__END__

=head1 To Do

=over

=item *

Add constraint such that channels always start with "#".

=item *

Map channels to networks instead of hosts.

=item *

Add a "help" command to the core bot.

=item *

Add some command to get circle to ignore an event. For example, a user should
be able to type:

  \ignore Damn I hate that guy who just left!

And circle would not send it to any handlers.

=item *

Add convenience event methods?

=over

=item * C<< $bot->say( $channel, $whatever, $emote ); >>

=item * C<< $bot->reply( $channel, $nick, $whatever ); >>

=item * C<< $bot->msg( $nick, $whatever, $emote ); >>

=item * C<< $bot->away( $message ); >>

=item * C<< $bot->back; >>

=item * C<< $bot->op( $nick ); >>

=item * C<< $bot->voice( $nick ); >>

=back

=item *

Break this code out into a separate module without the `go()`, `_config()`,
and `_getopt()` stuff? Maybe call it Bot::Handlers? IRC::Handlers?
Bot::IRC::Handlers?

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
