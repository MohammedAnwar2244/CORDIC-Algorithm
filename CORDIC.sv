module CORDIC #(
    parameter N_ITER = 10,
    parameter WIDTH  = 32 
) (
    input  wire clk,
    input  wire rst_n,
    input  wire signed [WIDTH-1:0] x_start,   // Q2.30
    input  wire signed [WIDTH-1:0] y_start,   // Q2.30
    input  wire signed [WIDTH-1:0] angle,     // Q5.27
    output wire signed [WIDTH-1:0] cosine,    // Q2.30
    output wire signed [WIDTH-1:0] sine,      // Q2.30
    output wire valid
);

    reg [3:0] cnt;      
    reg signed [WIDTH-1:0] acc_angle, angle_reg, x, y;
    reg sign_flag;

    // Constants in Q5.27
    localparam signed [WIDTH-1:0] PI       = 32'h1921FB54; // π
    localparam signed [WIDTH-1:0] TWO_PI   = 32'h3243F6A8; // 2π
    localparam signed [WIDTH-1:0] HALF_PI  = 32'h0C924924; // π/2

    // atan lookup table in Q2.30
    localparam signed [WIDTH-1:0] atan_table [0:N_ITER-1] = {
        32'h3243F6A9, // atan(2^0)
        32'h1DAC6705, // atan(2^-1)
        32'h0FADBAFC, // atan(2^-2)
        32'h07F56EA6, // atan(2^-3)
        32'h03FEAB76, // atan(2^-4)
        32'h01FFD55B, // atan(2^-5)
        32'h00FFFAAB, // atan(2^-6)
        32'h007FF555, // atan(2^-7)
        32'h003FFAAA, // atan(2^-8)
        32'h001FFFD5  // atan(2^-9)
    };

    // Internal angle scaling
    wire signed [WIDTH-1:0] angle_scaled;
    assign angle_scaled = {angle_reg[WIDTH-4:0], 3'b000};

    // Main CORDIC process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x         <= x_start;
            y         <= y_start;
            angle_reg <= angle;
            sign_flag <= 0;
            acc_angle <= 0;
            cnt       <= 0;
        end else if (angle_reg > PI) begin
            angle_reg <= angle_reg - TWO_PI;
        end else if (angle_reg < (-PI)) begin
            angle_reg <= angle_reg + TWO_PI;
        end else if (angle_reg < -(HALF_PI)) begin
            angle_reg <= angle_reg + PI;
            sign_flag <= 1;
        end else if (angle_reg > HALF_PI) begin
            angle_reg <= angle_reg - PI;
            sign_flag <= 1;
        end else if (cnt <= N_ITER-1) begin
            cnt <= cnt + 1;
            
            if (acc_angle < angle_scaled) begin
                x         <= x - (y >>> cnt);
                y         <= y + (x >>> cnt);
                acc_angle <= acc_angle + atan_table[cnt];
            end else begin
                x         <= x + (y >>> cnt);
                y         <= y - (x >>> cnt);
                acc_angle <= acc_angle - atan_table[cnt];
            end
        end
    end

    // Outputs
    assign valid  = (cnt > 9) ? 1 : 0;
    assign cosine = sign_flag ? -x : x;
    assign sine   = sign_flag ? -y : y;

endmodule
