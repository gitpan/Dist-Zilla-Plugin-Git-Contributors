use strict;
use warnings;
package Dist::Zilla::Plugin::Git::Contributors;
# git description: v0.007-10-gf16ab82
$Dist::Zilla::Plugin::Git::Contributors::VERSION = '0.008';
# ABSTRACT: Add contributor names from git to your distribution
# KEYWORDS: plugin distribution metadata git contributors authors commits
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with 'Dist::Zilla::Role::MetaProvider';

use List::Util 1.33 'none';
use Git::Wrapper 0.035;
use Try::Tiny;
use Safe::Isa;
use Path::Tiny;
use Data::Dumper;
use Moose::Util::TypeConstraints 'enum';
use Unicode::Collate 0.53;
use namespace::autoclean;

sub mvp_multivalue_args { qw(paths) }
sub mvp_aliases { return { path => 'paths' } }

has include_authors => (
    is => 'ro', isa => 'Bool',
    default => 0,
);

has include_releaser => (
    is => 'ro', isa => 'Bool',
    default => 1,
);

has order_by => (
    is => 'ro', isa => enum([qw(name commits)]),
    default => 'name',
);

has paths => (
    isa => 'ArrayRef[Str]',
    lazy => 1,
    default => sub { [] },
    traits => ['Array'],
    handles => { paths => 'elements' },
);

around dump_config => sub
{
    my ($orig, $self) = @_;
    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        include_authors => $self->include_authors,
        include_releaser  => $self->include_releaser,
        order_by => $self->order_by,
        paths => [ $self->paths ],
    };

    return $config;
};

sub metadata
{
    my $self = shift;

    my $contributors = $self->_contributors;
    return if not @$contributors;

    $self->_check_podweaver;
    +{ x_contributors => $contributors };
}

sub _contributors
{
    my $self = shift;

    my $in_repo;
    try {
        $in_repo = $self->_git(RUN => 'status');
    }
    catch {
        $self->log($_->$_isa('Git::Wrapper::Exception') ? $_->error : $_) ;
    };

    return [] if not $in_repo;

    my @paths = $self->paths;
    unshift @paths, '--' if @paths;

    my @data = $self->_git(shortlog =>
        {
            email => 1,
            summary => 1,
            $self->order_by eq 'commits' ? ( numbered => 1 ) : (),
        },
        'HEAD', @paths,
    );

    my @contributors = map { utf8::decode($_); m/^\s*\d+\s*(.*)$/g; } @data;

    $self->log_debug([ 'extracted contributors from git: %s',
        sub { Data::Dumper->new([ \@contributors ])->Indent(2)->Terse(1)->Dump } ]);

    @contributors = Unicode::Collate->new(level => 1)->sort(@contributors) if $self->order_by eq 'name';

    if (not $self->include_authors)
    {
        my $authors = $self->zilla->authors;
        @contributors = grep {
            my $contributor = $_;
            none { $contributor eq $_ } @$authors;
        } @contributors;
    }

    if (not $self->include_releaser and my $releaser = $self->_releaser)
    {
        @contributors = grep { $_ ne $releaser } @contributors;
    }

    return \@contributors;
}

sub _releaser
{
    my $self = shift;

    my ($username, $email);
    try {
        ($username) = $self->_git(config => 'user.name');
        ($email)    = $self->_git(config => 'user.email');
    };
    return if not $username or not $email;
    $username . ' <' . $email . '>';
}

sub _check_podweaver
{
    my $self = shift;

    # check if the module is loaded, not just that it is installed
    $self->log('WARNING! You appear to be using Pod::Weaver::Section::Contributors, but it is not new enough to take data directly from distmeta. Upgrade to version 0.008!')
        if eval { Pod::Weaver::Section::Contributors->VERSION(0); 1 }
            and not eval { Pod::Weaver::Section::Contributors->VERSION(0.007001); 1 };
}

has __git => (
    is => 'ro',
    isa => 'Git::Wrapper',
    lazy => 1,
    default => sub { Git::Wrapper->new(path(shift->zilla->root)->absolute->stringify) },
);

sub _git
{
    my ($self, $command, @args) = @_;

    my $git = $self->__git;
    my @result = $git->$command(@args);
    my $err = $git->ERR; $self->log(@$err) if @$err;
    return @result;
}

__PACKAGE__->meta->make_immutable;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Git::Contributors - Add contributor names from git to your distribution

=head1 VERSION

version 0.008

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

When true, authors (as defined by the preamble section in your F<dist.ini>)
are added to the list of contributors. When false, authors
are filtered out of the list of contributors.  Defaults to false.

=head2 C<include_releaser>

Defaults to true; set to false to remove the current user (who is doing the
distribution release) from the contributors list. It is applied after
C<include_authors>, so you will be removed from the list even if you are (one
of the) distribution author(s) and C<include_authors = 1>.

You probably don't want this option -- it was added experimentally to change
how contributors are displayed on L<http://metacpan.org>, but it was decided
that this should be managed at a different layer than the metadata.

=head2 C<order_by>

When C<order_by = name>, contributors are sorted alphabetically
(ascending); when C<order_by = commits>, contributors are sorted by number of
commits made to the repository (descending). The default value is C<name>.

=head2 C<path>

Indicates a path, relative to the repository root, to search for commits in.
Technically: "Consider only commits that are enough to explain how the files that match the specified paths came to be."
Defaults to the repository root. Can be used more than once.
I<You should almost certainly not need this.>

=for stopwords canonicalizing

=head1 CANONICALIZING NAMES AND ADDRESSES

If you or a contributor uses multiple names and/or email addresses to make
commits and would like them mapped to a canonical value (e.g. their
C<cpan.org> address), you can do this by
adding a F<.mailmap> file to your git repository, with entries formatted as
described in "MAPPING AUTHORS" in C<git help shortlog>
(L<https://www.kernel.org/pub/software/scm/git/docs/git-shortlog.html>).

=head1 ADDING CONTRIBUTORS TO POD DOCUMENTATION

You can add the contributor names to your module documentation by using
L<Pod::Weaver> in conjunction with L<Pod::Weaver::Section::Contributors>.

=head1 UNICODE SUPPORT

=for stopwords ascii

This module aims to properly handle non-ascii characters in contributor names.
However, on Windows you might need to do a bit more: see
L<https://github.com/msysgit/msysgit/wiki/Git-for-Windows-Unicode-Support> for
supported versions and extra configurations you may need to apply.

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

=for Pod::Coverage mvp_multivalue_args mvp_aliases metadata

=head1 AUTHOR

Karen Etheridge <ether@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
