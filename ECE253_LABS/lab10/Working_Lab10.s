/* This files provides address values that exist in the system */

/* Memory */
        .equ  DDR_BASE,	            0x00000000
        .equ  DDR_END,              0x3FFFFFFF
        .equ  A9_ONCHIP_BASE,       0xFFFF0000
        .equ  A9_ONCHIP_END,        0xFFFFFFFF
        .equ  SDRAM_BASE,           0xC0000000
        .equ  SDRAM_END,            0xC3FFFFFF
        .equ  FPGA_ONCHIP_BASE,     0xC8000000
        .equ  FPGA_ONCHIP_END,      0xC803FFFF
        .equ  FPGA_CHAR_BASE,       0xC9000000
        .equ  FPGA_CHAR_END,        0xC9001FFF

/* Cyclone V FPGA devices */
        .equ  LEDR_BASE,             0xFF200000
        .equ  HEX3_HEX0_BASE,        0xFF200020
        .equ  HEX5_HEX4_BASE,        0xFF200030
        .equ  SW_BASE,               0xFF200040
        .equ  KEY_BASE,              0xFF200050
        .equ  JP1_BASE,              0xFF200060
        .equ  JP2_BASE,              0xFF200070
        .equ  PS2_BASE,              0xFF200100
        .equ  PS2_DUAL_BASE,         0xFF200108
        .equ  JTAG_UART_BASE,        0xFF201000
        .equ  JTAG_UART_2_BASE,      0xFF201008
        .equ  IrDA_BASE,             0xFF201020
        .equ  TIMER_BASE,            0xFF202000
        .equ  AV_CONFIG_BASE,        0xFF203000
        .equ  PIXEL_BUF_CTRL_BASE,   0xFF203020
        .equ  CHAR_BUF_CTRL_BASE,    0xFF203030
        .equ  AUDIO_BASE,            0xFF203040
        .equ  VIDEO_IN_BASE,         0xFF203060
        .equ  ADC_BASE,              0xFF204000

/* Cyclone V HPS devices */
        .equ   HPS_GPIO1_BASE,       0xFF709000
        .equ   HPS_TIMER0_BASE,      0xFFC08000
        .equ   HPS_TIMER1_BASE,      0xFFC09000
        .equ   HPS_TIMER2_BASE,      0xFFD00000
        .equ   HPS_TIMER3_BASE,      0xFFD01000
        .equ   FPGA_BRIDGE,          0xFFD0501C

/* ARM A9 MPCORE devices */
        .equ   PERIPH_BASE,          0xFFFEC000   /* base address of peripheral devices */
        .equ   MPCORE_PRIV_TIMER,    0xFFFEC600   /* PERIPH_BASE + 0x0600 */

        /* Interrupt controller (GIC) CPU interface(s) */
        .equ   MPCORE_GIC_CPUIF,     0xFFFEC100   /* PERIPH_BASE + 0x100 */
        .equ   ICCICR,               0x00         /* CPU interface control register */
        .equ   ICCPMR,               0x04         /* interrupt priority mask register */
        .equ   ICCIAR,               0x0C         /* interrupt acknowledge register */
        .equ   ICCEOIR,              0x10         /* end of interrupt register */
        /* Interrupt controller (GIC) distributor interface(s) */
        .equ   MPCORE_GIC_DIST,      0xFFFED000   /* PERIPH_BASE + 0x1000 */
        .equ   ICDDCR,               0x00         /* distributor control register */
        .equ   ICDISER,              0x100        /* interrupt set-enable registers */
        .equ   ICDICER,              0x180        /* interrupt clear-enable registers */
        .equ   ICDIPTR,              0x800        /* interrupt processor targets registers */
        .equ   ICDICFR,              0xC00        /* interrupt configuration registers */
		
		
		
		
		















			.equ		EDGE_TRIGGERED,         0x1
			.equ		LEVEL_SENSITIVE,        0x0
			.equ		CPU0,         				0x01	// bit-mask; bit 0 represents cpu0
			.equ		ENABLE, 						0x1

			.equ		KEY0, 						0b0001
			.equ		KEY1, 						0b0010
			.equ		KEY2,							0b0100
			.equ		KEY3,							0b1000

			.equ		RIGHT,						1
			.equ		LEFT,							2

			.equ		USER_MODE,					0b10000
			.equ		FIQ_MODE,					0b10001
			.equ		IRQ_MODE,					0b10010
			.equ		SVC_MODE,					0b10011
			.equ		ABORT_MODE,					0b10111
			.equ		UNDEF_MODE,					0b11011
			.equ		SYS_MODE,					0b11111

			.equ		INT_ENABLE,					0b01000000
			.equ		INT_DISABLE,				0b11000000
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
/* 
 * This file:
 * 1. defines exception vectors for the A9 processor
 * 2. provides code that initializes the generic interrupt controller
 */

/*********************************************************************************
 * Initialize the exception vector table
 ********************************************************************************/
.section .vectors, "ax"

				B				_start						// Reset vector
				B				SERVICE_UND				// Undefined instruction vector
				B				SERVICE_SVC				// Software interrrupt vector
				B				SERVICE_ABT_INST	// aborted prefetch vector
				B				SERVICE_ABT_DATA	// aborted data vector
				.word		0									// Unused vector
				B				SERVICE_IRQ				// IRQ interrupt vector
				B				SERVICE_FIQ				// FIQ interrupt vector

.text
/*--- IRQ ---------------------------------------------------------------------*/
.global	SERVICE_IRQ

SERVICE_IRQ:
/*
 * Save R0-R3, because subroutines called from here might modify
 * these registers without saving/restoring them. Save R4, R5
 * because we modify them in this subroutine
 */
					PUSH		{R0-R5, LR}
					/* Read the ICCIAR from the CPU interface */
					LDR			R4,	=MPCORE_GIC_CPUIF
					LDR			R5,	[R4, #ICCIAR]						// Read the interrupt ID - stores 
																							// ID of device that caused interrupt

PRIV_TIMER_CHECK:
					CMP			R5, #MPCORE_PRIV_TIMER_IRQ	// Compare interrupt ID to 29
					BNE			KEYS_CHECK									// If timer didn't cause interrupt, check keys
					BL			PRIV_TIMER_ISR							// If timer, go to timer ISR
					B				EXIT_IRQ

KEYS_CHECK:
					CMP			R5, #KEYS_IRQ
UNEXPECTED:
					BNE			UNEXPECTED
					BL			KEY_ISR

EXIT_IRQ:
					/* Write to the End of Interrupt Register (ICCEOIR) */
					// Lets processor know when it has completed handling the interrupt
					STR			R5, [R4, #ICCEOIR]
					POP			{R0-R5, LR}
					SUBS		PC, LR, #4									// Return from interrupt


/*--- Undefined instructions --------------------------------------------------*/
.global SERVICE_UND
SERVICE_UND:
					B				SERVICE_UND
 
/*--- Software interrupts -----------------------------------------------------*/
.global SERVICE_SVC
SERVICE_SVC:
					B				SERVICE_SVC 

/*--- Aborted data reads ------------------------------------------------------*/
.global SERVICE_ABT_DATA
SERVICE_ABT_DATA:
					B				SERVICE_ABT_DATA 

/*--- Aborted instruction fetch -----------------------------------------------*/
				.global	SERVICE_ABT_INST
SERVICE_ABT_INST:
					B				SERVICE_ABT_INST 
 
/*--- FIQ ---------------------------------------------------------------------*/
.global SERVICE_FIQ
SERVICE_FIQ:
					B				SERVICE_FIQ 

/* 
 * Configure the Generic Interrupt Controller (GIC)
 */
.global CONFIG_GIC
CONFIG_GIC:
					PUSH		{LR}
					/* 
					 * Configure the A9 Private Timer interrupt and FPGA KEYs
					 * CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1));
					 */
					MOV			R0, #MPCORE_PRIV_TIMER_IRQ
					MOV			R1, #CPU0
					BL			CONFIG_INTERRUPT
					MOV			R0, #KEYS_IRQ
					MOV			R1, #CPU0
					BL			CONFIG_INTERRUPT

					/* Configure the GIC CPU interface */
					LDR			R0, =0xFFFEC100		// Base address of CPU interface
					/* Set Interrupt Priority Mask Register (ICCPMR) */
					LDR			R1, =0xFFFF				// Enable interrupts of all priorities levels
					STR			R1, [R0, #0x04]
					/* 
					 * Set the enable bit in the CPU Interface Control Register (ICCICR). 
					 * This bit allows interrupts to be forwarded to the CPU(s)
					 */
					MOV			R1, #1
					STR			R1, [R0]

					/* 
					 * Set the enable bit in the Distributor Control Register (ICDDCR). This bit
					 * allows the distributor to forward interrupts to the CPU interface(s)
					 */
					LDR			R0, =0xFFFED000
					STR			R1, [R0]

					POP			{PC}
/* 
 * Configure registers in the GIC for an individual interrupt ID
 * We configure only the Interrupt Set Enable Registers (ICDISERn) and Interrupt 
 * Processor Target Registers (ICDIPTRn). The default (reset) values are used for 
 * other registers in the GIC
 * Arguments: R0 = interrupt ID, N
 *            R1 = CPU target
 */
CONFIG_INTERRUPT:
					PUSH		{R4-R5, LR}

					/* 
					 * Configure Interrupt Set-Enable Registers (ICDISERn). 
					 * reg_offset = (integer_div(N / 32) * 4
					 * value = 1 << (N mod 32)
					 */
					LSR			R4, R0, #3				// Calculate reg_offset
					BIC			R4, R4, #3				// R4 = reg_offset
					LDR			R2, =0xFFFED100
					ADD			R4, R2, R4				// R4 = address of ICDISER

					AND			R2, R0, #0x1F			// N mod 32
					MOV			R5, #1						// Enable
					LSL			R2, R5, R2				// R2 = value

					/* now that we have the register address (R4) and value (R2), we need to set the
					 * correct bit in the GIC register */
					LDR		R3, [R4]						// read current register value
					ORR		R3, R3, R2					// set the enable bit
					STR		R3, [R4]						// store the new register value

					/* 
					 * Configure Interrupt Processor Targets Register (ICDIPTRn)
					 * reg_offset = integer_div(N / 4) * 4
					 * index = N mod 4
					 */
					BIC			R4, R0, #3				// R4 = reg_offset
					LDR			R2, =0xFFFED800
					ADD			R4, R2, R4				// R4 = word address of ICDIPTR
					AND			R2, R0, #0x3			// N mod 4
					ADD			R4, R2, R4				// R4 = byte address in ICDIPTR

					/* 
					 * Now that we have the register address (R4) and value (R2), write to (only)
					 * the appropriate byte
					 */
					STRB		R1, [R4]
					POP			{R4-R5, PC}
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					/* This files provides interrupt IDs */

/* FPGA interrupts (there are 64 in total; only a few are defined below) */
			.equ	INTERVAL_TIMER_IRQ, 			72
			.equ	KEYS_IRQ, 						73
			.equ	FPGA_IRQ2, 						74
			.equ	FPGA_IRQ3, 						75
			.equ	FPGA_IRQ4, 						76
			.equ	FPGA_IRQ5, 						77
			.equ	AUDIO_IRQ, 						78
			.equ	PS2_IRQ, 						79
			.equ	JTAG_IRQ, 						80
			.equ	IrDA_IRQ, 						81
			.equ	FPGA_IRQ10,						82
			.equ	JP1_IRQ,							83
			.equ	JP2_IRQ,							84
			.equ	FPGA_IRQ13,						85
			.equ	FPGA_IRQ14,						86
			.equ	FPGA_IRQ15,						87
			.equ	FPGA_IRQ16,						88
			.equ	PS2_DUAL_IRQ,					89
			.equ	FPGA_IRQ18,						90
			.equ	FPGA_IRQ19,						91

/* ARM A9 MPCORE devices (there are many; only a few are defined below) */
			.equ	MPCORE_GLOBAL_TIMER_IRQ,	27
			.equ	MPCORE_PRIV_TIMER_IRQ,		29
			.equ	MPCORE_WATCHDOG_IRQ,			30

/* HPS devices (there are many; only a few are defined below) */
			.equ	HPS_UART0_IRQ,   				194
			.equ	HPS_UART1_IRQ,   				195
			.equ	HPS_GPIO0_IRQ,          	196
			.equ	HPS_GPIO1_IRQ,          	197
			.equ	HPS_GPIO2_IRQ,          	198
			.equ	HPS_TIMER0_IRQ,         	199
			.equ	HPS_TIMER1_IRQ,         	200
			.equ	HPS_TIMER2_IRQ,         	201
			.equ	HPS_TIMER3_IRQ,         	202
			.equ	HPS_WATCHDOG0_IRQ,     		203
			.equ	HPS_WATCHDOG1_IRQ,     		204
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			/***************************************************************************************
 * Pushbutton - Interrupt Service Routine                                
 *                                                                          
 * This routine checks which KEY has been pressed.  If KEY3 it stops/starts the timer.
****************************************************************************************/
.global	KEY_ISR

KEY_ISR:
		LDR	R0, =KEY_BASE		// Base address of KEYs parallel port
		LDR	R1, [R0, #0xC]		// Read edge capture register
		STR	R1, [R0, #0xC]		// Clear the interrupt

CHK_KEY3:
		TST	R1, #0b1000		// Check if KEY3 has been pressed
		BEQ	END_KEY_ISR		// If equal, then KEY3 has not been pressed

START_STOP:
		LDR	R0, =MPCORE_PRIV_TIMER	// Timer base address
		LDR	R1, [R0, #0x8]		// Read timer control register
		MOV	R2, #1			// Move 1 into R3
		EOR	R1, R2			// EOR the enable bit with 1 to flip it
		STR	R1, [R0, #0x8]		// Store enable bit to control register 
																					// to start/stop the timer (E)
END_KEY_ISR:
		MOV	PC, LR
					
									
					
					
					
					/* 
 * This program demonstrates the use of interrupts using the KEY and timer ports. It
 * 	1. displays a sweeping red light on LEDR, which moves left and right
 * 	2. stops/starts the sweeping motion if KEY3 is presse
 * Both the timer and KEYs are handled via interrupts
*/
.text
.global _start

_start:
	// Initializing IRQ stack pointer 
		MOV	R0, #0b10010		// Load the IRQ mode value into R0
		MSR	CPSR, R0		// Change mode to IRQ
		LDR	SP, =0xFFFFFFFC		// Set stack pointer
	// Initializing SVC stack pointer 
		MOV	R0, #0b10011		// Load SVC mode value into R0
		MSR	CPSR, R0		// Change mode to SVC
		LDR	SP, =0x3FFFFFFC		// Set stack pointer to some random value far away

	// Configuring GIC, timer, KEYS
		BL	CONFIG_GIC		// Configure the ARM generic interrupt controller
		BL	CONFIG_PRIV_TIMER	// Configure the MPCore private timer
		BL	CONFIG_KEYS		// Configure the pushbutton KEYs
			
	// Enable ARM processor interrupts 
		MSR	CPSR, #0b00010011	// Change 7th bit to 0 in SVC mode to enable interrupts

		LDR	R6, =0xFF200000		// Red LED base address

MAIN:
		LDR	R4, LEDR_PATTERN	// LEDR pattern; modified by timer ISR
		STR	R4, [R6]		// Write to red LEDs
		B		MAIN

// Configure the MPCore private timer to create interrupts every 2.5/10 second 
CONFIG_PRIV_TIMER:
		LDR	R0, =0xFFFEC600		// Timer base address
		LDR	R1, =50000000		// Set timer to 0.25s
		STR	R1, [R0]		// Specify number to count down from
		MOV	R1, #0b111		// I = 1 (enable interrupts), A = 1 (auto-reload), E (start timer)
		STR	R1, [R0, #8]		// Write to control address
		MOV	PC, LR			// end branched loop

// Configure the KEYS to generate an interrupt 
CONFIG_KEYS:
		LDR	R0, =0xFF200050		// KEYs base address
		MOV	R1, #0b1000		// Look for when KEY3 is pressed
		STR	R1, [R0, #0x8]		// Store in interrupt mask register
		MOV	PC, LR			// end branched loop

		.global	LEDR_DIRECTION
LEDR_DIRECTION:
		.word	0			// 0 for left, 1 for right

		.global	LEDR_PATTERN
LEDR_PATTERN:
		.word	0x201			//1000000001
			
			



/*****************************************************************************
 * MPCORE Private Timer - Interrupt Service Routine
 *
 * Shifts the pattern being displayed on the LEDR
 * 
******************************************************************************/
.global PRIV_TIMER_ISR
PRIV_TIMER_ISR:
	LDR			R0, =MPCORE_PRIV_TIMER	// Base address of timer
				MOV		R1, #1
				STR		R1, [R0, #0xC]		// Write 1 to F bit to reset it and clear the interrupt

/*Move the two LEDS to the centre or away from the centre to the outside.*/
SWEEP:				LDR		R0, =LEDR_DIRECTION	// put shifting direction into R2
				LDR		R2, [R0]
				LDR		R1, =LEDR_PATTERN	// put LEDR pattern into R3
				LDR		R3, [R1]

				
				//From Lab 9
				//Check for edge cases
				LDR R12, =0x201 //1000000001 load the outside light pattern into ledr
				CMP R3, R12 			//check if pattern matches
				LDREQ R12, =0x102		//if same load next pattern
				STREQ R12, [R1]			// store new pattern into r1
				MOVEQ R11, #0			// store 0 in r11
				STREQ R11, [R0]			//move r11 to r0 so set direction to go inside
				BEQ END_TIMER_ISR
				
				LDR R12, =0x030 //0000110000 inside light pattern
				CMP R3, R12			//check if same
				LDREQ R12, =0x48		//if same load next pattern
				STREQ R12, [R1]			//store new pattern in r1
				MOVEQ R11, #1			//reset direction to 1
				STREQ R11, [R0]
				BEQ END_TIMER_ISR
				
				
				CMP	R2, #0		// Checks if direction if center=0, outside=1
				BEQ CENTER		//if 0, sweep through centre values
				BNE OUTSIDE		//if not 0 sweep through outside values
//same idea as before, comments unnecessary
CENTER: 
				LDR R12, =0x102 //0100000010
				CMP R3, R12
				LDREQ R12, =0x084
				STREQ R12, [R1]
				BEQ END_TIMER_ISR
				
				LDR R12, =0x084 //0010000100
				CMP R3, R12
				LDREQ R12, =0x048
				STREQ R12, [R1]
				BEQ END_TIMER_ISR


				LDR R12, =0x48 //0001001000
				CMP R3, R12
				LDREQ R12, =0x030
				STREQ R12, [R1]
				BEQ END_TIMER_ISR


OUTSIDE:
				LDR R12, =0x102 //0100000010
				CMP R3, R12
				LDREQ R12, =0x201
				STREQ R12, [R1]
				BEQ END_TIMER_ISR


				LDR R12, =0x084 //0010000100
				CMP R3, R12
				LDREQ R12, =0x102
				STREQ R12, [R1]
				BEQ END_TIMER_ISR


				LDR R12, =0x48 //0001001000
				CMP R3, R12
				LDREQ R12, =0x084
				STREQ R12, [R1]
				BEQ END_TIMER_ISR


END_TIMER_ISR:
				MOV		PC, LR