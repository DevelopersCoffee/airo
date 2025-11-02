#!/usr/bin/env python3
"""
Create Airo app icons using PIL (Pillow)
This creates a modern icon with gradient and AI/air theme
"""

from PIL import Image, ImageDraw
import os
import math

def create_airo_icon(size):
    """Create Airo icon with gradient and design"""
    
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Create gradient background (blue gradient)
    for y in range(size):
        # Gradient from light blue to dark blue
        r = int(33 + (13 - 33) * (y / size))
        g = int(150 + (118 - 150) * (y / size))
        b = int(243 + (161 - 243) * (y / size))
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    
    # Draw outer circle
    margin = int(size * 0.05)
    draw.ellipse(
        [(margin, margin), (size - margin, size - margin)],
        outline=(255, 255, 255, 50),
        width=int(size * 0.02)
    )
    
    # Center point
    cx, cy = size // 2, size // 2
    
    # Draw "A" shape (stylized)
    line_width = int(size * 0.08)
    
    # Left side of A
    left_x1, left_y1 = int(cx - size * 0.25), int(cy + size * 0.25)
    left_x2, left_y2 = int(cx - size * 0.08), int(cy - size * 0.25)
    draw.line([(left_x1, left_y1), (left_x2, left_y2)], fill=(255, 255, 255, 255), width=line_width)
    
    # Right side of A
    right_x1, right_y1 = int(cx + size * 0.25), int(cy + size * 0.25)
    right_x2, right_y2 = int(cx + size * 0.08), int(cy - size * 0.25)
    draw.line([(right_x1, right_y1), (right_x2, right_y2)], fill=(255, 255, 255, 255), width=line_width)
    
    # Horizontal bar of A
    bar_y = int(cy + size * 0.05)
    bar_left = int(cx - size * 0.15)
    bar_right = int(cx + size * 0.15)
    draw.line([(bar_left, bar_y), (bar_right, bar_y)], fill=(255, 255, 255, 255), width=line_width)
    
    # Neural network nodes (AI concept)
    node_radius = int(size * 0.04)
    
    # Top node
    top_node_y = int(cy - size * 0.28)
    draw.ellipse(
        [(cx - node_radius, top_node_y - node_radius), 
         (cx + node_radius, top_node_y + node_radius)],
        fill=(255, 255, 255, 255)
    )
    
    # Bottom left node
    left_node_x = int(cx - size * 0.28)
    left_node_y = int(cy + size * 0.28)
    draw.ellipse(
        [(left_node_x - node_radius, left_node_y - node_radius),
         (left_node_x + node_radius, left_node_y + node_radius)],
        fill=(255, 255, 255, 255)
    )
    
    # Bottom right node
    right_node_x = int(cx + size * 0.28)
    right_node_y = int(cy + size * 0.28)
    draw.ellipse(
        [(right_node_x - node_radius, right_node_y - node_radius),
         (right_node_x + node_radius, right_node_y + node_radius)],
        fill=(255, 255, 255, 255)
    )
    
    # Center node (larger, different color)
    center_node_radius = int(size * 0.05)
    draw.ellipse(
        [(cx - center_node_radius, cy - center_node_radius),
         (cx + center_node_radius, cy + center_node_radius)],
        fill=(100, 181, 246, 255),
        outline=(255, 255, 255, 200),
        width=int(size * 0.01)
    )
    
    # Connection lines (neural network)
    line_width_thin = int(size * 0.015)
    
    # Top to bottom left
    draw.line([(cx, top_node_y), (left_node_x, left_node_y)], 
              fill=(255, 255, 255, 150), width=line_width_thin)
    
    # Top to bottom right
    draw.line([(cx, top_node_y), (right_node_x, right_node_y)], 
              fill=(255, 255, 255, 150), width=line_width_thin)
    
    # Bottom left to center
    draw.line([(left_node_x, left_node_y), (cx, cy)], 
              fill=(255, 255, 255, 150), width=line_width_thin)
    
    # Bottom right to center
    draw.line([(right_node_x, right_node_y), (cx, cy)], 
              fill=(255, 255, 255, 150), width=line_width_thin)
    
    # Air flow curves (thin and elegant)
    curve_width = int(size * 0.02)
    
    # Left air flow
    for i in range(0, 100, 5):
        angle = (i / 100) * math.pi
        x = int(cx - size * 0.35 - size * 0.05 * math.sin(angle))
        y = int(cy - size * 0.2 + size * 0.2 * (i / 100))
        draw.ellipse([(x - 1, y - 1), (x + 1, y + 1)], fill=(255, 255, 255, 100))
    
    # Right air flow
    for i in range(0, 100, 5):
        angle = (i / 100) * math.pi
        x = int(cx + size * 0.35 + size * 0.05 * math.sin(angle))
        y = int(cy - size * 0.2 + size * 0.2 * (i / 100))
        draw.ellipse([(x - 1, y - 1), (x + 1, y + 1)], fill=(255, 255, 255, 100))
    
    return img

def generate_all_icons():
    """Generate icons for all platforms"""
    
    icon_configs = [
        # Android icons
        ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png", 48),
        ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png", 72),
        ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", 96),
        ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", 144),
        ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192),
        
        # Web icons
        ("web/icons/Icon-192.png", 192),
        ("web/icons/Icon-512.png", 512),
        ("web/favicon.png", 192),
    ]
    
    print("Generating Airo icons...")
    
    for output_path, size in icon_configs:
        output_dir = os.path.dirname(output_path)
        os.makedirs(output_dir, exist_ok=True)
        
        try:
            icon = create_airo_icon(size)
            icon.save(output_path, 'PNG')
            print(f"✓ Generated {output_path} ({size}x{size})")
        except Exception as e:
            print(f"✗ Failed to generate {output_path}: {e}")
            return False
    
    print("\n✓ All icons generated successfully!")
    return True

if __name__ == "__main__":
    generate_all_icons()

