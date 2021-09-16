module master_device (CLK, reset, SDA, SCL, dir);
input CLK;
input reset;
inout reg SDA;
output wire SCL;
output reg dir;

localparam STATE_IDLE = 0;
localparam STATE_START = 1;
localparam STATE_ADDR = 2;
localparam STATE_RW = 3;
localparam STATE_WACK = 4;
localparam STATE_WACK2 = 5;
localparam STATE_WACK3 = 6;
localparam STATE_DATA = 7;
localparam STATE_INPUT_DATA = 8;
localparam STATE_WACK_TO_STOP = 9;
localparam STATE_WACK_TO_STOP2 = 10;
localparam STATE_WACK_TO_STOP_WAIT = 11;
localparam STATE_WACK_TO_STOP2_WAIT = 12;
localparam STATE_STOP = 13;

reg [7:0] state; // Текущий статус
reg [6:0] addr; // Адрес устройства назначения
reg [7:0] count; // Счетчик
reg [7:0] data; // Отправляемые данные
reg [7:0] input_data; // Принимаемые данные
reg scl_enable = 0; // Значение SCL
reg resend = 0; // 0 - повтор передачи, 1 - отмена повторной передачи
reg SDA_level; // Напряжение на SDA
reg diraction; // Направление передачи, 0 - от MASTER, 1 - от SLAVE
reg RW; // Бит записи или чтения данных

assign dir = diraction;
assign SCL = (scl_enable == 0) ? 1: ~CLK;
assign SDA = (dir == 0) ? SDA_level: 8'bZ;


always@(negedge CLK) begin
	if(reset == 1) begin
		scl_enable <= 0;
	end 
	else begin
		if((state == STATE_IDLE) || (state == STATE_START) || (state == STATE_STOP) || (state == STATE_WACK2) || (state == STATE_WACK_TO_STOP2)) begin
			scl_enable <= 0;
		end
		else begin
			scl_enable <= 1;
		end
	end
end


always@(posedge CLK) begin
	if(reset == 1) begin
		state <= 0;
		SDA_level <= 1;
		addr <= 7'b1100111;
		count <= 8'd0;
		data <= 8'b10101010;
		diraction <= 0;
		RW <= 0;
	end 
	else begin
		case(state)
		STATE_IDLE: begin // состояние покоя 
			SDA_level <= 1;
			state <= STATE_START; 
			end
		STATE_START: begin // стартовый бит
			SDA_level <= 0;
			state <= STATE_ADDR; 
			count <= 6; 
			end
		STATE_ADDR: begin // передача адреса 
			SDA_level <= addr[count];			
			if(count == 0) state <= STATE_RW; 
			else count <= count - 1; 
			end
		STATE_RW: begin // бит чтения или записи
			if(RW == 0) begin
				SDA_level <= 0; 
			end
			if(RW == 1) begin
				SDA_level <= 1;
			end
			state <= STATE_WACK;
			end
		STATE_WACK: begin // в зависимости от бита чтения или записи переходим в состояние STATE_WACK2 или STATE_WACK3
			diraction <= 1;
			if(RW == 0) begin
				state <= STATE_WACK2; 
				count <= 7;
				end
			if(RW == 1) begin
				state <= STATE_WACK3;
				count <= 7;
				end
			end
		STATE_WACK2: begin // подтверждение от SLAVE, если нет - генерируем стоповый бит (при установленном бите записи)
			if(SDA == 1) begin
				state <= STATE_STOP;
				SDA_level <= 0;
				diraction <= 0;
				end
			if(SDA == 0) begin
				state <= STATE_WACK_TO_STOP2_WAIT; 
				SDA_level <= 0;
				count <= 7;
				diraction <= 0;
				end
			end
		STATE_WACK3: begin // подтверждение от SLAVE, если нет - генерируем стоповый бит (при установленном бите чтения)
			if(SDA == 1) begin
				state <= STATE_STOP; 
				SDA_level <= 0;
				diraction <= 0;
				end
			if(SDA == 0) begin
				state <= STATE_INPUT_DATA;
				count <= 7;
				diraction <= 1;
				end
			end
		STATE_DATA: begin
			diraction <= 0;
			SDA_level <= data[count];
			if(count == 0) state <= STATE_WACK_TO_STOP; 
			else count <= count - 1;
			end
		STATE_INPUT_DATA: begin
			diraction <= 1;
			input_data[count] <= SDA;
			if(count == 0) begin
				state <= STATE_WACK_TO_STOP2;
				diraction <= 0;
			end
			else begin 
				count <= count - 1;
			end
		end
		STATE_WACK_TO_STOP: begin 
			diraction <= 1;
			SDA_level <= 0;
			state <= STATE_WACK_TO_STOP_WAIT; 
			end
		STATE_WACK_TO_STOP2: begin 
			SDA_level <= 1;
			state <= STATE_WACK_TO_STOP2_WAIT; 
			end
		STATE_WACK_TO_STOP_WAIT: begin 
			state <= STATE_STOP; 
			end
		STATE_WACK_TO_STOP2_WAIT: begin 
			diraction <= 0;
			SDA_level <= 0;
			state <= STATE_STOP; 
			end
		STATE_STOP: begin  
			diraction <= 0;
			SDA_level <= 1;
			if(resend == 1) state <= STATE_IDLE;
			end
		endcase
	end
end
endmodule