package Stardust;
use 5.008;
use strict;
use warnings;
use Squatting;
use IO::All;
use Set::Object;
use File::ShareDir ':ALL';

our $VERSION = '0.08';

our %CONFIG = (
  debug          => 0,           # Noisy output to STDERR?
  allow_from     => '127.0.0.1', # Who may send us COMET messages?
  auth_user      => undef,       # If defined, make them HTTP Auth themselves
  auth_pass      => undef,       # ...before allowing them to send COMET messages to us.
  channel_length => 8,           # How many messages should a channel hold on to?
  timeout        => 55,          # How many seconds before we end a long-poll request?
  port           => 5742,        # What port should Stardust listen on?
  base           => '',          # What should the base path for Stardust's URLs be?
);

sub continue {
  my ($class, @args) = @_;
  if ($CONFIG{demo}) {
    require Sys::Hostname;
    my $hostname = lc Sys::Hostname::hostname();
    my $path = "/demo/";
    if ($CONFIG{base}) {
      $path = "$CONFIG{base}$path";
    }
    print "      The demo is at: http://$hostname:$CONFIG{port}$path\n";
  }
  $class->next::method(@args, docroot => dist_dir('Stardust'));
}

package Stardust::Controllers;
use strict;
use warnings;
use aliased 'Squatting::H';
use Time::HiRes 'time';
use JSON;
use AnyEvent;
use Coro;
use Coro::AnyEvent;
use Coro::Timer;
use Coro::Signal;

our $Channel = H->new({
  i           => 0,                       # current position in messages array
  size        => $CONFIG{channel_length}, # size of messages array
  messages    => [],                      # circular array of messages
  signal      => Coro::Signal->new,       # signal that is broadcast upon write
  subscribers => [],                      # subscribed client list

  # write messages to this channel
  write => sub {
    my ($self, @messages) = @_;
    my $i    = $self->{i};
    # warn $i;
    my $size = $self->{size};
    my $m    = $self->{messages};
    for (@messages) {
      $_->{_ts} = time;
      $_->{_ch} = $self->{name};
      $m->[$i++] = $_;
      $i = 0 if ($i >= $size);
    }
    # warn $i;
    $self->{i} = $i;
    $self->signal->broadcast;
    @messages;
  },

  # read $y messages from this channel
  read => sub {
    my ($self, $y) = @_;
    my $size = $self->{size};
    my $m    = $self->{messages};
    my $x;
    $y ||= 1;
    $y = $size if ($y > $size);
    my $i;
    $i = $self->{i} - 1;
    $i = ($size - 1) if ($i < 0);
    my @messages;
    for ($x = 0; $x < $y; $x++) {
      # warn $i;
      unshift @messages, $m->[$i];
      $i--;
      $i = ($size - 1) if ($i < 0);
    }
    @messages;
  },

  # read messages since $last time
  read_since => sub {
    my ($self, $last) = @_;
    grep { defined && ($_->{_ts} > $last) } $self->read($self->size);
  },

  to_hash => sub {
    my ($self) = @_;
    {
      name        => $self->name,
      i           => $self->i,
      size        => $self->size,
      messages    => $self->messages,
      subscribers => $self->subscribers,
    };
  },
});

our %channels;

sub channel {
  my ($name) = @_;
  $channels{$name} ||= $Channel->clone({ name => $name });
}

my $info = qq|{
  "name"     : "Stardust COMET Server",
  "language" : "Perl",
  "version"  : $VERSION
}
|;

our @C = (

  # Home - [public]
  # General Information
  C(
    Home => [ '/' ],
    get => sub {
      my ($self) = @_;
      $self->headers->{'Content-Type'} = 'text/plain';
      return $info;
    },
  ),

  # ChannelList - [public]
  # This returns a list of all channel names currently in use.
  C(
    ChannelList => [ '/channel' ],
    get => sub {
      my ($self) = @_;
      encode_json([ sort keys %channels ]);
    }
  ),

  # Channel
  # To generate messages on a channel, POST a JSON object to this controller
  # using the CGI variable 'm'.
  #
  # NOTE: 
  #   The post method of this controller is meant for INTERNAL USE ONLY.
  #     By default, only clients from 127.0.0.1 can access this controller.
  #     Everyone else is rejected.
  C(
    Channel => [ '/channel/([\w+]+)' ],

    # [public] It should return a list of channel objects.
    get => sub {
      my ($self, $channels) = @_;
      my @ch = split(/\+/, $channels);
      encode_json([ map { my $ch = channel($_); $ch->to_hash } @ch ]);
    },

    # [private] It should accept a JSON object and send it to the appropriate channels.
    post => sub {
      my ($self, $channels) = @_;
      my $m = $self->input->{m};
      return unless $m;

      my @ch = split(/\+/, $channels);
      my @ev;
      my $messages = (ref($m) eq 'ARRAY') ? $m : [$m];
      @ev = map { decode_json($_) } @$messages;
      for my $name (@ch) {
        for my $event (@ev) {
          channel($name)->write($event);
        }
      }
    },
  ),

  # Message - [public]
  # This controller emits a stream of messages to long-polling clients.
  C(
    Message => [ '/channel/([\w+]+)/stream/([.\d]+)' ],
    get => sub {
      warn "coro [$Coro::current]" if $CONFIG{debug};
      my ($self, $channels, $client_id) = @_;
      my $input  = $self->input;
      my $cr     = $self->cr;
      my @ch     = split(/\+/, $channels);
      my $last   = time;
      while (1) {
        # Output
        warn "top of loop" if $CONFIG{debug};
        my @messages = 
          grep { defined } 
          map  { my $ch = channel($_); $ch->read_since($last) } @ch;
        my $x = async {
          warn "printing...".encode_json(\@messages) if $CONFIG{debug};
          $cr->print(encode_json(\@messages));
        };
        $x->join;
        $last = time;

        # Hold for a brief moment until the next long poll request comes in.
        warn "waiting for next request" if ($CONFIG{debug});
        $cr->next;

        # Start 1 coro for each channel we're listening to.
        # Each coro will have the same Coro::Signal object, $activity.
        my $activity = Coro::Signal->new;
        my @coros = map {
          my $ch = channel($_);
          async { $ch->signal->wait; $activity->broadcast };
        } @ch;

        # When running this behind a reverse proxy,
        # it's useful to timeout before your proxy kills the connection.
        push @coros, async {
          my $timeout = Coro::Timer::timeout $CONFIG{timeout};
          while (not $timeout) {
            Coro::schedule;
          }
          warn "timeout\n" if $CONFIG{debug};
          $activity->broadcast;
        };

        # The first coro that does $activity->broadcast wins.
        warn "waiting for activity on any of (@ch); last is $last" if $CONFIG{debug};
        $activity->wait;

        # Cancel the remaining coros.
        for (@coros) { $_->cancel }
      }
    },
    continuity => 1,
  ),

);

1;

__END__

=head1 NAME

Stardust - the simplest COMET server I could imagine

=head1 SYNOPSIS

Installing Stardust:

  $ sudo cpan Stardust

Running the COMET server on port 5555:

  $ stardust.pl --port=5555 --base=/comet

Making pages subscribe to channel 'foo':

  <script>
    var uniqueId = Math.random().toString();
    $.ev.loop('/comet/channel/foo/'+uniqueId, {
      "*": function(ev) {
      }
    });
  </script>

Posting JSON messages to channel 'foo':

  curl -d 'm={ "type": "TestMessage", "data": [3, 2, 1] }' \
    http://localhost:5555/comet/channel/foo

=head1 DESCRIPTION

Stardust is a simple COMET server that can be integrated alongside existing
web applications.


=head1 CONCEPTS

=head2 Message

Messages are just abritrary JSON objects.

=head2 Channel

Channels are where messages travel trough.


=head1 API

Communication with the Stardust COMET server uses JSON over HTTP.
The following URLs represent your API.

=head2 GET  /

This is just a little informational JSON-encoded data that tells you what
version of the Stardust server you're using.

=head2 GET  /channel

This returns a list of all the channel names currently in use as a
JSON-encoded array of strings.

=head2 GET  /channel/([\w+]+)

This returns info about the specified channels as a JSON-encoded
array of objects.

=head2 POST /channel/([\w+]+)

This allows one to send a message to the specified channels.

B<Parameters>:

=over 4

=item m

an JSON-encoded object.  This parameter may be repeated if you want to
send more than one message per POST request.

=back

=head2 GET  /channel/([\w+]+)/stream/([.\d]+)

Long poll on this URL to receive a stream of messages as they become available.
They will come back to you as a JSON-encoded array of objects.

=head1 CONFIGURATION

=head2 nginx static + stardust

  upstream stardust_com_et {
    server 127.0.0.1:5742;
  }

  server {
    listen 80;
    server_name stardust.com.et;
    location / {
      root   /www/stardust.com.et;
      index  index.html index.htm;
    }
    location /comet {
      proxy_pass http://stardust_com_et;
    }
  }

=head2 nginx fastcgi + stardust

TODO

=head2 nginx reverse proxy + stardust

TODO

=head2 apache2 static + stardust

  <VirtualHost *:80>             
                                 
    ServerName stardust.com.et
    DocumentRoot /www/stardust.com.et
    CustomLog logs/stardust.com.et-access_log combined
    ErrorLog  logs/stardust.com.et-error_log

    <Directory "/www/stardust.com.et">         
      Options Indexes FollowSymLinks  
      AllowOverride All
      Order allow,deny
      Allow from all
    </Directory>

    ProxyRequests Off
    ProxyPass        /comet http://127.0.0.1:5742/comet
    ProxyPassReverse /comet http://127.0.0.1:5742/comet

  </VirtualHost>

=head2 apache2 fastcgi + stardust

TODO

=head2 apache2 reverse proxy + stardust

TODO

=head1 SEE ALSO

=over 4

=item GitHub Repository

L<http://github.com/beppu/stardust/tree/master>

=item jQuery.ev

L<http://github.com/beppu/jquery-ev/tree/master>

=item AnyEvent, Coro, Continuity

L<AnyEvent>, L<Coro>, L<Continuity>

=item Squatting

L<Squatting>

L<http://groups.google.com/group/squatting-framework>

=back

=head1 AUTHOR

John BEPPU E<lt>beppu@cpan.orgE<gt>

=head1 SPECIAL THANKS

Thanks to Marc Lehmann for his work on L<AnyEvent> and L<Coro>.

Thanks to Brock Wilcox and Scott Walters for their work on L<Continuity>.

=head1 COPYRIGHT

Copyright (c) 2009 John BEPPU E<lt>beppu@cpan.orgE<gt>.

=head2 The "MIT" License

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut

# Local Variables: ***
# mode: cperl ***
# indent-tabs-mode: nil ***
# cperl-close-paren-offset: -2 ***
# cperl-continued-statement-offset: 2 ***
# cperl-indent-level: 2 ***
# cperl-indent-parens-as-block: t ***
# cperl-tab-always-indent: nil ***
# End: ***
# vim:tabstop=8 softtabstop=2 shiftwidth=2 shiftround expandtab
