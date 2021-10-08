//============================================================================
//  Arcade: Robotron
//
//  Port to MiSTer
//  Copyright (C) 2018 
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign VGA_F1    = 0;
assign VGA_SCALER =0;
assign AUDIO_MIX = 0;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;
assign FB_FORCE_BLANK = '0;
assign HDMI_FREEZE = 0;

wire [1:0] ar = status[17:16];

assign VIDEO_ARX = (!ar) ? ((status[2] | landscape) ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] | landscape) ? 8'd3 : 8'd4) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.ROBTRN;;", 
	"-;",
	"H0OGH,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"h2O6,Fire,4-way,Move+Fire;",
	"h3O67,Control,Mode 1,Mode 2,Cabinet;",
	"h4O67,Fire,4-way,Move with Fire,Second Joystick;",
	"h2h3h4-;",
	"DIP;",
	"-;",
	"H5OR,Autosave Hiscores,Off,On;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Start 1P,Start 2P,Coin,Pause;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_vid;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid),
	.outclk_1(clk_sys)
);


///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire  [7:0] ioctl_data;
wire        ioctl_wait;

wire [31:0] joy1, joy2;
wire [31:0] joy = joy1 | joy2;

wire [15:0] joy1a, joy2a;
wire [15:0] joya = j2 ? joy2a : joy1a;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	
	.buttons(buttons),
	.status(status),
	.status_menumask({hs_configured,mod == mod_robotron,mod == mod_stargate,mod == mod_splat,landscape,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joy1),
	.joystick_1(joy2),

	.joystick_analog_0(joy1a),
	.joystick_analog_1(joy2a)

);

wire rom_download = ioctl_download && !ioctl_index;
wire reset = RESET | status[0] | buttons[1] | rom_download;

///////////////////////////////////////////////////////////////////

wire m_start1  = joy[10];
wire m_start2  = joy[11];
wire m_coin1   = joy[12];
wire m_advance = joy[13];
wire m_autoup  = joy[14];
wire m_pause   = joy[15];

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];
wire m_fire1c  = joy1[6];
wire m_fire1d  = joy1[7];
wire m_fire1e  = joy1[8];
wire m_fire1f  = joy1[9];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];
wire m_fire2c  = joy2[6];
wire m_fire2d  = joy2[7];
wire m_fire2e  = joy2[8];
wire m_fire2f  = joy2[9];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
wire m_fire_c  = m_fire1c | m_fire2c;
wire m_fire_d  = m_fire1d | m_fire2d;
wire m_fire_e  = m_fire1e | m_fire2e;
wire m_fire_f  = m_fire1f | m_fire2f;

// PAUSE SYSTEM
wire				pause_cpu;
wire [7:0]		rgb_out;
pause #(3,3,2,12) pause (
	.*,
	.user_button(m_pause),
	.pause_request(hs_pause),
	.options(~status[26:25])
);

///////////////////////////////////////////////////////////////////

localparam mod_robotron = 0;
localparam mod_joust    = 1;
localparam mod_splat    = 2;
localparam mod_bubbles  = 3;
localparam mod_stargate = 4;
localparam mod_alienar  = 5;
localparam mod_sinistar = 6;
localparam mod_playball = 7;

reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

///////////////////////////////////////////////////////////////////

reg  [7:0] JA;
reg  [7:0] JB;
reg  [7:0] SW;
reg  [2:0] BTN;
reg        blitter_sc2, sinistar;
reg        landscape;


always @(*) begin

	landscape = 1;
	JA = 0;
	JB = 0;
	BTN = 0;
	blitter_sc2 = 0;
	sinistar = 0;
	SW  = sw[0] | { 6'b0,m_advance,m_autoup};

	case (mod)
		mod_robotron:
			begin
				BTN = { m_start1, m_start2, m_coin1 };
				JA  = ~{ status[7] ? {m_right2, m_left2, m_down2, m_up2} : status[6] ? {m_right, m_left, m_down, m_up} : {m_fire_a, m_fire_d, m_fire_b, m_fire_c},
							status[7] ? {m_right1, m_left1, m_down1, m_up1} : {m_right, m_left, m_down, m_up}};
				JB  = JA;
			end
		mod_joust:
			begin
				BTN = { m_start2, m_start1, m_coin1 };
				JA  = ~{ 5'b00000, m_fire1a, m_right1, m_left1 };
				JB  = ~{ 5'b00000, m_fire2a, m_right2, m_left2 };
			end
		mod_splat:
			begin
				blitter_sc2 = 1;
				BTN = { m_start1, m_start2, m_coin1 };
				JA  = ~{ status[6] ? {m_right1, m_left1, m_down1, m_up1} : {m_fire1a, m_fire1d, m_fire1b, m_fire1c}, m_right1, m_left1, m_down1, m_up1 };
				JB  = ~{ status[6] ? {m_right2, m_left2, m_down2, m_up2} : {m_fire2a, m_fire2d, m_fire2b, m_fire2c}, m_right2, m_left2, m_down2, m_up2 };
			end
		mod_bubbles:
			begin
				BTN = { m_start2, m_start1, m_coin1 };
				JA  = ~{ 4'b0000, m_right, m_left, m_down, m_up };
				JB  = JA;
			end
		mod_stargate:
			begin
				BTN = { m_start2, m_start1, m_coin1 };
				JA  = ~{ m_fire_f, m_up, m_down, (status[7:6]==2'b10)? m_fire_e : (status[6] ? (sg_state ? m_right : m_left) : (m_left | m_right)), m_fire_d, m_fire_c, status[6] ? (sg_state ? m_left : m_right) : m_fire_b, m_fire_a };
				JB  = JA;
			end
		mod_alienar:
			begin
				BTN = { m_start1, m_start2, m_coin1 };
				JA  = ~{ 1'b0, 1'b0, m_fire1b, m_fire1a, m_right1, m_left1, m_down1, m_up1 };
				JB  = ~{ 1'b0, 1'b0, m_fire2b, m_fire2a, m_right2, m_left2, m_down2, m_up2 };
			end
		mod_sinistar:
			begin
				sinistar = 1;
				landscape = 0;
				BTN = { m_start1, m_start2, m_coin1 };
				JA  = ~{ (amx == 7) ? dmx : amx, (amy == 7) ? dmy : amy };
				JB  = JA;
			end
		mod_playball:
			begin
				landscape = 0;
				BTN = { 2'b00, m_coin1 };
				JA  = ~{ 4'b0000, m_start2, m_right, m_left, m_start1 };
				JB  = JA;
			end
		default: ;
	endcase
end


wire [3:0] dmx = m_left ? 4'd0 : m_right ? 4'd8 : 4'd7;
wire [3:0] dmy = m_down ? 4'd0 : m_up    ? 4'd8 : 4'd7;

wire [3:0] amx = ($signed(joya[7:0]) < -96) ? 4'd0  :
                 ($signed(joya[7:0]) < -64) ? 4'd4  :
                 ($signed(joya[7:0]) < -32) ? 4'd6  :
                 ($signed(joya[7:0]) >  96) ? 4'd8  :
                 ($signed(joya[7:0]) >  64) ? 4'd9  :
                 ($signed(joya[7:0]) >  32) ? 4'd11 : 4'd7;

wire [3:0] amy = ($signed(joya[15:8]) < -96) ? 4'd8  :
                 ($signed(joya[15:8]) < -64) ? 4'd9  :
                 ($signed(joya[15:8]) < -32) ? 4'd11 :
                 ($signed(joya[15:8]) >  96) ? 4'd0  :
                 ($signed(joya[15:8]) >  64) ? 4'd4  :
                 ($signed(joya[15:8]) >  32) ? 4'd6  : 4'd7; 

reg j2 = 0;
always @(posedge clk_sys) begin
	if(joy2) j2 <= 1;
	if(joy1) j2 <= 0;
end

wire no_rotate = status[2] | direct_video | landscape;

///////////////////////////////////////////////////////////////////

wire  [2:0] r,g;
wire  [1:0] b;
wire        vs,hs;

wire  [7:0] audio;
wire [15:0] speech;

wire [15:0] mem_addr;
wire  [7:0] mem_do = ~ramcs ? ram_do : rom_do;
wire  [7:0] mem_di;
wire        mem_we;
wire        ramcs;
wire        ramlb;
wire        ramub;

wire        sg_state;

williams_soc soc
(
	.clock       ( clk_sys     ),
	.vgaRed      ( r           ),
	.vgaGreen    ( g           ),
	.vgaBlue     ( b           ),
	.Hsync       ( hs          ),
	.Vsync       ( vs          ),
	.audio_out   ( audio       ),
	.speech_out  ( speech      ),

	.blitter_sc2 ( blitter_sc2 ),
	.sinistar    ( sinistar    ),
	.sg_state    ( sg_state    ),

	.BTN         ( {BTN[2:0],reset} ),
	.SIN_FIRE    ( ~m_fire_a   ),
	.SIN_BOMB    ( ~m_fire_b   ),
	.SW          ( SW          ),
	.JA          ( JA          ),
	.JB          ( JB          ),

	.MemAdr      ( mem_addr    ),
	.MemDin      ( mem_di      ),
	.MemDout     ( mem_do      ),
	.MemWR       ( mem_we      ),
	.RamCS       ( ramcs       ),
	.RamLB       ( ramlb       ),
	.RamUB       ( ramub       ),

	.pause       ( pause_cpu   ),

	.dl_clock    ( clk_sys     ),
	.dl_addr     ( ioctl_addr[16:0] ),
	.dl_data     ( ioctl_dout  ),
	.dl_wr       ( ioctl_wr & rom_download ),
	.dl_upload   ( ioctl_upload )
);

wire [7:0] rom_do;
dpram #(.dWidth(8),.aWidth(17)) cpu_prog_rom
(
	.clk_a(~clk_sys),
	.addr_a({1'b0,mem_addr[15], ~mem_addr[15] & mem_addr[14], mem_addr[13:0]}),
	.q_a(rom_do),

	.clk_b(clk_sys),
	.addr_b(ioctl_addr[16:0]),
	.d_b(ioctl_dout),
	.we_b(ioctl_wr & rom_download)
);

wire [7:0] ram_do;
williams_ram ram
(
	.CLK(~clk_sys),
	.ENL(~ramlb),
	.ENH(~ramub),
	.WE(~ramcs & ~mem_we),
	.ADDR(mem_addr),
	.DI(mem_di),
	.DO(ram_do),

	.dn_clock(clk_sys),
	.dn_addr(ioctl_download ? ioctl_addr[15:0] : hs_address),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & (rom_download|ioctl_index=='d4)),
	.dn_din(hs_data_out),
	.dn_nvram(ioctl_index == 8'd4)
);

///////////////////////////////////////////////////////////////////

wire ce_pix = pcnt[0];

reg        HBlank;
reg        VBlank;
reg [10:0] lcnt;
reg [10:0] pcnt;

always @(posedge clk_sys) begin
	reg old_vs, old_hs;

	if(~&pcnt) pcnt <= pcnt + 1'd1;

	old_hs <= hs;
	if(~old_hs & hs) begin
		pcnt <= 0;
		if(~&lcnt) lcnt <= lcnt + 1'd1;

		old_vs <= vs;
		if(~old_vs & vs) lcnt <= 0;
	end

	if (pcnt[10:1] == 336) HBlank <= 1;
	if (pcnt[10:1] == 040) HBlank <= 0;

	if (lcnt == 254) VBlank <= 1;
	if (lcnt == 14) VBlank <= 0;
end

wire rotate_ccw = 1;
screen_rotate screen_rotate (.*);

arcade_video #(296,8) arcade_video
(
	.*,
	.clk_video(clk_vid),
	.RGB_in(rgb_out),
	.HSync(hs),
	.VSync(vs),
	.fx(status[5:3])
);

///////////////////////////////////////////////////////////////////

logic [16:0] audsum;
assign audsum = {audio, 8'd0} + speech;
assign AUDIO_L = {1'b0, audsum[16:3]};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;


// HISCORE SYSTEM
// --------------
wire [9:0] hs_address;
wire [7:0] hs_data_out;
wire hs_pause;
wire hs_configured = ~(mod == mod_playball);

nvram #(
	.DUMPWIDTH(10),
	.DUMPINDEX(4),
	.PAUSEPAD(2)
) hi (
	.*,
	.clk(clk_sys),
	.paused(pause_cpu),
	.autosave(status[27]),
	.nvram_address(hs_address),
	.nvram_data_out(hs_data_out),
	.pause_cpu(hs_pause)
);

endmodule
