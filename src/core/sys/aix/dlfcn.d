/**
 * D header file for AIX.
 *
 * Copyright: Copyright Kai Nacke 2014.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Kai Nacke
 */
module core.sys.aix.dlfcn;

public import core.sys.posix.dlfcn;

version (AIX):
extern (C):
nothrow:

/*
 * Modes and flags for dlopen().
 */
static assert(RTLD_NOW    == 0x00000002);
static assert(RTLD_LAZY   == 0x00000004);
static assert(RTLD_GLOBAL == 0x00010000);
enum RTLD_NOAUTODEFER     =  0x00020000;
enum RTLD_MEMBER          =  0x00040000;
static assert(RTLD_LOCAL  == 0x00080000);

/*
 * Special handle arguments for dlsym().
 */
enum RTLD_DEFAULT = cast(void *)-1;    /* Start search from the executable module. */
enum RTLD_MYSELF  = cast(void *)-2;    /* Start search from the module calling dlsym(). */
enum RTLD_NEXT    = cast(void *)-3;    /* Start search from the module after the module which called dlsym(). */

enum RTLD_ENTRY   = cast(char *)-1;    /* Return the module's entry point from dlsym(). */

