module spi_shifter( input pclk, preset_N, ss, send_data, lsbfe, cpol, cpha,
					input miso_neg, miso_pos, mosi_neg, mosi_pos,
					input [7:0] data_mosi,
					input miso_in,
					input recieve_data,
					output reg [7:0] data_miso,
					output reg mosi_out);
		
		// count1 = mosi, count2 = miso
		reg [7:0] register;
		reg [3:0] count1, count2;
		
		
		// to perform send data or recieve data operations
		always@(posedge pclk or negedge preset_N) begin
			if(!preset_N)
				begin
					data_miso <= 1'd0;
					register <= 1'd0;
				end
			else
				begin
					if(send_data)
						register <= data_mosi;					
					else if(recieve_data)
						data_miso <= register;
				end
		end
		//mosi
		always@(posedge pclk or negedge preset_N) begin
			if(!preset_N)
				begin
					if(lsbfe)
						begin
							count1 <= 4'b0000;
							count2 <= 4'b0000;
						end
					else
						begin
							count1 <= 4'b0111;
							count2 <= 4'b0111;
						end
					mosi_out <= 1'b0;
				end
			else
				begin
					if(!ss)
						if(lsbfe)
							begin
								if(cpol == cpha)
									begin
										if(mosi_neg)
											begin
												if(count1 <= 7)
													begin
														mosi_out <= register[count1];
														count1 <= count1 + 1'b1;
													end
												else 
													count1 <= 4'b1111;
											end
										else if(miso_pos)
											begin
												if(count2 <= 7)
													begin
														register[count2] <= miso_in;
														count2 <= count2 + 1'b1;
													end
												else
													count2 <= 4'b1111;
											end
									end
								else
									begin
										if(mosi_pos)
											begin
												if(count1 <= 7)
													begin
														mosi_out <= register[count1];
														count1 <= count1 + 1'b1;
													end
												else
													count1 <= 4'b1111;
											end
										else if(miso_neg)
											begin
												if(count2 <= 7)
													begin
														register[count2] <= miso_in;
														count2 <= count2 + 1'b1;
													end
												else
													count2 <= 4'b1111;
											end
									end
							end
						else
							begin
								if(cpol == cpha)
									begin
										if(mosi_neg)
											begin
												if(count1 <= 7 && count1 >= 0)
													begin
														mosi_out <= register[count1];
														count1 <= count1 - 1'b1;
													end
												else
													count1 <= 4'b1000;
											end
										else if(miso_pos)
											begin
												if(count2 <= 7 && count2 >= 0)
													begin
														register[count2] <= miso_in;
														count2 <= count2 - 1'b1;
													end
												else
													count2 <= 4'b1000;
											end
									end
								else
									begin
										if(mosi_pos)
											begin
												if(count1 <= 7 && count1 >= 0)
													begin
														mosi_out <= register[count1];
														count1 <= count1 - 1'b1;
													end
												else
													count1 <= 4'b1000;
											end
										else if(miso_neg)
											begin
												if(count2 <= 7 && count2 >= 0)
													begin
														register[count2] <= miso_in;
														count2 <= count2 - 1'b1;
													end
												else
													count2 <= 4'b1000;
											end
									end
							end
					else
						begin
							if(lsbfe)
								begin
									count1 <= 4'b0000;
									count2 <= 4'b0000;
								end
							else
								begin
									count1 <= 4'b0111;
									count2 <= 4'b0111;
								end
							mosi_out <= 1'b0;
						end
				end
		end		
endmodule
				
		
					