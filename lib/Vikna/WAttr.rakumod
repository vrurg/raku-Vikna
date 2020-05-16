use v6.e.PREVIEW;

=begin pod
=NAME

C<Vikna::WAttr> - widget attributes

=DESCRIPTION

Inherits from L<V<Vikna::CAttr>>.

Class represents default widget attributes.

=ATTRIBUTES

=head3 C<$.pattern>

Background pattern of a widget. Interpretation of this attribute depends on a particular widget. But
L<C<Vikna::Widget>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Widget.md>
defines it as a string which fills the background. Say, if set to I<'.'> then the background will be filled with dots.

=ROUTINES

=head3 C<multi sub wattr($fg, $bg?, $style?, $pattern?)>
=head3 C<multi sub wattr(:$fg, :$bg?, :$style?, :$pattern?)>

Shortcut to create a C<Vikna::WAttr> instance.

=head1 SEE ALSO

L<C<Vikna>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna.md>,
L<C<Vikna::Manual>|https://github.com/vrurg/raku-Vikna/blob/v0.0.1/docs/md/Vikna/Manual.md>,

=AUTHOR Vadim Belman <vrurg@cpan.org>

=end pod

# Widget default attributes
unit class Vikna::WAttr;

use Vikna::CAttr;
use Vikna::Utils;

also is Vikna::CAttr;

has $.pattern is rw;

method build-Profile {
    %( :$!pattern, |callsame )
}

proto wattr(|) is export {*}
multi wattr($fg, $bg?, $style?, $pattern?) {
    ::?CLASS.new(:$fg, :$bg, :$style, :$pattern)
}
multi wattr(*%profile) {
    ::?CLASS.new(|%profile)
}
