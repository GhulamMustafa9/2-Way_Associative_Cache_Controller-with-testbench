//////////////////////////////////////////////////////////////////////////////////
// Create Date: 20.05.2022
// Project Name: 2-Way Associative Cache Controller
// Tool Versions: Questa Sim -64 10.7c     
// Revision 1.5.9 -
//////////////////////////////////////////////////////////////////////////////////
/*
Controller Specifications:
	> 2-Way Associative Cache Controller
	> Write-back scheme
	> No. of Sets = 512 (Cache Set-index is 09 bits)
	> Block size = 4 words, Offset is 4 bits (block-offset=2 bits, byte-offset=2 bits)
	> 32-byte addresses [ tag=18 bits, Index=10 bits, Block offset=4 bits]
	> The cache includes a LRU bit, valid bit and dirty bit per block	
*/

`timescale 1ns/1ns
module cache_controller (
	clk,
	rst_n,
	cpu_req_addr,  //CPU signals
	cpu_req_datain,
	cpu_req_dataout,
	cpu_req_rw,
	cpu_req_valid,
	cache_ready,   //Cache ready
	mem_req_addr,  //Main memory signals	
	mem_req_datain,
	mem_req_dataout,
	mem_req_rw,
	mem_req_valid,
	mem_req_ready,
        state_mode
);
output int state_mode;
//bit state_mode_YN;

parameter IDLE        = 2'b00;
parameter COMPARE_TAG = 2'b01;
parameter ALLOCATE    = 2'b10;
parameter WRITE_BACK  = 2'b11;

input clk;
input rst_n;

//CPU request to cache controller
input [31:0] cpu_req_addr;
input [127:0] cpu_req_datain;
output [31:0] cpu_req_dataout;
input cpu_req_rw; //1=write, 0=read
input cpu_req_valid;

//Main memory request from cache controller
output [31:0] mem_req_addr;
input [127:0] mem_req_datain;
output [31:0] mem_req_dataout;
output mem_req_rw;
output mem_req_valid;
input mem_req_ready;

//Cache ready
output cache_ready;

//Cache consists of tag memory and data memory
//Tag memory = LRU + valid bit + dirty bit + tag
reg [21:0] tag_mem [0:511];
reg [21:0] tag_mem1 [0:511];
//Data memory holds the actual data in cache
reg [127:0] data_mem [0:511];
reg [127:0] data_mem1 [0:511];

reg [1:0] present_state, next_state;
reg [31:0] cpu_req_dataout, next_cpu_req_dataout;
reg [31:0] cache_read_data; 
reg cache_ready, next_cache_ready;
reg [31:0] mem_req_addr, next_mem_req_addr;
reg mem_req_rw, next_mem_req_rw;
reg mem_req_valid, next_mem_req_valid;
reg [127:0] mem_req_dataout, next_mem_req_dataout;
reg write_datamem_mem; //write operation from memory
reg write_datamem_cpu; //write operation from cpu
reg tagmem_enable;
reg valid_bit, dirty_bit;

reg [31:0] cpu_req_addr_reg, next_cpu_req_addr_reg;
reg [127:0] cpu_req_datain_reg, next_cpu_req_datain_reg;
reg cpu_req_rw_reg, next_cpu_req_rw_reg;


wire [21:0] tag_mem_entry1;
wire [127:0] data_mem_entry1;
reg [31:0] cache_read_data1; 

wire [18:0] cpu_addr_tag;
wire [8:0] cpu_addr_index;
wire [1:0] cpu_addr_blk_offset;
wire [1:0] cpu_addr_byte_offset;
wire [21:0] tag_mem_entry;    
wire [127:0] data_mem_entry;
wire hit, hit1;
//CPU Address = tag + index + block offset + byte offset
assign cpu_addr_tag         = cpu_req_addr_reg[31:13];
assign cpu_addr_index       = cpu_req_addr_reg[12:4];
assign cpu_addr_blk_offset  = cpu_req_addr_reg[3:2];
assign cpu_addr_byte_offset = cpu_req_addr_reg[1:0];

assign tag_mem_entry  = tag_mem[cpu_addr_index];
assign data_mem_entry = data_mem[cpu_addr_index];
assign hit = tag_mem_entry[20] && (cpu_addr_tag == tag_mem_entry[18:0]);

assign tag_mem_entry1  = tag_mem1[cpu_addr_index];
assign data_mem_entry1 = data_mem1[cpu_addr_index];
assign hit1 = tag_mem_entry1[20] && (cpu_addr_tag == tag_mem_entry1[18:0]);

int fd_w;
initial begin

$readmemh("initial_tag_memory.mem", tag_mem);	//load initial values for tag memory
$readmemh("initial_tag_memory.mem", tag_mem1);
#999
fd_w = $fopen ("Result-Cache_memory.mem", "w"); 	// Open a new file in write mode and store file descriptor in fd_w
for (int i = 0; i < $size(tag_mem); i++)
	$fwrite (fd_w,"%5d(%4h)	%22b %32h | %22b %32h\n",i,i, tag_mem[i] , data_mem[i], tag_mem1[i] , data_mem1[i]);
#10 $fclose(fd_w);

end

initial begin
$readmemh("initial_data_memory.mem", data_mem);	//load initial values for data memory
$readmemh("initial_data_memory.mem", data_mem1);
end

always @ (posedge clk or negedge rst_n)
begin
  if(!rst_n)
  begin
	tag_mem[cpu_addr_index]  <= tag_mem[cpu_addr_index];
	data_mem[cpu_addr_index] <= data_mem[cpu_addr_index];
	present_state   	<= IDLE;
	cpu_req_dataout 	<= 32'd0;
	cache_ready     	<= 1'b0;
	mem_req_addr    	<= 32'd0;
	mem_req_rw      	<= 1'b0;
	mem_req_valid   	<= 1'b0;
	mem_req_dataout 	<= 128'd0;
	cpu_req_addr_reg	<= 1'b0;
	cpu_req_datain_reg  	<= 128'd0;
	cpu_req_rw_reg  	<= 1'b0;
  end
  else
  begin

	if(write_datamem_mem) begin
				if(!tag_mem[cpu_addr_index][21])  begin	data_mem[cpu_addr_index] <=   mem_req_datain;  end
				else  		begin			data_mem1[cpu_addr_index] <=   mem_req_datain; end
				end
	else begin
					if(write_datamem_cpu) begin
							if(!tag_mem[cpu_addr_index][21]) begin data_mem[cpu_addr_index] <=   cpu_req_datain_reg; end
							else  begin data_mem1[cpu_addr_index] <=   cpu_req_datain_reg;end
								end
					else begin
							 data_mem[cpu_addr_index]  <=   data_mem[cpu_addr_index] ;
							  data_mem1[cpu_addr_index]  <=   data_mem1[cpu_addr_index] ;  
						end
		end	

	if(tagmem_enable) begin
				if(present_state==3);				
				else   begin
				if(!tag_mem[cpu_addr_index][21]) begin tag_mem[cpu_addr_index]  <= {1'b1,valid_bit,dirty_bit,cpu_addr_tag}; tag_mem1[cpu_addr_index][21] <= 1'b0 ;  end
				else begin tag_mem1[cpu_addr_index]  <= {1'b1,valid_bit,dirty_bit,cpu_addr_tag}; tag_mem[cpu_addr_index][21] <= 1'b0 ;  end
						end
		end
	else begin
				tag_mem[cpu_addr_index]  <=  tag_mem[cpu_addr_index]; 
				tag_mem1[cpu_addr_index]  <= tag_mem1[cpu_addr_index] ;
		end
		
	present_state   	<= next_state;
	cpu_req_dataout 	<= next_cpu_req_dataout;
	cache_ready     	<= next_cache_ready;
	mem_req_addr    	<= next_mem_req_addr;
	mem_req_rw      	<= next_mem_req_rw;
	mem_req_valid   	<= next_mem_req_valid;
	mem_req_dataout 	<= next_mem_req_dataout;
	cpu_req_addr_reg	<= next_cpu_req_addr_reg;
	cpu_req_datain_reg  	<= next_cpu_req_datain_reg;
	cpu_req_rw_reg  	<= next_cpu_req_rw_reg;

  end
 end
 
 
always @ (*)
begin
write_datamem_mem    = 1'b0;
write_datamem_cpu    = 1'b0;
valid_bit            = 1'b0;
dirty_bit            = 1'b0;
tagmem_enable        = 1'b0;
next_state           = present_state;
next_cpu_req_dataout = cpu_req_dataout;
next_cache_ready     = 1'b1;
next_mem_req_addr    = mem_req_addr;
next_mem_req_rw      = mem_req_rw;
next_mem_req_valid   = mem_req_valid;
next_mem_req_dataout = mem_req_dataout;
next_cpu_req_addr_reg  = cpu_req_addr_reg;
next_cpu_req_datain_reg  = cpu_req_datain_reg;
next_cpu_req_rw_reg  = cpu_req_rw_reg;

case (cpu_addr_blk_offset)
	2'b00: cache_read_data   = data_mem_entry[31:0];
	2'b01: cache_read_data   = data_mem_entry[63:32];
	2'b10: cache_read_data   = data_mem_entry[95:64];
	2'b11: cache_read_data   = data_mem_entry[127:96];
	default: cache_read_data = 32'd0;
endcase

case (cpu_addr_blk_offset)
	2'b00: cache_read_data1   = data_mem_entry1[31:0];
	2'b01: cache_read_data1   = data_mem_entry1[63:32];
	2'b10: cache_read_data1   = data_mem_entry1[95:64];
	2'b11: cache_read_data1   = data_mem_entry1[127:96];
	default: cache_read_data1 = 32'd0;
endcase

case(present_state)
  IDLE:
  begin
    if (cpu_req_valid)
    begin
    next_cpu_req_addr_reg  = cpu_req_addr;
    next_cpu_req_datain_reg  = cpu_req_datain;
    next_cpu_req_rw_reg  = cpu_req_rw;
    next_cache_ready = 1'b0;  
    next_state = COMPARE_TAG;	
	state_mode = 0;  
    end
    else
    next_state = present_state;
  end
  
  COMPARE_TAG:
  begin
    if (hit & !cpu_req_rw_reg) //read hit
    begin
    next_cpu_req_dataout = cache_read_data;
    next_state = IDLE;
	if (state_mode == 0) state_mode =1;	
	if(!tag_mem_entry[21]) begin tag_mem[cpu_addr_index][21] <= 1'b1; tag_mem1[cpu_addr_index][21] <= 1'b0;  end
    end
	
	else if (hit1 & !cpu_req_rw_reg) //read hit
    begin
    next_cpu_req_dataout = cache_read_data1;
    next_state = IDLE;
	if (state_mode == 0) state_mode =1;
	if(!tag_mem_entry1[21]) begin tag_mem1[cpu_addr_index][21] <= 1'b1; tag_mem[cpu_addr_index][21] <= 1'b0;  end
    end
	
    else if (!cpu_req_rw_reg) //read miss
    begin
    next_cache_ready = 1'b0;  
	  
	if (!tag_mem_entry[21] && tag_mem_entry[19]) //Dirty, read new block from memory
	begin
	  next_mem_req_addr = {tag_mem_entry[18:0],cpu_addr_index,4'd0}; //old tag, current index, offset 00
	  next_mem_req_dataout = data_mem_entry;
	  next_mem_req_rw = 1'b1;
	  next_mem_req_valid = 1'b1;
	  next_state = WRITE_BACK;
	  if (state_mode == 0) state_mode =3;
	  end  
	else if (!tag_mem_entry1[21] && tag_mem_entry1[19]) //Dirty, read new block from memory
	  begin
	  next_mem_req_addr = {tag_mem_entry1[18:0],cpu_addr_index,4'd0}; //old tag, current index, offset 00
	  next_mem_req_dataout = data_mem_entry1;
	  next_mem_req_rw = 1'b1;
	  next_mem_req_valid = 1'b1;
	  next_state = WRITE_BACK;
		if (state_mode == 0) state_mode =3;
	  end
	else 					  //Clean, write cache block to old memory address, then read this block with curr addr
	  begin
	  next_mem_req_addr = cpu_req_addr_reg;
	  next_mem_req_rw = 1'b0;
	  next_mem_req_valid = 1'b1;
	  next_state = ALLOCATE;
		if (state_mode == 0) state_mode =2;
	  end   
	
   end
   
    else //write operation
    begin
    valid_bit = 1'b1;
    dirty_bit = 1'b1;
    tagmem_enable = 1'b1;
    write_datamem_cpu = 1'b1;
    next_state = IDLE;
if (state_mode == 0) state_mode =4;

  end
  end
  
  ALLOCATE:
  begin
  next_mem_req_valid = 1'b0;

  next_cache_ready = 1'b0;  
	if(!mem_req_valid && mem_req_ready)	//wait for memory to be ready with read data
	begin
	write_datamem_mem = 1'b1; //write to data mem
    	valid_bit = 1'b1;	//make the tag mem entry valid
    	dirty_bit = 1'b0;
    	tagmem_enable = 1'b1;
	next_state = COMPARE_TAG;
	end
	else
	begin
	next_state = present_state;
	end
  end
  
  WRITE_BACK:
  begin
  next_cache_ready = 1'b0;  
  next_mem_req_valid = 1'b0;

	if(!mem_req_valid && mem_req_ready)  //write is done, now read
	begin
	valid_bit = 1'b1;
	dirty_bit = 1'b0;
	tagmem_enable = 1'b1;
	next_mem_req_addr = cpu_req_addr_reg;
	next_mem_req_rw = 1'b0;
	next_mem_req_valid = 1'b1;
	next_state = ALLOCATE;
	end
	else
	begin
	next_state = present_state;
	end
  end

endcase
end
endmodule
