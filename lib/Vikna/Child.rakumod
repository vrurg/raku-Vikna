use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::Child> - child rol

=DESCRIPTION

Very simplistic role only defining C<$.parent> attribute, C<set-parent> and C<has-parent> methods.

Requires C<id> method from the consuming class.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.3/docs/md/Vikna/Manual.md>

=AUTHOR

Vadim Belman <vrurg@cpan.org>

=end pod

use Vikna::Parent;
use Vikna::Object;
unit role Vikna::Child;

method id {...}

has Vikna::Parent $.parent;

method set-parent($!parent) { }

method has-parent { ? $!parent }
