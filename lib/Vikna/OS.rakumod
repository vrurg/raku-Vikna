use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::OS> - base role for OS-specific layer class

=ATTRIBUTES

=head3 L<C<Vikna::Screen>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Screen.md> C<$.screen>

Screen driver.

=head1 REQUIRED METHODS

=head3 C<build-screen()>

Method must construct and return a L<C<Vikna::Screen>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Screen.md> object to initialize C<$.screen>. See
L<C<AttrX::Mooish>|https://modules.raku.org/dist/AttrX::Mooish> for lazy attributes implementation.

=head3 C<inputs()>

Method is expected to return a list of
L<C<Vikna::EventEmitter>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/EventEmitter.md>
objects for each OS-provided input device like a mouse or a keyboard.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Manual.md>,
L<C<Vikna::Classes>|https://github.com/vrurg/raku-Vikna/blob/v0.0.2/docs/md/Vikna/Classes.md>

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

unit role Vikna::OS;

use Vikna::Object;

also is Vikna::Object;

use Vikna::Screen;
use AttrX::Mooish;

has Vikna::Screen $.screen is mooish(:lazy);

method build-screen { ... }
method inputs {...}
