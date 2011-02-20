package Stardust::Demo;
use strict;
use warnings;
use Squatting;
use Data::Dump 'pp';

package Stardust::Demo::Controllers;
use AnyEvent::HTTP;
use JSON;
use Data::Dump 'pp';
use aliased 'Squatting::H';

our $Box = H->new({
  id    => "",
  color => "#dea",
});

our $boxes = H->new({
  columns => 8,
  rows    => 16,
  map     => [],
  init    => sub {
    my ($self) = @_;
    $self->map([]);
    my $rows = $self->rows;
    my $columns = $self->columns;
    for my $i (0 .. $rows) {
      for my $j (0 .. $columns) {
        my $id = "box-$i-$j";
        $self->map->[$i]->[$j] = $Box->clone({ id => $id });
      }
    }
  }
});

$boxes->init;

our %C;
our @C = (
  C(
    Home => [ '/' ],
    get => sub {
      my ($self) = @_;
      my $v = $self->v;
      $v->{demo} = 0;
      $v->{base} = $Stardust::CONFIG{base};
      $self->render('home');
    },
  ),

  # Run curl commands to see servers making requests to clients
  C(
    CurlCommands => [ '/curl_commands' ],
    get => sub {
      my ($self) = @_;
      my $v = $self->v;
      $v->{demo} = $self->name;
      $v->{base} = $Stardust::CONFIG{base};
      $self->render('curl_commands');
    },
  ),

  C(
    ColorfulBoxes => [ '/colorful_boxes' ],
    get => sub {
      my ($self) = @_;
      my $v = $self->v;
      $v->{demo}  = $self->name;
      $v->{base}  = $Stardust::CONFIG{base};
      $v->{boxes} = $boxes;
      $self->render('colorful_boxes');
    },
    post => sub {
      my ($self) = @_;
      my $input = $self->input;
      my $base = $Stardust::CONFIG{base};
      my $color = $input->{color} || "#ccf";
      my $url = "http://localhost:5742".Stardust::Controllers::R('Channel', 'colorful_boxes'),
      my $id = $self->input->{id};
      my ($blah, $x, $y) = split('-', $id);
      # my $box = $boxes->map->[$y]->[$x];
      # $box->color($color);
      my $body = "m=".encode_json({
        type  => "ColorBox",
        id    => $id,
        color => $color,
      });
      http_post(
        $url,
        $body,
        sub {  }
      );
      warn "post";
    }
  ),

  C(
    404 => [ '/(.+)' ],
    get => sub {
      my ($self, $path) = @_;
      my $v = $self->v;
      $v->{demo} = 0;
      $v->{path} = $path;
      $v->{base} = $Stardust::CONFIG{base};
      $self->status = 404;
      $self->render(404);
    }
  ),
);

package Stardust::Demo::Views;
use strict;
use warnings;
no  warnings 'once';
use base 'Tenjin::Context';
use File::ShareDir;
use Tenjin;
use Encode;
{
  no warnings;
  eval $Tenjin::Context::defun;
}
*escape = sub {
  my ($s) = @_;
  $s = encode('utf8', $s);
  $s =~ s/[&<>"]/$Tenjin::Helper::Html::_escape_table{$&}/ge if ($s);
  return $s;
};
$Tenjin::CONTEXT_CLASS = 'Stardust::Demo::Views';

# XXX - terrible hack
*Tenjin::Context::R = \&R;

my $template_path = File::ShareDir::dist_dir('Stardust');

our $tenjin = Tenjin->new({
  path    => [ $template_path ],
  postfix => '.html',
  cache   => 0,
});

our @V = (
  V(
    'tenjin',
    layout => sub {
      my ($self, $v, $content) = @_;
      $v->{content} = $content;
      $tenjin->render(":layout", $v);
    },
    _ => sub {
      my ($self, $v) = @_;
      $v->{self} = $self;
      $tenjin->render(":$self->{template}", $v);
    }
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
