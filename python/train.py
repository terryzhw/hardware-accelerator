"""Train the 784 -> 32 -> 10 digit network, convert it to integers, and write the
memory files the hardware loads.

    python python/train.py

Outputs
    rtl/weights.mem     8-bit weights, layer 1 then layer 2 (one hex byte per line)
    rtl/biases.mem      32-bit biases, layer 1 then layer 2
    tb/vectors/*.mem    test images and the expected hardware results

The integer math here (int_forward) is exactly what the hardware does, so the testbench
can check the RTL value by value.
"""

from pathlib import Path

import numpy as np
import torch
from torch import nn
from torchvision import datasets

REPO = Path(__file__).resolve().parent.parent
NUM_TEST_VECTORS = 50

torch.manual_seed(0)


# ---------------------------------------------------------------------------
# Data. Pixels are 0..255; the hardware input is x = pixel >> 1 (0..127) so it fits
# in a signed 8-bit number. The float model is trained on x / 128.

def load_mnist():
    train = datasets.MNIST(REPO / "data", train=True, download=True)
    test = datasets.MNIST(REPO / "data", train=False, download=True)
    train_x = train.data.numpy().reshape(-1, 784) >> 1
    test_x = test.data.numpy().reshape(-1, 784) >> 1
    # Hold out 5000 training images for validation; the test set is only used at the end
    order = np.random.default_rng(1234).permutation(len(train_x))
    val, tr = order[:5000], order[5000:]
    return ((train_x[tr], train.targets.numpy()[tr]),
            (train_x[val], train.targets.numpy()[val]),
            (test_x, test.targets.numpy()))


# ---------------------------------------------------------------------------
# Float training

def train_model(x, y, epochs=30):
    model = nn.Sequential(nn.Linear(784, 32), nn.ReLU(), nn.Linear(32, 10))
    opt = torch.optim.Adam(model.parameters(), lr=3e-3, weight_decay=1e-5)
    sched = torch.optim.lr_scheduler.CosineAnnealingLR(opt, epochs)
    x = torch.tensor(x, dtype=torch.float32) / 128
    y = torch.tensor(y)
    for epoch in range(epochs):
        order = torch.randperm(len(x))
        for i in range(0, len(x), 128):
            batch = order[i:i + 128]
            opt.zero_grad()
            loss = nn.functional.cross_entropy(model(x[batch]), y[batch])
            loss.backward()
            opt.step()
        sched.step()
    return model


def float_accuracy(model, x, y):
    with torch.no_grad():
        out = model(torch.tensor(x, dtype=torch.float32) / 128)
    return (out.argmax(1).numpy() == y).mean()


# ---------------------------------------------------------------------------
# Integer conversion. Every scale is a power of two so the hardware only needs shifts.
#   input x:   real = x / 2^7
#   weights:   real = w / 2^F   (F as large as possible while |w| <= 127)
#   hidden h:  real = h / 2^FH

def frac_bits(max_value):
    """Largest F with max_value * 2^F <= 127."""
    f = 0
    while max_value * 2 ** (f + 1) <= 127:
        f += 1
    while max_value * 2 ** f > 127:
        f -= 1
    return f


def quantize(model, train_x):
    w1 = model[0].weight.detach().numpy().astype(np.float64)
    b1 = model[0].bias.detach().numpy().astype(np.float64)
    w2 = model[2].weight.detach().numpy().astype(np.float64)
    b2 = model[2].bias.detach().numpy().astype(np.float64)

    f1 = frac_bits(np.abs(w1).max())
    f2 = frac_bits(np.abs(w2).max())
    # Hidden scale: the largest hidden value seen on the training set maps to <= 127
    hidden = np.maximum(train_x / 128 @ w1.T + b1, 0)
    fh = frac_bits(hidden.max())

    q = {
        "w1": np.round(w1 * 2 ** f1).astype(np.int64),
        "b1": np.round(b1 * 2 ** (7 + f1)).astype(np.int64),   # same scale as x * w1
        "w2": np.round(w2 * 2 ** f2).astype(np.int64),
        "b2": np.round(b2 * 2 ** (fh + f2)).astype(np.int64),  # same scale as h * w2
        "shift": 7 + f1 - fh,                                  # layer 1 sum -> hidden scale
    }
    return q


def int_forward(q, x):
    """Bit-exact model of the hardware. x: (N, 784) ints 0..127."""
    x = np.asarray(x, dtype=np.int64)
    acc1 = x @ q["w1"].T + q["b1"]
    # ReLU, then divide by 2^shift rounding half up, then clamp to 127
    s = q["shift"]
    hidden = np.where(acc1 <= 0, 0, np.minimum((acc1 + (1 << (s - 1))) >> s, 127))
    scores = hidden @ q["w2"].T + q["b2"]
    return hidden, scores, scores.argmax(1)   # argmax picks the lowest index on a tie


# ---------------------------------------------------------------------------
# Memory files ($readmemh format: one hex value per line, two's complement)

def write_hex(path, values, bits):
    path.parent.mkdir(parents=True, exist_ok=True)
    mask = (1 << bits) - 1
    with open(path, "w") as f:
        for v in np.asarray(values).reshape(-1):
            f.write(f"{int(v) & mask:0{bits // 4}x}\n")


def main():
    (train_x, train_y), (val_x, val_y), (test_x, test_y) = load_mnist()

    model = train_model(train_x, train_y)
    q = quantize(model, train_x)
    assert np.abs(q["w1"]).max() <= 127 and np.abs(q["w2"]).max() <= 127

    print(f"float accuracy: val {float_accuracy(model, val_x, val_y):.4f}  "
          f"test {float_accuracy(model, test_x, test_y):.4f}")
    print(f"int   accuracy: val {(int_forward(q, val_x)[2] == val_y).mean():.4f}  "
          f"test {(int_forward(q, test_x)[2] == test_y).mean():.4f}")
    print(f"SHIFT = {q['shift']}  (must match the SHIFT parameter in rtl/nn_core.sv)")

    write_hex(REPO / "rtl" / "weights.mem", np.concatenate([q["w1"].ravel(), q["w2"].ravel()]), 8)
    write_hex(REPO / "rtl" / "biases.mem", np.concatenate([q["b1"], q["b2"]]), 32)

    # Test vectors: the first few test images and what the hardware should produce
    x = test_x[:NUM_TEST_VECTORS]
    hidden, scores, pred = int_forward(q, x)
    vec = REPO / "tb" / "vectors"
    write_hex(vec / "images.mem", x, 8)
    write_hex(vec / "hidden.mem", hidden, 8)
    write_hex(vec / "scores.mem", scores, 32)
    write_hex(vec / "pred.mem", pred, 8)
    print(f"wrote {NUM_TEST_VECTORS} test vectors, labels {test_y[:NUM_TEST_VECTORS].tolist()}")


if __name__ == "__main__":
    main()
