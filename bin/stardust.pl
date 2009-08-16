#!/usr/bin/perl
use strict;
use warnings;
use Stardust 'On::Continuity', 'With::Log', 'With::AccessTrace'; # XXX - remove trace and make logging optional
use Getopt::Long;

# I usually prefer leaving the ".pl" extension off of perl scripts,
# but I intend to write a Javascript and Erlang implementation of
# the Stardust server, so using a file extension seemed like a good
# way to differentiate them.

my $__help;
my $__version;
my $__port = 5742;
#            STAR
my $__timeout;
my $__base;
my $__demo;

GetOptions(
  "help|h"      => \$__help,
  "version|v"   => \$__version,
  "port|p=n"    => \$__port,
  "timeout|t=n" => \$__timeout,
  "base|b=s"    => \$__base,
  "demo"        => \$__demo,
);

if ($__help) {
print qq|Stardust COMET Server $Stardust::VERSION (Perl)
  http://github.com/beppu/stardust-pl/tree/master

Usage: stardust.pl [OPTION]...

Options:

  --help, -h            This help message
  --version, -v         What version of Stardust is this?
  --port=NNNN, -p       What port should Stardust listen on?
                          (default: $Stardust::CONFIG{port})
  --base=PATH, -b       What is the base path for the Stardust URLs?
                          (default: "$Stardust::CONFIG{base}")

Examples:

  Run Stardust on port 5555 with all URLs prefixed with "/comet":

    stardust.pl --port=5555 --base=/comet

  Post a message to channel "foo" on the server we just started:

    curl -d 'm={ "type": "Test", "data": [1,2,3] }' \\
      http://localhost:5555/comet/channel/foo

|;
exit;
}

if ($__version) {
  print "Stardust COMET Server $Stardust::VERSION (Perl)\n";
  exit;
}

if ($__demo) {
  require Stardust::Demo;
  Stardust->mount('Stardust::Demo' => '/demo');
}
Stardust->init();
Stardust->relocate($__base) if $__base;
Stardust->continue(
  port    => $__port,
  docroot => 'share',
);

__END__

=head1 NAME

stardust.pl - Stardust COMET Server (Perl)

=head1 SYNOPSIS

Run Stardust on port 5555 with all URLs starting with "/comet":

  stardust.pl --port=5555 --base=/comet

Post a message to channel "foo" on the server we just started:

  curl -d 'm={ "type": "Test", "data": [1,2,3] }' \
    http://localhost:5555/comet/channel/foo

=head1 DESCRIPTION

This is a start-up script for the Perl version of the Stardust COMET Server.

=head1 AUTHOR

John BEPPU E<lt>beppu@cpan.orgE<gt>

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
