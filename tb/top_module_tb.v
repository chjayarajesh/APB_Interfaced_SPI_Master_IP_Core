`timescale 1ns/10ps
module top_module_tb;
	reg pclk, preset_N, pwrite, penable, psel;
	reg [2:0] paddr;
	reg [7:0] pw_data;
	reg miso_in;
	wire [7:0] pr_data;
	wire pready, pslverr, spi_interrupt_request, sclk, ss;
	
	parameter cycle = 5;
	
	top_module DUT(pclk, preset_N, pwrite, penable, psel, paddr, pw_data, miso_in, pr_data,
					pready, pslverr, spi_interrupt_request, sclk, ss, mosi_out);
	 
	wire lsbfe = DUT.lsbfe;
	wire spif = DUT.M1.spif;
			
	initial begin
		pclk = 1'b0;
		forever #5 pclk = ~pclk;
	end
	
	task reset;
		begin
			@(negedge pclk) preset_N = 1'b0;
			@(negedge pclk) preset_N = 1'b1;
		end
	endtask
	
	task initialize;
		begin
			preset_N = 1'b1;
			pwrite = 1'b1;
			penable = 1'b0;
			psel = 1'b0;
			paddr = 3'd0;
			pw_data = 8'd0;
			miso_in = 1'b0;
		end
	endtask
	
	task write_stimulus(input [7:0] reg_data, input [2:0] reg_addr);
		begin
			// setup state psel = 1 and penable = 0
			@(negedge pclk)
			paddr = reg_addr;
			pwrite = 1'b1;
			psel = 1'b1;
			penable = 1'b0;
			pw_data = reg_data;
			
			// enable state penable = 1
			@(negedge pclk) penable = 1'b1;
			
			// Idle state( wait until pready = 1)
			// pready = 1 means that the apb goes enable state 
			@(negedge pclk)
			wait(pready)
			penable = 1'b0;
			psel = 1'b0;
		end
	endtask 
	
	task read_stimulus(input [2:0] reg_addr);
		begin
			//setup state
			@(negedge pclk)
			paddr = reg_addr;
			pwrite = 1'b0;
			psel = 1'b1;
			penable = 1'b0;
			
			//enable state
			@(negedge pclk) penable = 1'b1;
			
			//idle state
			@(negedge pclk)
			wait(pready)
			penable = 1'b0;
			psel = 1'b0;
			
		end
	endtask
	
	task miso_DR_read;
		begin
			// wait until spif becomes 1
			wait(spif == 1'b1);
			$display("SPIF asserted = %b", spif);

			// read SR first
			read_stimulus(3'd3);
			$display("SR read completed at time %0t", $time);
			
			// Read DR after reading SR
			read_stimulus(3'd5);
			$display("DR read completed at time");
			
		end
	endtask

			
	task data_miso_tb(input [7:0] data_miso_in);
		begin : b1
			integer i;
			wait(ss == 1'b0)
			#(cycle * 2);
			if(lsbfe)
				begin
					for(i = 0; i < 8; i = i + 1) begin
						@(posedge sclk) miso_in = data_miso_in[i];
						$display("At sending time %d -> miso_in = %b",i, miso_in);
					end
				end
			else
				begin
					for(i = 0; i < 8; i = i + 1) begin
						@(negedge sclk) miso_in = data_miso_in[i];
						$display("At sending time %d -> miso_in = %b",i, miso_in);
					end
				end
		end
	endtask
	
	initial begin
		
		
		// cpol = 0, cpha = 1, sppr = 0, spr = 1, lsbfe = 1
		initialize;
		reset;
		write_stimulus(8'b00010101, 3'd0); // CR1
		write_stimulus(8'b00000000, 3'd1); // CR2
		write_stimulus(8'b00000000, 3'd2); // BR
		
		fork 
			data_miso_tb(8'b10101010);
			write_stimulus(8'b11110000, 3'd5); // DR
		join 
		miso_DR_read;
		#50;
		
		// cpol = 1, cpha = 1, sppr = 0, spr = 1, lsbfe = 0
		initialize;
		reset;
		write_stimulus(8'b00011101, 3'd0); // CR1
		write_stimulus(8'b00000000, 3'd1); // CR2
		write_stimulus(8'b00000000, 3'd2); // BR
		
		fork 
			data_miso_tb(8'b10101010);
			write_stimulus(8'b11110000, 3'd5);
		join 
		miso_DR_read;
		#50;
		$finish;
	end
	
endmodule


/*


add wave -position insertpoint \
sim:/top_module_tb/DUT/M2/sppr \
sim:/top_module_tb/DUT/M2/spr \
sim:/top_module_tb/DUT/M3/baud_divisor \
sim:/top_module_tb/lsbfe \
sim:/top_module_tb/DUT/M2/cpol \
sim:/top_module_tb/DUT/M2/cpha \
sim:/top_module_tb/miso_in \
sim:/top_module_tb/DUT/M4/temp_reg \
sim:/top_module_tb/DUT/M4/data_miso \
sim:/top_module_tb/DUT/M1/data_mosi \
sim:/top_module_tb/DUT/M4/shifter \
sim:/top_module_tb/mosi_out \
sim:/top_module_tb/psel \
sim:/top_module_tb/penable \
sim:/top_module_tb/pready \
sim:/top_module_tb/paddr \
sim:/top_module_tb/pwrite \
sim:/top_module_tb/pw_data \
sim:/top_module_tb/pr_data \
sim:/top_module_tb/pclk \
sim:/top_module_tb/preset_N \
sim:/top_module_tb/DUT/M1/send_data \
sim:/top_module_tb/DUT/M3/recieve_data \
sim:/top_module_tb/ss \
sim:/top_module_tb/sclk \
sim:/top_module_tb/DUT/M2/mosi_neg \
sim:/top_module_tb/DUT/M2/miso_pos \
sim:/top_module_tb/DUT/M2/mosi_pos \
sim:/top_module_tb/DUT/M2/miso_neg \
sim:/top_module_tb/DUT/M1/CR1 \
sim:/top_module_tb/DUT/M1/CR2 \
sim:/top_module_tb/DUT/M1/BR \
sim:/top_module_tb/DUT/M1/SR \
sim:/top_module_tb/DUT/M1/DR \
sim:/top_module_tb/DUT/M3/count \
sim:/top_module_tb/pslverr \
sim:/top_module_tb/spi_interrupt_request \
sim:/top_module_tb/DUT/M1/APB_state \
sim:/top_module_tb/DUT/M1/spi_mode \
sim:/top_module_tb/spif

*/