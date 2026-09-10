// Neural network core: 784 -> 32 -> 10 network using one multiply-accumulate per clock
module nn_core #(
  parameter WEIGHTS_FILE = "weights.mem",
  parameter BIASES_FILE  = "biases.mem",
  parameter SHIFT        = 11   // printed by python/train.py
) (
  input  logic       clk,
  reset,
  // Write the 784 image pixels (each 0..127) here before pulsing start
  input  logic       pixel_we,
  input  logic [9:0] pixel_addr,
  input  logic [7:0] pixel_data,
  input  logic       start,
  output logic       busy,
  done,                         // one-cycle pulse when prediction is ready
  output logic [3:0] prediction
);

  // Memories
  logic signed [7:0]  weights [25408];  // layer 1 (32 x 784) then layer 2 (10 x 32)
  logic signed [31:0] biases  [42];     // layer 1 (32) then layer 2 (10)
  logic        [7:0]  image   [784];
  logic        [7:0]  hidden  [32];     // layer 1 outputs

  initial begin
    $readmemh(WEIGHTS_FILE, weights);
    $readmemh(BIASES_FILE, biases);
  end

  typedef enum logic [2:0] {IDLE, CLEAR, MULTIPLY, LAST_ADD, SAVE, DONE} state_t;
  state_t state;

  logic        layer;        // 0 = hidden layer, 1 = output layer
  logic [4:0]  neuron;       // neuron being computed
  logic [9:0]  i;            // input being read
  logic [14:0] w_addr;       // weights are stored in the order we use them
  logic [9:0]  last_input;
  logic [4:0]  last_neuron;

  logic signed [7:0]  w;
  logic        [7:0]  image_out, hidden_out;
  logic signed [7:0]  x;
  logic               mac_enable;
  logic signed [31:0] acc, best_score;
  logic [3:0]         best_index;
  logic [7:0]         relu_out;

  assign last_input  = layer ? 10'd31 : 10'd783;
  assign last_neuron = layer ? 5'd9   : 5'd31;
  assign busy        = (state != IDLE);

  // Memory reads take one clock: the address goes in this cycle, data comes out next cycle
  always_ff @(posedge clk) begin
    if (pixel_we) image[pixel_addr] <= pixel_data;
    if (state == SAVE && layer == 0) hidden[neuron] <= relu_out;
    w          <= weights[w_addr];
    image_out  <= image[i];
    hidden_out <= hidden[i[4:0]];
  end

  assign x = layer ? hidden_out : image_out;

  mac mac_instance (
    .clk   (clk),
    .clear (state == CLEAR),
    .enable(mac_enable),
    .bias  (layer ? biases[32 + neuron] : biases[neuron]),
    .a     (x),
    .w     (w),
    .acc   (acc)
  );

  // ReLU, then scale down by 2^SHIFT (rounding to nearest), then clamp to 127.
  // acc stays far below 2^31, so adding the rounding constant can't overflow.
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

  // Control state machine. For each neuron:
  //   CLEAR     acc <= bias
  //   MULTIPLY  read input i and its weight, one per clock (added one cycle later)
  //   LAST_ADD  the last product is added
  //   SAVE      layer 1: store ReLU result; layer 2: keep the biggest score
  always_ff @(posedge clk) begin
    if (reset) begin
      state      <= IDLE;
      layer      <= 0;
      neuron     <= 0;
      i          <= 0;
      w_addr     <= 0;
      mac_enable <= 0;
      done       <= 0;
      best_score <= 0;
      best_index <= 0;
      prediction <= 0;
    end else begin
      done       <= 0;
      mac_enable <= (state == MULTIPLY);  // data read this cycle is ready next cycle

      case (state)
        IDLE: begin
          if (start) begin
            layer  <= 0;
            neuron <= 0;
            w_addr <= 0;
            state  <= CLEAR;
          end
        end

        CLEAR: begin
          i     <= 0;
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
          // Strictly greater, so a tie keeps the lower digit
          if (layer == 1 && (neuron == 0 || acc > best_score)) begin
            best_score <= acc;
            best_index <= neuron[3:0];
          end

          if (neuron != last_neuron) begin
            neuron <= neuron + 1;
            state  <= CLEAR;
          end else if (layer == 0) begin
            layer  <= 1;
            neuron <= 0;
            state  <= CLEAR;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          prediction <= best_index;
          done       <= 1;
          state      <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule : nn_core
