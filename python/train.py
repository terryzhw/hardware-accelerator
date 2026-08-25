"""Train the 784 -> 32 -> 10 digit network on MNIST.

    python python/train.py
"""

from pathlib import Path

import numpy as np
import torch
from torch import nn
from torchvision import datasets

REPO = Path(__file__).resolve().parent.parent

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
def main():
    (train_x, train_y), (val_x, val_y), (test_x, test_y) = load_mnist()

    model = train_model(train_x, train_y)
    print(f"float accuracy: val {float_accuracy(model, val_x, val_y):.4f}  "
          f"test {float_accuracy(model, test_x, test_y):.4f}")


if __name__ == "__main__":
    main()
