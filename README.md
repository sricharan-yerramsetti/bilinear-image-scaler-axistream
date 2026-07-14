# bilinear-image-scaler-axistream
**FPGA-based real-time image scaler using bilinear interpolation over AXI-Stream interface, implemented in Verilog with a multi-stage pipeline and line-buffer architecture.**
A high-performance, **four-stage streaming hardware pipeline** that resizes images on the fly using bilinear interpolation. Designed with an **AXI-Stream** interface (in and out) and optimized to operate under real-world hardware memory constraints—**no full frame-buffer required**.

---

## 💡 Why This Project Exists

Most hobbyist or educational image scalers load the entire image into a massive array and index into it arbitrarily. While that works fine in simulation, **real hardware doesn't have that luxury**. Holding a full 1080p or 4K frame in high-speed on-chip memory (SRAM/BRAM) is prohibitively expensive.

This design is engineered to respect real-world constraints:
*   **True Streaming:** Pixels arrive one-by-one in raster order[cite: 9].
*   **Line-Buffered Cache:** Keeps only **3 rows** of the source image in memory at any given time, discarding old lines as the coordinate mapper sweeps downward[cite: 9].
*   **Drop-In Integration:** Native AXI-Stream handshaking controls backpressure across all internal stages, allowing the design to easily integrate into larger FPGA video processing pipelines[cite: 9].

---

## 🖼️ Pipeline Visual Results

Here is how the pipeline performs on both single-channel grayscale and multi-channel RGB data. The stretching is deliberate to benchmark non-uniform scaling factors[cite: 9].

### 🔳 Grayscale Bilinear Scaling (480 × 451 → 960 × 500)

| Source Image (480x451) | Scaled Pipeline Output (960x500) |
| :---: | :---: |
| <img src="docs/images/grayscale_source.png" width="350" alt="Grayscale Source"> | <img src="docs/images/grayscale_output.png" width="450" alt="Grayscale Output"> |

### 🎨 RGB Bilinear Scaling (335 × 272 → 335 × 272 / Resized)

| Source RGB Image (Left) | Scaled RGB Output (Right) |
| :---: | :---: |
| <img src="docs/images/rgb_source.png" width="350" alt="RGB Source"> | <img src="docs/images/rgb_output.png" width="350" alt="RGB Output"> |

> *Note: Place your generated PNG files in a `docs/images/` directory in your repo to render these visuals on your GitHub main page.*

---

## ⚙️ Hardware Pipeline Architecture

The processing is split across four synchronous stages, synchronized by a master coordinate system and backward-propagated ready/valid handshake networks[cite: 9]:
