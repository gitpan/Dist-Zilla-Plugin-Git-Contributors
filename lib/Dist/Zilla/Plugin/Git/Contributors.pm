use strict;
use warnings;
package Dist::Zilla::Plugin::Git::Contributors;
BEGIN {
  $Dist::Zilla::Plugin::Git::Contributors::AUTHORITY = 'cpan:ETHER';
}
# git description: b633a10
$Dist::Zilla::Plugin::Git::Contributors::VERSION = '0.001';
# ABSTRACT: Add contributor names from git to your distribution
# KEYWORDS: plugin distribution metadata git contributors authors commits
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with 'Dist::Zilla::Role::MetaProvider';

use List::Util 1.33 'none';
use namespace::autoclean;

has include_authors => (
    is => 'ro', isa => 'Bool',
    default => 0,
);

sub metadata
{
    my $self = shift;

    +{ x_contributors => $self->_contributors }
}

sub _contributors
{
    my $self = shift;

    my $git = Git::Wrapper->new('.');
    my @data = $git->shortlog('HEAD', { email => 1, summary => 1});

    my @contributors = map { utf8::decode($_); m/^\s*\d+\s*(.*)$/g; } @data;

    if (not $self->include_authors)
    {
        my $authors = $self->zilla->authors;
        @contributors = grep {
            my $contributor = $_;
            none { $contributor eq $_ } @$authors;
        } @contributors;
    }

    return \@contributors;
}

__PACKAGE__->meta->make_immutable;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Git::Contributors - Add contributor names from git to your distribution

=head1 VERSION

version 0.001

=head1 SYNOPSIS

In your F<dist.ini>:

    [Git::Contributors]

=head1 DESCRIPTION

This is a L<Dist::Zilla> plugin that extracts all names and email addresses
from git commits in your repository and adds them to the distribution metadata
under the C<x_contributors> key.  It takes a minimalist approach to this -- no
data is stuffed into other locations, including stashes -- if other plugins
wish to work with this information, they should extract it from the
distribution metadata.

=head1 CONFIGURATION OPTIONS

=head2 C<include_authors>

By default, distribution authors are removed from the list of extracted git
contributors. To disable this, set C<include_authors> = 1.

=for stopwords canonicalizing

=head2 CANONICALIZING NAMES AND ADDRESSES

If you or a contributor uses multiple names and/or email addresses to make
commits and would like them mapped to a canonical value, you can do this by
adding a F<.mailmap> file to your git repository, with entries formatted as
described in "MAPPING AUTHORS" in C<git help shortlog>
(L<https://www.kernel.org/pub/software/scm/git/docs/git-shortlog.html>).

=head2 ADDING CONTRIBUTORS TO POD DOCUMENTATION

You can add the contributor names to your module documentation by using
L<Pod::Weaver> in conjunction with L<Pod::Weaver::Section::Contributors>.

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-Git-Contributors>
(or L<bug-Dist-Zilla-Plugin-Git-Contributors@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-Git-Contributors@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 SEE ALSO

=over 4

=item *

L<How I'm using Dist::Zilla to give credit to contributors|http://www.dagolden.com/index.php/1921/how-im-using-distzilla-to-give-credit-to-contributors/>

=item *

L<Pod::Weaver::Section::Contributors>

=item *

L<Dist::Zilla::Plugin::Meta::Contributors>

=item *

L<Dist::Zilla::Plugin::ContributorsFile>

=item *

L<Dist::Zilla::Plugin::ContributorsFromGit>

=item *

L<Dist::Zilla::Plugin::ContributorsFromPod>

=item *

L<Module::Install::Contributors>

=back

=for Pod::Coverage metadata

=head1 AUTHOR

Karen Etheridge <ether@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
