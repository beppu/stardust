package Stardust::Demo;
use strict;
use warnings;
use base 'Squatting';

package Stardust::Demo::Controllers;
use Squatting ':controllers';
use AnyEvent::HTTP;

# XXX HACK XXX
my $stardust = "http://localhost:5742/comet/channel/foo";

our @C = (
  C(
    Home => [ '/' ],
    get => sub {
      my ($self) = @_;
      $self->render('home');
    },
  ),
  C(
    Greeting => [ '/greeting' ],
    post => sub {
      my ($self) = @_;
      my $message = $self->input->{message};
      my $ch = Stardust::Controllers::channel('foo');
      $ch->write({ type => 'Greeting', message => $message });
    },
  ),
  C(
    Background => [ '/background' ],
    post => sub {
      my ($self) = @_;
      my $color = $self->input->{color};
    },
  ),
  C(
    404 => [ '/(.*)' ],
    get => sub {
      my ($self, $path) = @_;
      $self->status(404);
      $self->render('404');
    }
  ),
);

package Stardust::Demo::Views;
use Squatting ':views';
our @V = (
  V(
    'default',
    home => sub {
      my ($self, $v) = @_;
      qq|
        <html>
          <head>
            <title>Stardust::Demo</title>
            <script src="/js/jquery-1.3.2.js"></script>
            <script src="/js/jquery.ev.js"></script>
            <script src="/js/demo.js"></script>
          </head>
          <body>
<pre>
curl -d 'm={ "type": "Greeting", "message": "Hello, World" }' http://localhost:5742/comet/channel/foo
curl -d 'm={ "type": "Color", "color": "#dea" }' http://localhost:5742/comet/channel/foo
</pre>
            <h1>Events</h1>
            <ul id="events">
            </ul>
          </body>
        </html>
      |;
    },
    404 => sub {
      my ($self, $v) = @_;
      qq|
        <html>
          <head>
            <title>???</title>
          </head>
          <body>
            No lo tengo.
          </body>
        </html>
      |;
    },
  ),
);

1;

__END__

=head1 NAME

Stardust::Demo - an integrated demo of the Stardust COMET server

=head1 SYNOPSIS

Pass --demo to stardust.pl on startup.

  stardust.pl --demo

Then view:

  http://localhost:5742/demo/

=head1 DESCRIPTION

=head1 AUTHOR

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
# vim:tabstop=2 softtabstop=2 shiftwidth=2 shiftround expandtab
