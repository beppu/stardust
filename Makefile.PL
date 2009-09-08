use inc::Module::Install;

name            'Stardust';
all_from        'lib/Stardust.pm';
requires        'Squatting'              => '0.70';
requires        'Continuity'             => '1.00';
requires        'AnyEvent'               => '5.12';
requires        'Coro'                   => '5.17';
requires        'AnyEvent::HTTP'         => 0;
requires        'Set::Object'            => 0;
requires        'Sys::Hostname'          => 0;
requires        'aliased'                => 0;
requires        'Tenjin'                 => '0.04';
requires        'File::ShareDir'         => 0;
requires        'JSON'                   => 0;
install_script  'bin/stardust.pl';
install_share;

WriteAll;
