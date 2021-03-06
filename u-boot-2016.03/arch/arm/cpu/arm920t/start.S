/*
 *  armboot - Startup Code for ARM920 CPU-core
 *
 *  Copyright (c) 2001	Marius Gröger <mag@sysgo.de>
 *  Copyright (c) 2002	Alex Züpke <azu@sysgo.de>
 *  Copyright (c) 2002	Gary Jennejohn <garyj@denx.de>
 *
 * SPDX-License-Identifier:	GPL-2.0+
 */

#include <asm-offsets.h>
#include <common.h>
#include <config.h>

/*
 *************************************************************************
 *
 * Startup Code (called from the ARM reset exception vector)
 *
 * do important init only if we don't start from memory!
 * relocate armboot to ram
 * setup stack
 * jump to second stage
 *
 *************************************************************************
 */

	.globl	reset

reset:
	/*
	 * set the cpu to SVC32 mode
	 */
	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd3
	msr	cpsr, r0

#if	defined(CONFIG_AT91RM9200DK) || defined(CONFIG_AT91RM9200EK)
	/*
	 * relocate exception table
	 */
	ldr	r0, =_start
	ldr	r1, =0x0
	mov	r2, #16
copyex:
	subs	r2, r2, #1
	ldr	r3, [r0], #4
	str	r3, [r1], #4
	bne	copyex
#endif

#ifdef CONFIG_S3C24X0
	/* turn off the watchdog */

# if defined(CONFIG_S3C2400)
#  define pWTCON	0x15300000
#  define INTMSK	0x14400008	/* Interrupt-Controller base addresses */
#  define CLKDIVN	0x14800014	/* clock divisor register */
#else
#  define pWTCON	0x53000000
#  define INTMSK	0x4A000008	/* Interrupt-Controller base addresses */
#  define INTSUBMSK	0x4A00001C
#  define CLKDIVN	0x4C000014	/* clock divisor register */
# endif

	ldr	r0, =pWTCON
	mov	r1, #0x0
	str	r1, [r0]

	/*
	 * mask all IRQs by setting all bits in the INTMR - default
	 */
	mov	r1, #0xffffffff
	ldr	r0, =INTMSK
	str	r1, [r0]
# if defined(CONFIG_S3C2410)
	ldr	r1, =0x3ff
	ldr	r0, =INTSUBMSK
	str	r1, [r0]
# endif
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
	/* FCLK:HCLK:PCLK = 1:2:4 */
	/* default FCLK is 120 MHz ! */
	ldr	r0, =CLKDIVN
	mov	r1, #3
	str	r1, [r0]
#endif
#endif	/* CONFIG_S3C24X0 */

	/*
	 * we do sys-critical inits only at reboot,
	 * not when booting from ram!
	 */
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
	bl	cpu_init_crit
#endif

#ifdef CONFIG_BOOT_FROM_FLASH
	ldr	sp, =CONFIG_SYS_INIT_SP_ADDR
	bl boot_clock_init
	ldr r0,=0
	ldr r1,=__image_copy_start
	ldr r2,=__image_copy_end
	sub r2,r2,r1
	bl copy_code_nandtosdram
	bl boot_clear_bss
	ldr pc,=START_ON_RAM
START_ON_RAM:
#endif
	bl	_main

/*------------------------------------------------------------------------------*/

	.globl	c_runtime_cpu_setup
c_runtime_cpu_setup:

	mov	pc, lr

/*
 *************************************************************************
 *
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************
 */


#ifndef CONFIG_SKIP_LOWLEVEL_INIT
cpu_init_crit:
	/*
	 * flush v4 I/D caches
	 */
	mov	r0, #0
	mcr	p15, 0, r0, c7, c7, 0	/* flush v3/v4 cache */
	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	/*
	 * disable MMU stuff and caches
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	@ clear bits 13, 9:8 (--V- --RS)
	bic	r0, r0, #0x00000087	@ clear bits 7, 2:0 (B--- -CAM)
	orr	r0, r0, #0x00000002	@ set bit 1 (A) Align
	orr	r0, r0, #0x00001000	@ set bit 12 (I) I-Cache
	mcr	p15, 0, r0, c1, c0, 0

	/*
	 * before relocating, we have to setup RAM timing
	 * because memory timing is board-dependend, you will
	 * find a lowlevel_init.S in your board directory.
	 */
	mov	ip, lr

	bl	lowlevel_init

	mov	lr, ip
	mov	pc, lr
#endif /* CONFIG_SKIP_LOWLEVEL_INIT */

#define BWSCON1	0x48000000

	.globl lowlevel_init1
lowlevel_init1:
/* memory control configuration */	
/* make r0 relative the current location so that it */	
/* reads SMRDATA out of FLASH rather than memory ! */	
	ldr     r0, =SMRDATA1	
	ldr	r1, =CONFIG_SYS_TEXT_BASE	
	sub	r0, r0, r1	
	ldr	r1, =BWSCON1	
	/* Bus Width Status Controller */	
	add     r2, r0, #13*4
0:	ldr     r3, [r0], #4	
	str     r3, [r1], #4	
	cmp     r2, r0	
	bne     0b

	/* everything is fine now */	
	mov	pc, lr	
	mov	pc, lr	
	b lowlevel_init	
	
	.ltorg
	/* the literal pools origin */
SMRDATA1:	
	.word   0x220d9110	
	.word   0x00000700	
	.word   0x00000700	
	.word   0x00000700	
	.word   0x00001f4c	
	.word   0x00001f88	
	.word   0x00000700	
	.word   0x00018005	
	.word   0x00018005	
	.word   0x008e04f4	
	.word   0x000000b1	
	.word   0x00000030	
	.word   0x00000030

/*****************************liup led test code***start**********************************/
#define LIUP_LED_PORT_CON 0x56000050
#define LIUP_LED_PORT_DAT 0x56000054
#define LIUP_LED_ON_MASK 0x00000020
#define LIUP_LED_OFF_MASK 0xFFFFFFDF

	.global liup_led_test
liup_led_test:
    mov sp,lr
    bl liup_led_init
    bl liup_wait
    mov pc,sp

liup_led_init:
    LDR R0,=LIUP_LED_PORT_DAT
    LDR R1,[R0]
    LDR R3,=LIUP_LED_OFF_MASK
    ORR R1,R1,R3
    STR R1,[R0]

    LDR R0,=LIUP_LED_PORT_CON
    LDR R1,[R0]
    LDR R3,=0xFFFFF3FF
    AND R1,R1,R3
    LDR R3,=0x00000400
    ORR R1,R1,R3
    STR R1,[R0]
    MOV PC,LR

	.global liup_wait
liup_wait:
    BL liup_ledon
    BL liup_leddelay
    BL liup_ledoff
    BL liup_leddelay
    B liup_wait
	
liup_ledon:
    LDR R0,=LIUP_LED_PORT_DAT
    LDR R1,[R0]
    LDR R3,=LIUP_LED_ON_MASK
    ORR R1,R1,R3
    STR     R1,[R0]
    MOV PC,LR
	
liup_ledoff:
    LDR R0,=LIUP_LED_PORT_DAT
    LDR R1,[R0]
    LDR R3,=LIUP_LED_OFF_MASK
    AND R1,R1,R3
    STR R1,[R0]
    MOV PC,LR

#define LIUP_WAIT_LED_DELAY 0x200000	
liup_leddelay:
	MOV R0,#LIUP_WAIT_LED_DELAY
0:
	SUB R0,R0,#1
	MOV R1,#0
	CMP R0,r1
	BNE 0b
	MOV PC,LR

/*****************************liup led test code***end**********************************/
