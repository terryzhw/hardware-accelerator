// 784 -> 32 -> 10 network, one MAC per clock
module nn_core #(
    parameter WEIGHTS_FILE = "weights.mem",
    parameter BIASES_FILE = "biases.mem",
    parameter SHIFT = 11
) (
    input logic clk, reset,
    input logic pixel_we,
    input logic [9:0] pixel_addr,
    input logic [7:0] pixel_data,
    input logic start,
    output logic busy,
    output logic done,
    output logic [3:0] prediction
);

    logic signed [7:0] weights [25408]; // layer 1 then layer 2
    logic signed [31:0] biases [42];
    logic [7:0] image [784];
    logic [7:0] hidden [32];

    initial begin
        $readmemh(WEIGHTS_FILE, weights);
        $readmemh(BIASES_FILE, biases);
    end

    typedef enum logic [2:0] {IDLE, CLEAR, MULTIPLY, LAST_ADD, SAVE, DONE} state_t;
    state_t state;

    logic layer;
    logic [4:0] neuron;
    logic [9:0] i;
    logic [14:0] w_addr;
    logic [9:0] last_input;
    logic [4:0] last_neuron;

    logic signed [7:0] w;
    logic [7:0] image_out, hidden_out;
    logic signed [7:0] x;
    logic mac_enable;
    logic signed [31:0] acc, best_score;
    logic [3:0] best_index;
    logic [7:0] relu_out;

    assign last_input = layer ? 10'd31 : 10'd783;
    assign last_neuron = layer ? 5'd9 : 5'd31;
    assign busy = (state != IDLE);

    always_ff @(posedge clk) begin
        if (pixel_we && !busy) image[pixel_addr] <= pixel_data;
        if (state == SAVE && layer == 0) hidden[neuron] <= relu_out;
        w <= weights[w_addr];
        image_out <= image[i];
        hidden_out <= hidden[i[4:0]];
    end

    assign x = layer ? hidden_out : image_out;

    mac mac_instance (
        .clk(clk),
        .clear(state == CLEAR),
        .enable(mac_enable),
        .bias(layer ? biases[32 + neuron] : biases[neuron]),
        .a(x),
        .w(w),
        .acc(acc)
    );

    // ReLU, divide by 2^SHIFT with rounding, clamp to 127
    logic signed [31:0] scaled;
    always_comb begin
        scaled = (acc + (1 <<< (SHIFT - 1))) >>> SHIFT;
        if (acc <= 0)
            relu_out = 8'd0;
        else if (scaled > 127)
            relu_out = 8'd127;
        else
            relu_out = scaled[7:0];
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            layer <= 0;
            neuron <= 0;
            i <= 0;
            w_addr <= 0;
            mac_enable <= 0;
            done <= 0;
            best_score <= 0;
            best_index <= 0;
            prediction <= 0;
        end else begin
            done <= 0;
            mac_enable <= (state == MULTIPLY);

            case (state)
                IDLE: begin
                    if (start) begin
                        layer <= 0;
                        neuron <= 0;
                        w_addr <= 0;
                        state <= CLEAR;
                    end
                end

                CLEAR: begin
                    i <= 0;
                    state <= MULTIPLY;
                end

                MULTIPLY: begin
                    w_addr <= w_addr + 1;
                    if (i == last_input)
                        state <= LAST_ADD;
                    else
                        i <= i + 1;
                end

                LAST_ADD: state <= SAVE;

                SAVE: begin
                    if (layer == 1 && (neuron == 0 || acc > best_score)) begin
                        best_score <= acc;
                        best_index <= neuron[3:0];
                    end

                    if (neuron != last_neuron) begin
                        neuron <= neuron + 1;
                        state <= CLEAR;
                    end else if (layer == 0) begin
                        layer <= 1;
                        neuron <= 0;
                        state <= CLEAR;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    prediction <= best_index;
                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule : nn_core
