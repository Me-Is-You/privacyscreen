# Privacy Screen

A lightweight utility for Windows that applies customizable privacy overlays to displays. It helps enhance privacy in public spaces by reducing peripheral distractions through customizable dimming or masking effects.

## Features

- **Dual Modes**: Choose between a smooth **Vignette** overlay or a **Pixel Masking** pattern.
- **Multi-Monitor Support**: Automatically detects and covers all connected displays.
- **Configurable Effects**: Choose from multiple shapes, patterns, and mathematical fall-off functions.
- **Venetian Blinds**: Add optional horizontal stripes to the vignette for additional privacy.
- **Click-Through**: The overlay is completely transparent to mouse input, so it won't interfere with your workflow.
- **Always On Top**: Stays above other windows to ensure the privacy effect is always active.
- **Performance Focused**: Minimal CPU and memory footprint using native Win32 APIs.


## Installation

### From Releases

You can download the pre-compiled binaries for Windows from the [Releases](https://github.com/dhr412/privacyscreen/releases) page.

### From Source

Ensure you have one of the following toolchains installed:

#### Zig Implementation
Tested with Zig 0.15.2.
```bash
zig build -Doptimize=ReleaseSafe
```
The binary will be located at `zig-out/bin/privscrn.exe`.

## Usage

Run the executable with a command (`vig` or `pix`) and optional flags:

```bash
# Example: circular vignette with higher falloff
./privscrn.exe vig --shape circle --opacity 0.5 --falloff 3.0

# Example: checkerboard pixel mask
./privscrn.exe pix --mask-pattern checkerboard --mask-size 4
```

### Commands

| Command | Description |
|---------|-------------|
| `vig`, `vignette` | Applies a smooth vignette effect to the screen. |
| `pix`, `pixel` | Applies a pixel-based masking pattern to the screen. |

### Vignette Options (`vig`)

| Flag | Description | Default | Values |
|------|-------------|---------|--------|
| `-s, --shape` | The shape of the clear area | `elliptical` | `circle`, `rectangle`, `diamond`, `elliptical` |
| `-t, --type` | The mathematical function for the fall-off | `smootherstep` | `power`, `exponential`, `gaussian`, `smootherstep` |
| `-o, --opacity` | Maximum opacity at the edges (0.0 to 1.0) | `0.3` | Any float |
| `-f, --falloff` | Intensity/steepness of the fall-off curve | `4.0` | Any float |
| `-l, --left-bias` | Darken the left side more (optional strength) | `None` | Any float (default: 0.2) |
| `-r, --right-bias` | Darken the right side more (optional strength) | `None` | Any float (default: 0.2) |
| `-W, --stripe-width` | Venetian blind stripe width in pixels | `0` (off) | Any integer |
| `-S, --stripe-opacity`| Opacity of the stripes (0.0 to 1.0) | `0.8` | Any float |
| `-i, --invert` | Reverse the vignette effect | `false` | flag |

### Pixel Mask Options (`pix`)

| Flag | Description | Default | Values |
|------|-------------|---------|--------|
| `-p, --pattern` | The pattern for masking | `checkerboard` | `checkerboard`, `vertical`, `horizontal`, `diagonal` |
| `-s, --size` | Size of the pattern units in pixels | `2` | Any integer |
| `-o, --opacity` | Opacity of the mask (0.0 to 1.0) | `0.55` | Any float |


To exit the application, press `Ctrl+C` in the terminal or close the terminal window.

## How It Works

Privacy Screen creates a borderless, transparent, and layered window that spans the entire dimensions of each monitor on Windows.

It utilizes the Win32 API (`UpdateLayeredWindow`) and GDI to render a pre-computed vignette bitmap. The window style is set to `WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW` to allow for per-pixel alpha blending, mouse click-through, and to keep it hidden from the taskbar.

The application calculates the overlay in real-time based on the selected mode:
- **Vignette**: Uses mathematical functions (like Smootherstep or Gaussian) to create a smooth alpha transition based on the selected shape and bias.
- **Pixel Masking**: Generates a repeating geometric pattern (checkerboard, stripes, etc.) that acts as a physical-style privacy filter.


## License

This project is licensed under the [MIT License](LICENSE).
