`default_nettype none

module bf (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,

    output reg  [15:0] mem_addr,
    output reg  [7:0]  mem_write_data,
    output reg         mem_read_en,
    output reg         mem_write_en,
    input  wire [7:0]  mem_read_data,
    input  wire        mem_resp_val
);

// State Definitions
localparam STATE_IDLE       = 4'd0;
localparam STATE_FETCH      = 4'd1;
localparam STATE_DECODE     = 4'd2;
localparam STATE_DATA_READ  = 4'd3;
localparam STATE_MODIFY     = 4'd4;
localparam STATE_DATA_WRITE = 4'd5;
localparam STATE_SCAN_FWD   = 4'd6;
localparam STATE_IO_READ    = 4'd7;
localparam STATE_IO_WRITE   = 4'd8;
localparam STATE_SCAN_BWD   = 4'd9;

reg [15:0] PC;
reg [15:0] DP;
reg [7:0]  instr_reg;
reg [7:0]  data_reg;
reg [3:0]  state_reg, next_state;

// Hardware Bracket Stack

parameter STACK_DEPTH   = 8;
parameter NEST_DEPTH    = 8;
localparam SP_BITS = $clog2(STACK_DEPTH + 1);

reg [15:0] pc_stack [0:STACK_DEPTH-1];
reg [SP_BITS:0]  sp;
reg [NEST_DEPTH-1:0]  nest_depth;
reg [7:0]  overflow_count; // nesting counter for when stack overflows

// ==============================================================================
// DATAPATH
// ==============================================================================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state_reg      <= STATE_IDLE;
        PC             <= 16'h0000;
        DP             <= 16'h8000;
        instr_reg      <= 8'd0;
        data_reg       <= 8'd0;
        sp             <= 3'd0;
        nest_depth     <= 8'd0;
        overflow_count <= 8'd0;
    end else begin
        state_reg <= next_state; 

        case (state_reg)
            STATE_FETCH: begin
                if (mem_resp_val) begin
                    instr_reg <= mem_read_data;
                    PC <= PC + 1;
                end
            end

            STATE_DECODE: begin
                if (instr_reg == 8'd62) DP <= DP + 1;      // >
                if (instr_reg == 8'd60) DP <= DP - 1;      // <
            end

            STATE_DATA_READ, STATE_IO_READ: begin
                if (mem_resp_val) data_reg <= mem_read_data;
            end

            STATE_MODIFY: begin
                if (instr_reg == 8'd43) data_reg <= data_reg + 1; // +
                if (instr_reg == 8'd45) data_reg <= data_reg - 1; // -
                
                // Stack Operations
                if (instr_reg == 8'd91) begin // [
                    if (data_reg != 0) begin
                        if (sp < STACK_DEPTH) begin
                            // Push onto stack
                            pc_stack[sp] <= PC;
                            sp <= sp + 1;
                        end else begin
                            // Stack is full
                            overflow_count <= overflow_count + 1;
                        end
                    end else begin
                        nest_depth <= 8'd1;
                    end
                end
                
                if (instr_reg == 8'd93) begin // ]
                    if (data_reg != 0) begin
                        if (overflow_count > 0) begin
                            // Matching '[' is not on the stack
                            nest_depth <= 8'd1;
                            PC <= PC - 2; 
                        end else begin
                            // Hardware stack hit
                            PC <= pc_stack[sp - 1]; 
                        end
                    end else begin
                        if (overflow_count > 0) begin
                            overflow_count <= overflow_count - 1;
                        end else begin
                            sp <= sp - 1;           
                        end
                    end
                end
            end

            STATE_SCAN_FWD: begin
                if (mem_resp_val) begin
                    PC <= PC + 1;
                    if (mem_read_data == 8'd91) nest_depth <= nest_depth + 1;
                    if (mem_read_data == 8'd93) nest_depth <= nest_depth - 1;
                end
            end

            STATE_SCAN_BWD: begin
                if (mem_resp_val) begin
                    if (mem_read_data == 8'd93) nest_depth <= nest_depth + 1;
                    else if (mem_read_data == 8'd91) nest_depth <= nest_depth - 1;

                    if (mem_read_data == 8'd91 && nest_depth == 8'd1) begin
                        PC <= PC + 1; 
                    end else begin
                        PC <= PC - 1;
                    end
                end
            end
            
            // STATE_DATA_WRITE and STATE_IO_WRITE only drive outputs
        endcase
    end
end

// ==============================================================================
// CONTROL PATH
// ==============================================================================
always @(*) begin
    // Default assignments
    next_state     = state_reg;
    mem_addr       = 16'd0;
    mem_write_data = 8'd0;
    mem_read_en    = 1'b0;
    mem_write_en   = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            if (start) next_state = STATE_FETCH;
        end

        STATE_FETCH: begin
            mem_addr    = PC;
            mem_read_en = 1'b1;
            if (mem_resp_val) next_state = STATE_DECODE;
        end

        STATE_DECODE: begin
            case (instr_reg)
                8'd62: next_state = STATE_FETCH;      // >
                8'd60: next_state = STATE_FETCH;      // <
                8'd43: next_state = STATE_DATA_READ;  // +
                8'd45: next_state = STATE_DATA_READ;  // -
                8'd91: next_state = STATE_DATA_READ;  // [
                8'd93: next_state = STATE_DATA_READ;  // ]
                8'd46: next_state = STATE_DATA_READ;  // .
                8'd44: next_state = STATE_IO_READ;    // ,
                default: next_state = STATE_FETCH;
            endcase
        end

        STATE_DATA_READ: begin
            mem_addr    = DP;
            mem_read_en = 1'b1;
            if (mem_resp_val) next_state = STATE_MODIFY;
        end

        STATE_MODIFY: begin
            if (instr_reg == 8'd43 || instr_reg == 8'd45) next_state = STATE_DATA_WRITE;
            else if (instr_reg == 8'd46) next_state = STATE_IO_WRITE;
            else if (instr_reg == 8'd91 && data_reg == 0) next_state = STATE_SCAN_FWD;
            else if (instr_reg == 8'd93 && data_reg != 0 && overflow_count > 0) next_state = STATE_SCAN_BWD;
            else next_state = STATE_FETCH;
        end

        STATE_DATA_WRITE: begin
            mem_addr       = DP;
            mem_write_data = data_reg;
            mem_write_en   = 1'b1;
            if (mem_resp_val) next_state = STATE_FETCH;
        end

        STATE_SCAN_FWD: begin
            mem_addr    = PC;
            mem_read_en = 1'b1;
            if (mem_resp_val && mem_read_data == 8'd93 && nest_depth == 8'd1) 
                next_state = STATE_FETCH;
        end

        STATE_SCAN_BWD: begin
            mem_addr    = PC;
            mem_read_en = 1'b1;
            if (mem_resp_val && mem_read_data == 8'd91 && nest_depth == 8'd1) 
                next_state = STATE_FETCH;
        end

        STATE_IO_READ: begin
            mem_addr    = 16'hFFFF;
            mem_read_en = 1'b1;
            if (mem_resp_val) next_state = STATE_DATA_WRITE;
        end

        STATE_IO_WRITE: begin
            mem_addr       = 16'hFFFF;
            mem_write_data = data_reg;
            mem_write_en   = 1'b1;
            if (mem_resp_val) next_state = STATE_FETCH;
        end
    endcase
end

endmodule