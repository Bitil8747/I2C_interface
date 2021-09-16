module slave_device (CLK, reset, SDA, SCL, dir);
input CLK;
input reset;
inout reg SDA;
input SCL;
input dir;

localparam STATE_IDLE = 0;
localparam STATE_START = 1;
localparam STATE_ADDR = 2;
localparam STATE_RW = 3;
localparam STATE_ACK = 4;
localparam STATE_WAIT = 5;
localparam STATE_DATA = 6;
localparam STATE_OUTPUT_DATA = 7;
localparam STATE_STOP = 8;
localparam STATE_ACK2 = 9;

reg [7:0] state; // Текущий статус
reg [6:0] addr = 7'b1100111; // Адрес устройства
reg [7:0] data ; // Входные данные
reg [7:0] output_data; // Выходные данные
reg [6:0] addr_compare = 7'd0 ; // Адрес устройства назначения, полученный от Мастера
reg [3:0] addr_counter = 0 ; // Счетчик для адреса
reg [3:0] data_counter = 0 ; // Счетчик для входных данных
reg [3:0] count; // Счетчик для выходных данных
reg RW; // Бит записи или чтения данных MASTER
reg ACK; // Передача сигналов по SDA от SLAVE к MASTER
reg start = 0; // Определение стартового бита
reg stop = 0; // Определение сторового бита
reg SDA_DATA; // Шина данных SDA

assign SDA = (dir == 1) ? ACK: 8'bZ;
assign SDA_DATA = SDA;


always@(posedge CLK) begin // Если reset = 1, то переходим в состояние STATE_IDLE
	if(reset == 1) begin
		state <= STATE_IDLE;
		output_data <= 8'b10101010;
	end
end

always@(negedge SDA_DATA) begin // Определяем стартовый бит и переходим в состояние STATE_START
	if(~reset & (SCL == 1) & (dir == 0)) begin
		start <= 1;
		state <= STATE_START;
	end
end
 
always@(posedge SDA_DATA) begin // Определяем стоповый бит и переходим в состояние STATE_STOP
	if(~reset & (SCL == 1) & (dir == 0)) begin
		stop <= 1;
		state <= STATE_STOP;
	end
end

always@(posedge SCL) begin // Определяем адрес назначения и заносим его значение в переменную addr_compare
	if((state == STATE_START) & (addr_counter < 7)) begin
		addr_compare[6 - addr_counter] = SDA_DATA;
		addr_counter = addr_counter + 1;
		start <= 0;
		if(addr_counter > 6) state <= STATE_RW; // После переходим в состояние STATE_RW
	end
	else begin 
		case(state)
			STATE_RW: begin // Определяем, какой бит установлен, чтения или записи.
				state <= STATE_ACK;
				if(SDA == 0) begin
					RW = 0;
				end
				else begin
					RW = 1;
				end
				if(addr_compare == addr) begin // Сравниваем адрес назначения с адресом устройства
					ACK <= 0;
				end
				else begin
					ACK <= 1;
				end
				end
			STATE_ACK: begin // Если установлен бит записи, то переходим в состояние STATE_DATA, если бит чтения - в в состояние STATE_WAIT
			//ACK <= 0;
			if(addr_compare == addr) begin // Сравниваем адрес назначения с адресом устройства
					ACK <= 0;
				end
				else begin
					ACK <= 1;
				end
				if(RW == 0) begin
					data_counter <= 0;
					state <= STATE_DATA;
					
				end
				if(RW == 1) begin
					count <= 7;
					state <= STATE_OUTPUT_DATA;
				end
				end
			STATE_WAIT: begin // Переходим в состояние STATE_OUTPUT_DATA
				state <= STATE_OUTPUT_DATA;
				end
			STATE_DATA: begin // Считываем приходящие данные в переменную data
				if(data_counter < 8) begin
					data[7 - data_counter] = SDA_DATA;
					data_counter = data_counter + 1;
				end
				else state <= STATE_ACK2;
				end
			STATE_OUTPUT_DATA: begin // Отправляем данные от SLAVE к MASTER
				ACK <= output_data[count];
				count <= count - 1;
				end
			STATE_ACK2: begin // Подтверждаем получение данных
				ACK <= 0;
				if(stop == 1)
					state <= STATE_STOP;
				end
			STATE_STOP: begin
				ACK <= 0;
			end
		endcase
	end
end

endmodule