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

     --config FILE         YAML configuration file.
  -h --host HOST           IRC server host name. Default: localhost.
  -p --port PORT           IRC server port. Default: 6667.
  -U --username USERNAME   Username to connect as. Optional.
  -P --password PASSWORD   IRC server password. Optional.
  -c --channel CHANNEL     Channel to join. Multiples allowed. Required.
  -n --nick NICK           Nickname to use. Multiples allowed. Default: circle.
  -e --encoding ENCODING   Assumed message character encoding. Default: UTF-8.
     --ssl                 Connect via SSL. Optional.
  -V --verbose             Incremental verbose mode.
  -H --help                Print a usage statement and exit.
  -M --man                 Print the complete documentation and exit.
  -v --version             Print the version number and exit.

=cut

sub _config {
    my $self = shift;
    require Getopt::Long;
    Getopt::Long::Configure( qw(bundling) );

    my %opts = (
        server  => 'localhost',
        port    => 6667,
        nick    => ['circle'],
        charset => 'UTF-8',
        verbose => 0,
    );

    Getopt::Long::GetOptions(
        'config=s'          => \$opts{config},
        'host|h=s'          => \$opts{server},
        'port|p=s'          => \$opts{port},
        'channel|c=s@'      => \$opts{channels},
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

    # Modify options and set defaults as appropriate.
    my @nicks = @{ $opts{nick} };
    $opts{nick} = shift @nicks;
    $opts{alt_nicks} = \@nicks if @nicks;

    # Check required options.
    for my $spec ( [host => 'server'], 'port', [channel => 'channels'] ) {
        my ($opt, $key) = ref $spec ? @{ $spec } : ($spec, $spec);
        next if $opts{$key};
        $self->_pod2usage( '-message' => "Missing required --$opt option" );
    }

    return \%opts;
}

=head3 C<run>

=cut

sub run {
    my $class = shift;
    $class->new( $class->_config )->SUPER::run;
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
