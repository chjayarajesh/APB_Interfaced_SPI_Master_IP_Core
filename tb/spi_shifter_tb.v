module spi_shifter_tb;

	parameter cycle = 5;
	integer i;
	reg pclk, preset_N, ss, send_data, lsbfe, cpol, cpha;
	reg [7:0] data_mosi;
	reg miso_in;
	reg recieve_data;
	wire [7:0] data_miso;
	wire mosi_out;
	
	// baudrate signals
	reg [1:0] spi_mode;
	reg spiswai;
	reg [2:0] sppr, spr;
	wire sclk;
	wire mosi_neg, mosi_pos, miso_neg, miso_pos;
	wire [11:0] baud_divisor;
	
	baud_rate_generator DUT1(pclk, preset_N, spi_mode, spiswai,
						sppr, spr, cpol, cpha, ss, sclk,
						mosi_neg, mosi_pos, miso_neg, miso_pos,
						baud_divisor);
					
					
	spi_shifter DUT2(pclk, preset_N, ss, send_data, lsbfe, cpol, cpha,
					miso_neg, miso_pos, mosi_neg, mosi_pos,
					data_mosi, miso_in,
					recieve_data, data_miso, mosi_out);
	
	initial begin
		pclk = 0;
		forever #(cycle) pclk = ~pclk;
	end
	
	task reset;
		begin
			@(posedge pclk) preset_N = 1'b0;
			@(posedge pclk) preset_N = 1'b1;
		end
	endtask
	
	task send_data_tb;
		begin
			@(negedge pclk) send_data = 1'b1;
			@(negedge pclk) send_data = 1'b0;
			@(negedge pclk) ss = 1'b0;
		end
	endtask
	
	task recieve_data_tb;
		begin
			@(posedge pclk) 
			ss = 1'b1;
			recieve_data = 1'b1;
			@(posedge pclk) recieve_data = 1'b0;
		end
	endtask
	
	task initialize;
		begin
			ss = 1'b1;
			send_data = 1'b0;
			recieve_data = 1'b0;
			lsbfe = 1'b1;
			cpol = 1'b0;
			cpha = 0;
			data_mosi = 8'o000;
			miso_in = 1'b0;
			spi_mode = 2'b00;
			spiswai = 1'b0;
			sppr = 3'b000;
			spr = 3'b000;
		end
	endtask
	
	
	task stimulus(input [7:0] data_mosi_tb, data_miso_in, input [2:0] sppr_in, spr_in, input cpol_in, cpha_in);
		begin
			data_mosi = data_mosi_tb;
			sppr = sppr_in;
			spr = spr_in;
			cpol = cpol_in;
			cpha = cpha_in;
			send_data_tb;
			
			wait(ss == 1'b0)
			if(lsbfe)
				begin
					for(i = 0; i < 8; i = i + 1) begin
						@(posedge sclk) miso_in = data_miso_in[i];
						$display("At sending time %d -> miso_in = %b",i, miso_in);
					end
				end
			else
				begin
					for(i = 7; i >= 0; i = i - 1) begin
						@(negedge sclk) miso_in = data_miso_in[i];
						$display("At sending time %d -> miso_in = %b",i, miso_in);
					end
				end
				
			#20; // extra delay taken as same in slave select block
			recieve_data_tb;
		end
	endtask
	
	initial begin
		$monitor("mosi out = %b", mosi_out);
		reset;
		initialize;
		stimulus(8'b10101010, 8'b10010011, 3'b000, 3'b000, 0, 0);
		#100;
		$display("TX data = %b, RX data = %b", data_mosi, data_miso);
		
		reset;
		initialize;
		stimulus(8'b10101010, 8'b10010011, 3'b000, 3'b000, 0, 1);
		#100;
		$display("TX data = %b, RX data = %b", data_mosi, data_miso);
		
		reset;
		initialize;
		stimulus(8'b10101010, 8'b10010011, 3'b000, 3'b000, 1, 0);
		#100;
		$display("TX data = %b, RX data = %b", data_mosi, data_miso);
		
		reset;
		initialize;
		stimulus(8'b10101010, 8'b10010011, 3'b000, 3'b000, 1, 1);
		#100;
		$display("TX data = %b, RX data = %b", data_mosi, data_miso);
		$finish;
	end
			
endmodule		
			
			
			
			
							
							
							