
# Cache Controller SystemVerilog Design 

The hardware description language we are using in this section is SystemVerilog.
 
 The tag field is 18 bits wide and the index field is 10 bits wide, while a 2-bit field (bits 3–2) is used to index the block and
select the word from the block. The rest of the type declaration is found in the following figure.


## Specifications:
•	2-Way-Associative  Cache Controller

•	Write-back scheme

•	No. of Sets = 512  -  (09 bits)

•	Block size = 4 words,  Offset is 4 bits  (word-offset=2 bits, byte-offset=2 bits)

•	32-byte addresses [ tag=19 bits,  Index=09 bits, Block offset=4 bits]

•	The cache includes a LRU bit, valid bit and dirty bit per block

## Processor to the cache signals 
	1-bit Read or Write signal

	1-bit Valid signal, saying whether there is a cache operation or not

	32-bit address

	32-bit data from processor to cache

	32-bit data from cache to processor

	1-bit Ready signal, saying the cache operation is complete

## Cache to the main memory signals 
	1-bit Read or Write signal

	1-bit Valid signal, saying whether there is a memory operation or not

	32-bit address

	128-bit data from cache to memory

	128-bit data from memory to cache

	1-bit Ready signal, saying the memory operation is complete

![3-s2 0-B9780128200643000088-f08-09-9780128200643](https://user-images.githubusercontent.com/105862227/169900725-14d250a1-0c17-4221-8d16-60f40b21ba90.jpg)

## FSM Logic:

There are 4 states for the FSM:

•	IDLE: 

```bash
  Wait in this state until a valid CPU request is received.
```

•	COMPARE_TAG: 

```bash
  There are  following possibilities
Read hit?	
        Then cache is ready with read data. Set tag and valid bit.
Write hit? 	
        Then write data is written. Set tag, valid bit and dirty bit.
Read miss?      
        Now check for dirty bit.
                    Clean? 	Goto ALLOCATE
                    Dirty? 	Goto WRITE_BACK

```

•	ALLOCATE:  

```bash
  The new block is fetched from memory. We remain in this state waiting for the Ready signal from memory. When the memory read is complete, the FSM goes to the Compare Tag state. Although we could have gone to a new state to complete the operation instead of reusing the Compare Tag state, there is a good deal of overlap, including the update of the appropriate word in the block if the access was a write.
```

•	WRITE_BACK: 

```bash
  This state writes the 128-bit block to memory using the address composed from the tag and cache index. We remain in this state waiting for the Ready signal from memory. When the memory write is complete, the FSM goes to the Allocate state.
FSM goes to the Allocate state.

```
![phpoMLHDa - Copy](https://user-images.githubusercontent.com/105862227/169900902-76245071-4477-481a-a67d-15b0263ec28d.png)
