module ldc.llvmir;

/**
 * Definition of LLVM inline IR.
 *
 * Copyright: Copyright The LDC Developers 2015
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Kai Nacke <kai@redstar.de>
 */

/*          Copyright The LDC Developers 2015.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

/* See https://wiki.dlang.org/LDC_inline_IR for examples.
 */

pragma(LDC_inline_ir)
    R __ir(string s, R, P...)(P);
