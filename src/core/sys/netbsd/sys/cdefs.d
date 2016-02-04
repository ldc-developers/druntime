/**
 * D header file for NetBSD
 *
 * Authors: Martin Nowak
 */
module core.sys.netbsd.sys.cdefs;

version (NetBSD):

public import core.sys.posix.config;

// http://ftp.netbsd.org/pub/NetBSD/NetBSD-current/src/sys/sys/cdefs.h
enum __POSIX_VISIBLE = 200112;
enum __XSI_VISIBLE = 700;
enum __BSD_VISIBLE = true;
enum __ISO_C_VISIBLE = 1999;
