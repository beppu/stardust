use inc::Module::Install;

name            'Stardust';
all_from        'lib/Stardust.pm';
requires        'Squatting'   => '0.70';
requires        'Set::Object' => 0;
requires        'aliased'     => 0;
install_script  'bin/stardust.pl';

WriteAll;
