module baud_rate_generator_tb;

    reg pclk, preset_N, spiswai, cpol, cpha, ss;
    reg [1:0] spi_mode;
    reg [2:0] sppr, spr;

    wire sclk, mosi_neg, mosi_pos, miso_neg, miso_pos;
    wire [11:0] baud_divisor;

    baud_rate_generator DUT (
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

    
    initial begin
        pclk = 1'b0;
        forever #5 pclk = ~pclk;
    end

    task preset;
        begin
            @(posedge pclk)
			preset_N = 1'b0;
			@(posedge pclk)
			preset_N = 1'b1;
        end
    endtask
	
	
	task initialize;
		begin
			pclk = 1'b0;
			preset_N = 1'b0;
			spi_mode = 2'b00;
			spr = 3'b000;
			sppr = 3'b000;
			spiswai = 1'b0;
			cpol = 1'b0;
			cpha = 1'b0;
			ss = 1'b1;
		end
	endtask
	
	task stimulus(input [2:0] i,j, input x, input y);
		begin
			spi_mode = 2'b01;
			spr = i;
			sppr = j;
			cpol = x;
			cpha = y;
			ss = 1'b0;
		end
	endtask
	
	initial begin
		initialize;
		preset;
		stimulus(3'b000, 3'b000, 0,0);
		#170;
		
		stimulus(3'b000, 3'b000, 0,1);
		#170;
		
		stimulus(3'b000, 3'b000, 1,0);
		#170;
		
		stimulus(3'b000, 3'b000, 1,1);
		#170;
		
		$finish;
	end

    
endmodule
