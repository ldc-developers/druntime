/**
 * This module implements the runtime-part of LDC exceptions
 * on Windows win32.
 */
module ldc.eh.win32;

version(CRuntime_Microsoft):
version(Win32):

import ldc.eh.common;
import ldc.attributes;
import core.sys.windows.windows;
import core.exception : onOutOfMemoryError, OutOfMemoryError;
import core.stdc.stdlib : malloc, free;
import core.stdc.string : memcpy;
import rt.util.container.common : xmalloc;

// pointers are image relative for Win64 versions
version(Win64)
    alias ImgPtr(T) = uint; // offset into image
else
    alias ImgPtr(T) = T*;

alias PMFN = ImgPtr!(void function(void*));

struct TypeDescriptor
{
    version(_RTTI)
        const void * pVFTable;  // Field overloaded by RTTI
    else
        uint hash;  // Hash value computed from type's decorated name

    void * spare;   // reserved, possible for RTTI
    char[1] name;   // variable size, zero terminated
}

struct PMD
{
    int mdisp;      // Offset of intended data within base
    int pdisp;      // Displacement to virtual base pointer
    int vdisp;      // Index within vbTable to offset of base
}

struct CatchableType
{
    uint  properties;       // Catchable Type properties (Bit field)
    ImgPtr!TypeDescriptor pType;   // Pointer to TypeDescriptor
    PMD   thisDisplacement; // Pointer to instance of catch type within thrown object.
    int   sizeOrOffset;     // Size of simple-type object or offset into buffer of 'this' pointer for catch object
    PMFN  copyFunction;     // Copy constructor or CC-closure
}

enum CT_IsSimpleType    = 0x00000001;  // type is a simple type (includes pointers)
enum CT_ByReferenceOnly = 0x00000002;  // type must be caught by reference
enum CT_HasVirtualBase  = 0x00000004;  // type is a class with virtual bases
enum CT_IsWinRTHandle   = 0x00000008;  // type is a winrt handle
enum CT_IsStdBadAlloc   = 0x00000010;  // type is a a std::bad_alloc

struct CatchableTypeArray
{
    int	nCatchableTypes;
    ImgPtr!CatchableType[1] arrayOfCatchableTypes; // variable size
}

struct _ThrowInfo
{
    uint    attributes;     // Throw Info attributes (Bit field)
    PMFN    pmfnUnwind;     // Destructor to call when exception has been handled or aborted.
    PMFN    pForwardCompat; // pointer to Forward compatibility frame handler
    ImgPtr!CatchableTypeArray pCatchableTypeArray; // pointer to CatchableTypeArray
}

struct ExceptionRecord
{
    uint ExceptionCode;
    uint ExceptionFlags;
    uint ExceptionRecord;
    uint ExceptionAddress;
    uint NumberParameters;
    union
    {
        ULONG_PTR[15] ExceptionInformation;
        CxxExceptionInfo CxxInfo;
    }
}

struct CxxExceptionInfo
{
    size_t Magic;
    Throwable* pThrowable; // null for rethrow
    _ThrowInfo* ThrowInfo;
}

enum TI_IsConst     = 0x00000001;   // thrown object has const qualifier
enum TI_IsVolatile  = 0x00000002;   // thrown object has volatile qualifier
enum TI_IsUnaligned = 0x00000004;   // thrown object has unaligned qualifier
enum TI_IsPure      = 0x00000008;   // object thrown from a pure module
enum TI_IsWinRT     = 0x00000010;   // object thrown is a WinRT Exception

extern(Windows) void RaiseException(DWORD dwExceptionCode,
                                    DWORD dwExceptionFlags,
                                    DWORD nNumberOfArguments,
                                    ULONG_PTR* lpArguments);

enum int STATUS_MSC_EXCEPTION = 0xe0000000 | ('m' << 16) | ('s' << 8) | ('c' << 0);

enum EXCEPTION_NONCONTINUABLE     = 0x01;
enum EXCEPTION_UNWINDING          = 0x02;

enum EH_MAGIC_NUMBER1             = 0x19930520;

extern(C) void _d_throw_exception(Object e)
{
    if (e is null)
        fatalerror("Cannot throw null exception");
    auto ti = typeid(e);
    if (ti is null)
        fatalerror("Cannot throw corrupt exception object with null classinfo");

    exceptionStack.push(cast(Throwable) e);

    ULONG_PTR[3] ExceptionInformation;
    ExceptionInformation[0] = EH_MAGIC_NUMBER1;
    ExceptionInformation[1] = cast(ULONG_PTR) cast(void*) &e;
    ExceptionInformation[2] = cast(ULONG_PTR) getThrowInfo(ti);

    RaiseException(STATUS_MSC_EXCEPTION, EXCEPTION_NONCONTINUABLE, 3, ExceptionInformation.ptr);
}

///////////////////////////////////////////////////////////////

extern(C) string _d_toString(Object o)
{
    return o.toString();
}

///////////////////////////////////////////////////////////////

import rt.util.container.hashtab;
import core.sync.mutex;

__gshared HashTab!(TypeInfo_Class, ImgPtr!_ThrowInfo) throwInfoHashtab;
__gshared HashTab!(TypeInfo_Class, ImgPtr!CatchableType) catchableHashtab;
__gshared Mutex throwInfoMutex;

// create and cache throwinfo for ti
ImgPtr!_ThrowInfo getThrowInfo(TypeInfo_Class ti)
{
    throwInfoMutex.lock();
    if (auto p = ti in throwInfoHashtab)
    {
        throwInfoMutex.unlock();
        return *p;
    }

    size_t classes = 0;
    for (TypeInfo_Class tic = ti; tic; tic = tic.base)
        classes += 2; // D and C++

    size_t sz = int.sizeof + classes * ImgPtr!(CatchableType).sizeof;
    auto cta = cast(CatchableTypeArray*) xmalloc(sz);
    cta.nCatchableTypes = classes;

    size_t c = 0;
    for (TypeInfo_Class tic = ti; tic; tic = tic.base, c += 2)
    {
        cta.arrayOfCatchableTypes.ptr[c] = getCatchableType(tic);
        cta.arrayOfCatchableTypes.ptr[c + 1] = cta.arrayOfCatchableTypes.ptr[c] + 1;
    }

    auto tinf = cast(_ThrowInfo*) xmalloc(_ThrowInfo.sizeof);
    *tinf = _ThrowInfo(0, null, null, cta);
    throwInfoHashtab[ti] = tinf;
    throwInfoMutex.unlock();
    return tinf;
}

// returns pointer to array of 2 elements, one for D and one for C++
CatchableType* getCatchableType(TypeInfo_Class ti)
{
    if (auto p = ti in catchableHashtab)
        return *p;

    // generate catch types for both D (fully.qualified.name)
    //  and C++ (D::name mangled to .PAVname@D@@)
    size_t p = ti.name.length;
    for ( ; p > 0 && ti.name[p-1] != '.'; p--) {}
    string name = ti.name[p .. $];

    size_t szd = (TypeDescriptor.sizeof + ti.name.length + 3) & ~3;
    size_t szcpp = TypeDescriptor.sizeof + name.length + 8;
    auto tdd = cast(TypeDescriptor*) xmalloc(szd + szcpp);

    tdd.hash = 0;
    tdd.spare = null;
    tdd.name.ptr[0] = 'D';
    memcpy(tdd.name.ptr + 1, ti.name.ptr, ti.name.length);
    tdd.name.ptr[ti.name.length + 1] = 0;

    auto tdcpp = cast(TypeDescriptor*) (cast(char*)tdd + szd);
    tdcpp.hash = 0;
    tdcpp.spare = null;
    memcpy(tdcpp.name.ptr, ".PAV".ptr, 4);
    memcpy(tdcpp.name.ptr + 4, name.ptr, name.length);
    memcpy(tdcpp.name.ptr + 4 + name.length, "@D@@".ptr, 5);

    auto ct = cast(CatchableType*) xmalloc(2 * CatchableType.sizeof);
    ct[0] = CatchableType(CT_IsSimpleType, tdd,   PMD(0, -1, 0), 4, null);
    ct[1] = CatchableType(CT_IsSimpleType, tdcpp, PMD(0, -1, 0), 4, null);

    catchableHashtab[ti] = ct;
    return ct;
}

///////////////////////////////////////////////////////////////
extern(C) Object _d_eh_enter_catch(void* ptr, ClassInfo catchType)
{
    assert(ptr);

    // is this a thrown D exception?
    auto e = *(cast(Throwable*) ptr);
    size_t pos = exceptionStack.find(e);
    if (pos >= exceptionStack.length())
        return null;

    auto caught = e;
    // append inner unhandled thrown exceptions
    for (size_t p = pos + 1; p < exceptionStack.length(); p++)
        e = chainExceptions(e, exceptionStack[p]);
    exceptionStack.shrink(pos);

    // given the bad semantics of Errors, we are fine with passing
    //  the test suite with slightly inaccurate behaviour by just
    //  rethrowing a collateral Error here, though it might need to
    //  be caught by a catch handler in an inner scope
    if (e !is caught)
    {
        if (_d_isbaseof(typeid(e), catchType))
            *cast(Throwable*) ptr = e; // the current catch can also catch this Error
        else
            _d_throw_exception(e);
    }
    return e;
}

Throwable chainExceptions(Throwable e, Throwable t)
{
    if (!cast(Error) e)
        if (auto err = cast(Error) t)
        {
            err.bypassedException = e;
            return err;
        }

    auto pChain = &e.next;
    while (*pChain)
        pChain = &(pChain.next);
    *pChain = t;
    return e;
}

ExceptionStack exceptionStack;

struct ExceptionStack
{
nothrow:
    ~this()
    {
        if (_p)
            free(_p);
    }

    void push(Throwable e)
    {
        if (_length == _cap)
            grow();
        _p[_length++] = e;
    }

    Throwable pop()
    {
        return _p[--_length];
    }

    void shrink(size_t sz)
    {
        while (_length > sz)
            _p[--_length] = null;
    }

    ref inout(Throwable) opIndex(size_t idx) inout
    {
        return _p[idx];
    }

    size_t find(Throwable e)
    {
        for (size_t i = _length; i > 0; )
            if (exceptionStack[--i] is e)
                return i;
        return ~0;
    }

    @property size_t length() const { return _length; }
    @property bool empty() const { return !length; }

    void swap(ref ExceptionStack other)
    {
        static void swapField(T)(ref T a, ref T b) { T o = b; b = a; a = o; }
        swapField(_length, other._length);
        swapField(_p,      other._p);
        swapField(_cap,    other._cap);
    }

private:
    void grow()
    {
        // alloc from GC? add array as a GC range?
        immutable ncap = _cap ? 2 * _cap : 64;
        auto p = cast(Throwable*)xmalloc(ncap * Throwable.sizeof);
        p[0 .. _length] = _p[0 .. _length];
        free(_p);
        _p = p;
        _cap = ncap;
    }

    size_t _length;
    Throwable* _p;
    size_t _cap;
}

///////////////////////////////////////////////////////////////
struct FrameInfo
{
    FrameInfo* next;
    void* handler; // typeof(&_d_unwindExceptionHandler) causes compilation error
    void* continuationAddress;
    void* returnAddress;

    size_t ebx;
    size_t ecx;
    size_t edi;
    size_t esi;

    size_t ebp;
    size_t esp;
};

// "offsetof func" does not work in inline asm
__gshared handler = &_d_unwindExceptionHandler;

///////////////////////////////////////////////////////////////
extern(C) bool _d_enter_cleanup(void* ptr)
{
    // setup an exception handler here (ptr passes the address
    // of a 40 byte stack area in a parent function scope) to deal with
    // unhandled exceptions during unwinding.

    asm
    {
        naked;
        // fill the frame with information for continuation similar
        //  to setjmp/longjmp when an exception is thrown during cleanup
        mov EAX,[ESP+4]; // ptr
        mov EDX,[ESP];   // return address
        mov [EAX+12], EDX;
        call cont;       // push continuation address
        jmp catch_handler;
    cont:
        pop dword ptr [EAX+8];

        mov [EAX+16], EBX;
        mov [EAX+20], ECX;
        mov [EAX+24], EDI;
        mov [EAX+28], ESI;
        mov [EAX+32], EBP;
        mov [EAX+36], ESP;

        mov EDX, handler;
        mov [EAX+4], EDX;
        // add link to exception chain on parent stack
        mov EDX, FS:[0];
        mov [EAX], EDX;
        mov FS:[0], EAX;
        mov AL, 1;
        ret;

    catch_handler:
        // EAX set to frame, FS:[0] restored to previous frame
        mov EBX, [EAX+16];
        mov ECX, [EAX+20];
        mov EDI, [EAX+24];
        mov ESI, [EAX+28];
        mov EBP, [EAX+32];
        mov ESP, [EAX+36];

        mov EDX, [EAX+12];
        mov [ESP], EDX;
        mov AL, 0;
        ret;
    }
}

extern(C) void _d_leave_cleanup(void* ptr)
{
    asm
    {
        naked;
        // unlink from exception chain
        // for a regular call, ptr should be the same as FS:[0]
        // if an exception has been caught in _d_enter_cleanup,
        //  FS:[0] is already the next frame, but setting it again
        //  should do no harm
        mov EAX, [ESP+4]; // ptr
        mov EAX, [EAX];
        mov FS:[0], EAX;
        ret;
    }
}

enum EXCEPTION_DISPOSITION
{
    ExceptionContinueExecution,
    ExceptionContinueSearch,
    ExceptionNestedException,
    ExceptionCollidedUnwind
}

// @safeseh to be marked as "safe" for the OS security check
extern(C) @safeseh()
EXCEPTION_DISPOSITION _d_unwindExceptionHandler(ExceptionRecord* exceptionRecord,
                                                FrameInfo* frame,
                                                CONTEXT* context,
                                                FrameInfo** dispatcherContext)
{
    // catch any D exception
    Throwable excObj = null;
    if (exceptionRecord.CxxInfo.Magic == EH_MAGIC_NUMBER1)
        excObj = *exceptionRecord.CxxInfo.pThrowable;

    // pass through non-D exceptions (should be wrapped?)
    if (!excObj || exceptionStack.find(excObj) >= exceptionStack.length())
        return EXCEPTION_DISPOSITION.ExceptionContinueSearch;

    // unwind inner frames
    doRtlUnwind(frame, exceptionRecord, &RtlUnwind);

    // continue in
    exceptionRecord.ExceptionFlags &= ~EXCEPTION_NONCONTINUABLE;
    *dispatcherContext = frame;
    context.Eip = cast(size_t) frame.continuationAddress;
    context.Eax = cast(size_t) frame;
    return EXCEPTION_DISPOSITION.ExceptionContinueExecution;
}

extern(Windows)
void RtlUnwind(void* targetFrame, void* targetIp, ExceptionRecord* pExceptRec, void* valueForEAX);

extern(C)
int doRtlUnwind(void* pFrame, ExceptionRecord* eRecord, typeof(RtlUnwind)* handler)
{
    asm {
        naked;
        push EBP;
        mov EBP,ESP;
        push ECX;
        push EBX;
        push ESI;
        push EDI;
        push EBP;

        push 0;
        push dword ptr 12[EBP]; // eRecord
        call __system_unwind;   // push targetIp
        jmp __unwind_exit;
    __system_unwind:
        push dword ptr 8[EBP];  // pFrame
        mov EAX, 16[EBP];
        call EAX;               // RtlUnwind;
    __unwind_exit:

        pop EBP;
        pop EDI;
        pop ESI;
        pop EBX;
        pop ECX;
        mov ESP,EBP;
        pop EBP;
        ret;
    }
}

///////////////////////////////////////////////////////////////
struct FiberContext
{
    ExceptionStack exceptionStack;
    void* currentException;
    void* currentExceptionContext;
    int processingContext;
}

FiberContext* fiberContext;

extern(C) void** __current_exception() nothrow;
extern(C) void** __current_exception_context() nothrow;
extern(C) int* __processing_throw() nothrow;

extern(C) void* _d_eh_swapContext(FiberContext* newContext) nothrow
{
    import core.stdc.string : memset;
    if (!fiberContext)
    {
        fiberContext = cast(FiberContext*) xmalloc(FiberContext.sizeof);
        memset(fiberContext, 0, FiberContext.sizeof);
    }
    fiberContext.exceptionStack.swap(exceptionStack);
    fiberContext.currentException = *__current_exception();
    fiberContext.currentExceptionContext = *__current_exception_context();
    fiberContext.processingContext = *__processing_throw();

    if (newContext)
    {
        exceptionStack.swap(newContext.exceptionStack);
        *__current_exception() = newContext.currentException;
        *__current_exception_context() = newContext.currentExceptionContext;
        *__processing_throw() = newContext.processingContext;
    }
    else
    {
        exceptionStack = ExceptionStack();
        *__current_exception() = null;
        *__current_exception_context() = null;
        *__processing_throw() = 0;
    }

    FiberContext* old = fiberContext;
    fiberContext = newContext;
    return old;
}

static ~this()
{
    import core.stdc.stdlib : free;
    if (fiberContext)
    {
        destroy(*fiberContext);
        free(fiberContext);
    }
}

///////////////////////////////////////////////////////////////
void msvc_eh_init()
{
    throwInfoMutex = new Mutex;

    // preallocate type descriptors likely to be needed
    getThrowInfo(typeid(Exception));
    // better not have to allocate when this is thrown:
    getThrowInfo(typeid(OutOfMemoryError));
}

shared static this()
{
    // should be called from rt_init
    msvc_eh_init();
}
