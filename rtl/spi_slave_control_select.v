module spi_slave_control_select( input pclk, preset_N, spiswai, mstr, send_data,
									input [1:0] spi_mode,
									input [11:0] baud_divisor,
									output reg recieve_data,
									output reg ss,
									output tip);
	reg [15:0] count;
	wire [14:0] target = baud_divisor << 3;
	wire spi_active = (mstr && (spi_mode == 2'b00 || (spi_mode == 2'b01 && spiswai == 0)));
	reg rcv_s;
	assign tip = ~ss;
		
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			begin
				ss <= 1'b1;
				count <= 16'hffff;
				rcv_s <= 1'b0;
				
			end
		else
			begin
				if(spi_active && send_data)
					begin
						count <= 16'b0;
						rcv_s <= 1'b0;
						ss <= 1'b0;
					end
				else
					begin			
						if(spi_active)
							begin
								if(count < target - 1'b1)
									begin
										rcv_s <= 1'b0;
										count <= count + 1'b1;
										ss <= 1'b0;
									end
								else if(count == target - 1'b1)
									begin
										rcv_s <= 1'b1;
										ss <= 1'b0;
										count <= count + 1'b1;
									end
								else
									begin
										rcv_s <= 1'b0;
										count <= 16'hffff;
										ss <= 1'b1;
									end
							end
						else
							begin
								rcv_s <= 0;
								ss <= 1'b1;
								count <= 16'hffff;
							end	
					end
			end		
	end
	
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			recieve_data <= 1'b0;
		else
			recieve_data <= rcv_s;
	end
endmodule

			
			
				
			