`timescale 1ns/10ps
module APB_slave_interface_tb;
	reg pclk, preset_N, pwrite, psel, penable, ss, recieve_data, tip;
	reg [2:0] paddr;
	reg [7:0] pw_data, data_miso;
	wire [7:0] pr_data, data_mosi;
	wire mstr, cpol, cpha, lsbfe, spiswai, spi_interrupt_request, pready, pslverr, send_data;
	wire [1:0] spi_mode;
	wire [2:0] sppr,spr;
	
	APB_slave_interface DUT(pclk, preset_N, pwrite, psel, penable, ss, recieve_data, tip, 
							paddr, pw_data, data_miso, pr_data, data_mosi,
							mstr, cpol, cpha, lsbfe, spiswai, spi_interrupt_request, pready, pslverr,
							send_data, spi_mode, sppr, spr);
							
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
	
	task recieve_data_tb(input [7:0] data_miso_in);
		begin
			@(negedge pclk) data_miso = data_miso_in;
			@(negedge pclk) recieve_data = 1'b1;
			@(negedge pclk) recieve_data = 1'b0;
			$display("Miso input given -> miso data = %b", data_miso);
		end
	endtask
	
	task initialize;
		begin
			pwrite = 1'b1;
			psel = 1'b0;
			penable = 1'b0;
			ss = 1'b1;
			recieve_data = 1'b0;
			tip = 1'b0;
			paddr = 3'd0;
			pw_data = 8'd0;
			data_miso = 8'd0;
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
	
	initial begin
		
		 /*
		$monitor("[%0t] mode=%0d  mstr=%b  cpol=%b  cphase=%b  lsbfe=%b  spr=%0d  sppr=%0d send_data =%b  data_mosi= %b  spi_interrupt = %b  pslverr=%b data" ,
					$time, spi_mode, mstr, cpol, cpha, lsbfe, spr, sppr,
					send_data, data_mosi, spi_interrupt_request, pslverr);
		*/		
		
		// testing registers 
		initialize;
		reset;
		ss = 1'b0;
		tip = 1'b1;
			
		write_stimulus(8'b00010001, 3'd0);
		write_stimulus(8'b00000000, 3'd1);
		write_stimulus(8'b00000001, 3'd2);
		write_stimulus(8'b10101010, 3'd5);

		// testing data
		recieve_data_tb(8'b00001111);
		read_stimulus(3'd3);
		read_stimulus(3'd5);
		read_stimulus(3'd3);

		#100;
		$finish;
		
		
	end
endmodule
			
			
			