#!/bin/sh
START=55

start() {
        cd /usr/local/bifrost
        /usr/bin/perl read_card.pl 2>&1 | logger -p daemon.info
}

stop() {
        pkill -f '/usr/bin/perl read_card.pl'
}

$1
