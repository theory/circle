package App::Circle::Bot;

use strict;
use warnings;
use feature ':5.10';
use utf8;
use Bot::BasicBot 0.81;
use parent 'Bot::BasicBot';

use Class::XSAccessor accessors => {
    dsn => 'dsn',
};


=head1 Name

App::Cicle::Root - App::Circle IRC Bot

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

=head3 C<go>

=cut

sub go {
    my $class = shift;
    $class->new( $class->_config )->run;
}

=head3 C<dbwrite>

=cut

sub dbwrite {
        my ($channel, $who, $line) = @_;
        # mncharity aka putter has an IRC client that prepends some lines with
        # a BOM. Remove that:
        $line =~ s/\A\x{ffef}//;
        my @sql_args = ($channel, $who, time, $line);
        print "'", join( "', '", @sql_args), "'\n";
    }

=head3 C<said>

=cut

sub said {
        my ($self, $e) = @_;
        dbwrite($e->{channel}, $e->{who}, $e->{body} . ($e->{address} ? "($e->{address})" : ''));
        return undef;
    }

=head3 C<emoted>

=cut

sub emoted {
        my $self = shift;
        my $e = shift;
        dbwrite($e->{channel}, '* ' . $e->{who}, $e->{body});
        return undef;

    }

=head3 C<chanjoin>

=cut

sub chanjoin {
        my $self = shift;
        my $e = shift;
        dbwrite($e->{channel}, '',  $e->{who} . ' joined ' . $e->{channel});
        return undef;
    }

=head3 C<chanquit>

=cut

sub chanquit {
        my $self = shift;
        my $e = shift;
        dbwrite($e->{channel}, '', $e->{who} . ' left ' . $e->{channel});
        return undef;
    }

=head3 C<chanpart>

=cut

sub chanpart {
        my $self = shift;
        my $e = shift;
        dbwrite($e->{channel}, '',  $e->{who} . ' left ' . $e->{channel});
        return undef;
    }

=head3 C<_channels_for_nick>

=cut

sub _channels_for_nick {
        my $self = shift;
        my $nick = shift;

        return grep { $self->{channel_data}{$_}{$nick} } keys( %{ $self->{channel_data} } );
    }

=head3 C<userquit>

=cut

sub userquit {
        my $self = shift;
        my $e = shift;
        my $nick = $e->{who};

        foreach my $channel ($self->_channels_for_nick($nick)) {
            $self->chanpart({ who => $nick, channel => $channel });
        }
    }

=head3 C<topic>

=cut

sub topic {
        my $self = shift;
        my $e = shift;
        dbwrite($e->{channel}, "", 'Topic for ' . $e->{channel} . ' is now ' . $e->{topic});
        return undef;
    }

=head3 C<nick_change>

=cut

sub nick_change {
        my $self = shift;
        my($old, $new) = @_;

        foreach my $channel ($self->_channels_for_nick($new)) {
            dbwrite($channel, "", $old . ' is now known as ' . $new);
        }

        return undef;
    }

=head3 C<kicked>

=cut

sub kicked {
        my $self = shift;
        my $e = shift;
        dbwrite($e->{channel}, "", $e->{nick} . ' was kicked by ' . $e->{who} . ': ' . $e->{reason});
        return undef;
    }

=head3 C<help>

=cut

sub help {
        my $self = shift;
        return "This is a passive irc logging bot. Homepage: http://moritz.faui2k3.org/en/ilbot";
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
