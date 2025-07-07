#!/usr/bin/env python3
import os
import shutil
import sys

def main():
    # Source file location
    source_file = os.path.expanduser("~/Desktop/elephaslogo.png")
    
    # Destination directory
    current_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Check if source file exists
    if not os.path.exists(source_file):
        print(f"Error: Source file {source_file} not found!")
        print("Please make sure elephaslogo.png is on your desktop.")
        return 1
        
    print(f"Found logo file: {source_file}")
    
    # Copy the original file to all required destinations
    try:
        # Full logo
        shutil.copy(source_file, os.path.join(current_dir, "elephas_logo_full.png"))
        print(f"Created full logo: {os.path.join(current_dir, 'elephas_logo_full.png')}")
        
        # Square logo
        shutil.copy(source_file, os.path.join(current_dir, "elephas_logo.png"))
        print(f"Created square logo: {os.path.join(current_dir, 'elephas_logo.png')}")
        
        # Icon
        shutil.copy(source_file, os.path.join(current_dir, "elephas_icon.png"))
        print(f"Created app icon: {os.path.join(current_dir, 'elephas_icon.png')}")
        
        print("\nSuccessfully created all required logo files!")
        print("Note: All files are identical copies since image processing is not available.")
        print("You can now use these images in your Elephas AI app.")
        print("\nTo get better results, you may want to manually create:")
        print("1. A square version of your logo (elephas_logo.png)")
        print("2. A smaller icon version (elephas_icon.png)")
        return 0
        
    except Exception as e:
        print(f"Error processing image: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
