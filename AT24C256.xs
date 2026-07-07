#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <linux/fs.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <assert.h>
#include <string.h>
#include "eeprom.h"

/* Acknowledge-polling tunables (see eeprom_write) */
#define POLL_INTERVAL_US    500     /* Gap between address ACK probes (us) */
#define POLL_TIMEOUT_MIN_US 15000   /* Poll-ceiling floor at the 15ms t_WR bound */

int write_cycle_time = 0;

static int _writeAddress(int fd, __u8 buf[2]){

	int r = i2c_smbus_write_byte_data(fd, buf[0], buf[1]);

	if(r < 0){
		fprintf(stderr, "Error _writeAddress: %s\n", strerror(errno));
		croak("_writeAddress() failed to write to the i2c bus\n");
    }

	usleep(10);

	return r;
}

static int _writeByte(int fd, __u8 buf[3]){

	int r = i2c_smbus_write_word_data(fd, buf[0], buf[2] << 8 | buf[1]);

	if(r < 0){
		fprintf(stderr, "Error _writeByte: %s\n", strerror(errno));
		croak("_writeByte() failed to write to the i2c bus\n");
	  }

	usleep(10);

	return r;
}

static int _writeBlock(int fd, __u8 eepromAddr, int len, __u8 *data){

	int r = i2c_smbus_write_block_data(fd, eepromAddr, len, data);

	if(r < 0){
		fprintf(stderr, "Error _writeBlock: %s\n", strerror(errno));
		croak("_writeBlock() failed to write to the i2c bus\n");
    }

	usleep(10);

	return r;
}

int eeprom_init(char *dev_fqn, int addr, int delay){

	int fd, r;

	fd = open(dev_fqn, O_RDWR);

	if(fd <= 0){
		fprintf(stderr, "Error eeprom_init: %s\n", strerror(errno));
		return -1;
	}

	if( ( r = ioctl(fd, I2C_SLAVE, addr)) < 0){
		fprintf(stderr, "Error opening EEPROM i2c connection: %s\n", strerror(errno));
		return -1;
	}

    write_cycle_time = delay;

	return fd;
}

int eeprom_close(int fd){
	close(fd);
	return 0;
}

int eeprom_read_current_byte(int fd){
	ioctl(fd, BLKFLSBUF);
	return i2c_smbus_read_byte(fd);
}

int eeprom_read(int fd, int mem_addr){

	ioctl(fd, BLKFLSBUF);

	__u8 buf[2] = { (mem_addr >> 8) & 0x0ff, mem_addr & 0x0ff };

    int r = _writeAddress(fd, buf);

    if (r < 0){
		return r;
    }

    return(i2c_smbus_read_byte(fd));
}

int eeprom_write(int fd, int mem_addr, int data){

    __u8 buf[3] = {
        (__u8)(mem_addr >> 8) & 0x00ff,
        (__u8)mem_addr & 0x00ff,
        (__u8)data
    };

    int ret = _writeByte(fd, buf);

    if (ret == 0) {

        /* Acknowledge polling (AT24C256 datasheet): while the internally-timed
           write cycle runs (t_WR, up to 15ms) the AT24C256 NACKs
           its own address, then ACKs once the write completes. Re-address
           the chip until it ACKs, so we wait exactly as long as it needs
           instead of a fixed guess. Cap the wait at write_cycle_time ms (the
           'delay' param) but never below t_WR, so a missing or wedged chip
           can't spin forever. */

        int timeout_us = 1000 * write_cycle_time;

        if (timeout_us < POLL_TIMEOUT_MIN_US) {
            timeout_us = POLL_TIMEOUT_MIN_US;
        }

        int waited_us = 0;

        while (i2c_smbus_write_quick(fd, I2C_SMBUS_WRITE) < 0) {
            if (waited_us >= timeout_us) {
                break;
            }
            usleep(POLL_INTERVAL_US);
            waited_us += POLL_INTERVAL_US;
        }
    }

    return ret;
}

MODULE = RPi::EEPROM::AT24C256  PACKAGE = RPi::EEPROM::AT24C256

PROTOTYPES: DISABLE

int
eeprom_init (dev_fqn, addr, delay)
	char *	dev_fqn
	int	addr
	int	delay

int
eeprom_close (fd)
	int	fd

int
eeprom_read_current_byte (fd)
	int	fd

int
eeprom_read (fd, mem_addr)
	int	fd
	int	mem_addr

int
eeprom_write (fd, mem_addr, data)
	int	fd
	int	mem_addr
	int	data

