use inc::Module::Install;

name            'Stardust';
all_from        'lib/Stardust.pm';
requires        'Squatting'      => '0.70';
requires        'Set::Object'    => 0;
requires        'Sys::Hostname'  => 0;
requires        'aliased'        => 0;
requires        'Tenjin'         => 0;
requires        'AnyEvent::HTTP' => 0;
requires        'File::ShareDir' => 0;
install_script  'bin/stardust.pl';
install_share;

WriteAll;
