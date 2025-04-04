import cv2 as cv
import numpy as np
import argparse
import tkinter as tk
from tkinter import ttk
from PIL import Image, ImageTk

src = None
max_kernel_size = 21
max_shape = 2  # 0: Rect, 1: Cross, 2: Ellipse
title_window = 'Morphological Operations'
threshold_value = 128  # Default threshold value
max_threshold = 255  # Maximum threshold value

def main(image_path):
    global src
    src = cv.imread(cv.samples.findFile(image_path))
    if src is None:
        print('Could not open or find the image: ', image_path)
        exit(0)

    # Double the size of the image
    src = cv.resize(src, (src.shape[1] * 3, src.shape[0] * 3))
    
    # Create the main window
    root = tk.Tk()
    root.title(title_window)

    # Set a maximum width for the window
    # root.geometry("400x400")  # Adjust the width and height as needed

    # Create sliders with a fixed width
    dilate_shape_slider = ttk.Scale(root, from_=0, to=max_shape, orient=tk.HORIZONTAL)
    dilate_size_slider = ttk.Scale(root, from_=0, to=max_kernel_size, orient=tk.HORIZONTAL)
    erode_shape_slider = ttk.Scale(root, from_=0, to=max_shape, orient=tk.HORIZONTAL)
    erode_size_slider = ttk.Scale(root, from_=0, to=max_kernel_size, orient=tk.HORIZONTAL)
    threshold_slider = ttk.Scale(root, from_=0, to=max_threshold, orient=tk.HORIZONTAL)

    # Create labels for sliders
    dilate_shape_label = ttk.Label(root, text="Dilate Shape: 0")
    dilate_size_label = ttk.Label(root, text="Dilate Size: 9")
    erode_shape_label = ttk.Label(root, text="Erode Shape: 0")
    erode_size_label = ttk.Label(root, text="Erode Size: 9")
    threshold_label = ttk.Label(root, text="B&W Threshold: 128")

    # Set default values
    dilate_shape_slider.set(0)
    dilate_size_slider.set(9)
    erode_shape_slider.set(0)
    erode_size_slider.set(9)
    threshold_slider.set(threshold_value)

    # Pack labels and sliders
    dilate_shape_label.pack(fill=tk.X, padx=10, pady=5)
    dilate_shape_slider.pack(fill=tk.X, padx=10, pady=5, expand=True)
    dilate_size_label.pack(fill=tk.X, padx=10, pady=5)
    dilate_size_slider.pack(fill=tk.X, padx=10, pady=5, expand=True)
    erode_shape_label.pack(fill=tk.X, padx=10, pady=5)
    erode_shape_slider.pack(fill=tk.X, padx=10, pady=5, expand=True)
    erode_size_label.pack(fill=tk.X, padx=10, pady=5)
    erode_size_slider.pack(fill=tk.X, padx=10, pady=5, expand=True)
    threshold_label.pack(fill=tk.X, padx=10, pady=5)
    threshold_slider.pack(fill=tk.X, padx=10, pady=5, expand=True)

    # Create a label to display the image
    image_label = ttk.Label(root)
    image_label.pack(padx=10, pady=10)

    def update():
        dilate_shape = int(dilate_shape_slider.get())
        dilate_size = int(dilate_size_slider.get())
        erode_shape = int(erode_shape_slider.get())
        erode_size = int(erode_size_slider.get())
        threshold_value = int(threshold_slider.get())

        # Update labels with current slider values
        dilate_shape_label.config(text=f"Dilate Shape: {dilate_shape}")
        dilate_size_label.config(text=f"Dilate Size: {dilate_size}")
        erode_shape_label.config(text=f"Erode Shape: {erode_shape}")
        erode_size_label.config(text=f"Erode Size: {erode_size}")
        threshold_label.config(text=f"B&W Threshold: {threshold_value}")

        # Convert to grayscale
        gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY)

        # Apply threshold
        _, result = cv.threshold(gray, threshold_value, 255, cv.THRESH_BINARY)

        # Create structuring elements
        dilate_element = cv.getStructuringElement(morph_shape(dilate_shape), 
                                                  (2 * dilate_size + 1, 2 * dilate_size + 1),
                                                  (dilate_size, dilate_size)) if dilate_size > 0 else None
        erode_element = cv.getStructuringElement(morph_shape(erode_shape), 
                                                 (2 * erode_size + 1, 2 * erode_size + 1),
                                                 (erode_size, erode_size)) if erode_size > 0 else None

        # Apply dilation and erosion
        if dilate_element is not None:
            result = cv.dilate(result, dilate_element)
        if erode_element is not None:
            result = cv.erode(result, erode_element)

        # Create a copy of the result to draw text on
        display = cv.cvtColor(result, cv.COLOR_GRAY2BGR)

        # Convert OpenCV image to PIL Image
        image = Image.fromarray(cv.cvtColor(display, cv.COLOR_BGR2RGB))
        
        # Convert PIL Image to ImageTk
        photo = ImageTk.PhotoImage(image)
        
        # Update the image in the label
        image_label.config(image=photo)
        image_label.image = photo  # Keep a reference to prevent garbage collection

        # Schedule the next update
        root.after(100, update)

    # Start the update loop
    update()

    # Start the Tkinter event loop
    root.mainloop()

def morph_shape(val):
    return cv.MORPH_RECT if val == 0 else cv.MORPH_CROSS if val == 1 else cv.MORPH_ELLIPSE

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Code for Eroding and Dilating tutorial.')
    parser.add_argument('--input', help='Path to input image.', default='bank.png')
    args = parser.parse_args()
    main(args.input)
