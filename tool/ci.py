import cv2
import numpy as np
import os

def add_vertical_lines(image, line_interval=10):
    # Convert image to grayscale and then to binary
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    _, binary = cv2.threshold(gray, 128, 255, cv2.THRESH_BINARY)

    # Create vertical lines at regular intervals
    for x in range(0, binary.shape[1], line_interval):
        binary[:, x] = 255  # Set the vertical line to white

    return binary

def erode_image(binary_image, kernel_size=(3, 3)):
    kernel = np.ones(kernel_size, np.uint8)
    eroded = cv2.erode(binary_image, kernel, iterations=1)
    return eroded
def dilate_image(binary_image, kernel_size=(3, 3)):
    kernel = np.ones(kernel_size, np.uint8)
    dilated = cv2.dilate(binary_image, kernel, iterations=1)
    return dilated

def find_contours_and_save(image, output_dir):
    # Erode the image to separate connected components
    eroded_image = erode_image(image)
    
    # Find contours of the characters
    contours, _ = cv2.findContours(eroded_image, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Create a directory to save the characters
    characters_dir = os.path.join(output_dir, 'characters')
    os.makedirs(characters_dir, exist_ok=True)

    # Iterate through each contour and save the characters
    for i, contour in enumerate(contours):
        x, y, w, h = cv2.boundingRect(contour)
        character = image[y:y+h, x:x+w]
        character_path = os.path.join(characters_dir, f'character_{i}.png')
        cv2.imwrite(character_path, character)

# Load your image
image = cv2.imread('casa_alberto.png')

# Add vertical lines and erode
binary_image = add_vertical_lines(image, line_interval=30)  # Increased line interval

# Create tmp directory if it doesn't exist
output_dir = 'tmp'
os.makedirs(output_dir, exist_ok=True)
for i in range(2):
    binary_image = dilate_image(binary_image, kernel_size=(4, 4))  # Adjusted kernel size
eroded_output_path = os.path.join(output_dir, 'dilate_image.png')
cv2.imwrite(eroded_output_path, binary_image)

for i in range(3):
    binary_image = erode_image(binary_image, kernel_size=(4, 4))  # Adjusted kernel size

# Save the eroded image
eroded_output_path = os.path.join(output_dir, 'eroded_image.png')
cv2.imwrite(eroded_output_path, binary_image)

# Find contours and save individual characters
find_contours_and_save(binary_image, output_dir)

print("Individual characters saved in the 'tmp/characters' directory.")