import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

async def memory_bus_sim(dut, memory_array, input_buffer, output_buffer):
    """
    Simulates the SPI Memory.
    """
    dut.mem_resp_val.value = 0
    dut.mem_read_data.value = 0
    
    while True:
        await RisingEdge(dut.clk)
        
        read_en = dut.mem_read_en.value == 1
        write_en = dut.mem_write_en.value == 1
        
        if read_en or write_en:
            addr = int(dut.mem_addr.value)
            
            if read_en:
                if addr == 0xFFFF: # I/O address
                    if len(input_buffer) > 0:
                        dut.mem_read_data.value = input_buffer.pop(0)
                    else:
                        dut.mem_read_data.value = 0 # Empty
                else:
                    dut.mem_read_data.value = memory_array[addr]
                    
            elif write_en:
                if addr == 0xFFFF:
                    output_buffer.append(int(dut.mem_write_data.value))
                else:
                    memory_array[addr] = int(dut.mem_write_data.value)
                    
            # Acknowledgement
            dut.mem_resp_val.value = 1
            await RisingEdge(dut.clk)
            dut.mem_resp_val.value = 0
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

async def setup_test(dut, program_string, inputs=None):
    """Helper to initialize core, memory server, and inject the program."""
    cocotb.start_soon(Clock(dut.clk, 10).start())
    
    memory = bytearray(65536)
    for i, char in enumerate(program_string):
        memory[i] = ord(char)
        
    in_buf = inputs if inputs else []
    out_buf = []
    
    # Start server
    task = cocotb.start_soon(memory_bus_sim(dut, memory, in_buf, out_buf))
    await reset_and_start_core(dut)
    
    return memory, out_buf, task

# ==============================================================================
# UNIT TESTS
# ==============================================================================

@cocotb.test()
async def test_pointers(dut):
    """Unit Test: > and < instructions"""
    # Move right 2, left 1. DP starts at 0x8000. Should end at 0x8001
    memory, out_buf, task = await setup_test(dut, ">><")
    await ClockCycles(dut.clk, 40)
    
    assert int(dut.uut.DP.value) == 0x8001
    task.kill()

@cocotb.test()
async def test_math(dut):
    """Unit Test: + and - instructions"""
    # Add 5, Sub 2. Cell should equal 3.
    memory, out_buf, task = await setup_test(dut, "+++++--")
    await ClockCycles(dut.clk, 60)
    assert memory[0x8000] == 3
    task.kill()

@cocotb.test()
async def test_loop_execute(dut):
    """Unit Test: Taking a loop and exiting it ([ ]) via Stack"""
    # Add 3, then loop to subtract 1 until 0. Write 99 to next cell to prove exit.
    memory, out_buf, task = await setup_test(dut, "+++[-]>+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    await ClockCycles(dut.clk, 1000)
    assert memory[0x8000] == 0 
    assert memory[0x8001] == 99 
    task.kill()

@cocotb.test()
async def test_loop_skip(dut):
    """Unit Test: Scanning Forward"""
    # Start at 0, hit loop (should skip scanned instructions), add 5.
    memory, out_buf, task = await setup_test(dut, "[++++++++++]+++++")
    await ClockCycles(dut.clk, 100)
    assert memory[0x8000] == 5 
    task.kill()

@cocotb.test()
async def test_deep_loop_overflow(dut):
    """Unit Test: Bracket Stack Overflow"""
    # Overflows a 4 entry bracket stack.
    # Math logic: 2 * 2 * 2 * 2 * 2 = 32. 
    program = "++ [ > ++ [ > ++ [ > ++ [ > ++ [ > + < - ] < - ] < - ] < - ] < - ]"
    
    memory, out_buf, task = await setup_test(dut, program)
    
    await ClockCycles(dut.clk, 15000)
    
    # Cell 5 should have 32 in it
    assert memory[0x8005] == 32, f"Expected 32 at 0x8005, got {memory[0x8005]}"
    # Cell 0-4 should all be 0
    assert memory[0x8001] == 0
    assert memory[0x8002] == 0
    assert memory[0x8003] == 0
    assert memory[0x8004] == 0
    task.kill()

# ==============================================================================
# Integration Tests
# ==============================================================================

@cocotb.test()
async def test_bf_echo(dut):
    """Tests the ',' and '.' instructions."""
    memory, out_buf, task = await setup_test(dut, ",.", inputs=[ord('Z')])
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        if len(out_buf) > 0:
            break
            
    assert len(out_buf) > 0, "Core did not produce any output."
    assert out_buf[0] == ord('Z'), f"Expected 'Z', got {chr(out_buf[0])}"
    dut._log.info("Echo Test Passed")
    task.kill()

@cocotb.test()
async def test_bf_loops_and_math(dut):
    """Tests pointers, addition, subtraction, and looping ([ ] + - < >)."""
    # Program: 5 * 13 = 65 ('A')
    memory, out_buf, task = await setup_test(dut, "+++++[>+++++++++++++<-]>.")
    
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if len(out_buf) > 0:
            break
            
    assert len(out_buf) > 0, "Core did not produce any output."
    assert out_buf[0] == ord('A'), f"Expected 'A' (65), got {out_buf[0]}"
    dut._log.info("Loops and Math Test Passed")
    task.kill()