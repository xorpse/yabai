#!/bin/sh

# assemble
as -o sa_arm64e.o sa_arm64e.s

# calculate size and offset
off=$(otool -l sa_arm64e.o | grep fileoff | sed 's/  fileoff //')
siz=$(otool -l sa_arm64e.o | grep filesize | sed 's/ filesize //')

# extract
dd if=sa_arm64e.o of=sa_arm64e bs=1 count=$siz skip=$off &> /dev/null

# build header
xxd -i -a sa_arm64e sa_arm64e.h
