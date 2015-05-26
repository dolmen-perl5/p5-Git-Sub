use strict;
use warnings;
use Test::More;
use Test::Requires::Git;
use File::Temp qw( tempdir );
use Cwd qw( cwd abs_path );
use Git::Sub;

# clean up the environment
delete @ENV{grep /^GIT_/, keys %ENV};
$ENV{GIT_AUTHOR_NAME}     = 'Test Author';
$ENV{GIT_AUTHOR_EMAIL}    = 'test.author@example.com';
$ENV{GIT_COMMITTER_NAME}  = 'Test Committer';
$ENV{GIT_COMMITTER_EMAIL} = 'test.committer@example.com';

my $home = cwd;
my $dir = tempdir( CLEANUP => 1 );

# need to be there to test
chdir $dir;

# we need git
test_requires_git;

# but go back home before removing the dir
END { chdir $home; }

my %tested;

# skip if we can't get a version number
my $git_version = eval {git::version};
$tested{version}++;

diag "Testing <$git_version>";

# init a repository
test_requires_git version_gt => '1.5.0.rc1';
ok( !-d "$dir/.git", 'no repository yet' );
git::init;
ok( -d "$dir/.git", 'init' );
$tested{init}++;

# create the emptry tree
my $tree = git::mktree( \'' );
is( $tree, '4b825dc642cb6eb9a060e54bf8d69288fbee4904', 'mktree' );
$tested{mktree}++;

# commit it
$ENV{GIT_AUTHOR_DATE}    = 'Mon Jan 21 21:14:18 CET 2013';
$ENV{GIT_COMMITTER_DATE} = 'Mon Jan 21 21:14:18 CET 2013';
my $commit = git::commit_tree $tree, \'empty tree';
$tested{commit_tree}++;
is( $commit, '52870678501379ecd14277fad5e69961ce7bd39b', 'commit_tree' );

# point master to it
git::update_ref 'refs/heads/master', $commit;
$tested{update_ref}++;

# check we got it right
my $log = git::log qw( --pretty=format:%H -1 );
is( $log, $commit, 'log' );

$log = git::log qw( --pretty=format:%s -1 );
is( $log, 'empty tree', 'log' );

# create a new branch
git::checkout -b => 'branch';
$tested{checkout}++;

is_deeply( [git::branch], [ '* branch', '  master' ], 'branch' );
$tested{branch}++;

# add a new file
open my $fh, '>', 'hello.txt';
print $fh "Hello, world!\n";
close $fh;

is_deeply( [ git::status '--porcelain' ],
    ['?? hello.txt'], 'status --porcelain' );
$tested{status}++;
git::add 'hello.txt';
$tested{add}++;
is_deeply( [ git::status '--porcelain' ],
    ['A  hello.txt'], 'status --porcelain' );
$tested{status}++;

# and commit it
$ENV{GIT_AUTHOR_DATE}    = 'Mon Jan 21 21:14:19 CET 2013';
$ENV{GIT_COMMITTER_DATE} = 'Mon Jan 21 21:14:19 CET 2013';
git::commit -m => 'hello';
$tested{commit}++;
$commit = git::log qw( -1 --pretty=format:%H );
$tested{log}++;
is( $commit, 'b462686c994180efe7fcf5e4e682907834c93f38', 'log' );

# check an unsupported command
use Git::Sub 'show_branch';
is_deeply(
    [ git::show_branch '--all' ],
    [ split /\n/, << 'EOT' ], 'show-branch' );
* [branch] hello
 ! [master] empty tree
--
*  [branch] hello
*+ [master] empty tree
EOT

is_deeply(
    [ git::cat_file commit => 'b462686c994180efe7fcf5e4e682907834c93f38' ],
    [ split /\n/, << 'EOT' ], 'cat_file' );
tree ec947e3dd7a7752d078f1ed0cfde7457b21fef58
parent 52870678501379ecd14277fad5e69961ce7bd39b
author Test Author <test.author@example.com> 1358799259 +0100
committer Test Committer <test.committer@example.com> 1358799259 +0100

hello
EOT
$tested{cat_file}++;

is_deeply( [ git::ls_tree 'master' ], [], 'ls_tree' );
is_deeply( [ git::ls_tree 'branch' ],
    ["100644 blob af5626b4a114abcb82d63db7c8082c3c4756e51b\thello.txt"],
    'ls_tree' );

# inform us about untested commands
diag "Not tested: ", join ' ', sort grep !exists $tested{$_},
    grep /^[a-z_]+$/, keys %git::;

done_testing;
