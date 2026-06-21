# test_top.py -- full-chip integration tests. Preload a BF program into the mock
# SPI RAM, run the real top module, and check its I/O.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

RUN_TIMEOUT = 60000   # max cycles to wait for output


def clear_mem(dut):
    # Mock RAM persists across tests, so zero the windows each program uses.
    for i in range(256):
        dut.ram.mem[i].value = 0
    for i in range(0x8000, 0x8100):
        dut.ram.mem[i].value = 0
    
    # Clear the memory-mapped I/O address as well
    dut.ram.mem[0xFFFF].value = 0


def load_program(dut, program):
    for i, ch in enumerate(program):
        dut.ram.mem[i].value = ord(ch)


async def output_monitor(dut, out_buf):
    while True:
        await RisingEdge(dut.ram.cs_n)  # Wait for end of SPI transaction
        
        try:
            cmd = int(dut.ram.cmd.value)
            addr = int(dut.ram.addr.value)
        except ValueError:
            # Handles 'x' or 'z' states before initialization
            continue

        # If it was a WRITE (0x02) to the IO address
        if cmd == 2 and addr == 0xFFFF:
            out_buf.append(int(dut.ram.mem[0xFFFF].value))


async def input_driver(dut, in_bytes):
    if not in_bytes:
        return

    # Pre-load the first byte so it's ready for the first read
    dut.ram.mem[0xFFFF].value = in_bytes[0]
    idx = 1

    while True:
        await RisingEdge(dut.ram.cs_n) # Wait for end of SPI transaction
        
        try:
            cmd = int(dut.ram.cmd.value)
            addr = int(dut.ram.addr.value)
        except ValueError:
            continue

        # If it was a READ (0x03) from the IO address, prep the next byte
        if cmd == 3 and addr == 0xFFFF:
            if idx < len(in_bytes):
                dut.ram.mem[0xFFFF].value = in_bytes[idx]
                idx += 1


async def run_program(dut, program, inputs=None):
    """Reset, preload, start, and return output bytes once the first appears."""
    inputs = inputs or []
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.r_start.value = 0
    dut.r_in_valid.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    clear_mem(dut)
    load_program(dut, program)
    await ClockCycles(dut.clk, 2)
    
    out_buf = []
    cocotb.start_soon(output_monitor(dut, out_buf))
    if inputs:
        cocotb.start_soon(input_driver(dut, inputs))
        
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 3)

    dut.r_start.value = 1
    await ClockCycles(dut.clk, 2)
    dut.r_start.value = 0

    for _ in range(RUN_TIMEOUT):
        await RisingEdge(dut.clk)
        if out_buf:
            break
    return out_buf


@cocotb.test()
async def test_top_arith(dut):
    """'+++++.' -> 5. Read-modify-write to data RAM over SPI."""
    out = await run_program(dut, "+++++.")
    assert out and out[0] == 5, f"expected 5, got {out}"


@cocotb.test()
async def test_top_echo(dut):
    """',.' with input 'Z' -> 'Z'. Input + output handshakes."""
    out = await run_program(dut, ",.", inputs=[ord('Z')])
    assert out and out[0] == ord('Z'), f"expected 90, got {out}"


@cocotb.test()
async def test_top_loop(dut):
    """'++[>+<-]>.' -> 2. Brackets/loops + pointer moves over SPI."""
    out = await run_program(dut, "++[>+<-]>.")
    assert out and out[0] == 2, f"expected 2, got {out}"