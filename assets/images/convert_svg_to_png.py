#!/usr/bin/env python3
import os

# pyright: reportMissingImports=false

try:
    # pylint: disable=import-error
    import cairosvg
    
    # Define SVG files to convert
    svg_files = [
        {"svg": "elephas_logo.svg", "png": "elephas_logo.png", "width": 512, "height": 512},
        {"svg": "elephas_logo_full.svg", "png": "elephas_logo_full.png", "width": 1024, "height": 256},
        {"svg": "elephas_icon.svg", "png": "elephas_icon.png", "width": 192, "height": 192}
    ]
    
    # Check if SVG files exist and convert them
    found_svg = False
    for file_info in svg_files:
        if os.path.exists(file_info["svg"]):
            found_svg = True
            print(f"Converting {file_info['svg']} to {file_info['png']}...")
            cairosvg.svg2png(
                url=file_info["svg"], 
                write_to=file_info["png"], 
                output_width=file_info["width"], 
                output_height=file_info["height"]
            )
    
    if found_svg:
        print("Successfully converted SVG files to PNG!")
    else:
        print("No SVG files found in the current directory.")
        print("Expected files: elephas_logo.svg, elephas_logo_full.svg, elephas_icon.svg")
        
except ImportError:
    print("CairoSVG is not installed. Please install it using: pip install cairosvg")
    print("Or manually convert the SVG files to PNG using an online converter.")
