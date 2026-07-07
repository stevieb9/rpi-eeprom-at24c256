package RPi::EEPROM::AT24C256;

use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('RPi::EEPROM::AT24C256', $VERSION);

use constant {
    ADDR_MIN_VALUE => 0,
    ADDR_MAX_VALUE => 32767,
    BYTE_MIN_VALUE => 0,
    BYTE_MAX_VALUE => 255,
};

sub new {
    my ($class, %args) = @_;

    $args{device}  //= '/dev/i2c-1';
    $args{address} //= 0x50;
    $args{delay}   //= 1;

    my $self = bless {%args}, $class;

    my $fd = eeprom_init($args{device}, $args{address}, $args{delay});
    $self->fd($fd);

    return $self;
}
sub fd {
    my ($self, $fd) = @_;
    $self->{fd} = $fd if defined $fd;
    return $self->{fd};
}
sub read {
    my ($self, $addr) = @_;
    _check_addr('read', $addr);
    return eeprom_read($self->fd, $addr);
}
sub write {
    my ($self, $addr, $byte) = @_;
    _check_addr('write', $addr);
    _check_byte('write', $byte);
    return eeprom_write($self->fd, $addr, $byte);
}
sub _check_addr {
    my ($sub, $addr) = @_;

    croak "_check_addr() requires \$sub param...\n" if ! defined $sub;

    if (! defined $addr) {
        croak "$sub requires an EEPROM memory address sent in...\n";
    }

    if ($addr < ADDR_MIN_VALUE || $addr > ADDR_MAX_VALUE) {
        croak "address parameter out of range. Must be between " .
              ADDR_MIN_VALUE . " and " . ADDR_MAX_VALUE . "\n";
    }

    return 1;
}
sub _check_byte {
    my ($sub, $byte) = @_;

    croak "_check_byte() requires \$sub param...\n" if ! defined $sub;

    if (! defined $byte) {
        croak "$sub requires a data byte sent in...\n";
    }

    if ($byte < BYTE_MIN_VALUE || $byte > BYTE_MAX_VALUE) {
        croak "data byte parameter out of range. Must be between " .
              BYTE_MIN_VALUE . " and " . BYTE_MAX_VALUE . "\n";
    }

    return 1;
}

1;
__END__

=head1 NAME

RPi::EEPROM::AT24C256 - Read and write to the AT24C256 based EEPROM IC via i2c

=for html
<a href="https://github.com/stevieb9/rpi-eeprom-at24c256/actions"><img src="https://github.com/stevieb9/rpi-eeprom-at24c256/workflows/CI/badge.svg"/></a>
<a href='https://coveralls.io/github/stevieb9/rpi-eeprom-at24c256?branch=main'><img src='https://coveralls.io/repos/stevieb9/rpi-eeprom-at24c256/badge.svg?branch=main&service=github' alt='Coverage Status' /></a>

=head1 DESCRIPTION

Read and write data to the AT24C256-based EEPROM Integrated Circuit over the
i2c bus.

The AT24C256 provides C<256Kbit> of storage as 32768 bytes, so memory
addresses C<0-32767> are available for use.

Its byte-at-a-time interface is identical to that of the smaller
L<RPi::EEPROM::AT24C32>; only the capacity and the page size differ.

=head1 SYNOPSIS

    use RPi::EEPROM::AT24C256;

    my $eeprom = RPi::EEPROM::AT24C256->new;

    # write to, and read from a block of EEPROM addresses in a loop

    my $value = 1;

    for my $slot (200..225){
        $eeprom->write($slot, $value);
        print $eeprom->read($slot) . "\n";
        $value++;
    }

=head1 METHODS

=head2 new(%args)

Instantiates a new L<RPi::EEPROM::AT24C256> object, initializes the i2c bus,
and returns the object.

Parameters:

All parameters are sent in as a hash.

    device => '/dev/i2c-1'

Optional, String. The name of the i2c bus device to use. Defaults to
C</dev/i2c-1>.

    address => 0x50

Optional, Integer. The i2c address of the EEPROM device. Defaults to C<0x50>
(the A2/A1/A0 straps all tied low), the out-of-the-box wiring on most bare
AT24C256 breakout boards. Strap the address pins to select any value in the
C<0x50-0x57> range.

    delay => 1

Optional, Integer. An upper bound, in milliseconds, on how long a
L<write|/"write($addr, $byte)"> waits for the chip to finish its internal
write cycle. Writes B<acknowledge-poll> the chip (re-address it until it
ACKs) and return the instant the write completes - typically well under the
15ms maximum - so this value is rarely relevant. It is floored at that
ceiling, so too small a value can never make a write return early; raise it
only if a slow or flaky bus ever needs a longer ceiling.

Defaults to C<1> (floored to the ~15ms write ceiling).

=head2 read($addr)

Performs a single-byte read of the EEPROM storage from the specified memory
location.

Parameters:

    $addr

Mandatory, Integer. Valid values are C<0-32767>.

Return: The byte value located within the specified EEPROM memory register.

=head2 write($addr, $byte)

Writes a single 8-bit byte of data to the EEPROM memory address specified.

Parameters:

    $addr

Mandatory, Integer. Valid values are C<0-32767>.

    $byte

Mandatory, Integer. Valid values are C<0-255>.

Return: C<0> on success, C<-1> on failure.

=head1 ACCESSORY METHODS

These are methods that aren't normally required for the use of this software,
but may be handy for troubleshooting or future purposes.

=head2 fd($fd)

Sets/gets the file descriptor that our i2c initialization routine assigned to
us.

Parameters:

    $fd

Optional, Integer: This is set internally, and it would be very unwise to set
it manually at any other time.

Return: The file descriptor (integer) that the C<ioctl()> initialization
routine assigned us.

=head1 PRIVATE METHODS

=head2 _check_addr

Ensures that the EEPROM memory register address supplied as a parameter is
within limits.

=head2 _check_byte

For write calls, ensures that the data byte supplied is within valid limits.

=head1 TECHNICAL INFORMATION

=head2 DEVICE SPECIFICS

    - 256Kbit serial EEPROM: 32768 x 8 bits, in 64-byte pages
    - 1 million write cycle endurance, 100-year data retention
    - Self-timed write cycle, bounded here at 15ms, during which the chip
      ignores the bus entirely (see L</ON THE WIRE>)
    - 1.8V, 2.5V, 2.7V and 5V grades; SCL is rated 400kHz at Pi voltages,
      comfortably above the Pi's default 100kHz bus speed
    - Eight strap-selectable bus addresses, 0x50-0x57, via the A2/A1/A0
      pins (all three strapped low read as 0x50); this module defaults to
      0x50, the wiring found on most bare AT24C256 breakout boards
    - WP pin to VCC enables the chip's hardware write-protect (see the
      datasheet for the region protected on your part); tied to ground,
      the whole array is writable

Wiring: VCC to 3.3V, GND to ground, SDA to GPIO 2 (pin 3), SCL to GPIO 3
(pin 5); strap A2/A1/A0 and WP per the notes above. C<i2cdetect -y 1>
shows the chip at whatever address is strapped.

=head2 MEMORY MAP

    0x0000-0x7FFF   32768 bytes (256Kbit), as 512 pages of 64 bytes

The word address is 15 bits, sent on the wire as two bytes; the top bit of
the first byte is a don't-care. The 64-byte page size matters only for the
chip's multi-byte page-write mode - this module writes a single byte per
transaction, so page boundaries never come into play.

An internal address counter holds the last address accessed (plus one once a
byte has actually been read) and persists between transactions as long as the
chip stays powered - L<read|/"read($addr)"> relies on exactly that (see
L</ON THE WIRE>).

The chip answers the bus with the standard 2-wire EEPROM device address word:

    1  0  1  0  A2 A1 A0 R/W

The fixed C<1010> nibble plus the three strap bits give the 0x50-0x57 range;
the trailing bit selects read (1) or write (0).

=head2 ON THE WIRE

The XS drives the kernel's C</dev/i2c-N> SMBus interface. Everything the
module does reduces to two frame shapes:

    S = START    P = STOP
    A = ACK (receiver pulls SDA low)    N = NACK (master, "no more bytes")

A L<write|/"write($addr, $byte)"> is the chip's byte-write operation - one
four-byte frame. C<< $eeprom->write(677, 66) >> at the default address 0x50
(address byte C<0xA0> on the wire):

    +---+------+---+------+---+------+---+------+---+---+
    | S | 0xA0 | A | 0x02 | A | 0xA5 | A | 0x42 | A | P |
    +---+------+---+------+---+------+---+------+---+---+
         addr+W     word       word       data
         (0x50)     addr MSB   addr LSB   byte

At that STOP the chip starts its self-timed internal write cycle (t_WR, up to
15ms) and ignores the bus completely - it won't even
acknowledge its own address - until the cycle finishes. The XS exploits
exactly that: after each write it B<acknowledge-polls> the chip, re-sending
the device address until the chip ACKs, which happens only once the write
cycle completes. C<write> therefore blocks for the real t_WR and no longer - a
following operation can never land inside a still-running write cycle. The
C<delay> parameter in L<new|/"new(%args)"> is now just a rarely-needed ceiling
on that poll.

A L<read|/"read($addr)"> is two frames: an address-load write (no data byte),
then a current-address read that the chip answers from its address counter:

    +---+------+---+------+---+------+---+---+
    | S | 0xA0 | A | 0x02 | A | 0xA5 | A | P |    Load the address
    +---+------+---+------+---+------+---+---+    counter, write nothing

    +---+------+---+------+---+---+
    | S | 0xA1 | A | 0x42 | N | P |    Current-address read;
    +---+------+---+------+---+---+    chip drives the data byte
         addr+R

The datasheet draws its "random read" with a repeated START joining those two;
the SMBus calls used here issue them as separate STOP-divided transactions,
which works because the address counter persists between operations. After the
byte is delivered the counter sits at the next address - the chip could stream
sequentially from there, but this module reads one byte per call.

=head2 DATASHEET

The Atmel (now Microchip) AT24C128/256 datasheet (doc0670) is distributed
with this software as F<docs/datasheet/AT24C256.pdf>. It covers the
addressing, the read/write frames, the timing and the electrical
characteristics this module's XS layer implements.

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2026 Steve Bertrand.

GPL version 2+ (due to using modified GPL'd code).

=cut
