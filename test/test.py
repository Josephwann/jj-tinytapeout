# test.py -- full-chip integration tests (run by the TT CI). Preload a BF program
# into the mock SPI RAM, run the real top module, and check its I/O.
# uio: [5]=out_valid (strobe on '.'), [6]=in_valid (driven), [7]=in_ack (strobe on ',').

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


def load_program(dut, program):
    for i, ch in enumerate(program):
        dut.ram.mem[i].value = ord(ch)


async def output_monitor(dut, out_buf):
    while True:
        await RisingEdge(dut.clk)
        if (int(dut.uio_out.value) >> 5) & 1:        # out_valid
            out_buf.append(int(dut.uo_out.value))


async def input_driver(dut, in_bytes):
    dut.r_in_valid.value = 0
    for b in in_bytes:
        dut.ui_in.value = b
        dut.r_in_valid.value = 1
        while True:                                  # hold until in_ack
            await RisingEdge(dut.clk)
            if (int(dut.uio_out.value) >> 7) & 1:
                break
        dut.r_in_valid.value = 0
        await RisingEdge(dut.clk)


async def run_program(dut, program, inputs=None):
    """Reset, preload, start, and return output bytes once the first appears."""
    inputs = inputs or []
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.r_start.value = 0
    dut.r_in_valid.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    clear_mem(dut)
    load_program(dut, program)
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 3)

    out_buf = []
    cocotb.start_soon(output_monitor(dut, out_buf))
    if inputs:
        cocotb.start_soon(input_driver(dut, inputs))

    dut.r_start.value = 1
    await ClockCycles(dut.clk, 2)
    dut.r_start.value = 0

    for _ in range(RUN_TIMEOUT):
        await RisingEdge(dut.clk)
        if out_buf:
            break
    return out_buf


@cocotb.test()
async def test_arith(dut):
    """'+++++.' -> 5. Read-modify-write to data RAM over SPI."""
    out = await run_program(dut, "+++++.")
    assert out and out[0] == 5, f"expected 5, got {out}"


@cocotb.test()
async def test_echo(dut):
    """',.' with input 'Z' -> 'Z'. Input + output handshakes."""
    out = await run_program(dut, ",.", inputs=[ord('Z')])
    assert out and out[0] == ord('Z'), f"expected 90, got {out}"


@cocotb.test()
async def test_loop(dut):
    """'++[>+<-]>.' -> 2. Brackets/loops + pointer moves over SPI."""
    out = await run_program(dut, "++[>+<-]>.")
    assert out and out[0] == 2, f"expected 2, got {out}"
