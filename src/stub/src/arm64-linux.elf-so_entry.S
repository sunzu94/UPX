/*  arm64-linux.elf-so_entry.S -- Linux DT_INIT & decompressor (Elf shared lib)
*
*  This file is part of the UPX executable compressor.
*
*  Copyright (C) 1996-2021 Markus Franz Xaver Johannes Oberhumer
*  Copyright (C) 1996-2021 Laszlo Molnar
*  Copyright (C) 2000-2023 John F. Reiser
*  All Rights Reserved.
*
*  UPX and the UCL library are free software; you can redistribute them
*  and/or modify them under the terms of the GNU General Public License as
*  published by the Free Software Foundation; either version 2 of
*  the License, or (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU General Public License for more details.
*
*  You should have received a copy of the GNU General Public License
*  along with this program; see the file COPYING.
*  If not, write to the Free Software Foundation, Inc.,
*  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*
*  Markus F.X.J. Oberhumer              Laszlo Molnar
*  <markus@oberhumer.com>               <ezerotven+github@gmail.com>
*
*  John F. Reiser
*  <jreiser@users.sourceforge.net>
*/

NBPW= 8
#include "arch/arm64/v8/macros.S"
lr .req x30

#define DEBUG 0

sz_Elf64_Ehdr = 8*NBPW
sz_Elf64_Phdr = 7*NBPW

sz_b_info= 12
  sz_unc= 0
  sz_cpr= 4
  b_method= 8
sz_l_info= 12
sz_p_info= 12

PROT_READ=  1
PROT_WRITE= 2
PROT_EXEC=  4

MAP_PRIVATE= 2
MAP_FIXED=     0x10
MAP_ANONYMOUS= 0x20

PAGE_SHIFT= 12
PAGE_MASK=  (~0<<PAGE_SHIFT)
PAGE_SIZE= -PAGE_MASK

// /usr/include/asm-generic/unistd.h
__NR_close    = 0x39  //  57
__NR_exit     = 0x5d  //  93
__NR_memfd_create = 0x117  // 279
__NR_mmap     = 0xde  // 222
__NR_mprotect = 0xe2  // 226
__NR_munmap   = 0xd7  // 215
__NR_openat   = 0x38  //  56
__NR_write    = 0x40  //  64

arg1  .req x0
arg1w .req w0
arg2  .req x1
arg2w .req w1
arg3  .req x2
arg3w .req w2
arg4  .req x3
arg4w .req w3
arg5  .req x4
arg5w .req w4
arg6  .req x5
arg6w .req w5

#define bkpt brk #0
#define call bl

  section ELFMAINX
//  .long offset(b_info)|(asl_delta>>12)  src for f_exp  FIXME: really?
//SO_INFO:
//  .word offset(.)  // detect relocation
//  .word offset(user DT_INIT)
//  .word offset(escape_hatch)  // override with round_up(2, PT_LOAD[0]{.p_memsz + .p_vaddr})
//  .word offset(dst for f_exp)

        .balign 4
_start: .globl _start
L000: b L000  //  nop  // bkpt // DEBUG
        PUSH4 (x0,x1,x2,lr)  // MATCH_00

        sub sp,sp,#4*NBPW  // space for ADRU, LENU
F_MFD=  0 * NBPW
F_ADRU= 2 * NBPW
F_LENU= 3 * NBPW

O_ARGC= 4 * NBPW

        mov arg2w,#0
        adr arg1,str_upx
        do_sys __NR_memfd_create; str w0,[sp,#F_MFD]

        bl L70
L70_ret:
    foldi   .req lr  // &fold_info
        add arg4,sp,#F_LENU  // &dstlen (IN and OUT for f_decompress)
        ldr arg2w,[foldi,#sz_cpr]  // srclen
        add arg1,foldi,#sz_b_info  // src
        ldr w7,[foldi,#sz_unc]
        str w7,[sp,#F_LENU]
    .unreq foldi

    old_sp  .req x15  //
        mov old_sp,sp
        sub x7,sp,x7  // alloca
        and sp,x7,#-2*NBPW  // align stack
        mov arg3,sp  // dst for decompress
        bl f_decompress

        ldr arg3w,[old_sp,#F_LENU]
        mov arg2,sp  // &unfolded
        ldr arg1w,[old_sp,#F_MFD]
        do_sys __NR_write
        mov sp,old_sp  // un_alloca
    .unreq old_sp

        mov arg6w,#0  // beginning of file
        ldr arg5w,[sp,#F_MFD]
        mov arg4w,#MAP_PRIVATE  // modes
        mov arg3w,#PROT_READ|PROT_EXEC  // prot
        ldr arg2w,[sp,#F_LENU]
        mov arg1,#0  // addr (kernel chooses)
        do_sys __NR_mmap; str x0,[sp,#F_ADRU]

        ldr arg1,[sp],#2*NBPW  // mfd; sp= &F_ADRU
        do_sys __NR_close

        adr arg1,_start -4 *4  // &SO_INFO
        add arg2,sp,#O_ARGC - 2*NBPW
        ldr x15,[sp,#F_ADRU - 2*NBPW]
        br x15  // invoke folded code

str_upx:
        .asciz "upx"

//%esp:
//  MATCH_04  ptr unfolded_code
//  MATCH_10  len unfolded_code
//  MATCH_00  argc,argv,envp,lr(_start)

f_decompress:
#define NO_METHOD_CHECK 1
#undef  NO_SYNC_CACHE
off     .req w5
#include "arch/arm64/v8/nrv2b_d32.S"

// IDENTSTR goes here

  section ELFMAINZ
L70:
lr .req x30
        blr lr  // lr= &fold_info
fold_info:
//  b_info (sz_unc, sz_cpr, method) of folded code (C-language, etc.)

/* vim:set ts=8 sw=8 et: */
