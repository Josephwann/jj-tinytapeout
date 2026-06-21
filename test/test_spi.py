# test_spi.py -- cocotb tests for the SPI subsystem. Drives the BF memory bus
# the way bf.v does, against the 23LC512 model over real SPI.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

XFER_TIMEOUT = 2000   # cycles; one transaction is ~270 for CLK_DIV=4


async def reset_dut(dut):
    dut.rst.value = 1
    dut.mem_addr.value = 0
    dut.mem_write_data.value = 0
    dut.mem_read_en.value = 0
    dut.mem_write_en.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 2)


async def mem_write(dut, addr, data):
    dut.mem_addr.value = addr
    dut.mem_write_data.value = data
    dut.mem_write_en.value = 1
    dut.mem_read_en.value = 0
    for _ in range(XFER_TIMEOUT):
        await RisingEdge(dut.clk)
        if dut.mem_ready.value == 1:
            break
    else:
        raise TimeoutError(f"write to 0x{addr:04X} never acked")
    dut.mem_write_en.value = 0
    await RisingEdge(dut.clk)


async def mem_read(dut, addr):
    dut.mem_addr.value = addr
    dut.mem_read_en.value = 1
    dut.mem_write_en.value = 0
    data = None
    for _ in range(XFER_TIMEOUT):
        await RisingEdge(dut.clk)
        if dut.mem_ready.value == 1:
            data = int(dut.mem_read_data.value)
            break
    if data is None:
        raise TimeoutError(f"read from 0x{addr:04X} never acked")
    dut.mem_read_en.value = 0
    await RisingEdge(dut.clk)
    return data


@cocotb.test()
async def test_spi_write_then_read(dut):
    """Write a byte over SPI, read it back, compare."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)
    await mem_write(dut, 0x1234, 0xA5)
    got = await mem_read(dut, 0x1234)
    assert got == 0xA5, f"round-trip failed: read 0x{got:02X}"


@cocotb.test()
async def test_spi_multiple_cells(dut):
    """Independent cells across the 16-bit address space must not clobber."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)
    cells = {0x0000: 0x11, 0x0001: 0x22, 0x7FFF: 0x33, 0x8000: 0x44, 0xBEEF: 0x55}
    for addr, val in cells.items():
        await mem_write(dut, addr, val)
    for addr, val in cells.items():
        got = await mem_read(dut, addr)
        assert got == val, f"0x{addr:04X}: read 0x{got:02X}, expected 0x{val:02X}"
