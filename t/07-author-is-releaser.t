use strict;
use warnings FATAL => 'all';

# this test demonstrates the recommended configuration settings for
# multi-author distributions, where the releaser is one of the authors.

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Test::Deep;
use Path::Tiny;

use lib 't/lib';
use GitSetup;

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => dist_ini(
                {
                    name     => 'DZT-Sample',
                    abstract => 'Sample DZ Dist',
                    version  => '0.001',
                    author   => [
                        'Anne O\'Thor <author@example.com>',
                        'Test User <test@example.com>', # <-- the releaser
                    ],
                    license  => 'Perl_5',
                    copyright_holder => 'Anne O\'Thor',
                },
                [ GatherDir => ],
                [ MetaConfig => ],
                [ 'Git::Contributors' => { include_authors => 1, include_releaser => 0 } ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
        },
    },
);

my $root = path($tzil->tempdir)->child('source');
my $git = git_wrapper($root);

my $releaser = 'Test User <test@example.com>';

my $changes = $root->child('Changes');
$changes->spew("Release history for my dist\n\n");
$git->add('Changes');
$git->commit({ message => 'first commit', author => $tzil->authors->[0] });

$changes->append("- a changelog entry\n");
$git->add('Changes');
$git->commit({ message => 'second commit', author => $releaser });

$changes->append("- a changelog entry\n");
$git->add('Changes');
$git->commit({ message => 'third commit', author => 'Anon Y. Moose <anon@null.com>' });

$tzil->chrome->logger->set_debug(1);
is(
    exception { $tzil->build },
    undef,
    'build proceeds normally',
);

is(
    $tzil->plugin_named('Git::Contributors')->_releaser,
    $releaser,
    'properly determined the name+email of the current user',
);

cmp_deeply(
    $tzil->distmeta,
    superhashof({
        x_contributors => [
            'Anne O\'Thor <author@example.com>',
            'Anon Y. Moose <anon@null.com>',
        ],
        x_Dist_Zilla => superhashof({
            plugins => supersetof(
                {
                    class => 'Dist::Zilla::Plugin::Git::Contributors',
                    config => {
                        'Dist::Zilla::Plugin::Git::Contributors' => superhashof({
                            include_authors => 1,
                            include_releaser => 0,
                        }),
                    },
                    name => 'Git::Contributors',
                    version => ignore,
                },
            ),
        }),
    }),
    'all authors included, except the releaser',
) or diag 'got distmeta: ', explain $tzil->distmeta;

diag 'got log messages: ', explain $tzil->log_messages
    if not Test::Builder->new->is_passing;

done_testing;
