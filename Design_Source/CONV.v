
`timescale 1ns/10ps

module  CONV(
	input	wire				clk,
	input	wire				reset,
	output reg 				busy,	
	input	wire				ready,	
			
	output reg [11:0]	iaddr,
	input	wire [19:0] idata, 		// 4 + 16
	
	output reg	 			cwr,
	output reg [11:0]	caddr_wr,
	output reg [19:0]	cdata_wr, // 4 + 16
	
	output reg	 			crd,
	output reg [11:0]	caddr_rd, 
	input	wire [19:0]	cdata_rd, // 4 + 16
	
	output reg [2:0] 	csel	// 0 : no sel
												 	// 1 : layer 0 Kernel 0 result
												 	// 2 : layer 0 Kernel 1 result
												 	// 3 : layer 1 Kernel 0 result
												 	// 4 : layer 1 Kernel 1 result
												 	// 5 : layer 2 
);



	localparam [19:0] KERNEL_0_0 = 20'h0A89E;
	localparam [19:0] KERNEL_0_1 = 20'h092D5;
	localparam [19:0] KERNEL_0_2 = 20'h06D43;
	localparam [19:0] KERNEL_0_3 = 20'h01004;
	localparam [19:0] KERNEL_0_4 = 20'hF8F71;
	localparam [19:0] KERNEL_0_5 = 20'hF6E54;
	localparam [19:0] KERNEL_0_6 = 20'hFA6D7;
	localparam [19:0] KERNEL_0_7 = 20'hFC834;
	localparam [19:0] KERNEL_0_8 = 20'hFAC19;


	localparam [19:0] KERNEL_1_0 = 20'hFDB55;
	localparam [19:0] KERNEL_1_1 = 20'h02992;
	localparam [19:0] KERNEL_1_2 = 20'hFC994;
	localparam [19:0] KERNEL_1_3 = 20'h050FD;
	localparam [19:0] KERNEL_1_4 = 20'h02F20;
	localparam [19:0] KERNEL_1_5 = 20'h0202D;
	localparam [19:0] KERNEL_1_6 = 20'h03BD7;
	localparam [19:0] KERNEL_1_7 = 20'hFD369;
	localparam [19:0] KERNEL_1_8 = 20'h05E68;



	parameter [19:0] BIAS_0 = 20'h01310;
	parameter [19:0] BIAS_1 = 20'hF7295;



	reg [20:0] 	ma;
	reg [19:0]	mb;
	reg  				me;
	wire [40:0] mo;
	wire 				mv;

	multi_div
	#(
	  .SIZE_A(21),
	  .SIZE_B(20),
	  .SIGNED(1),
	  .STEP_SIZE(1) 
	) multi_u1(
	  .clk(clk),.reset(reset),
	  .en(me),
	  .select(1'b0),
	  .a(ma),
	  .b(mb),
	  .P(mo),
	  .div_zero(),
	  .Valid(mv),
	  .Busy()
	);





	parameter LAYER_0 	= 0,
						LAYER_1_2 = 1,
						IDLE 			= 2;


	reg [1:0] 				state;
	reg 							IMG_S;
	reg [5:0] 				state_x,state_y;
	reg [3:0] 				state_step;
	reg [1:0] 				state_dx,state_dy;  

	reg signed [43:0] write_reg;


	always@(*)begin
		busy <= state==IDLE ? 0:1;
	end

	always @(posedge clk or posedge reset) begin
		if(reset)begin

			//if(ready) state <= LAYER_0;
			//else state <= IDLE;
	
			state <= IDLE;
			cwr <= 0;
			IMG_S <= 0;
			me<= 0;
			write_reg <= 0;
			state_step <= 0;
			{state_y,state_x} 	<= 0;
			{state_dx,state_dy} <= 0;
		end else begin
			case(state)
				





				
				LAYER_0:begin	

					
					case(state_step)

						// Out Address
						0:begin

							if( $signed(state_x+state_dx-1) < 0 || $signed(state_x+state_dx-1) > 63 
								|| $signed(state_y+state_dy-1) < 0 || $signed(state_y+state_dy-1) > 63)begin
								iaddr <= 0;	
								state_step <= 3;
							end else begin
								iaddr[11:6] 	<= state_y + state_dy - 1;
								iaddr[5:0] 	<= state_x + state_dx - 1;
								state_step <= state_step + 1;
							end
							
							
						end


						// (Read Data) and ( mov ma mb multi)
						1:begin
							me <= 1;
							ma <= idata;
							if(IMG_S==0)begin
								case({state_dy,state_dx})
									{2'd0,2'd0}: mb <= KERNEL_0_0;
									{2'd0,2'd1}: mb <= KERNEL_0_1;
									{2'd0,2'd2}: mb <= KERNEL_0_2;
									{2'd1,2'd0}: mb <= KERNEL_0_3;
									{2'd1,2'd1}: mb <= KERNEL_0_4;
									{2'd1,2'd2}: mb <= KERNEL_0_5;
									{2'd2,2'd0}: mb <= KERNEL_0_6;
									{2'd2,2'd1}: mb <= KERNEL_0_7;
									{2'd2,2'd2}: mb <= KERNEL_0_8;
									default mb <= 0;
								endcase
							end
							else begin
								case({state_dy,state_dx})
									{2'd0,2'd0}: mb <= KERNEL_1_0;
									{2'd0,2'd1}: mb <= KERNEL_1_1;
									{2'd0,2'd2}: mb <= KERNEL_1_2;
									{2'd1,2'd0}: mb <= KERNEL_1_3;
									{2'd1,2'd1}: mb <= KERNEL_1_4;
									{2'd1,2'd2}: mb <= KERNEL_1_5;
									{2'd2,2'd0}: mb <= KERNEL_1_6;
									{2'd2,2'd1}: mb <= KERNEL_1_7;
									{2'd2,2'd2}: mb <= KERNEL_1_8;
									default mb <= 0;
								endcase
							end

							state_step <= state_step + 1;
						end


						// add write
						2:begin
							me <= 0;
							if(mv)begin // wait multi ip done
								write_reg <= $signed(write_reg) + $signed(mo); 
								state_step <= state_step + 1;
							end
							else state_step <= state_step;
						end


						// refresh dx and dy 
						3:begin

							

							if(state_dy == 2 && state_dx == 2)begin
								//	Write cdata 
								{state_dx,state_dy} <= 0;
								state_step <= state_step + 1;

								//relu
								if(IMG_S) write_reg <= $signed(write_reg) + ($signed(BIAS_1)<<16);
								else write_reg <= $signed(write_reg) + ($signed(BIAS_0)<<16);

							end else if(state_dx == 2)begin
								state_dx <= 0;
								state_dy <= state_dy + 1;
								state_step <= 0;
							end else begin
								state_dx <= state_dx + 1;
								state_step <= 0;
							end
						end


						4:begin
								cwr <= 1;
								csel <= IMG_S ? 2:1;
								state_step <= state_step + 1;
								caddr_wr <= {state_y,state_x};
								cdata_wr <= (write_reg < 0) ? 0 :  ((write_reg>>16)+write_reg[15]) ; // 8+32 
						end


						5:begin

							

							cwr <= 0;
							if(state_y == 63 && state_x == 63)begin
								if(IMG_S)begin
									state <= LAYER_1_2;
									IMG_S <= 0;
								end else begin
									IMG_S <= 1;
								end 	
								state_x <= 0;
								state_y <= 0;
							end 
							else if(state_x == 63)begin
								state_x <= 0;
								state_y <= state_y + 1; 
							end 
							else begin
								state_x <= state_x + 1;
							end

							state_dx <= 0;
							state_dy <= 0;
							state_step <= 0;
							
							write_reg <= 0;

						end



					endcase
				
				end 
				
				







			

				
				LAYER_1_2:begin
					case(state_step)
						0:begin
							csel <= IMG_S ? 2 : 1;
							cwr <= 0;
							crd <= 1;
							caddr_rd[11-:5] <= state_y; 
							caddr_rd[5-:5]  <= state_x; 
							caddr_rd[6] <= 0;
							caddr_rd[0] <= 0;
							state_step <= state_step + 1;
						end
						1:begin
							caddr_rd[6] <= 0;
							caddr_rd[0] <= 1;
							write_reg <= 	cdata_rd;			
							state_step <= state_step + 1;
						end
						2:begin
							caddr_rd[6] <= 1;
							caddr_rd[0] <= 0;
							write_reg <= (write_reg > cdata_rd) ? write_reg : cdata_rd;			
							state_step <= state_step + 1;
						end
						3:begin
							caddr_rd[6] <= 1;
							caddr_rd[0] <= 1;
							write_reg <= (write_reg > cdata_rd) ? write_reg : cdata_rd;			
							state_step <= state_step + 1;
						end
						4:begin
							
							crd <= 0;
							cwr <= 1;
							csel <= IMG_S ? 4 : 3;
							caddr_wr <= {2'b00,state_y[4:0],state_x[4:0]};
							cdata_wr <= (write_reg > cdata_rd) ? write_reg : cdata_rd;			

							state_step <= state_step + 1;
						end

						5:begin
							csel <= 5;
							if(IMG_S) caddr_wr <= {1'b0,state_y[4:0],state_x[4:0],1'b1};
							else caddr_wr <= {1'b0,state_y[4:0],state_x[4:0],1'b0};
							
							state_step <= state_step + 1;
						end

						6:begin
							cwr <= 0;
							if(state_y==31 && state_x==31)begin
								if(IMG_S)begin
									state <= IDLE;
									IMG_S <= 0;
								end else begin
									IMG_S <= 1;
								end
								state_x <= 0;
								state_y <= 0;
							end
							else if(state_x == 31)begin
								state_y <= state_y + 1;
								state_x <= 0;
							end else begin
								state_x <= state_x + 1;
							end
							state_step <= 0;

						end
					endcase
				end
				
				
				
				




				
				




				
				
				IDLE:begin
					if(ready)begin
						state <= LAYER_0;
					end

					cwr <= 0;
					IMG_S <= 0;
					me <= 0;
					write_reg <= 0;
					state_step <= 0;
					{state_y,state_x} 	<= 0;
					{state_dx,state_dy} <= 0;
				end






			endcase
		end
	end





endmodule











// File Name:
//  mulit_div.v
//
// Interface:
//  
//  Author:
//    CHONG-HAO XU
//
//  Descritpion:
//    select: multi : 0
//            div   : 1   
//    


module multi_div
#(
  parameter SIZE_A = 128,
  parameter SIZE_B = 64,
  parameter SIGNED = 0,
  parameter STEP_SIZE = 1 
)(
  input wire clk,reset,
  input wire en,
  input wire select,
  input wire [SIZE_A-1:0] a,
  input wire [SIZE_B-1:0] b,
  output reg [SIZE_A+SIZE_B-1:0] P,
  output reg div_zero,
  output reg Valid,
  output reg Busy
);

  parameter READ_IN       = 0,
            CALCULATE     = 1,
            PREPARE_DATA  = 2,
            DATA_OUT      = 3;


  reg [1:0] state;
  reg [9:0] state_counter;
  
  reg neg_signed;

  reg [SIZE_A-1:0] data_b;
  reg [SIZE_A+SIZE_B:0] r;  //a + 1'b0 + SIZE_B'b0

  always@(*)begin
    Valid <= (state == DATA_OUT) ? 1'b1:1'b0;
    Busy  <= (state == CALCULATE || state == PREPARE_DATA) ? 1'b1:1'b0;
  end


  always@(posedge clk or posedge reset)begin
    if(reset)begin
      state <= READ_IN;
      state_counter <= 0;
    end else begin
      case(state)
        
        
        READ_IN   :begin
          if(en)begin

            if(select && b==0)begin
              state <= DATA_OUT;
              div_zero <= 1;
            end else begin
              state <= CALCULATE;
              div_zero <= 0;
            end 
            state_counter <= 0;

          end  
        end
        
        
        
        
        CALCULATE :begin
          

          if(state_counter == (SIZE_A/STEP_SIZE)-1)begin
            state <= PREPARE_DATA;
            state_counter <= 0;
          end
          else begin
            state_counter <= state_counter + 1;
          end

        end
        
        

        PREPARE_DATA:begin
          state <= DATA_OUT;
          state_counter <= 0;
        end
        
        
        DATA_OUT  :begin
          state <= READ_IN;
          state_counter <= 0;
        end
        
        
        default begin
          state <= READ_IN;
          state_counter <= 0;
        end

      endcase
    end
  end



  reg [SIZE_A-1:0] na;
  reg [SIZE_B-1:0] nb;

  reg in_select;
  integer i;
  always@(posedge clk or posedge reset)begin
    if(reset)begin
      r = 0;
      data_b = 0;
			P = 0;
      neg_signed = 0;
    end else begin


      case(state)
        
        READ_IN   :begin
          if(en)begin
            
            if(SIGNED)begin
              neg_signed = a[SIZE_A-1] ^ b[SIZE_B-1];
              na = a[SIZE_A-1] ? -a:a;
              nb = b[SIZE_B-1] ? -b:b;
            end
            else begin
              na = a;
              nb = b;
            end

            r = {na,1'b0,{SIZE_B{1'b0}}};
            data_b = nb;
            in_select = select;

          end  
        end
        
        
        
        
        CALCULATE :begin

          for(i=0;i<STEP_SIZE;i=i+1)begin 
          	r = r[SIZE_A+SIZE_B] ? ((r<<1)+data_b) : (r<<1);
          end
        end

        PREPARE_DATA:begin
          
          P = r[SIZE_A+SIZE_B-1:0];
          
          if(neg_signed)begin
            P = -P;
          end
        end

      endcase
    end
  end




endmodule
