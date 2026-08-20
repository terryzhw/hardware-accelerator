"""Train the 784 -> 32 -> 10 digit network on MNIST.

    python python/train.py
"""

from pathlib import Path

import numpy as np
from torchvision import datasets

REPO = Path(__file__).resolve().parent.parent


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
def main():
    (train_x, train_y), (val_x, val_y), (test_x, test_y) = load_mnist()
    print(f"train {train_x.shape}  val {val_x.shape}  test {test_x.shape}  "
          f"pixel range {train_x.min()}..{train_x.max()}")


if __name__ == "__main__":
    main()
