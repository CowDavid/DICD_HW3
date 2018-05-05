module IG ( clk , reset, done, img_wr, img_rd, img_addr, img_di, img_do, 
            grad_wr, grad_rd, grad_addr, grad_do, grad_di);

input clk, reset;
input [7:0] img_di;
input [19:0] grad_di;
output done, img_wr, img_rd, grad_wr, grad_rd;
output [15:0] img_addr, grad_addr;
output [7:0] img_do;
output [19:0] grad_do;

parameter IDLE = 3'b000;
parameter READ0 = 3'b001;//for reading notification
parameter READ = 3'b010;
parameter CALCULATION = 3'b011;
parameter WRITE0 = 3'b100;
parameter WRITE = 3'b101;
//------------------------------------------------------------------
// reg & wire
reg [2:0] state, state_next;
reg [15:0] count, count_next;
reg [15:0] wr_count, wr_count_next;
reg [7:0] cal_count, cal_count_next;
reg [7:0] y_count, y_count_next;
reg img_rd_next;
reg grad_wr_next;
reg [15:0] img_addr_next;
reg [15:0] grad_addr_next;
reg [19:0] grad_do_next;
reg [7:0] img_di_next;
reg signed[9:0] img_x_pixels0 [0:255];
reg signed[9:0] img_x_pixels1 [0:255];
reg signed[9:0] img_x_grads[0:255];
reg signed[9:0] img_y_grads[0:255];
reg flag, flag_next = 1'b0, 1'b0;//For the store of the first row of pixels
wire [255:0] index;
wire [255:0] wr_index;
assign index = (count>255) ? (count+1)%256-1:count;
assign wr_index = (wr_count>255) ? (wr_count+1)%256-1:count;
//------------------------------------------------------------------
// combinational part
always@(*)begin
	case(state)
		IDLE:begin
			img_rd_next = 1'b0;
			count_next = 16'd0;
			flag_next = 1'b0;
			cal_count_next = 8'd0;
			y_count_next = 8'd1
			grad_wr_next = 1'b0;
			wr_count_next = 16'd0;
		end
		READ0:begin
			img_rd_next = 1'b1;
			img_addr_next = count;
			if(img_rd != 1'b1)begin
				state_next = READ0;
			end
			else begin
				state_next = READ;
			end
		end
		READ:begin
			img_rd_next = 1'b1;
			img_addr_next = count + 1;
			count_next = count + 1;
			if (flag)begin
			//The first row has been completely stored
				img_x_pixels1[index][7:0] = img_di;
				img_x_pixels1[index][9:8] = 2'b00;
			end
			else begin
			//The first row has not been completely stored
				img_x_pixels0[index][7:0] = img_di;
				img_x_pixels0[index][9:8] = 2'b00;
				flag_next = 1'b1;
			end
			if ((count + 1)%256 == 0)begin
				if(flag)begin
					state_next = CALCULATION;
				end
				else begin
				//The first row is stored
					state_next = READ;
					flag_next = 1'b1;
				end
			end
			else begin
				state_next = READ;
			end
		end
		CALCULATION: begin
			y_count_next = y_count + 1;
			cal_count_next = cal_count + 1;
			if(cal_count != 255)begin
				img_x_grads[cal_count] = img_x_pixels0[cal_count + 1] - img_x_pixels0[cal_count]
				img_y_grads[cal_count] = img_x_pixels0[cal_count] - img_x_pixels1[cal_count]
				state_next = CALCULATION;
			end
			else begin
				img_y_grads[cal_count] = img_x_pixels1[cal_count] - img_x_pixels0[cal_count]
				state_next = WRITE0;
			end
		end
		WRITE0:begin
			grad_wr_next = 1'b1;
			grad_addr_next = wr_count;
			grad_do_next[19:10] = img_x_grads[wr_index];
			grad_do_next[9:0] = img_y_grads[wr_index];

		end
		default:begin
			state_next = IDLE;
		end
	endcase
end

//------------------------------------------------------------------
// sequential part
always @(posedge clk or posedge rst) begin
	if (rst) begin
		// reset
		state <= READ0;
		count <= count_next;
		img_rd <= img_rd_next;
		img_addr <= img_addr_next;
		flag <= flag_next;
	end
	else begin
		state <= state_next;
		count <= count_next;
		img_rd <= img_rd_next;
		img_addr <= img_addr_next;
		flag <= flag_next;
	end
end


endmodule
