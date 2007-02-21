
=pod

L<Module::Install> file for L<re::engine::POSIX>. M::I knows how to
build our XS stuff automatically.

=cut

use strict;
use inc::Module::Install;

name 're-engine-POSIX';

# Requires the unreleased match vars features in (as of writing)
# unreleased 5.9.6, but 5.9.5 is the version of blead
perl_version '5.009005';

author 'Ævar Arnfjörð Bjarmason <avar@cpan.org>';

abstract_from 'POSIX.pm';
license_from  'POSIX.pm';

inc '-I/usr/include';

# t/
build_requires 'Test::More' => 0; # 5.007003

tests 't/*.t';

auto_install;
WriteAll;
