/*
 * This module holds declarations to LLVM intrinsics.
 *
 * See the LLVM language reference for more information:
 *
 * - http://llvm.org/docs/LangRef.html#intrinsics
 *
 */

module ldc.intrinsics;

// Check for the right compiler
version(LDC)
{
    // OK
}
else
{
    static assert(false, "This module is only valid for LDC");
}

// All intrinsics are nothrow. The codegen intrinsics are not categorized any
// further (they probably could), the rest is pure (aborting is fine by
// definition; memcpy and friends can be viewed as weakly pure, just as e.g.
// strlen() is marked weakly pure as well) and mostly @safe.
nothrow:


//
// CODE GENERATOR INTRINSICS
//


// The 'llvm.returnaddress' intrinsic attempts to compute a target-specific
// value indicating the return address of the current function or one of its
// callers.

pragma(intrinsic, "llvm.returnaddress")
    void* llvm_returnaddress(uint level);


// The 'llvm.frameaddress' intrinsic attempts to return the target-specific
// frame pointer value for the specified stack frame.

pragma(intrinsic, "llvm.frameaddress")
    void* llvm_frameaddress(uint level);


// The 'llvm.stacksave' intrinsic is used to remember the current state of the
// function stack, for use with llvm.stackrestore. This is useful for
// implementing language features like scoped automatic variable sized arrays
// in C99.

pragma(intrinsic, "llvm.stacksave")
    void* llvm_stacksave();


// The 'llvm.stackrestore' intrinsic is used to restore the state of the
// function stack to the state it was in when the corresponding llvm.stacksave
// intrinsic executed. This is useful for implementing language features like
// scoped automatic variable sized arrays in C99.

pragma(intrinsic, "llvm.stackrestore")
    void llvm_stackrestore(void* ptr);


// The 'llvm.prefetch' intrinsic is a hint to the code generator to insert a
// prefetch instruction if supported; otherwise, it is a noop. Prefetches have
// no effect on the behavior of the program but can change its performance
// characteristics.

pragma(intrinsic, "llvm.prefetch")
    void llvm_prefetch(void* ptr, uint rw, uint locality);


// The 'llvm.pcmarker' intrinsic is a method to export a Program Counter (PC)
// in a region of code to simulators and other tools. The method is target
// specific, but it is expected that the marker will use exported symbols to
// transmit the PC of the marker. The marker makes no guarantees that it will
// remain with any specific instruction after optimizations. It is possible
// that the presence of a marker will inhibit optimizations. The intended use
// is to be inserted after optimizations to allow correlations of simulation
// runs.

pragma(intrinsic, "llvm.pcmarker")
    void llvm_pcmarker(uint id);


// The 'llvm.readcyclecounter' intrinsic provides access to the cycle counter
// register (or similar low latency, high accuracy clocks) on those targets that
// support it. On X86, it should map to RDTSC. On Alpha, it should map to RPCC.
// As the backing counters overflow quickly (on the order of 9 seconds on
// alpha), this should only be used for small timings.

pragma(intrinsic, "llvm.readcyclecounter")
    ulong readcyclecounter();




//
// STANDARD C LIBRARY INTRINSICS
//


pure:

// The 'llvm.memcpy.*' intrinsics copy a block of memory from the source
// location to the destination location.
// Note that, unlike the standard libc function, the llvm.memcpy.* intrinsics do
// not return a value, and takes an extra alignment argument.

pragma(intrinsic, "llvm.memcpy.p0i8.p0i8.i#")
    void llvm_memcpy(T)(void* dst, void* src, T len, uint alignment, bool volatile_ = false);


// The 'llvm.memmove.*' intrinsics move a block of memory from the source
// location to the destination location. It is similar to the 'llvm.memcpy'
// intrinsic but allows the two memory locations to overlap.
// Note that, unlike the standard libc function, the llvm.memmove.* intrinsics
// do not return a value, and takes an extra alignment argument.


pragma(intrinsic, "llvm.memmove.p0i8.p0i8.i#")
    void llvm_memmove(T)(void* dst, void* src, T len, uint alignment, bool volatile_ = false);


// The 'llvm.memset.*' intrinsics fill a block of memory with a particular byte
// value.
// Note that, unlike the standard libc function, the llvm.memset intrinsic does
// not return a value, and takes an extra alignment argument.

pragma(intrinsic, "llvm.memset.p0i8.i#")
    void llvm_memset(T)(void* dst, ubyte val, T len, uint alignment, bool volatile_ = false);


@safe:

// The 'llvm.sqrt' intrinsics return the sqrt of the specified operand,
// returning the same value as the libm 'sqrt' functions would. Unlike sqrt in
// libm, however, llvm.sqrt has undefined behavior for negative numbers other
// than -0.0 (which allows for better optimization, because there is no need to
// worry about errno being set). llvm.sqrt(-0.0) is defined to return -0.0 like
// IEEE sqrt.

pragma(intrinsic, "llvm.sqrt.f#")
    T llvm_sqrt(T)(T val);


// The 'llvm.sin.*' intrinsics return the sine of the operand.

pragma(intrinsic, "llvm.sin.f#")
    T llvm_sin(T)(T val);


// The 'llvm.cos.*' intrinsics return the cosine of the operand.

pragma(intrinsic, "llvm.cos.f#")
    T llvm_cos(T)(T val);


// The 'llvm.powi.*' intrinsics return the first operand raised to the specified
// (positive or negative) power. The order of evaluation of multiplications is
// not defined. When a vector of floating point type is used, the second
// argument remains a scalar integer value.

pragma(intrinsic, "llvm.powi.f#")
    T llvm_powi(T)(T val, int power);


// The 'llvm.pow.*' intrinsics return the first operand raised to the specified
// (positive or negative) power.

pragma(intrinsic, "llvm.pow.f#")
    T llvm_pow(T)(T val, T power);


// The 'llvm.exp.*' intrinsics perform the exp function.

pragma(intrinsic, "llvm.exp.f#")
    T llvm_exp(T)(T val);


// The 'llvm.log.*' intrinsics perform the log function.

pragma(intrinsic, "llvm.log.f#")
    T llvm_log(T)(T val);


// The 'llvm.fma.*' intrinsics perform the fused multiply-add operation.

pragma(intrinsic, "llvm.fma.f#")
    T llvm_fma(T)(T vala, T valb, T valc);


// The 'llvm.fabs.*' intrinsics return the absolute value of the operand.

pragma(intrinsic, "llvm.fabs.f#")
    T llvm_fabs(T)(T val);


// The 'llvm.floor.*' intrinsics return the floor of the operand.

pragma(intrinsic, "llvm.floor.f#")
    T llvm_floor(T)(T val);


// The 'llvm.fmuladd.*' intrinsic functions represent multiply-add expressions
// that can be fused if the code generator determines that the fused expression
//  would be legal and efficient.

pragma(intrinsic, "llvm.fmuladd.f#")
    T llvm_fmuladd(T)(T vala, T valb, T valc);


//
// BIT MANIPULATION INTRINSICS
//

// The 'llvm.bswap' family of intrinsics is used to byte swap integer values
// with an even number of bytes (positive multiple of 16 bits). These are
// useful for performing operations on data that is not in the target's native
// byte order.

pragma(intrinsic, "llvm.bswap.i#.i#")
    T llvm_bswap(T)(T val);


// The 'llvm.ctpop' family of intrinsics counts the number of bits set in a
// value.

pragma(intrinsic, "llvm.ctpop.i#")
    T llvm_ctpop(T)(T src);


// The 'llvm.ctlz' family of intrinsic functions counts the number of leading
// zeros in a variable.

version (LDC_LLVM_300)
{
    pragma(intrinsic, "llvm.ctlz.i#")
        T llvm_ctlz(T)(T src);
}
else
{
    pragma(intrinsic, "llvm.ctlz.i#")
        T llvm_ctlz(T)(T src, bool isZerodefined);
}


// The 'llvm.cttz' family of intrinsic functions counts the number of trailing
// zeros.

version (LDC_LLVM_300)
{
    pragma(intrinsic, "llvm.cttz.i#")
        T llvm_cttz(T)(T src);
}
else
{
    pragma(intrinsic, "llvm.cttz.i#")
        T llvm_cttz(T)(T src, bool isZerodefined);
}


// The 'llvm.part.select' family of intrinsic functions selects a range of bits
// from an integer value and returns them in the same bit width as the original
// value.

pragma(intrinsic, "llvm.part.select.i#")
    T llvm_part_select(T)(T val, uint loBit, uint hiBit);


// The 'llvm.part.set' family of intrinsic functions replaces a range of bits
// in an integer value with another integer value. It returns the integer with
// the replaced bits.

// TODO
// declare i17 @llvm.part.set.i17.i9 (i17 %val, i9 %repl, i32 %lo, i32 %hi)
// declare i29 @llvm.part.set.i29.i9 (i29 %val, i9 %repl, i32 %lo, i32 %hi)




//
// ATOMIC OPERATIONS AND SYNCHRONIZATION INTRINSICS
//

enum AtomicOrdering {
  NotAtomic = 0,
  Unordered = 1,
  Monotonic = 2,
  Consume = 3,
  Acquire = 4,
  Release = 5,
  AcquireRelease = 6,
  SequentiallyConsistent = 7
};
alias AtomicOrdering.SequentiallyConsistent DefaultOrdering;

// The 'fence' intrinsic is used to introduce happens-before edges between operations.
pragma(fence)
    void llvm_memory_fence(AtomicOrdering ordering = DefaultOrdering);

// This intrinsic loads a value stored in memory at ptr.
pragma(atomic_load)
    T llvm_atomic_load(T)(in shared T *ptr, AtomicOrdering ordering = DefaultOrdering);

// This intrinsic stores a value in val in the memory at ptr.
pragma(atomic_store)
    void llvm_atomic_store(T)(T val, shared T *ptr, AtomicOrdering ordering = DefaultOrdering);


// This loads a value in memory and compares it to a given value. If they are
// equal, it stores a new value into the memory.

pragma(atomic_cmp_xchg)
    T llvm_atomic_cmp_swap(T)(shared T* ptr, T cmp, T val, AtomicOrdering ordering = DefaultOrdering);


// This intrinsic loads the value stored in memory at ptr and yields the value
// from memory. It then stores the value in val in the memory at ptr.

pragma(atomic_rmw, "xchg")
    T llvm_atomic_swap(T)(shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

// This intrinsic adds delta to the value stored in memory at ptr. It yields
// the original value at ptr.

pragma(atomic_rmw, "add")
    T llvm_atomic_load_add(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

// This intrinsic subtracts delta to the value stored in memory at ptr. It
// yields the original value at ptr.

pragma(atomic_rmw, "sub")
    T llvm_atomic_load_sub(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

// These intrinsics bitwise the operation (and, nand, or, xor) delta to the
// value stored in memory at ptr. It yields the original value at ptr.

pragma(atomic_rmw, "and")
    T llvm_atomic_load_and(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

pragma(atomic_rmw, "nand")
    T llvm_atomic_load_nand(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

pragma(atomic_rmw, "or")
    T llvm_atomic_load_or(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

pragma(atomic_rmw, "xor")
    T llvm_atomic_load_xor(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

// These intrinsics takes the signed or unsigned minimum or maximum of delta
// and the value stored in memory at ptr. It yields the original value at ptr.

pragma(atomic_rmw, "max")
    T llvm_atomic_load_max(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

pragma(atomic_rmw, "min")
    T llvm_atomic_load_min(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

pragma(atomic_rmw, "umax")
    T llvm_atomic_load_umax(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);

pragma(atomic_rmw, "umin")
    T llvm_atomic_load_umin(T)(in shared T* ptr, T val, AtomicOrdering ordering = DefaultOrdering);


//
// ARITHMETIC-WITH-OVERFLOW INTRINSICS
//

struct OverflowRet(T) {
    static assert(is(T : long), T.stringof ~ " is not an integer type!");
    T result;
    bool overflow;
}

// Signed and unsigned addition
pragma(intrinsic, "llvm.sadd.with.overflow.i#")
    OverflowRet!(T) llvm_sadd_with_overflow(T)(T lhs, T rhs);

pragma(intrinsic, "llvm.uadd.with.overflow.i#")
    OverflowRet!(T) llvm_uadd_with_overflow(T)(T lhs, T rhs);


// Signed and unsigned subtraction
pragma(intrinsic, "llvm.ssub.with.overflow.i#")
    OverflowRet!(T) llvm_ssub_with_overflow(T)(T lhs, T rhs);

pragma(intrinsic, "llvm.usub.with.overflow.i#")
    OverflowRet!(T) llvm_usub_with_overflow(T)(T lhs, T rhs);


// Signed and unsigned multiplication
pragma(intrinsic, "llvm.smul.with.overflow.i#")
    OverflowRet!(T) llvm_smul_with_overflow(T)(T lhs, T rhs);

/* Note: LLVM documentations says:
 *  Warning: 'llvm.umul.with.overflow' is badly broken.
 *  It is actively being fixed, but it should not currently be used!
 *
 * See: http://llvm.org/docs/LangRef.html#int_umul_overflow
 */
//pragma(intrinsic, "llvm.umul.with.overflow.i#")
//    OverflowRet!(T) llvm_umul_with_overflow(T)(T lhs, T rhs);


//
// GENERAL INTRINSICS
//


// This intrinsics is lowered to the target dependent trap instruction. If the
// target does not have a trap instruction, this intrinsic will be lowered to
// the call of the abort() function.

pragma(intrinsic, "llvm.trap")
    void llvm_trap();
