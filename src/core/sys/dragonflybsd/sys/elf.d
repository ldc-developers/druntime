/**
 * D header file for FreeBSD.
 *
 * $(LINK2 http://svnweb.freebsd.org/base/head/sys/sys/elf.h?view=markup, sys/elf.h)
 */
module core.sys.dragonflybsd.sys.elf;

version (DragonFlyBSD):

public import core.sys.dragonflybsd.sys.elf32;
public import core.sys.dragonflybsd.sys.elf64;
