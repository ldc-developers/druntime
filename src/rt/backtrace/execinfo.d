module rt.backtrace.execinfo;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (ExtExecinfo_BSDFmt)
    version = _extExecinfo;
else version (ExtExecinfo_DarwinFmt)
    version = _extExecinfo;
else version (ExtExecinfo_GNUFmt)
    version = _extExecinfo;
else version (ExtExecinfo_SolarisFmt)
    version = _extExecinfo;

/** Imports the appropriate execinfo module depending on the actual
 * OS and libc version. If the libc implementation does not include
 * any execinfo methods, it is possible to link with an external
 * execinfo library. In the latter case one of the $(D ExtExecinfo_)
 * version identifier should be set and the corresponding external
 * library should be linked with druntime.
 *
 * $(TABLE_2COLS Possible external execinfo version IDs,
 * $(THEAD Version ID, Backtrace format)
 * $(TROW $(D ExtExecinfo_BSDFmt), $(D 0x00000000 <_D6module4funcAFZv+0x78> at module))
 * $(TROW $(D ExtExecinfo_DarwinFmt), $(D 1  module    0x00000000 D6module4funcAFZv + 0))
 * $(TROW $(D ExtExecinfo_GNUFmt), $(D module(_D6module4funcAFZv) [0x00000000]) or
 * $(D module(_D6module4funcAFZv+0x78) [0x00000000]) or $(D module(_D6module4funcAFZv-0x78) [0x00000000]))
 * $(TROW $(D ExtExecinfo_SolarisFmt), $(D object'symbol+offset [pc]))
 * )
 */
mixin template ImportExecinfoPOSIX()
{
    version (linux)
    {
        version (CRuntime_Glibc)
            import _execinfo = core.sys.linux.execinfo;
	else version (CRuntime_UClibc)
            import _execinfo = core.sys.linux.execinfo;
	else version (_extExecinfo)
            import _execinfo = core.sys.linux.execinfo;
    }
    else version (Darwin)
        import _execinfo = core.sys.darwin.execinfo;
    else version (FreeBSD)
        import _execinfo = core.sys.freebsd.execinfo;
    else version (NetBSD)
        import _execinfo = core.sys.netbsd.execinfo;
    else version (DragonFlyBSD)
        import _execinfo = core.sys.dragonflybsd.execinfo;
    else version (Solaris)
        import _execinfo = core.sys.solaris.execinfo;
//    else
//        enum _execinfo = false; // execinfo is not implemented on this platform

    static if (__traits(compiles, _execinfo) && is(_execinfo == module))
    {
        alias backtrace = _execinfo.backtrace;
        alias backtrace_symbols = _execinfo.backtrace_symbols;
        alias backtrace_symbols_fd = _execinfo.backtrace_symbols_fd;
    }
}

/// Indicates the availability of backtrace functions
enum bool hasExecinfo = ()
{
    mixin ImportExecinfoPOSIX;

    return __traits(compiles, backtrace) &&
           __traits(compiles, backtrace_symbols) &&
           __traits(compiles, backtrace_symbols_fd);
}();

// Inspect possible backtrace formats
private
{
    version (FreeBSD)
        enum _BTFmt_BSD = true;
    else version (DragonFlyBSD)
        enum _BTFmt_BSD = true;
    else version (NetBSD)
        enum _BTFmt_BSD = true;
    else version (ExtExecinfo_BSDFmt)
        enum _BTFmt_BSD = true;
    else
        enum _BTFmt_BSD = false;
    
    version (Darwin)
        enum _BTFmt_Darwin = true;
    else version (ExtExecinfo_DarwinFmt)
        enum _BTFmt_Darwin = true;
    else
        enum _BTFmt_Darwin = false;
    
    version (CRuntime_Glibc)
        enum _BTFmt_GNU = true;
    else version (CRuntime_UClibc)
        enum _BTFmt_GNU = true;
    else version (ExtExecinfo_GNUFmt)
        enum _BTFmt_GNU = true;
    else
        enum _BTFmt_GNU = false;
    
    version (Solaris)
        enum _BTFmt_Solaris = true;
    else version (ExtExecinfo_SolarisFmt)
        enum _BTFmt_Solaris = true;
    else
        enum _BTFmt_Solaris = false;
}

/** Indicates the backtrace format of the actual execinfo implementation.
 * At most one of the values is allowed to be set to $(D true) the
 * others should be $(D false).
 */
enum BacktraceFmt : bool
{
    /// $(D 0x00000000 <_D6module4funcAFZv+0x78> at module)
    BSD = _BTFmt_BSD,

    /// $(D 1  module    0x00000000 D6module4funcAFZv + 0)
    Darwin = _BTFmt_Darwin,

    /// $(D module(_D6module4funcAFZv) [0x00000000])
    /// or $(D module(_D6module4funcAFZv+0x78) [0x00000000])
    /// or $(D module(_D6module4funcAFZv-0x78) [0x00000000])
    GNU = _BTFmt_GNU,

    /// $(D object'symbol+offset [pc])
    Solaris = _BTFmt_Solaris
}

private bool atMostOneBTFmt()
{
    size_t trueCnt = 0;

    foreach (fmt; __traits(allMembers, BacktraceFmt))
        if (__traits(getMember, BacktraceFmt, fmt)) ++trueCnt;

    return trueCnt < 2;
}

static assert(atMostOneBTFmt, "Cannot be set more than one BacktraceFmt at the same time.");
