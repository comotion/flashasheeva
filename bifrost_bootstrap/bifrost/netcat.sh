#!/bin/sh
CMDS=$1
shift;
cat $CMDS | nc -w 10 $*
