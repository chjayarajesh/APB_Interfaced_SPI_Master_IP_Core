module APB_slave_interface(input pclk, preset_N, pwrite, psel, penable, ss, recieve_data, tip,
							input [2:0] paddr,
							input [7:0] pw_data, data_miso,
							output reg [7:0] pr_data, data_mosi,
							output mstr, cpol, cpha, lsbfe, spiswai, spi_interrupt_request, pready, pslverr, 
							output reg send_data,
							output [1:0] spi_mode,
							output [2:0] sppr, spr);
				
	parameter APB_IDLE = 2'b00,
				APB_SETUP = 2'b01,
				APB_ENABLE = 2'b10;
	
	parameter SPI_RUN = 2'b00,
				SPI_WAIT = 2'b01,
				SPI_STOP = 2'b10;
				
	// Declaration of registers
	wire spe, spie, sptie;
	reg [7:0] CR1, CR2, BR, DR;
	wire [7:0] SR;
	reg spif, sptef, modf;
	assign SR = {spif, 1'b0, sptef, modf, 4'b0};
	
	//FSM declarations
	reg [1:0] APB_state, APB_next_state;
	reg [1:0] SPI_state, SPI_next_state;
	
	// APB control signals
	assign pready = (APB_state == APB_ENABLE);
	assign pslverr = ((APB_state == APB_ENABLE) && !tip);
	
	// spi active condition
	wire spi_active = (SPI_state == SPI_RUN || (SPI_state == SPI_WAIT && !spiswai));
		
	// write and read signals
	wire wr_enable = ((APB_state == APB_ENABLE) && pwrite && pready);
	wire rd_enable = ((APB_state == APB_ENABLE) && !pwrite && pready);
	wire tx_write = wr_enable && (paddr == 3'b101) && spi_active && sptef;
	reg tx_pending;
	reg modf_read_done;
	reg sr_read_done; // using for spif flag (asserted after reading the data)
	reg transferred; // using to make the send_Data to be 1 for one clk cycle
	reg recieve_delay; // to delay the transmission of miso to DR
	// outputs from registers
	assign spie = CR1[7];
	assign spe = CR1[6];
	assign sptie = CR1[5];
	assign mstr = CR1[4];
	assign cpol = CR1[3];
	assign cpha = CR1[2];
	assign lsbfe = CR1[0];
	
	assign modfen = CR2[4];
	assign spiswai = CR2[1];
	
	assign sppr = BR[6:4];
	assign spr = BR[2:0];
	
	//spi interrupt request
	assign spi_interrupt_request = ((!spie && !sptie) ? 1'b0 :
										(spie && !sptie)  ? (spif || modf) :
										(!spie && sptie)  ? sptef : (spif || sptef || modf));
							
	// APB FSM				
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			APB_state <= APB_IDLE;
		else
			APB_state <= APB_next_state;
	end
	
	always@(*) begin
			case(APB_state)
				2'b00 : begin
							if(psel && !penable)
								APB_next_state = APB_SETUP;
							else
								APB_next_state = APB_IDLE;
						end
				2'b01 : begin
							if(psel && penable)
								APB_next_state = APB_ENABLE;
							else if(psel && !penable)
								APB_next_state = APB_SETUP;
							else
								APB_next_state = APB_IDLE;
						end
				2'b10 : begin	
							if(psel)
								APB_next_state = APB_SETUP;
							else
								APB_next_state = APB_IDLE;
						end
				default : APB_next_state = APB_IDLE;
			endcase
	end
	
	// SPI modes FSM				
	assign spi_mode = SPI_state;
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			SPI_state <= SPI_RUN;
		else
			SPI_state <= SPI_next_state;
	end
	
	always@(*) begin
			case(SPI_state)
				2'b00 : begin
							if(!spe)
								SPI_next_state = SPI_WAIT;
							else 
								SPI_next_state = SPI_RUN;
						end
				2'b01 : begin
							if(spe)
								SPI_next_state = SPI_RUN;
							if(spiswai)
								SPI_next_state = SPI_STOP;
							else
								SPI_next_state = SPI_WAIT;
						end
				2'b10 : begin
							if(spe)
								SPI_next_state = SPI_RUN;
							else if(!spiswai)
								SPI_next_state = SPI_WAIT;
							else
								SPI_next_state = SPI_STOP;
						end
				default : SPI_next_state = SPI_RUN;
			endcase
	end
	
	// read operation
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			begin
				pr_data <= 8'd0;
			end
		else begin
			if(rd_enable && pready)
				begin	
					case(paddr)
						3'b000 : pr_data <= CR1;
						3'b001 : pr_data <= CR2;
						3'b010 : pr_data <= BR;
						3'b011 : pr_data <= SR;
						3'b101 : pr_data <= (spif) ? DR : 8'd0;
						default : pr_data <= 8'd0;
					endcase
				end
			else
				pr_data <= 8'd0;
		end
	end
	
	//write registers
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			begin
				CR1 <= 8'b00000100;
				CR2 <= 8'b00000000;
				BR <= 8'b00000000;
			end
		else
			begin
				if(wr_enable && APB_state == APB_ENABLE)
					begin
						case(paddr)
							3'b000 : CR1 <= pw_data;
							3'b001 : CR2 <= pw_data;
							3'b010 : BR <= pw_data;
							default : begin
											CR1 <= CR1;
											CR2 <= CR2;
											BR <= BR;
										end
						endcase
					end
				else
					begin
						CR1 <= CR1;
						CR2 <= CR2;
						BR <= BR;
					end
			end
	end
	
	
	// SR flags assignment
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			begin
				spif <= 1'b0;
				sptef <= 1'b1;
				modf <= 1'b0;
				sr_read_done <= 1'b0;
				modf_read_done <= 1'b0;
			end
		else
			begin
				// modf logic
				if(!ss && mstr && modfen && !CR1[1])
					modf <= 1'b1;
				else if(rd_enable && paddr == 3'b011 && modf)
					modf_read_done <= 1'b1;
				else if(wr_enable && paddr == 3'b000 && modf_read_done)
					begin
						modf <= 1'b0;
						modf_read_done <= 1'b0;
					end
					
				// sptef flag logic
				if(tx_write)
					sptef <= 1'b0;
				else if(transferred)
					sptef <= 1'b1;
				
					
				// spif flag logic
				if (recieve_delay) begin
					spif <= 1'b1;
					sr_read_done <= 1'b0;
				end
				else if (rd_enable && paddr == 3'b011 && spif) begin
					sr_read_done <= 1'b1;
				end
				else if (rd_enable && paddr == 3'b101 && sr_read_done) begin
					spif <= 1'b0;
					sr_read_done <= 1'b0;
				end
			end
	end
					
	// writing transmit data (MOSI) into DR and recieving data (MISO) into DR
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			begin
				DR <= 8'd0;
				recieve_delay <= 1'b0;
			end
		else
			begin
				if(recieve_data)
					recieve_delay = 1'b1;
				else if(recieve_delay)
					begin
						DR <= data_miso;
						recieve_delay <= 1'b0;
					end
				else if(tx_write)
					DR <= pw_data;
				else 
					DR <= DR;
			end
	end
	
	
	// transfering DR data to data_mosi and asserting send_data
	always@(posedge pclk or negedge preset_N) begin
		if(!preset_N)
			begin
				data_mosi <= 8'd0;
				transferred <= 1'b0;
				send_data <= 1'b0;
				tx_pending <= 1'b0;
			end
		else
			begin
				send_data <= 1'b0;
				
				if(tx_write)
					tx_pending <= 1'b1;
				else if(tx_pending && spi_active)
					begin
						data_mosi <= DR;
						transferred <= 1'b1;
						send_data <= 1'b1;
						tx_pending <= 1'b0;
					end
				else if(recieve_data)
					transferred <= 1'b0;
				
			end
	end
	
endmodule