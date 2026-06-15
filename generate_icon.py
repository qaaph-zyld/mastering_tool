#!/usr/bin/env python3
"""Generate a clean, scalable icon inspired by the green equalizer design."""
from PIL import Image, ImageDraw, ImageFilter


def draw_equalizer_icon(size: int) -> Image.Image:
    """Draw a stylized equalizer icon at given size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Scale factor
    s = size / 256.0

    # Dark background circle with subtle green glow
    cx, cy = size // 2, size // 2
    radius = int(120 * s)

    # Outer glow ring
    for r in range(radius + int(8 * s), radius, -1):
        alpha = int(30 * (radius + int(8 * s) - r) / (int(8 * s)))
        draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            outline=(0, 255, 100, alpha),
            width=1,
        )

    # Main dark circle background
    draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        fill=(10, 15, 10, 255),
        outline=(0, 200, 80, 255),
        width=max(1, int(2 * s)),
    )

    # Equalizer bars
    bar_count = 7
    bar_width = max(2, int(14 * s))
    gap = max(2, int(6 * s))
    total_width = bar_count * bar_width + (bar_count - 1) * gap
    start_x = cx - total_width // 2 + bar_width // 2

    # Bar heights (stylized pattern)
    heights = [0.35, 0.55, 0.75, 0.9, 0.65, 0.45, 0.3]
    max_bar_h = int(140 * s)

    for i, h_ratio in enumerate(heights):
        bar_h = int(max_bar_h * h_ratio)
        x = start_x + i * (bar_width + gap)
        y_bottom = cy + int(20 * s)
        y_top = y_bottom - bar_h

        # Bar glow (wider, more transparent)
        glow = max(2, int(4 * s))
        draw.rectangle(
            [x - glow, y_top - glow, x + bar_width + glow, y_bottom + glow],
            fill=(0, 255, 100, 40),
        )

        # Bar body
        draw.rectangle(
            [x, y_top, x + bar_width, y_bottom],
            fill=(0, 220, 90, 255),
        )

        # Bar highlight (top edge)
        hl_h = max(1, int(3 * s))
        draw.rectangle(
            [x, y_top, x + bar_width, y_top + hl_h],
            fill=(100, 255, 150, 255),
        )

    # Circular knob element at bottom center
    knob_r = max(6, int(28 * s))
    knob_cy = cy + int(85 * s)
    # Knob glow
    draw.ellipse(
        [cx - knob_r - 4, knob_cy - knob_r - 4, cx + knob_r + 4, knob_cy + knob_r + 4],
        fill=(0, 255, 100, 60),
    )
    # Knob body
    draw.ellipse(
        [cx - knob_r, knob_cy - knob_r, cx + knob_r, knob_cy + knob_r],
        fill=(30, 40, 35, 255),
        outline=(0, 220, 90, 255),
        width=max(1, int(2 * s)),
    )
    # Knob indicator line (12 o'clock)
    line_len = max(3, int(12 * s))
    line_w = max(1, int(3 * s))
    draw.rectangle(
        [cx - line_w // 2, knob_cy - knob_r + 2, cx + line_w // 2, knob_cy - knob_r + 2 + line_len],
        fill=(0, 255, 100, 255),
    )

    return img


def main():
    # Generate at 1024x1024 for high quality, then downscale
    large = draw_equalizer_icon(1024)

    # Save PNG
    png = large.resize((512, 512), Image.LANCZOS)
    png.save("icon.png")
    print("Saved icon.png (512x512)")

    # Build multi-resolution ICO
    sizes = [16, 24, 32, 48, 64, 128, 256, 512]
    ico_images = []
    for sz in sizes:
        icon = draw_equalizer_icon(sz)
        ico_images.append(icon)

    # Save ICO — PIL handles multi-image ICO when sizes list is provided
    ico_images[0].save(
        "icon.ico",
        format="ICO",
        sizes=[(sz, sz) for sz in sizes],
        append_images=ico_images[1:],
    )
    print("Saved icon.ico with sizes:", sizes)


if __name__ == "__main__":
    main()
