`include "../base/defs.v"

module map_098
(map_out, bus, sys_cfg, ss_ctrl);

	`include "../base/bus_in.v"
	`include "../base/map_out.v"
	`include "../base/sys_cfg_in.v"
	`include "../base/ss_ctrl_in.v"
	
	output [`BW_MAP_OUT-1:0]map_out;
	input [`BW_SYS_CFG-1:0]sys_cfg;
	
	assign irq = (ppu_addr[12] | irq_latch_q) & irq_enable;
	
	assign chr_mask_off = 1;
	assign sync_m2 = 1;
	assign mir_4sc = !fourscreen_disable;
	assign srm_addr[12:0] = cpu_addr[12:0];
	assign prg_oe = cpu_rw;
	assign chr_oe = !ppu_oe;
	wire cfg_fla_mod = map_sub == 1;
	//*************************************************************  save state setup
	assign ss_rdat[7:0] = 
	ss_addr[7:0] == 0   ? prg_bank_reg : 
	ss_addr[7:0] == 1   ? fla_state : 
	ss_addr[7:0] == 127 ? map_idx : 8'hff;
	//*************************************************************
	assign ram_ce = ({cpu_addr[15:13], 13'd0} == 16'h6000) & wram_enable;
	assign ram_we = !cpu_rw & ram_ce;
	assign rom_ce = cpu_addr[15];
	assign rom_we = fla_we;
	assign chr_ce = ciram_ce;
	assign chr_we = cfg_chr_ram ? !ppu_we & ciram_ce : 0;
	
	assign ciram_a10 = swap_spr_nt;
	assign ciram_ce = !nametable_access;
	
	assign prg_addr[13:0] = cpu_addr[13:0];
	assign prg_addr[18:14] = cpu_addr[14] == 0 ? prg[7:0] : 8'b11111111;	
	
   wire fourscreen_disable = 1; //chr_reg[3];
   wire swap_spr_nt = chr_reg[4];
   wire wram_enable = 1; //chr_reg[5];
   wire irq_enable = chr_reg[7];

   wire spr_or_nt_fetch = ppu_addr[12] | ppu_addr[13];
	wire vram_a12 = spr_or_nt_fetch ? 1'b0 : chr[0]; // TODO: Verify
   wire vram_a13 = spr_or_nt_fetch ? swap_spr_nt : chr[1];
   wire vram_a14 = spr_or_nt_fetch ? !chr[2] : chr[2];

	assign chr_addr[11:0] = attribute_access ? {6'b111111, ppu_addr[5:0]} : ppu_addr[11:0];
	assign chr_addr[14:12] = attribute_access ? {!chr[2], nt_lsb_y_d, nt_lsb_x_d} : {vram_a14, vram_a13, vram_a12};
	
	wire fla_area = cpu_addr[15:14] == 2'b10;
	wire reg_area_prg = cpu_addr[15:14] == 2'b11;
	wire reg_area_chr = cpu_addr[15:14] == 2'b10;
	wire fla_we   = fla_area & fla_state == 3 & !cpu_rw;
	
	wire [7:0]prg = prg_bank_reg[7:0];
	wire [2:0]chr = chr_reg[2:0];
	wire one_scr = 1;
	
	wire attribute_access = ppu_oe ? 1'b0 : at_read;
	wire nametable_access = (ppu_addr[13] & !attribute_access);
	
	reg [7:0] prg_bank_reg;
	reg [7:0] chr_reg;
	reg nt_lsb_x;
	reg nt_lsb_y;
	reg nt_lsb_x_d;
	reg nt_lsb_y_d;
	reg a13_d;
	reg a13_dd;
	reg a13_ddd;
	reg at_read;

	// IRQ state: Activated when PPU A12 goes high. Deactivated when the 1st attribute access occurs.
   // Emulate SR-latch via SR-flipflop
   reg irq_latch_q;
   always @(negedge ppu_oe)
   begin
		case({ppu_addr[12], next_fetch_is_at})
			2'b00:   irq_latch_q <= irq_latch_q;
			2'b01:   irq_latch_q <= 1'b0;
			2'b10:   irq_latch_q <= 1'b1;
			default: irq_latch_q <= irq_latch_q;
		endcase	
   end

	reg [1:0]fla_state;
	
	always @(negedge m2)
	if(ss_act)
	begin
		if(ss_we & ss_addr[7:0] == 0) prg_bank_reg <= cpu_dat;
		if(ss_we & ss_addr[7:0] == 1) fla_state <= cpu_dat;
	end
		else
	if(map_rst)
	begin
		prg_bank_reg <= 0;
	end
		else
	if(!cpu_rw)
	begin
		if(reg_area_prg) prg_bank_reg[7:0] <= cpu_dat[7:0];
		if(reg_area_chr) chr_reg[7:0] <= cpu_dat[7:0];		
	end
	
	// TODO: Investigate why using a13_d in place of ppu_addr[13] causes issues with at_after_dummy_fetch
	wire at_after_normal_fetch = ppu_addr[13] & (!a13_dd & !a13_ddd); // a13_d & (!a13_dd & !a13_ddd);
	wire at_after_dummy_fetch = ppu_addr[13] & (a13_dd & a13_ddd); // a13_d & (a13_dd & a13_ddd);
	wire next_fetch_is_at = at_after_normal_fetch | at_after_dummy_fetch;
	always @(negedge ppu_oe)
	begin
		nt_lsb_x_d <= nt_lsb_x;
		nt_lsb_y_d <= nt_lsb_y;
		nt_lsb_x <= ppu_addr[0];
		nt_lsb_y <= ppu_addr[5];
		a13_ddd <= a13_dd;
		a13_dd <= a13_d;
		a13_d <= ppu_addr[13];
		at_read <= next_fetch_is_at;
	end

endmodule
