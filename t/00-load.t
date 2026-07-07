#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'RPi::EEPROM::AT24C256' ) || print "Bail out!\n";
}

diag( "Testing RPi::EEPROM::AT24C256 $RPi::EEPROM::AT24C256::VERSION, Perl $], $^X" );
