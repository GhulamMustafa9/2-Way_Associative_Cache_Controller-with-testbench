
# Cache Controller SystemVerilog Design 

The hardware description language we are using in this section is SystemVerilog.
 
 The tag field is 18 bits wide and the index field is 10 bits wide, while a 2-bit field (bits 3–2) is used to index the block and
select the word from the block. The rest of the type declaration is found in the following figure.


## Specifications:
•	Direct Mapped Cache

•	Write-back scheme

•	Block size = 4 words,  Offset is 4 bits  (block-offset=2 bits, byte-offset=2 bits)

•	Cache size = 1024 blocks / Lines (Cache index is 10 bits)

•	Block size is 4 words (16 bytes or 128 bits)

•	32-byte addresses [ tag=18 bits,  Index=10 bits, Block offset=4 bits]

•	The cache includes a valid bit and dirty bit per block

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

![cache_structure](https://user-images.githubusercontent.com/105862227/169352909-12ac2c86-3815-4c48-a42b-6fb282712a45.png)

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
![phpoMLHDa](https://user-images.githubusercontent.com/105862227/169352622-b0c9ccbb-5cc5-489d-95ef-611379397ea2.png)
