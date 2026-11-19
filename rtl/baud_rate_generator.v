module baud_rate_generator( input pclk, preset_N,
							input [1:0] spi_mode,
							input spiswai,
							input [2:0] sppr, spr,
							input cpol, cpha,
							input ss,
							output reg sclk,
							output reg mosi_neg, mosi_pos, miso_neg, miso_pos,
							output [11:0] baud_divisor);
							
	reg [11:0] count;
	wire pre_sclk;
	
	assign baud_divisor = (sppr+1) << (spr+1);
	assign pre_sclk = cpol;
	
	wire spi_active = !ss && (spi_mode == 2'b00 || (spi_mode == 2'b01 && !spiswai));
	
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			begin
				count <= 12'b0;
				sclk <= pre_sclk;
			end
		else
			begin
				if(spi_active)
					begin
						if(count == (baud_divisor/2) - 1)
							begin
								sclk <= ~sclk;
								count <= 12'b0;	
							end
						else
							count <= count + 1'b1;
					end
				else
					begin
						sclk <= pre_sclk;
						count <= 12'b0;
					end
			end
	end
	
		
	// miso
	always@(posedge pclk or negedge preset_N) 
		begin
			if(!preset_N)
				begin
					miso_neg <= 1'b0;
					miso_pos <= 1'b0;
				end
			else if(baud_divisor == 2)
				begin
					miso_neg <= 1'b0;
					miso_pos <= 1'b0;
					if(spi_active)
						begin
							if(sclk)
								begin
									if(cpol == 0 && cpha == 0)
										miso_pos <= 1'b1;
									else if(cpol == 0 && cpha == 1)
										miso_neg <= 1'b1;
								end
							else
								begin
									if(cpol == 1 && cpha == 0)
										miso_neg <= 1'b1;
									else if(cpol == 1 && cpha == 1)
										miso_pos <= 1'b1;
								end
						end
				end
			else
				begin
					miso_neg <= 1'b0;
					miso_pos <= 1'b0;
					if(spi_active)
						begin
							if((cpol == cpha) && !sclk)
								begin
									if(count == (baud_divisor/2) - 1)
										miso_pos <= 1'b1;
								end
							else if((cpol != cpha) && sclk)
								begin
									if(count == (baud_divisor/2) - 1)
										miso_neg <= 1'b1;
								end
						end
				end
		end
	
	//mosi
	always@(posedge pclk or negedge preset_N) 
		begin
			if(!preset_N)
				begin
					mosi_neg <= 1'b0;
					mosi_pos <= 1'b0;
				end
			else if(baud_divisor == 2)
				begin
					mosi_neg <= 1'b0;
					mosi_pos <= 1'b0;
					if(spi_active)
						begin
							if(sclk)
								begin
									if(cpol == 1 && cpha == 0)
										mosi_pos <= 1'b1;
									else if(cpol == 1 && cpha == 1)
										mosi_neg <= 1'b1;
								end
							else
								begin
									if(cpol == 0 && cpha == 0)
										mosi_neg <= 1'b1;
									else if(cpol == 0 && cpha == 1)
										mosi_pos <= 1'b1;
								end
						end
				end
			else
				begin
					mosi_neg <= 1'b0;
					mosi_pos <= 1'b0;
					if(spi_active)
						begin
							if((cpol == cpha) && !sclk)
								begin
									if(count == (baud_divisor/2) - 2)
										mosi_neg <= 1'b1;
								end
							else if((cpol != cpha) && sclk)
								begin
									if(count == (baud_divisor/2) - 2)
										mosi_pos <= 1'b1;
								end
						end
				end
		end
						
								
				
endmodule
	
		
		
							
			
							