module spi_slave_control_select_tb;
	reg pclk, preset_N, spiswai, mstr, send_data;
	reg [1:0] spi_mode;
	reg [11:0] baud_divisor;
	
	wire recieve_data, ss, tip;
	
	spi_slave_control_select DUT(pclk, preset_N, spiswai, mstr, send_data, spi_mode, baud_divisor, recieve_data, ss, tip);
	
	
	initial begin
		pclk = 1'b0;
		forever #5 pclk = ~pclk;
	end
	
	
	task preset;
        begin
            @(negedge pclk)
			preset_N = 1'b0;
			@(negedge pclk)
			preset_N = 1'b1;
        end
    endtask
	
	task send_data_stimulus;
		begin
			@(negedge pclk)
			send_data = 1'b1;
			@(negedge pclk)
			send_data = 1'b0;
		end
	endtask
	
	task initialize;
		begin
			pclk = 1'b0;
			preset_N = 1'b0;
			spiswai = 1'b0;
			spi_mode = 2'b00;
			baud_divisor = 12'b10;
			mstr = 1'b1;
			send_data = 1'b0;
		end
	endtask
	
	task stimulus(input [1:0] spi_mode_i, input [11:0] baud_divisor_i);
		begin
			send_data_stimulus;
			spi_mode = spi_mode_i;
			baud_divisor = baud_divisor_i;
		end
	endtask
	
	initial begin
		initialize;
		preset;
		stimulus(2'b00 , 2);
		#500;
		
		initialize;
		preset;
		stimulus(2'b00 , 4);
		#500;
		$finish;
	end
endmodule
			