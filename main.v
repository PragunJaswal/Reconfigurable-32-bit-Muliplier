
/*
    phoeniX RV32IM Multiplier: Designer Guidelines with new multiplier unit by Pragun 
    ==========================================================================================================================
    DESIGNER NOTICE:
    - Kindly adhere to the established guidelines and naming conventions outlined in the project documentation. 
    - Following these standards will ensure smooth integration of your custom-made modules into this codebase.
    - Thank you for your cooperation.
    ==========================================================================================================================
    Multiplier Approximation CSR:
    - MUL CSR is addressed as 0x801 in control status registers.
    - Multiplier circuit is used for 4 M-Extension instructions: MUL/MULH/MULHSU/MULHU
    - Internal signals are all generated according to phoeniX core "Self Control Logic" of the modules so designer won't 
      need to change anything inside this module (excepts parts which are considered for designers to instatiate their own 
      custom made designs).

    - How to work with the speical purpose mulcsr:
        mulcsr [0]       : APPROXIMATE = 1 | ACCURATE = 0
        mulcsr [2   : 1] : CIRCUIT_SELECT (Defined for switching between 4 accuarate or approximate circuits)
        mulcsr [10   : 3] : APPROXIMATION_ERROR_CONTROL for Lower 8-bit multiplier AL×BL
        mulcsr [18  : 11] : APPROXIMATION_ERROR_CONTROL for Middle two 8-bit multipliers AH×BL and AL×BH
        mulcsr [26 : 19] :  APPROXIMATION_ERROR_CONTROL for Upper 8-bit multiplie AH×BH
        mulcsr [31 : 27] :  CUSTOM FIELD
    - Input and Output paramaters:
        Input:  clk           = Source clock signal
        Input:  control_status_register = {accuracy_control[USER_ERROR_LEN:3], accuracy_control[2:1] (module select), accuracy_control[0]}
        Input:  input_1       = First operand of your module
        Input:  input_2       = Second operand of your module
        Output: result        = Module Multiplier output
        Output: busy          = Module busy signal
    ==========================================================================================================================
*/

`include "Defines.v"

module Multiplier_Unit
#(
    parameter GENERATE_CIRCUIT_1 = 1,
    parameter GENERATE_CIRCUIT_2 = 0,
    parameter GENERATE_CIRCUIT_3 = 0,
    parameter GENERATE_CIRCUIT_4 = 0
)
(
    input wire clk, 

    input wire [ 6 : 0] opcode, 
    input wire [ 6 : 0] funct7,
    input wire [ 2 : 0] funct3, 

    input wire [31 : 0] control_status_register, 

    input wire [31 : 0] rs1, 
    input wire [31 : 0] rs2,  

    output              multiplier_unit_busy, 
    output reg [31 : 0] multiplier_unit_output  
);

    reg  [31 : 0] operand_1;            // RS1 latch
    reg  [31 : 0] operand_2;            // RS2 latch

    reg  [31 : 0] input_1;              // Modules input 1
    reg  [31 : 0] input_2;              // Modules input 2

    wire [ 23 : 0] multiplier_accuracy; // 24 bit control signal 
    wire [31 : 0] multiplier_input_1;   // Latched modules input 1
    wire [31 : 0] multiplier_input_2;   // Latched modules input 2

    wire [63 : 0] result;               

    reg  multiplier_0_enable;
    reg  multiplier_1_enable;
    reg  multiplier_2_enable;
    reg  multiplier_3_enable;

    wire [63 : 0] multiplier_0_result;
    wire [63 : 0] multiplier_1_result;
    wire [63 : 0] multiplier_2_result;
    wire [63 : 0] multiplier_3_result;

    wire multiplier_0_busy;
    wire multiplier_1_busy;
    wire multiplier_2_busy;
    wire multiplier_3_busy;

    reg reset_enable_signals = 0;
    reg [1 : 0] signal_state;
    reg [1 : 0] next_state;

    localparam signal_zero = 2'b00;
    localparam signal_high = 2'b01;
    localparam signal_low  = 2'b10;

    reg reset_controller_enable;
    reg state_machine_enable;

    always @(*) 
    begin
        operand_1 = rs1;
        operand_2 = rs2;
        if (!reset_enable_signals)
        begin
        case ({funct7, funct3, opcode})
            {`MULDIV, `MUL, `OP} : 
            begin
                input_1 = $signed(operand_1);
                input_2 = $signed(operand_2);
                multiplier_unit_output = result[31 : 0];
                case (control_status_register[2 : 1])
                    2'b00:   begin multiplier_0_enable = 1'b1; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                    2'b01:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b1; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                    2'b10:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b1; multiplier_3_enable = 1'b0; end
                    2'b11:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b1; end 
                    default: begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                endcase
            end
            {`MULDIV, `MULH, `OP} : 
            begin 
                input_1 = $signed(operand_1);
                input_2 = $signed(operand_2);
                multiplier_unit_output = result >>> 32;
                case (control_status_register[2 : 1])
                    2'b00:   begin multiplier_0_enable = 1'b1; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                    2'b01:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b1; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                    2'b10:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b1; multiplier_3_enable = 1'b0; end
                    2'b11:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b1; end 
                    default: begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                endcase
            end
            {`MULDIV, `MULHSU, `OP} : 
            begin
                input_1 = $signed(operand_1);
                input_2 = operand_2;
                multiplier_unit_output = result >>> 32;
                case (control_status_register[2 : 1])
                    2'b00:   begin multiplier_0_enable = 1'b1; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                    2'b01:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b1; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                    2'b10:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b1; multiplier_3_enable = 1'b0; end
                    2'b11:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b1; end 
                    default: begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                endcase
            end
            {`MULDIV, `MULHU, `OP} : 
            begin
                input_1 = operand_1;
                input_2 = operand_2;
                multiplier_unit_output = result >> 32;
                case (control_status_register[2 : 1])
                    2'b00:   begin multiplier_0_enable = 1'b1; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                    2'b01:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b1; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                    2'b10:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b1; multiplier_3_enable = 1'b0; end
                    2'b11:   begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b1; end 
                    default: begin multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0; multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0; end
                endcase
            end
            default: 
            begin
                multiplier_unit_output = 32'bz; 
                multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0;
                multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0;
            end
        endcase
        end else if (reset_enable_signals) 
        begin
            multiplier_0_enable = 1'b0; multiplier_1_enable = 1'b0;
            multiplier_2_enable = 1'b0; multiplier_3_enable = 1'b0;
        end
    end

    assign multiplier_unit_busy = (multiplier_0_enable | multiplier_1_enable | multiplier_2_enable | multiplier_3_enable);

    always @(multiplier_0_busy or multiplier_1_busy or multiplier_2_busy or multiplier_3_busy or reset_controller_enable) 
    begin 
        if (!multiplier_0_busy) begin state_machine_enable <= 1; end 
        else if (!multiplier_1_busy) begin state_machine_enable <= 1; end 
        else if (!multiplier_2_busy) begin state_machine_enable <= 1; end
        else if (!multiplier_3_busy) begin state_machine_enable <= 1; end
        else if (reset_controller_enable) begin state_machine_enable <= 0; end
    end

    always @(posedge clk or negedge state_machine_enable) 
    begin
        if (!state_machine_enable) signal_state <= signal_zero;
        else signal_state <= next_state;
    end
    
    always @(*) 
    begin
        case (signal_state)
            signal_zero:   
                begin 
                    if (state_machine_enable) 
                    begin reset_enable_signals <= 0; next_state <= signal_high; reset_controller_enable <= 0; end
                    else if (!state_machine_enable)
                    begin reset_enable_signals <= 0; next_state <= signal_low;  reset_controller_enable <= 0; end
                end
            signal_high:   
                begin 
                    if (state_machine_enable) 
                    begin reset_enable_signals <= 1; next_state <= signal_low; reset_controller_enable <= 0; end
                    else if (!state_machine_enable)
                    begin reset_enable_signals <= 0; next_state <= signal_low; reset_controller_enable <= 0; end 
                end
            signal_low:    
                begin 
                    if (state_machine_enable) 
                    begin reset_enable_signals <= 0; next_state <= signal_low; reset_controller_enable <= 1; end
                    else if (!state_machine_enable)
                    begin reset_enable_signals <= 0; next_state <= signal_low; reset_controller_enable <= 0; end
                end
            default:       
                begin 
                    if (state_machine_enable) 
                    begin reset_enable_signals <= 0; next_state <= signal_low; reset_controller_enable <= 1; end
                    else if (!state_machine_enable)
                    begin reset_enable_signals <= 0; next_state <= signal_low; reset_controller_enable <= 0; end
                end
        endcase
    end

    assign multiplier_0_enable_wire = (!reset_enable_signals) ? multiplier_0_enable : 0;
    assign multiplier_1_enable_wire = (!reset_enable_signals) ? multiplier_1_enable : 0; 
    assign multiplier_2_enable_wire = (!reset_enable_signals) ? multiplier_2_enable : 0; 
    assign multiplier_3_enable_wire = (!reset_enable_signals) ? multiplier_3_enable : 0;  

    // Assigning multiplier circuits' inputs
    reg circuits_input_enable = 0;
    wire enables_combine = (multiplier_0_enable | multiplier_1_enable | multiplier_2_enable | multiplier_3_enable);
    always @(posedge enables_combine) 
    begin circuits_input_enable = 1; end
    assign multiplier_input_1  = (circuits_input_enable) ? input_1 : 32'bz;
    assign multiplier_input_2  = (circuits_input_enable) ? input_2 : 32'bz;
    assign multiplier_accuracy = (circuits_input_enable) ? (control_status_register[26 : 3]) : 24'bz;

    // Assigning multiplier circuits' results to top unit result
    assign result = (multiplier_0_enable) ? multiplier_0_result :
                    (multiplier_1_enable) ? multiplier_1_result :
                    (multiplier_2_enable) ? multiplier_2_result :
                    (multiplier_3_enable) ? multiplier_3_result : multiplier_0_result;

    // *** Instantiate your multiplier circuit here ***
    // Please instantiate your multiplier module according to the guidelines and naming conventions of phoeniX
    // -------------------------------------------------------------------------------------------------------
    generate 
        if (GENERATE_CIRCUIT_1)
        begin : Multiplier_1_Generate_Block
            // Circuit 1 (default) instantiation
            //----------------------------------
            Approximate_Accuracy_Controllable_Multiplier approximate_accuracy_controllable_multiplier 
            (
                .clk(clk),
                .enable(multiplier_0_enable_wire),
                .Er(multiplier_accuracy),
                .Operand_1(multiplier_input_1), 
                .Operand_2(multiplier_input_2),  
                .Result(multiplier_0_result),
                .Busy(multiplier_0_busy)
            );
            //----------------------------------
            // End of Circuit 1 instantiation
        end
        if (GENERATE_CIRCUIT_2)
        begin : Multiplier_2_Generate_Block
            // Circuit 2 instantiation
            //-------------------------------
            sample_multiplier mul
            (
                .clk(clk),
                .enable(multiplier_0_enable_wire),
                .multiplier_input_1(multiplier_input_1),
                .multiplier_input_2(multiplier_input_2),
                .multiplier_0_result(multiplier_0_result),
                .multiplier_0_busy(multiplier_0_busy)
            );
            //-------------------------------
            // End of Circuit 2 instantiation
        end
        if (GENERATE_CIRCUIT_3)
        begin : Multiplier_3_Generate_Block
            // Circuit 3 instantiation
            //-------------------------------

            //-------------------------------
            // End of Circuit 3 instantiation
        end
        if (GENERATE_CIRCUIT_4)
        begin : Multiplier_4_Generate_Block
            // Circuit 4 instantiation
            //-------------------------------

            //-------------------------------
            // End of Circuit 4 instantiation
        end
    endgenerate
    // -------------------------------------------------------------------------------------------------------
    // *** End of multiplier module instantiation ***
endmodule



module Approximate_Accuracy_Controllable_Multiplier 
(
    input wire clk,
    input wire enable,

    input wire [23 : 0] Er,
    input wire [31 : 0] Operand_1,
    input wire [31 : 0] Operand_2,

    output reg [63 : 0] Result,
    output reg Busy
);
    
    wire [31 : 0] Partial_Product [0 : 3];
    wire Partial_Busy [0 : 3];

    Approximate_Accuracy_Controllable_Multiplier_16bit multiplier_LOWxLOW
    (
        .clk(clk),
        .enable(enable),

        .Er(Er[7:0]),
        .Operand_1(Operand_1[15 : 0]),
        .Operand_2(Operand_2[15 : 0]),

        .Result(Partial_Product[0]),
        .Busy(Partial_Busy[0])
    );

    Approximate_Accuracy_Controllable_Multiplier_16bit multiplier_HIGHxLOW
    (
        .clk(clk),
        .enable(enable),

        .Er(Er[15:8]),
        .Operand_1(Operand_1[31 : 16]),
        .Operand_2(Operand_2[15 :  0]),

        .Result(Partial_Product[1]),
        .Busy(Partial_Busy[1])
    );

    Approximate_Accuracy_Controllable_Multiplier_16bit multiplier_LOWxHIGH
    (
        .clk(clk),
        .enable(enable),

        .Er(Er[15:8]),
        .Operand_1(Operand_1[15 :  0]),
        .Operand_2(Operand_2[31 : 16]),

        .Result(Partial_Product[2]),
        .Busy(Partial_Busy[2])
    );

    Approximate_Accuracy_Controllable_Multiplier_16bit multiplier_HIGHxHIGH
    (
        .clk(clk),
        .enable(enable),

        .Er(Er[23:16]),
        .Operand_1(Operand_1[31 : 16]),
        .Operand_2(Operand_2[31 : 16]),

        .Result(Partial_Product[3]),
        .Busy(Partial_Busy[3])
    );

    always @(*) 
    begin
        Result = {32'b0, Partial_Product[0]} + {16'b0, Partial_Product[1], 16'b0} + {16'b0, Partial_Product[2], 16'b0} + {Partial_Product[3], 32'b0};
        Busy = &{Partial_Busy[0], Partial_Busy[1], Partial_Busy[2], Partial_Busy[3]};
    end
endmodule

module Approximate_Accuracy_Controllable_Multiplier_16bit 
(
    input wire clk,
    input wire enable,

    input wire [ 7 : 0] Er,
    input wire [15 : 0] Operand_1,
    input wire [15 : 0] Operand_2,

    output reg [31 : 0] Result,
    output reg Busy
);

    reg     [ 7 : 0] mul_input_1;
    reg     [ 7 : 0] mul_input_2;
    wire    [15 : 0] mul_result;

    reg     [15 : 0] partial_result_1;
    reg     [15 : 0] partial_result_2;
    reg     [15 : 0] partial_result_3;
    reg     [15 : 0] partial_result_4;

        prop_mul8_pp mul
    (
        .Er(Er),
        .a(mul_input_1),
        .b(mul_input_2),
        .out(mul_result)
    );

    reg [2 : 0] state;
    reg [2 : 0] next_state;

    always @(posedge clk) 
    begin
        if (~enable)    state <= 3'b000;
        else            state <= next_state;
    end

    always @(*) 
    begin
        next_state <= 'bz;
       
        case (state)
            3'b000 : 
            begin 
                mul_input_1 <= 'bz; 
                mul_input_2 <= 'bz; 
                
                partial_result_1 <= 'bz; 
                partial_result_2 <= 'bz; 
                partial_result_3 <= 'bz; 
                partial_result_4 <= 'bz; 
                
                Busy <= 1'b0; 
                next_state <= 3'b001; 
            end
            3'b001 : begin mul_input_1 <= Operand_1[ 7 : 0]; mul_input_2 <= Operand_2[ 7 : 0]; partial_result_1 <= mul_result; next_state <= 3'b010; Busy <= 1'b1; end
            3'b010 : begin mul_input_1 <= Operand_1[15 : 8]; mul_input_2 <= Operand_2[ 7 : 0]; partial_result_2 <= mul_result; next_state <= 3'b011; end
            3'b011 : begin mul_input_1 <= Operand_1[ 7 : 0]; mul_input_2 <= Operand_2[15 : 8]; partial_result_3 <= mul_result; next_state <= 3'b100; end
            3'b100 : begin mul_input_1 <= Operand_1[15 : 8]; mul_input_2 <= Operand_2[15 : 8]; partial_result_4 <= mul_result; next_state <= 3'b101; end
            3'b101 : 
            begin 
                Result =    {16'b0, partial_result_1} +
                            {8'b0,  partial_result_2, 8'b0} +
                            {8'b0,  partial_result_3, 8'b0} +
                            {partial_result_4, 16'b0}; 

                next_state <= 3'b000; 
                Busy <= 1'b0;
            end
        endcase 
    end
endmodule


//proposed 8-bit unsigned reconfigurable multiplier 
module prop_mul8_pp (input [7:0] a, b, Er, output [15:0] out);

	wire p77, p67, p57, p47, p37, p27, p17, p07, p76, p66, p56, p46, p36, p26, p16, p06, p75, p65, p55, p45, p35, p25, p15, p05, p74, p64, p54, p44, p34, p24, p14, p04, p73, p63, p53, p43, p33, p23, p13, p03, p72, p62, p52, p42, p32, p22, p12, p02, p71, p61, p51, p41, p31, p21, p11, p01, p70, p60, p50, p40, p30, p20, p10, p00;
	wire hc1, hs1, ad1, ac1, as1, ad2, ac2, as2, hc2, hs2, ad3, ac3, as3, ad4, ac4, as4, ad5, ac5, as5, ad6, ac6, as6, ad7, ac7, as7, fc1, fs1, ad8, ac8, as8, fc2, fs2;
	wire hc3, hs3, ad9, ac9, as9, ad10, ac10, as10, ad11, ac11, as11, ad12, ac12, as12, ad13, ac13, as13, ad14, ac14, as14, ad15, ac15, as15, ad16, ac16, as16, ad17, ac17, as17, ad18, ac18, as18, fc3, fs3;
	wire hc4, hs4, fc4, fs4, hc5, hs5, fc5, fs5, fc6, fs6, fc7, fs7, fc8, fs8, fc9, fs9, fc10, fs10, fc11, fs11, fc12, fs12, fc13, fs13, fc14, fs14, fc15, fs15;

	and (p77, a[7], b[7]);
	and (p67, a[6], b[7]);
	and (p57, a[5], b[7]);
	and (p47, a[4], b[7]);
	and (p37, a[3], b[7]);
	and (p27, a[2], b[7]);
	and (p17, a[1], b[7]);
	and (p07, a[0], b[7]);
	and (p76, a[7], b[6]);
	and (p66, a[6], b[6]);
	and (p56, a[5], b[6]);
	and (p46, a[4], b[6]);
	and (p36, a[3], b[6]);
	and (p26, a[2], b[6]);
	and (p16, a[1], b[6]);
	and (p06, a[0], b[6]);
	and (p75, a[7], b[5]);
	and (p65, a[6], b[5]);
	and (p55, a[5], b[5]);
	and (p45, a[4], b[5]);
	and (p35, a[3], b[5]);
	and (p25, a[2], b[5]);
	and (p15, a[1], b[5]);
	and (p05, a[0], b[5]);
	and (p74, a[7], b[4]);
	and (p64, a[6], b[4]);
	and (p54, a[5], b[4]);
	and (p44, a[4], b[4]);
	and (p34, a[3], b[4]);
	and (p24, a[2], b[4]);
	and (p14, a[1], b[4]);
	and (p04, a[0], b[4]);
	and (p73, a[7], b[3]);
	and (p63, a[6], b[3]);
	and (p53, a[5], b[3]);
	and (p43, a[4], b[3]);
	and (p33, a[3], b[3]);
	and (p23, a[2], b[3]);
	and (p13, a[1], b[3]);
	and (p03, a[0], b[3]);
	and (p72, a[7], b[2]);
	and (p62, a[6], b[2]);
	and (p52, a[5], b[2]);
	and (p42, a[4], b[2]);
	and (p32, a[3], b[2]);
	and (p22, a[2], b[2]);
	and (p12, a[1], b[2]);
	and (p02, a[0], b[2]);
	and (p71, a[7], b[1]);
	and (p61, a[6], b[1]);
	and (p51, a[5], b[1]);
	and (p41, a[4], b[1]);
	and (p31, a[3], b[1]);
	and (p21, a[2], b[1]);
	and (p11, a[1], b[1]);
	and (p01, a[0], b[1]);
	and (p70, a[7], b[0]);
	and (p60, a[6], b[0]);
	and (p50, a[5], b[0]);
	and (p40, a[4], b[0]);
	and (p30, a[3], b[0]);
	and (p20, a[2], b[0]);
	and (p10, a[1], b[0]);
	and (p00, a[0], b[0]);

	// stage 1
	FA u1 (hc1, hs1, p04, p13,p22);
	Compressor_prop u2 (ad1, ac1, as1, hc1, p05, p14, p23, p32,Er[2]);
	Compressor_prop u3 (ad2, ac2, as2, ad1, p06, p15, p24, p33,Er[3]);
	FA u4 (hc2, hs2, p42, p51, p60);
	Compressor_prop u5 (ad3, ac3, as3, ad2, p07, p16, p25, p34,Er[4]);
	Compressor_prop u6 (ad4, ac4, as4, p43, p52, p61, p70, hc2,Er[4]);
	Compressor_prop u7 (ad5, ac5, as5, ad3, p17, p26, p35, p44,Er[5]);
	Compressor_prop u8 (ad6, ac6, as6, ad4, p53, p62, p71, 1'b0,Er[5]);
	Compressor_prop u9 (ad7, ac7, as7, ad5, p27, p36, p45, p54,Er[6]);
	FA u10 (fc1, fs1, p63, p72, ad6);
	Compressor_prop u11 (ad8, ac8, as8, ad7, p37, p46, p55, p64,Er[7]);
	FA u12 (fc2, fs2, p65, p47, p56);

	// stage 2
	HA u13 (hc3, hs3, p02, p11);
	Compressor_prop u14 (ad9, ac9, as9, p03, p12, p21, p30, 1'b0,Er[0]);
	Compressor_prop u15 (ad10, ac10, as10, hs1, 1'b0, p31, p40, ad9,Er[1]);
	Compressor_prop u16 (ad11, ac11, as11, as1, p41, p50, ad10, 1'b0,Er[2]);
	Compressor_prop u17 (ad12, ac12, as12, as2, ac1, 1'b0, hs2, ad11,Er[3]);
	Compressor_prop u18 (ad13, ac13, as13, as3, ac2, as4, ad12, 1'b0,Er[4]);
	Compressor_prop u19 (ad14, ac14, as14, as5, ac3, ac4, as6, ad13,Er[5]);
	Compressor_prop u20 (ad15, ac15, as15, as7, ac5, ac6, fs1, ad14,Er[6]);
	Compressor_prop u21 (ad16, ac16, as16, as8, ac7, p73, fc1, ad15,Er[7]);
	cmp_e5 u22 (ad17, ac17, as17, ac8, fs2, ad8, p74, ad16);
	cmp_e5 u23 (ad18, ac18, as18, fc2, p57, p66, p75, ad17);
	FA u24 (fc3, fs3, p67, p76, ad18);

	// stage 3
	HA u25 (hc4, hs4, p01, p10);
	FA u26 (fc4, fs4, hs3, p20, hc4);
	FA u27 (hc5, hs5, as9, fc4,hc3);
	FA u28 (fc5, fs5, as10, ac9, hc5);
	FA u29 (fc6, fs6, as11, ac10, fc5);
	FA u30 (fc7, fs7, as12, ac11, fc6);
	FA u31 (fc8, fs8, as13, ac12, fc7);
	FA u32 (fc9, fs9, as14, ac13, fc8);
	FA u33 (fc10, fs10, as15, ac14, fc9);
	FA u34 (fc11, fs11, as16, ac15, fc10);
	FA u35 (fc12, fs12, as17, ac16, fc11);
	FA u36 (fc13, fs13, as18, ac17, fc12);
	FA u37 (fc14, fs14, fs3, ac18, fc13);
	FA u38 (fc15, fs15, fc3, p77, fc14);

	assign out = {fc15, fs15, fs14, fs13, fs12, fs11, fs10, fs9, fs8, fs7, fs6, fs5, hs5, fs4, hs4, p00};

endmodule


//Conventional 4:2 Compressor
module cmp_e5(
    output Cout,
    output Carry,
    output Sum,
    input  In1,
    input  In2,
    input  In3,
    input  In4,
    input  Cin

);

    wire s1, c1, c2;

    // First FA
    FA fa1 (
        .A   (In1),
        .B   (In2),
        .Cin (In3),
        .Sum (s1),
        .Carry (c1)
    );

    // Second FA
    FA fa2 (
        .A   (In4),
        .B   (s1),
        .Cin (Cin),
        .Sum (Sum),
        .Carry (c2)
    );

    assign Carry = c2;
    assign Cout  = c1;

endmodule



//Reconfigurable 4:2 Compressor (DFC)
module cmp_e5_Er(
    output Cout,
    output Carry,
    output Sum,
    input  In1,
    input  In2,
    input  In3,
    input  In4,
    input  Cin,
    input Er

);
    wire s1, c1, c2;
    // First FA
    Prop_FA fa1 (
        .A   (In1),
        .B   (In2),
        .Cin (In3),
        .Er (Er),
        .Sum (s1),
        .Cout (c1)
    );

    // Second FA
    Prop_FA fa2 (
        .A   (In4),
        .B   (s1),
        .Cin (Cin),
        .Er (Er),
        .Sum (Sum),
        .Cout (c2)
    );

    assign Carry = c2;
    assign Cout  = c1;

endmodule


// module Ph_FA
// (
//     input Er,
//     input A,
//     input B, 
//     input Cin,

//     output Sum, 
//     output Cout
// );
//     assign Sum = ~(Er && (A ^ B) && Cin) && ((A ^ B) || Cin);
//     assign Cout = (Er && B && Cin) || ((B || Cin) && A);
// endmodule



// //Propsoed Reconfigurable Full Adder (RFA)
module Prop_FA (
    input  Er,
    input  A,
    input  B, 
    input  Cin,
    output Sum, 
    output Cout
);

    wire p, q, r, s, t, u, v;

    // -----------------------------
    // Internal signals
    // -----------------------------
    assign p = (A ^ B);          // xnor g1
    assign q = ~(Cin | p);        // nor g2
    assign s = Cin & Er;          // and g3
    assign r = p & s;             // and g4
    assign Sum = ~(r | q);        // nor g5

    assign u = B | Cin;           // or g7
    assign v = (A & u);          // and g8
    assign t = (s & B);          // and g9
    assign Cout = (t | v);       // or g10

endmodule




//Proposed 4:2 Reconfigurable Compressor (SSC)
module Compressor_prop (
	output Cout,
    output Carry,
    output Sum,
    input  In1,
    input  In2,
    input  In3,
    input  In4,
    input  Cin,
	input Er

);

    // Internal Wires for Single Stage Stacking
    wire X1_bar, X2_bar, X3_bar, X4_bar;
    
    // Internal Wires for Carry/Sum Logic
    wire cout1;
    wire C_temp1, C_temp2;
    wire Y,trmp1,temp2,temp3,temp4;

    // ----- Single Stage Stacking -----
    assign X1_bar = ~(In1 | In2);          // NOR
    assign X2_bar = ~(In1 & In2);          // NAND
    assign X3_bar = ~(In3 | In4);          // NOR
    assign X4_bar = ~(In3 & In4);          // NAND

    // ----- Carry Logic -----
    // First carry path
    assign cout1  = ~(X3_bar & X2_bar);    // NAND
    assign Cout   = cout1 & (~X1_bar);     // AND with inverted X1_bar

    // Intermediate carry calculations
    assign C_temp1 = ~(X4_bar & (~X3_bar)); // NAND
    assign C_temp2 = ~( (~X1_bar) & X2_bar); // NAND

    
    // Combined carry logic
    assign Y = C_temp1 ^ C_temp2;          // XOR

    assign temp1 = Cin & Er;               // AND
    assign temp2 = Y &temp1;               // AND
    assign temp3 = ~ (Cin | Y);             // NOR
    assign Sum = ~ (temp2 | temp3);        // NOR

    // // ----- Final Carry using MUX -----
    assign Carry = Y ? Cin : (~X4_bar) ;

endmodule



//Half Adder
module HA(
    output Carry,
    output Sum,
    input  A,
    input  B
);
    assign Sum   = A ^ B;
    assign Carry = A & B;
endmodule


//Full Adder
module FA(
    output Carry,
    output Sum,
    input  A,
    input  B,
    input  Cin
);
    assign Sum   = A ^ B ^ Cin;
    assign Carry = (A & B) | (B & Cin) | (A & Cin);
endmodule









//Conventional Multiplier with Compressors without Error signal
module unsigned_multiplier (input [7:0] a, b, output [15:0] out);

	wire p77, p67, p57, p47, p37, p27, p17, p07, p76, p66, p56, p46, p36, p26, p16, p06, p75, p65, p55, p45, p35, p25, p15, p05, p74, p64, p54, p44, p34, p24, p14, p04, p73, p63, p53, p43, p33, p23, p13, p03, p72, p62, p52, p42, p32, p22, p12, p02, p71, p61, p51, p41, p31, p21, p11, p01, p70, p60, p50, p40, p30, p20, p10, p00;
	wire hc1, hs1, ad1, ac1, as1, ad2, ac2, as2, hc2, hs2, ad3, ac3, as3, ad4, ac4, as4, ad5, ac5, as5, ad6, ac6, as6, ad7, ac7, as7, fc1, fs1, ad8, ac8, as8, fc2, fs2;
	wire hc3, hs3, ad9, ac9, as9, ad10, ac10, as10, ad11, ac11, as11, ad12, ac12, as12, ad13, ac13, as13, ad14, ac14, as14, ad15, ac15, as15, ad16, ac16, as16, ad17, ac17, as17, ad18, ac18, as18, fc3, fs3;
	wire hc4, hs4, fc4, fs4, hc5, hs5, fc5, fs5, fc6, fs6, fc7, fs7, fc8, fs8, fc9, fs9, fc10, fs10, fc11, fs11, fc12, fs12, fc13, fs13, fc14, fs14, fc15, fs15;

	and (p77, a[7], b[7]);
	and (p67, a[6], b[7]);
	and (p57, a[5], b[7]);
	and (p47, a[4], b[7]);
	and (p37, a[3], b[7]);
	and (p27, a[2], b[7]);
	and (p17, a[1], b[7]);
	and (p07, a[0], b[7]);
	and (p76, a[7], b[6]);
	and (p66, a[6], b[6]);
	and (p56, a[5], b[6]);
	and (p46, a[4], b[6]);
	and (p36, a[3], b[6]);
	and (p26, a[2], b[6]);
	and (p16, a[1], b[6]);
	and (p06, a[0], b[6]);
	and (p75, a[7], b[5]);
	and (p65, a[6], b[5]);
	and (p55, a[5], b[5]);
	and (p45, a[4], b[5]);
	and (p35, a[3], b[5]);
	and (p25, a[2], b[5]);
	and (p15, a[1], b[5]);
	and (p05, a[0], b[5]);
	and (p74, a[7], b[4]);
	and (p64, a[6], b[4]);
	and (p54, a[5], b[4]);
	and (p44, a[4], b[4]);
	and (p34, a[3], b[4]);
	and (p24, a[2], b[4]);
	and (p14, a[1], b[4]);
	and (p04, a[0], b[4]);
	and (p73, a[7], b[3]);
	and (p63, a[6], b[3]);
	and (p53, a[5], b[3]);
	and (p43, a[4], b[3]);
	and (p33, a[3], b[3]);
	and (p23, a[2], b[3]);
	and (p13, a[1], b[3]);
	and (p03, a[0], b[3]);
	and (p72, a[7], b[2]);
	and (p62, a[6], b[2]);
	and (p52, a[5], b[2]);
	and (p42, a[4], b[2]);
	and (p32, a[3], b[2]);
	and (p22, a[2], b[2]);
	and (p12, a[1], b[2]);
	and (p02, a[0], b[2]);
	and (p71, a[7], b[1]);
	and (p61, a[6], b[1]);
	and (p51, a[5], b[1]);
	and (p41, a[4], b[1]);
	and (p31, a[3], b[1]);
	and (p21, a[2], b[1]);
	and (p11, a[1], b[1]);
	and (p01, a[0], b[1]);
	and (p70, a[7], b[0]);
	and (p60, a[6], b[0]);
	and (p50, a[5], b[0]);
	and (p40, a[4], b[0]);
	and (p30, a[3], b[0]);
	and (p20, a[2], b[0]);
	and (p10, a[1], b[0]);
	and (p00, a[0], b[0]);

	// stage 1
	HA u1 (hc1, hs1, p04, p13);
	cmp_e5 u2 (ad1, ac1, as1, hc1, p05, p14, p23, p32);
	cmp_e5 u3 (ad2, ac2, as2, ad1, p06, p15, p24, p33);
	HA u4 (hc2, hs2, p42, p51);
	cmp_e5 u5 (ad3, ac3, as3, ad2, p07, p16, p25, p34);
	cmp_e5 u6 (ad4, ac4, as4, p43, p52, p61, p70, hc2);
	cmp_e5 u7 (ad5, ac5, as5, ad3, p17, p26, p35, p44);
	cmp_e5 u8 (ad6, ac6, as6, ad4, p53, p62, p71, 1'b0);
	cmp_e5 u9 (ad7, ac7, as7, ad5, p27, p36, p45, p54);
	FA u10 (fc1, fs1, p63, p72, ad6);
	cmp_e5 u11 (ad8, ac8, as8, ad7, p37, p46, p55, p64);
	FA u12 (fc2, fs2, ad8, p47, p56);

	// stage 2
	HA u13 (hc3, hs3, p02, p11);
	cmp_e5 u14 (ad9, ac9, as9, p03, p12, p21, p30, 1'b0);
	cmp_e5 u15 (ad10, ac10, as10, hs1, p22, p31, p40, ad9);
	cmp_e5 u16 (ad11, ac11, as11, as1, p41, p50, ad10, 1'b0);
	cmp_e5 u17 (ad12, ac12, as12, as2, ac1, p60, hs2, ad11);
	cmp_e5 u18 (ad13, ac13, as13, as3, ac2, as4, ad12, 1'b0);
	cmp_e5 u19 (ad14, ac14, as14, as5, ac3, ac4, as6, ad13);
	cmp_e5 u20 (ad15, ac15, as15, as7, ac5, ac6, fs1, ad14);
	cmp_e5 u21 (ad16, ac16, as16, as8, ac7, p73, fc1, ad15);
	cmp_e5 u22 (ad17, ac17, as17, ac8, fs2, p65, p74, ad16);
	cmp_e5 u23 (ad18, ac18, as18, fc2, p57, p66, p75, ad17);
	FA u24 (fc3, fs3, p67, p76, ad18);

	// stage 3
	HA u25 (hc4, hs4, p01, p10);
	FA u26 (fc4, fs4, hs3, p20, hc4);
	FA u27 (hc5, hs5, as9, fc4,hc3);
	FA u28 (fc5, fs5, as10, ac9, hc5);
	FA u29 (fc6, fs6, as11, ac10, fc5);
	FA u30 (fc7, fs7, as12, ac11, fc6);
	FA u31 (fc8, fs8, as13, ac12, fc7);
	FA u32 (fc9, fs9, as14, ac13, fc8);
	FA u33 (fc10, fs10, as15, ac14, fc9);
	FA u34 (fc11, fs11, as16, ac15, fc10);
	FA u35 (fc12, fs12, as17, ac16, fc11);
	FA u36 (fc13, fs13, as18, ac17, fc12);
	FA u37 (fc14, fs14, fs3, ac18, fc13);
	FA u38 (fc15, fs15, fc3, p77, fc14);

	assign out = {fc15, fs15, fs14, fs13, fs12, fs11, fs10, fs9, fs8, fs7, fs6, fs5, hs5, fs4, hs4, p00};

endmodule

