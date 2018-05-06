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
parameter WRITE = 3'b100;

//------------------------------------------------------------------
// reg & wire
reg [2:0] state, state_next;
//reg [16:0] count, count_next;
//reg [16:0] wr_count, wr_count_next;
reg [7:0] cal_count, cal_count_next;
reg [7:0] y_count, y_count_next;
reg img_rd_next;
reg grad_wr_next;
reg [15:0] img_addr_next;
reg [15:0] grad_addr_next;
reg [19:0] grad_do_next;
reg signed[9:0] img_x_pixels0 [0:255];
reg signed[9:0]img_x_pixels0_next [0:255];
reg signed[9:0] img_x_pixels1 [0:255];
reg signed[9:0] img_x_pixels1_next [0:255];
reg signed[9:0] img_x_grads [0:255];
reg signed[9:0] img_x_grads_next [0:255];
reg signed[9:0] img_y_grads [0:255];
reg signed[9:0] img_y_grads_next [0:255];
reg flag, flag_next;//For the store of the first row of pixels
reg wr_flag, wr_flag_next;
wire [7:0] index;
wire [7:0] wr_index;

integer i;

reg done_tem, img_rd_tem, grad_wr_tem;
assign done = done_tem;
assign img_rd = img_rd_tem;
assign grad_wr = grad_wr_tem;
reg [19:0]grad_do_tem;
assign grad_do = grad_do_tem;
reg [15:0]img_addr_tem, grad_addr_tem;
assign img_addr = img_addr_tem;
assign grad_addr = grad_addr_tem;
reg [7:0] img_di_tem;
wire [7:0] img_di_next;
assign img_di_next = img_di;
assign index = (img_addr_tem>256) ? (img_addr_tem)%256-1:img_addr_tem-1;
assign wr_index = (grad_addr_tem>256) ? (grad_addr_tem+1)%256-1+1:grad_addr_tem+1;
//------------------------------------------------------------------
// combinational part
always@(*)begin
	state_next = state;
	//count_next = count;
	//wr_count_next = wr_count;
	cal_count_next = cal_count;
	y_count_next =  y_count;
	img_addr_next = img_addr_tem;
	grad_addr_next = grad_addr_tem;
	grad_do_next = grad_do_tem;
	flag_next = flag;
	wr_flag_next = wr_flag;
	for(i = 0; i <= 255; i=i+1)begin
		img_x_pixels0_next[i] = img_x_pixels0[i];
		img_x_pixels1_next[i] = img_x_pixels1[i];
		img_x_grads_next[i] = img_x_grads[i];
		img_y_grads_next[i] = img_y_grads[i];
	end
	case(state)
		IDLE:begin//0
			img_rd_next = 1'b0;
			grad_wr_next = 1'b0;
			//count_next = 17'd0;
			flag_next = 1'b0;
			wr_flag = 1'b0;
			cal_count_next = 8'd0;
			y_count_next = 8'd0;
			grad_wr_next = 1'b0;
			//wr_count_next = 17'd0;
			done_tem = 1'b0;
			img_addr_next = 16'd0;
			grad_addr_next = 16'd0;
			grad_do_next = 20'd0;
			for(i = 0; i <= 255; i=i+1)begin
				img_x_pixels0_next[i] = 10'b0;
				img_x_pixels1_next[i] = 10'b0;
				img_x_grads_next[i] = 10'b0;
				img_y_grads_next[i] = 10'b0;
			end
		end
		READ0:begin//1
			img_rd_next = 1'b1;
			grad_wr_next = 1'b0;
			if(img_rd != 1'b1)begin
				state_next = READ0;
				img_addr_next = img_addr_tem;
			end
			else begin
				state_next = READ;
				img_addr_next = img_addr_tem + 1;
			end
		end
		READ:begin//2
			img_rd_next = 1'b1;
			grad_wr_next = 1'b0;
			
			//count_next = count + 1;
			if (flag == 1'b1)begin
			//The first row has been completely stored
				img_x_pixels1_next[index][7:0] = img_di_tem;
				img_x_pixels1_next[index][9:8] = 2'b00;
			end
			else begin
			//The first row has not been completely stored
				img_x_pixels0_next[index][7:0] = img_di_tem;
				img_x_pixels0_next[index][9:8] = 2'b00;
			end
			if ((img_addr_tem)%256 == 0)begin
				if(flag == 1'b1)begin
					state_next = CALCULATION;
					img_addr_next = img_addr_tem;
				end
				else begin
				//The first row is stored
					img_addr_next = img_addr_tem + 1;
					state_next = READ;
					flag_next = 1'b1;
				end
			end
			else begin
				img_addr_next = img_addr_tem + 1;
				state_next = READ;
			end
		end
		CALCULATION: begin//3
			img_rd_next = 1'b0;
			grad_wr_next = 1'b0;
			cal_count_next = cal_count + 1;
			if(cal_count < 255)begin
				img_x_grads_next[cal_count] = img_x_pixels0[cal_count + 1] - img_x_pixels0[cal_count];
				img_y_grads_next[cal_count] = img_x_pixels1[cal_count] - img_x_pixels0[cal_count];
				state_next = CALCULATION;
			end
			else begin
				img_x_grads_next[cal_count] = 10'b0;
				img_y_grads_next[cal_count] = img_x_pixels1[cal_count] - img_x_pixels0[cal_count];
				state_next = WRITE;
			end
		end
		WRITE:begin//4
			cal_count_next = 0;
			img_rd_next = 1'b0;
			grad_wr_next = 1'b1;
			if(wr_flag == 1'b1)begin
				grad_addr_next = grad_addr_tem + 1;
				grad_do_next[19:10] = img_x_grads[wr_index];
				grad_do_next[9:0] = img_y_grads[wr_index];
			end
			else begin
				grad_addr_next = grad_addr_tem;
				wr_flag_next = 1'b1;
				grad_do_next[19:10] = img_x_grads[0];
				grad_do_next[9:0] = img_y_grads[0];
			end
			//wr_count_next = wr_count + 1;
			
			if((grad_addr_tem + 1)%256 == 0)begin
				if(y_count != 254)begin
					y_count_next = y_count + 1;
					state_next = READ0;
					wr_flag_next = 1'b0;
					for(i=0;i<=255;i=i+1)begin
						img_x_pixels0_next[i] = img_x_pixels1[i];
					end	
				end
				else begin
					state_next = IDLE;
					done_tem = 1'b1;
				end
			end
			else begin
				state_next = WRITE;
			end
		end
		default:begin
			state_next = IDLE;
		end
	endcase
end

//------------------------------------------------------------------
// sequential part
always @(posedge clk or posedge reset) begin
	if (reset) begin
		// reset
		state <= READ0;
		//count <= 0;
		img_rd_tem <= 0;
		img_addr_tem <= 0;
		flag <= 0;
		wr_flag <= 0;
		//wr_count <= 0;
		cal_count <= 0;
		y_count <= 0;
		img_rd_tem <= 0;
		grad_wr_tem <= 0;
		img_addr_tem <= 0;
		grad_addr_tem <= 0;
		grad_do_tem <= 0;
		img_di_tem <= img_di_next;
		for(i = 0; i <= 255; i=i+1)begin
			img_x_pixels0[i] <= 0;
			img_x_pixels1[i] <= 0;
			img_x_grads[i] <= 0;
			img_y_grads[i] <= 0;
		end
	end
	else begin
		state <= state_next;
		//count <= count_next;
		img_rd_tem <= img_rd_next;
		img_addr_tem <= img_addr_next;
		flag <= flag_next;
		wr_flag <= wr_flag_next;
		//wr_count <= wr_count_next;
		cal_count <= cal_count_next;
		y_count <= y_count_next;
		img_rd_tem <= img_rd_next;
		grad_wr_tem <= grad_wr_next;
		img_addr_tem <= img_addr_next;
		grad_addr_tem <= grad_addr_next;
		grad_do_tem <= grad_do_next;
		img_di_tem <= img_di_next;
		for(i = 0; i <= 255; i=i+1)begin
			img_x_pixels0[i] <= img_x_pixels0_next[i];
			img_x_pixels1[i] <= img_x_pixels1_next[i];
			img_x_grads[i] <= img_x_grads_next[i];
			img_y_grads[i] <= img_y_grads_next[i];
		end
	end
end

initial begin
	//$fsdbDumpfile("counter.fsdb");
	//$fsdbDumpvars();
	$dumpfile("counter.vcd");
	$dumpvars();
	$display("\n === I love Misaka Mikoto === \n");
end
endmodule
