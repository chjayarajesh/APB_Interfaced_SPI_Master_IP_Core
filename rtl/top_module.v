module top_module(input pclk, preset_N, pwrite, penable, psel,
					input [2:0] paddr,
					input [7:0] pw_data,
					input miso_in,
					output [7:0] pr_data,
					output pready, pslverr, spi_interrupt_request,sclk, ss, mosi_out);
					
	//	APB_slave interface outputs	
	wire mstr, cpol, cpha, lsbfe, spiswai;
	wire [7:0] data_mosi;
	wire send_data;
	wire [1:0] spi_mode;
	wire [2:0] sppr, spr;
	
	// Baud rate outputs
	wire [11:0] baud_divisor;
	wire mosi_neg, mosi_pos, miso_neg, miso_pos;
	
	// SPI slave control select
	wire tip, recieve_data;
	
	//SPI shifter
	wire [7:0] data_miso;
	
	APB_slave_interface M1(pclk, preset_N, pwrite, psel, penable, ss, recieve_data, tip, 
							paddr, pw_data, data_miso, pr_data, data_mosi,
							mstr, cpol, cpha, lsbfe, spiswai, spi_interrupt_request, pready, pslverr,
							send_data, spi_mode, sppr, spr);
							
	baud_rate_generator M2(
        .pclk(pclk),
        .preset_N(preset_N),
        .spi_mode(spi_mode),
        .spiswai(spiswai),
        .sppr(sppr),
        .spr(spr),
        .cpol(cpol),
        .cpha(cpha),
        .ss(ss),
        .sclk(sclk),
        .mosi_neg(mosi_neg),
        .mosi_pos(mosi_pos),
        .miso_neg(miso_neg),
        .miso_pos(miso_pos),
        .baud_divisor(baud_divisor)
    );
			
	spi_slave_control_select M3(pclk, preset_N, spiswai, mstr, send_data, spi_mode, baud_divisor, recieve_data, ss, tip);
	
	spi_shifter M4(pclk, preset_N, ss, send_data, lsbfe, cpol, cpha,
					miso_neg, miso_pos, mosi_neg, mosi_pos,
					data_mosi, miso_in,
					recieve_data, data_miso, mosi_out);
endmodule