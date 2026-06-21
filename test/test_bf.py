import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

async def memory_bus_server(dut, memory_array, input_buffer, output_buffer):
    """
    Simulates the Memory/SPI backend.
    Watches the bus and responds to read/write requests with a 1-cycle latency.
    """
    dut.mem_ready.value = 0
    dut.mem_read_data.value = 0
    
    while True:
        await RisingEdge(dut.clk)
        
        read_en = dut.mem_read_en.value == 1
        write_en = dut.mem_write_en.value == 1
        
        if read_en or write_en:
            addr = int(dut.mem_addr.value)
            
            if read_en:
                if addr == 0xFFFF: # I/O Read mapped
                    if len(input_buffer) > 0:
                        dut.mem_read_data.value = input_buffer.pop(0)
                    else:
                        dut.mem_read_data.value = 0 # EOF / Empty
                else:
                    dut.mem_read_data.value = memory_array[addr]
                    
            elif write_en:
                if addr == 0xFFFF: # I/O Write mapped
                    output_buffer.append(int(dut.mem_write_data.value))
                else:
                    memory_array[addr] = int(dut.mem_write_data.value)
                    
            # Drive ready high to acknowledge
            dut.mem_ready.value = 1
            await RisingEdge(dut.clk)
            
            # De-assert ready
            dut.mem_ready.value = 0
            dut.mem_read_data.value = 0

async def reset_and_start_core(dut):
    dut.rst.value = 1
    dut.start.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)
    
    dut.start.value = 1
    await ClockCycles(dut.clk, 1)
    dut.start.value = 0

@cocotb.test()
async def test_bf_echo(dut):
    """Tests the ',' and '.' instructions."""
    dut._log.info("Starting Echo Test...")
    cocotb.start_soon(Clock(dut.clk, 10).start())
    
    # Program: Read input, output it (',.')
    program = ",."
    memory = bytearray(65536)
    for i, char in enumerate(program):
        memory[i] = ord(char)
        
    in_buf = [ord('Z')] # Provide 'Z' to be read
    out_buf = []
    
    cocotb.start_soon(memory_bus_server(dut, memory, in_buf, out_buf))
    await reset_and_start_core(dut)
    
    # Wait for the program to output something
    for _ in range(500):
        await RisingEdge(dut.clk)
        if len(out_buf) > 0:
            break
            
    assert len(out_buf) > 0, "Core did not produce any output."
    assert out_buf[0] == ord('Z'), f"Expected 'Z', got {chr(out_buf[0])}"
    dut._log.info("Echo Test Passed!")

@cocotb.test()
async def test_bf_loops_and_math(dut):
    """Tests pointers, addition, subtraction, and looping ([ ] + - < >)."""
    dut._log.info("Starting Loops and Math Test...")
    cocotb.start_soon(Clock(dut.clk, 10).start())
    
    # Program: 5 * 13 = 65 ('A')
    # +++++ [ > +++++++++++++ < - ] > .
    program = "+++++[>+++++++++++++<-]>."
    memory = bytearray(65536)
    for i, char in enumerate(program):
        memory[i] = ord(char)
        
    in_buf = []
    out_buf = []
    
    cocotb.start_soon(memory_bus_server(dut, memory, in_buf, out_buf))
    await reset_and_start_core(dut)
    
    # Wait for output
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if len(out_buf) > 0:
            break
            
    assert len(out_buf) > 0, "Core did not produce any output."
    assert out_buf[0] == ord('A'), f"Expected 'A' (65), got {out_buf[0]}"
    dut._log.info("Loops and Math Test Passed!")