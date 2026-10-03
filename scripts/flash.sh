!#/bin/sh

/usr/bin/openocd -f /usr/share/openocd/scripts/board/pico-debug.cfg  -c 'program firmware.bin verify reset exit 0x101c0000'
