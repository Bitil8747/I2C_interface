`timescale 1ns/1ns

module I2C_tb;

wire SDA;
wire SCL;
reg CLK;
reg reset;
wire dir;

initial begin
	MASTER.resend = 0;
	end

slave_device SLAVE(.CLK(CLK), .reset(reset), .SDA(SDA), .SCL(SCL), .dir(dir));
master_device MASTER(.CLK(CLK), .reset(reset), .SDA(SDA), .SCL(SCL), .dir(dir));

initial begin
	CLK = 0;
	forever begin
		CLK = #500 ~CLK;
	end
end

initial begin
	reset = 1;
	#2000 reset = 0;
end

endmodule