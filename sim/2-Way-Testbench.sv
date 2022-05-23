
`timescale 1ns/1ns
module cache_controller_tb;

reg clk =1'b0;;
reg rst_n;
reg [31:0] cpu_req_addr;
reg [127:0] cpu_req_datain;
wire [31:0] cpu_req_dataout;
reg cpu_req_rw; //1=write, 0=read
reg cpu_req_valid;

wire [31:0] mem_req_addr;
reg [127:0] mem_req_datain;
wire [127:0] mem_req_dataout;
wire mem_req_rw;
wire mem_req_valid;
reg mem_req_ready;

int state_mode;


cache_controller dut (
    .clk	       (clk),
    .rst_n             (rst_n),
    .cpu_req_addr      (cpu_req_addr),  
    .cpu_req_datain    (cpu_req_datain),
    .cpu_req_dataout   (cpu_req_dataout),
    .cpu_req_rw        (cpu_req_rw),
    .cpu_req_valid     (cpu_req_valid),
    .cache_ready       (cache_ready),   
    .mem_req_addr      (mem_req_addr),  
    .mem_req_datain    (mem_req_datain),
    .mem_req_dataout   (mem_req_dataout),
    .mem_req_rw        (mem_req_rw),
    .mem_req_valid     (mem_req_valid),
    .mem_req_ready     (mem_req_ready),
    .state_mode        (state_mode)
	);

reg [127:0] mem [2**16];
int fd_w;
	
always #5 clk = ~clk;

task reset_values ();
begin
  clk = 1'b1; rst_n = 1'b0;
  cpu_req_addr = 32'd0; cpu_req_datain = 128'd0; cpu_req_rw = 1'b0; cpu_req_valid = 1'b0; 
  mem_req_datain = 128'd0; mem_req_ready = 1'b1;
@(posedge clk) 
@(posedge clk) 
 rst_n = 1'b1;
end
endtask

task cache_write (input [31:0]addr, input [127:0]data);
begin
wait(cache_ready);
	cpu_req_addr = addr; 
	cpu_req_rw = 1'b1; 
	cpu_req_valid = 1'b1; 
	cpu_req_datain = data; 

 @(posedge clk) 
	cpu_req_addr = 32'd0; 
	cpu_req_rw = 1'b0; 
	cpu_req_valid = 1'b0; 
	cpu_req_datain = 128'd0;  
        $display (" Write data - tag=%0d(%20b) index=%0d(%0b) offset=%0d(%0b)  Addr=%0d(h%6h)(b%0b)", addr[31:13], addr[31:13], addr[12:4], addr[12:4], addr[3:0], addr[3:0], addr,addr,addr);	
@(posedge clk) ;

end
endtask

task cache_read (input [31:0]addr);
begin

wait(cache_ready); 

	cpu_req_addr = addr; 
	cpu_req_rw = 1'b0; 
	cpu_req_valid = 1'b1;  

@(posedge clk) 
	cpu_req_addr = 32'd0; 
	cpu_req_rw = 1'b0; 
	cpu_req_valid = 1'b0; 
@(negedge clk)
 if (state_mode == 1)  begin 
  	 $display (" Read Hit - tag=%0d(%20b) index=%0d(%0b) offset=%0d(%0b)  Addr=%0d(h%6h)(b%0b)",  addr[31:13], addr[31:13], addr[12:4], addr[12:4], addr[3:0], addr[3:0], addr,addr,addr);	

@(posedge clk); 
@(posedge clk); 

end

else if (state_mode == 2 || state_mode == 3) begin   	
@(negedge mem_req_valid)

if (state_mode == 2) begin //$display ("[%0t] - read clean  ",$time);
 $display (" Read Clean - tag=%0d(%20b) index=%0d(%0b) offset=%0d(%0b)  Addr=%0d(h%6h)(b%0b)", addr[31:13], addr[31:13], addr[12:4], addr[12:4], addr[3:0], addr[3:0], addr,addr,addr);	

	mem_req_ready = 1'b0;
  	@(posedge clk) 
	mem_req_datain <= mem[mem_req_addr];  
	mem_req_ready = 1'b1;
	@(posedge clk); 
end 
else if (state_mode == 3) begin //$display ("[%0t] - read dirty  ",$time);
 $display (" Read Dirty - tag=%0d(%20b) index=%0d(%0b) offset=%0d(%0b)  Addr=%0d(h%6h)(b%0b)", addr[31:13], addr[31:13], addr[12:4], addr[12:4], addr[3:0], addr[3:0], addr,addr,addr);	

	mem_req_ready = 1'b0;  
  @(posedge clk)
	mem[mem_req_addr] <= mem_req_dataout;
	mem_req_ready = 1'b1;      
		@(negedge mem_req_valid) 
		mem_req_ready = 1'b0;
					
  	@(posedge clk)
	 	mem_req_datain <= mem[mem_req_addr];
		@(posedge clk);
		mem_req_ready = 1'b1;
		@(posedge clk);

end
@(posedge clk);
end

end 
endtask


initial begin
$readmemh("initial_main_memory.mem", mem);
#5
  reset_values();

cache_write (32'h6B00 ,128'h663322);  	
 cache_write  (32'hEB00 ,128'h444444);	 		
 //cache_write  (32'hEB00 ,128'h444444);
  cache_read  (32'h6B00); //read hit	    		
  cache_read  (32'hEB00); //read hit
	cache_read  (32'h2B00); //read Dirty  
	cache_read  (32'h6B00); //read dirty  
  cache_read  (32'hAB00); //read clean
  cache_read  (32'h2C00);  //read clean 
  //cache_read  (32'hEC00); 
   // cache_read  (32'h6C00); 
	//cache_read  (32'hAC00); 


#50
fd_w = $fopen ("Result-main_memory.mem", "w"); 	// Open a new file in write mode and store file descriptor in fd_w
for (int i = 0; i < $size(mem); i++)
	$fwrite (fd_w,"%5d(%4h)	%32h\n",i,i, mem[i] );
#20 $fclose(fd_w);

end //initial end
endmodule










