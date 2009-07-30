use inc::Module::Install;

name 'Stardust';
all_from 'lib/Stardust.pm';
requires 'Squatting' => '0.70';
install_script 'bin/stardust.pl';

WriteAll;
