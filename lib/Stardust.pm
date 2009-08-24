package Stardust;
use strict;
use warnings;
use base 'Squatting';
use IO::All;
use Set::Object;

our $VERSION = '1.00';

our %CONFIG = (
  debug          => 0,           # Noisy output to STDERR?
  allow_from     => '127.0.0.1', # Who may send us COMET messages?
  auth_user      => undef,       # If defined, make them HTTP Auth themselves
  auth_pass      => undef,       # ...before allowing them to send COMET messages to us.
  channel_length => 8,           # How many messages should a channel hold on to?
  timeout        => 55,          # How many seconds before we end a long-poll request?
  port           => 5742,        # What port should Stardust listen on?
  base           => '/',         # What should the base path for Stardust's URLs be?
);

package Stardust::Controllers;
use strict;
use warnings;
use aliased 'Squatting::H';
use Squatting ':controllers';
use Time::HiRes 'time';
use JSON;
use AnyEvent;
use Coro;
use Coro::AnyEvent;
use Coro::Timer;
use Coro::Signal;

our $Channel = H->new({
  i        => 0,                       # current position in messages array
  size     => $CONFIG{channel_length}, # size of messages array
  messages => [],                      # circular array of messages
  signal   => Coro::Signal->new,       # signal that is broadcast upon write

  # write messages to this channel
  write => sub {
    my ($self, @messages) = @_;
    my $i    = $self->{i};
    # warn $i;
    my $size = $self->{size};
    my $m    = $self->{messages};
    for (@messages) {
      $_->{time} = time;
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
    grep { defined && ($_->{time} > $last) } $self->read($self->size);
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

  # Channel - [private]
  # To generate messages on a channel, POST a JSON object to this controller
  # using the CGI variable 'm'.
  #
  # NOTE: 
  #   The post method of this controller is meant for INTERNAL USE ONLY.
  #     By default, only clients from 127.0.0.1 can access this controller.
  #     Everyone else is rejected.
  C(
    Channel => [ '/channel/([\w+]+)' ],

    # It should return a list of channel objects. 
    get => sub {
      my ($self, $channels) = @_;
      my @ch = split(/\+/, $channels);
      encode_json([ map { my $ch = channel($_); { name => $ch->name, subscribers => [] } } @ch ]);
    },

    # It should accept a JSON object and send it to the appropriate channels.
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

        # when running this behind a reverse proxy,
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

  $ stardust.pl -p 5555 --relocate '/comet'

Making pages subscribe to channel 'foo':

  <script>
    var uniqueId = Math.random().toString();
    $.ev.loop('/comet/messages/'+uniqueId, [ 'foo' ], {
      "*": function(ev) {
      }
    });
  </script>

Posting JSON messages to channel 'foo':

  curl -d 'm={ "type": "TestMessage", "data": [3, 2, 1] }' \
    http://localhost:5555/channel/foo
  
=head1 DESCRIPTION

=head2 How to Integrate Stardust Into an Existing Web Application

=head2 Client-side Javascript Libraries for Long Polling


=head2 Ambient Messages from the Server Side


=head1 API

Communication with the Stardust COMET server uses JSON over HTTP.
The following URLs represent your API.

=head2 GET  /

This is just a little informational JSON-encoded data that tells you what
version of the Stardust server you're using.

=head2 GET  /channel/([\w+]+)

=head2 POST /channel/([\w+]+)

=head2 GET  /messages/(.*)

=head1 CONFIGURATION

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
