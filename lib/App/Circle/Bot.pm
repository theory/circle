package App::Circle::Bot;

use strict;
use warnings;
use feature ':5.10';
use utf8;
use Bot::BasicBot 0.81;
use parent 'Bot::BasicBot';
#use App::Circle;

=head1 Name

App::Cicle::Root - App::Circle IRC Bot

=head1 Usage

  circle --host irc.freenode.net \
         --channel '#perl'

=head1 Description

The App::Circle IRC bot.

=head1 Options

  -c --config FILE         YAML configuration file.
  -n --nick NICK           Nickname to use. Multiples allowed. Default: circle.
  -j --join CHANNEL        Channel to join. Multiples allowed. Required.
  -h --host HOST           IRC server host name. Default: localhost.
  -p --port PORT           IRC server port. Default: 6667.
  -U --username USERNAME   Username to connect as. Optional.
  -P --password PASSWORD   IRC server password. Optional.
  -e --encoding ENCODING   Assumed message character encoding. Default: UTF-8.
     --ssl                 Connect via SSL. Optional.
  -V --verbose             Incremental verbose mode.
  -H --help                Print a usage statement and exit.
  -M --man                 Print the complete documentation and exit.
  -v --version             Print the version number and exit.

=head2 Configuration File

The configuration file specified via C<--config> is in YAML format. Here's a simple
example:

  ---
  bot:
    host: example.com
    port: 6666
    join: postgresql
    nick: fred
    username: bobby
    password: ybbob
    encoding: big-5
    ssl: 1
    verbose: 2

These keys may be used instead of command-line options. However, command-line
options override any values found in the configuration file. Here are the
supported top-level keys:

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
one channel, or as a list for multple channels. Equivalent to C<--join>

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

=item C<verbose>

  verbose: 1

Verbosity level. Useful for debugging. Defaults to 0, but may go up to 3 for
serious debugging output. Equivalent to C<--verbose>.

=back

=cut

sub _config {
    my $self = shift;

    my $opts = $self->_getopt();

    if (my $file = delete $opts->{config}) {
        require YAML::Syck;
        my $config = YAML::Syck::LoadFile($file);
        if (my $bc = $config->{bot}) {
            while (my ($k, $v) = each %{ $bc }) {
                # Perform transformations.
                given ($k) {
                    when ('join') { $v = [$v] unless ref $v; $k = 'channels'; }
                    when ('host') { $k = 'server' }
                    when ('encoding') { $k = 'charset' }
                }

                # Don't override command-line options.
                $opts->{$k} = $v unless defined $opts->{$k};
            }
        }
    }

    # Modify nicks.
    if (ref $opts->{nick}) {
        my @nicks = @{ $opts->{nick} };
        $opts->{nick} = shift @nicks;
        $opts->{alt_nicks} = \@nicks if @nicks;
    }

    # Set default values.
    for my $spec (
        [ server  => 'localhost' ],
        [ port    => 6667        ],
        [ nick    => 'circle'    ],
        [ charset => 'UTF-8'     ],
        [ verbose => 0           ],
    ) {
        $opts->{$spec->[0]} = $spec->[1] unless defined $opts->{$spec->[0]};
    }

    # Check required options.
    for my $spec ( [host => 'server'], 'port', [join => 'channels'] ) {
        my ($opt, $key) = ref $spec ? @{ $spec } : ($spec, $spec);
        next if $opts->{$key};
        $self->_pod2usage( '-message' => "Missing required --$opt option" );
    }

    return %{ $opts };
}

sub _getopt {
    my $self = shift;
    require Getopt::Long;
    Getopt::Long::Configure( qw(bundling) );

    my %opts;
    Getopt::Long::GetOptions(
        'config|c=s'        => \$opts{config},
        'host|h=s'          => \$opts{server},
        'port|p=s'          => \$opts{port},
        'join|j=s@'         => \$opts{channels},
        'nick|n=s@'         => \$opts{nick},
        'username|user|U=s' => \$opts{username},
        'password|pass|P=s' => \$opts{password},
        'encoding|e=s'      => \$opts{charset},
        'ssl'               => \$opts{ssl},
        'verbose|V+'        => \$opts{verbose},
        'help|H'            => \$opts{help},
        'man|M'             => \$opts{man},
        'version|v'         => \$opts{version},
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

=head3 C<run>

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
