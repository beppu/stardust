package Stardust::Demo;
use strict;
use warnings;
use base 'Squatting';
use Data::Dump 'pp';

package Stardust::Demo::Controllers;
use Squatting ':controllers';
use AnyEvent::HTTP;
use Data::Dump 'pp';

our %C;
our @C = (
  C(
    Home => [ '/' ],
    get => sub {
      my ($self) = @_;
      $self->v->{base} = $Stardust::CONFIG{base};
      $self->render('home');
    },
  ),
  C(
    CurlCommands => [ '/curl_commands' ],
    get => sub {
      my ($self) = @_;
      $self->v->{base} = $Stardust::CONFIG{base};
      $self->render('curl_commands');
    },
  ),
  C(
    ColorfulBoxes => [ '/colorful_boxes' ],
    get => sub {
      my ($self) = @_;
      $self->v->{base} = $Stardust::CONFIG{base};
      $self->render('movable_sprites');
    },
  ),
  C(
    404 => [ '/(.+)' ],
    get => sub {
      my ($self, $path) = @_;
      $self->v->{path} = $path;
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
use Squatting ':views';
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

my $template_path = File::ShareDir::dist_dir('Stardust');

our $tenjin = Tenjin::Engine->new({
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
