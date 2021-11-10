
`include "../base/defs.v"

module map_042
(map_out, bus, sys_cfg, ss_ctrl);

	`include "../base/bus_in.v"
	`include "../base/map_out.v"
	`include "../base/sys_cfg_in.v"
	`include "../base/ss_ctrl_in.v"
	
	output [`BW_MAP_OUT-1:0]map_out;
	input [`BW_SYS_CFG-1:0]sys_cfg;
	
	
	assign sync_m2 = 1;
	assign mir_4sc = 0;//enable support for 4-screen mirroring. for activation should be ensabled in sys_cfg also
	assign srm_addr[12:0] = cpu_addr[12:0];
	assign prg_oe = cpu_rw;
	assign chr_oe = !ppu_oe;
	//*************************************************************  save state setup
	assign ss_rdat[7:0] = 
	ss_addr[7:0] == 0 ? prg : 
	ss_addr[7:0] == 1 ? chr : 
	ss_addr[7:0] == 2 ? mirror_mode : 
	ss_addr[7:0] == 127 ? map_idx : 8'hff;
	//*************************************************************

	assign ram_we = !cpu_rw & ram_ce;
	assign ram_ce = 0;//cpu_addr[14:13] == 2'b11 & cpu_ce & m2;
	assign rom_ce = !cpu_ce | cpu_addr[14:13] == 2'b11 & cpu_ce;
	assign chr_ce = ciram_ce;
	assign chr_we = cfg_chr_ram ? !ppu_we & ciram_ce : 0;
	
	//A10-Vmir, A11-Hmir
	assign ciram_a10 = !mirror_mode ? ppu_addr[10] : ppu_addr[11];
	assign ciram_ce = !ppu_addr[13];
	
	assign prg_addr[12:0] = cpu_addr[12:0];
	assign prg_addr[18:13] = !cpu_ce ? {4'b1111, cpu_addr[14:13]} : prg[5:0];
	
	assign chr_addr[12:0] = ppu_addr[12:0];
	assign chr_addr[18:13] = cfg_chr_ram ? 0 : chr;
	
	reg [5:0]prg;
	reg [5:0]chr;
	reg mirror_mode;
	
	always @(negedge m2)
	if(ss_act)
	begin
		if(ss_we & ss_addr[7:0] == 0)prg <= cpu_dat;
		if(ss_we & ss_addr[7:0] == 1)chr <= cpu_dat;
		if(ss_we & ss_addr[7:0] == 2)mirror_mode <= cpu_dat;
	end
		else
	begin
		if(!cpu_ce & !cpu_rw & cpu_addr[14:13] == 2'b00)chr[5:0] <= cpu_dat[5:0];
		
		if(!cpu_ce & !cpu_rw & cpu_addr[14:13] == 2'b11)
		begin
			if(!cpu_addr[0])prg[5:0] <= cpu_dat[5:0];
				else
			mirror_mode <= cpu_dat[3];
		end
	end
	
endmodule
