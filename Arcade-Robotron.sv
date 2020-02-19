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
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	
	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : (status[2] | landscape) ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : (status[2] | landscape) ? 8'd3 : 8'd4;

`include "build_id.v" 
localparam CONF_STR = {
	"A.ROBTRN;;", 
	"-;",
	"H0O1,Aspect Ratio,Original,Wide;",
	"H1H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"h2O6,Fire,4-way,Move+Fire;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Fire 3,Fire 4,Start 1P,Start 2P,Coin;",
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
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;
wire  [7:0] ioctl_data;
wire        ioctl_wait;

wire [10:0] ps2_key;

wire [31:0] joy1, joy2;
wire [31:0] joy = joy1 | joy2;

wire [15:0] joy1a, joy2a;
wire [15:0] joya = j2 ? joy2a : joy1a;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask({fourfire,landscape,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joy1),
	.joystick_1(joy2),

	.joystick_analog_0(joy1a),
	.joystick_analog_1(joy2a),

	.ps2_key(ps2_key)
);

wire rom_download = ioctl_download && !ioctl_index;
wire reset = RESET | status[0] | buttons[1] | rom_download;

///////////////////////////////////////////////////////////////////

wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'h75: btn_up            <= pressed; // up
			'h72: btn_down          <= pressed; // down
			'h6B: btn_left          <= pressed; // left
			'h74: btn_right         <= pressed; // right
			'h76: btn_coin1         <= pressed; // ESC
			'h05: btn_start1        <= pressed; // F1
			'h06: btn_start2        <= pressed; // F2
			//'h04: btn_start3        <= pressed; // F3
			//'h0C: btn_start4        <= pressed; // F4
			'h14: btn_fireA         <= pressed; // lctrl
			'h11: btn_fireB         <= pressed; // lalt
			'h29: btn_fireC         <= pressed; // Space
			'h12: btn_fireD         <= pressed; // l-shift

			// JPAC/IPAC/MAME Style Codes
			'h16: btn_start1        <= pressed; // 1
			'h1E: btn_start2        <= pressed; // 2
			//'h26: btn_start3        <= pressed; // 3
			//'h25: btn_start4        <= pressed; // 4
			'h2E: btn_coin1         <= pressed; // 5
			'h36: btn_coin2         <= pressed; // 6
			//'h3D: btn_coin3         <= pressed; // 7
			//'h3E: btn_coin4         <= pressed; // 8
			'h2D: btn_up2           <= pressed; // R
			'h2B: btn_down2         <= pressed; // F
			'h23: btn_left2         <= pressed; // D
			'h34: btn_right2        <= pressed; // G
			'h1C: btn_fire2A        <= pressed; // A
			'h1B: btn_fire2B        <= pressed; // S
			'h21: btn_fire2C        <= pressed; // Q
			'h1D: btn_fire2D        <= pressed; // W
			//'h1D: btn_fire2E        <= pressed; // W
			//'h1D: btn_fire2F        <= pressed; // W
			//'h1D: btn_tilt <= pressed; // W
		endcase
	end
end

reg btn_left   = 0;
reg btn_right  = 0;
reg btn_down   = 0;
reg btn_up     = 0;
reg btn_fireA  = 0;
reg btn_fireB  = 0;
reg btn_fireC  = 0;
reg btn_fireD  = 0;
reg btn_coin1  = 0;
reg btn_coin2  = 0;
reg btn_start1 = 0;
reg btn_start2 = 0;
reg btn_up2    = 0;
reg btn_down2  = 0;
reg btn_left2  = 0;
reg btn_right2 = 0;
reg btn_fire2A = 0;
reg btn_fire2B = 0;
reg btn_fire2C = 0;
reg btn_fire2D = 0;

wire m_start1  = btn_start1 | joy[8];
wire m_start2  = btn_start2 | joy[9];
wire m_coin1   = btn_coin1  | btn_coin2 | joy[10];

wire m_right1  = btn_right  | joy1[0];
wire m_left1   = btn_left   | joy1[1];
wire m_down1   = btn_down   | joy1[2];
wire m_up1     = btn_up     | joy1[3];
wire m_fire1a  = btn_fireA  | joy1[4];
wire m_fire1b  = btn_fireB  | joy1[5];
wire m_fire1c  = btn_fireC  | joy1[6];
wire m_fire1d  = btn_fireD  | joy1[7];
//wire m_rcw1    =              joy1[8];
//wire m_rccw1   =              joy1[9];
//wire m_spccw1  =              joy1[30];
//wire m_spcw1   =              joy1[31];

wire m_right2  = btn_right2 | joy2[0];
wire m_left2   = btn_left2  | joy2[1];
wire m_down2   = btn_down2  | joy2[2];
wire m_up2     = btn_up2    | joy2[3];
wire m_fire2a  = btn_fire2A | joy2[4];
wire m_fire2b  = btn_fire2B | joy2[5];
wire m_fire2c  = btn_fire2C | joy2[6];
wire m_fire2d  = btn_fire2D | joy2[7];
//wire m_rcw2    =              joy2[8];
//wire m_rccw2   =              joy2[9];
//wire m_spccw2  =              joy2[30];
//wire m_spcw2   =              joy2[31];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
wire m_fire_c  = m_fire1c | m_fire2c;
wire m_fire_d  = m_fire1d | m_fire2d;
//wire m_rcw     = m_rcw1   | m_rcw2;
//wire m_rccw    = m_rccw1  | m_rccw2;
//wire m_spccw   = m_spccw1 | m_spccw2;
//wire m_spcw    = m_spcw1  | m_spcw2;

///////////////////////////////////////////////////////////////////

localparam mod_robotron = 0;
localparam mod_joust    = 1;
localparam mod_splat    = 2;
localparam mod_bubbles  = 3;
localparam mod_stargate = 4;
localparam mod_alienar  = 5;
localparam mod_sinistar = 6;

reg [7:0] mod = 0;
always @(posedge clk_sys) if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

///////////////////////////////////////////////////////////////////

reg  [7:0] JA;
reg  [7:0] JB;
reg  [2:0] BTN;
reg        blitter_sc2, sinistar;
reg        landscape;
reg        fourfire;

always @(*) begin

	landscape = 1;
	JA = 0;
	JB = 0;
	BTN = 0;
	blitter_sc2 = 0;
	sinistar = 0;
	fourfire = 0;

	case (mod)
		mod_robotron:
			begin
				fourfire = 1;
				BTN = { m_start1, m_start2, m_coin1 };
				JA  = ~{ status[6] ? {m_right, m_left, m_down, m_up} : {m_fire_a, m_fire_d, m_fire_b, m_fire_c}, m_right, m_left, m_down, m_up };
				JB  = ~{ status[6] ? {m_right, m_left, m_down, m_up} : {m_fire_a, m_fire_d, m_fire_b, m_fire_c}, m_right, m_left, m_down, m_up };
			end
		mod_joust:
			begin
				BTN = { m_start2, m_start1, m_coin1 };
				JA  = ~{ 5'b00000, m_fire1a, m_right1, m_left1 };
				JB  = ~{ 5'b00000, m_fire2a, m_right2, m_left2 };
			end
		mod_splat:
			begin
				fourfire = 1;
				blitter_sc2 = 1;
				BTN = { m_start1, m_start2, m_coin1 };
				JA  = ~{ status[6] ? {m_right1, m_left1, m_down1, m_up1} : {m_fire1a, m_fire1d, m_fire1b, m_fire1c}, m_right1, m_left1, m_down1, m_up1 };
				JB  = ~{ status[6] ? {m_right2, m_left2, m_down2, m_up2} : {m_fire2a, m_fire2d, m_fire2b, m_fire2c}, m_right2, m_left2, m_down2, m_up2 };
			end
		mod_bubbles:
			begin
				BTN = { m_start2, m_start1, m_coin1 };
				JA  = ~{ 4'b0000, m_right, m_left, m_down, m_up };
				JB  = ~{ 4'b0000, m_right, m_left, m_down, m_up };
			end
		mod_stargate:
			begin
				BTN = { m_start2, m_start1, m_coin1 };
				JA  = ~{ m_start1, m_up, m_down, m_left | m_right, m_fire_d, m_fire_c, m_fire_b, m_fire_a };
				JB  = ~{ m_start1, m_up, m_down, m_left | m_right, m_fire_d, m_fire_c, m_fire_b, m_fire_a };
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
				JB  = ~{ (amx == 7) ? dmx : amx, (amy == 7) ? dmy : amy };
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


wire [15:0] mem_addr;
wire  [7:0] mem_do = ~ramcs ? ram_do : rom_do;
wire  [7:0] mem_di;
wire        mem_we;
wire        ramcs;
wire        ramlb;
wire        ramub;

williams_soc soc
(
	.clock       ( clk_sys     ),
	.vgaRed      ( r           ),
	.vgaGreen    ( g           ),
	.vgaBlue     ( b           ),
	.Hsync       ( hs          ),
	.Vsync       ( vs          ),
	.audio_out   ( audio       ),

	.blitter_sc2 ( blitter_sc2 ),
	.sinistar    ( sinistar    ),
	.BTN         ( {BTN[2:0],reset} ),
	.SIN_FIRE    ( ~m_fire_a   ),
	.SIN_BOMB    ( ~m_fire_b   ),
	.SW          ( sw[0]       ),
	.JA          ( JA          ),
	.JB          ( JB          ),

	.MemAdr      ( mem_addr    ),
	.MemDin      ( mem_di      ),
	.MemDout     ( mem_do      ),
	.MemWR       ( mem_we      ),
	.RamCS       ( ramcs       ),
	.RamLB       ( ramlb       ),
	.RamUB       ( ramub       ),

	.dl_clock    ( clk_sys     ),
	.dl_addr     ( ioctl_addr[15:0] ),
	.dl_data     ( ioctl_dout  ),
	.dl_wr       ( ioctl_wr & rom_download )
);

wire [7:0] rom_do;
dpram #(.dWidth(8),.aWidth(16)) cpu_prog_rom
(
	.clk_a(~clk_sys),
	.addr_a({mem_addr[15], ~mem_addr[15] & mem_addr[14], mem_addr[13:0]}),
	.q_a(rom_do),

	.clk_b(clk_sys),
	.addr_b(ioctl_addr[15:0]),
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
	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download)
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

	if (lcnt == 246) VBlank <= 1;
	if (lcnt == 006) VBlank <= 0;
end

arcade_video #(296,240,8) arcade_video
(
	.*,
	.clk_video(clk_vid),
	.RGB_in({r,g,b}),
	.HSync(hs),
	.VSync(vs),
	.rotate_ccw(1),
	.fx(status[5:3])
);

assign AUDIO_L = {audio, audio};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

endmodule
