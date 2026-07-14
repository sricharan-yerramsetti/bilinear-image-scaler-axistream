# bilinear-image-scaler-axistream
**FPGA-based real-time image scaler using bilinear interpolation over AXI-Stream interface, implemented in Verilog with a multi-stage pipeline and line-buffer architecture.**
A high-performance, **four-stage streaming hardware pipeline** that resizes images on the fly using bilinear interpolation. Designed with an **AXI-Stream** interface (in and out) and optimized to operate under real-world hardware memory constraints—**no full frame-buffer required**.

---
##  Project Details

This design is engineered to respect real-world constraints:
*   **True Streaming:** Pixels arrive one-by-one in raster order.
*   **Line-Buffered Cache:** Keeps only **3 rows** of the source image in memory at any given time, discarding old lines as the coordinate mapper sweeps downward.
*   **Drop-In Integration:** Native AXI-Stream handshaking controls backpressure across all internal stages, allowing the design to easily integrate into larger FPGA video processing pipelines.
---

## Pipeline Visual Results

Here is how the pipeline performs on both single-channel grayscale and multi-channel RGB data. The stretching is deliberate to benchmark non-uniform scaling factors.

### Grayscale Bilinear Scaling

| Source Image (480x451) | Scaled Pipeline Output (960x500) |
| :---: | :---: |
| <img src="trail_run_and_results/grayscale_image_1.png" width="350" alt="Grayscale Source"> | <img src="docs/images/grayscale_output.png" width="450" alt="Grayscale Output"> |

### 🎨 RGB Bilinear Scaling

| Source RGB Image (Left) | Scaled RGB Output (Right) |
| :---: | :---: |
| <img src="docs/images/rgb_source.png" width="350" alt="RGB Source"> | <img src="docs/images/rgb_output.png" width="350" alt="RGB Output"> |

> *Note: Place your generated PNG files in a `docs/images/` directory in your repo to render these visuals on your GitHub main page.*

---

## ⚙️ Hardware Pipeline Architecture

The processing is split across four synchronous stages, synchronized by a master coordinate system and backward-propagated ready/valid handshake networks:

              ┌──────────────┐
              │ s_axis_tdata │ (Incoming Pixel Stream)
              └──────┬───────┘
                     ▼
 ───────────┐      ┌───────────┐      ┌───────────┐      ┌───────────┐
│  Stage 1  ├─────►│  Stage 2  ├─────►│  Stage 3  ├─────►│  Stage 4  │
│  mapper   │      │  buffer   │      │  h_interp │      │  v_interp │
└───────────┘      └───────────┘      └───────────┘      └─────┬─────┘
                                                               ▼
                                                        ┌──────────────┐
                                                        │ m_axis_tdata │ (Scaled Output Stream)
                                                        └──────────────┘
