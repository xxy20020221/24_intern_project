import os
import cv2
import json
from tqdm import tqdm
import shutil
def summarize(output_dir, output_text_file):
    with open(output_text_file, 'w') as f:
        for root, dirs, files in os.walk(output_dir):
            for file in files:
                if file.endswith('.jpg'):
                    file = file.replace('.jpg','')
                    f.write(f"{file}\n")

def delete_all_folders_in_directory(directory):
    for root, dirs, files in os.walk(directory):
        for dir_name in dirs:
            shutil.rmtree(os.path.join(root, dir_name))

def desummarize(output_text_file, source_images_dir, annotation_dir, output_dir):
    delete_all_folders_in_directory(output_dir)
    with open(output_text_file, 'r') as f:
        lines = f.readlines()
        for line in tqdm(lines):
            file = line.strip()
            img_name, label_text, class_name, prediction_name = file.split('&')
            img_name = img_name+'.jpg'
            output_name = file+'.jpg'
            json_file_name = img_name.replace('.jpg', '.json')
            img_path = os.path.join(source_images_dir, img_name)
            json_path = os.path.join(annotation_dir, json_file_name)
            
            # Load the image
            img = cv2.imread(img_path)

            with open(json_path, 'r') as jf:
                annotation = json.load(jf)

            for shape in annotation['shapes']:
                if shape['label'] == label_text:
                    points = shape['points']
                    x1, y1 = int(points[0][0]), int(points[0][1])
                    x2, y2 = int(points[1][0]), int(points[1][1])
                    cv2.rectangle(img, (x1, y1), (x2, y2), (0, 0, 255), 2)
                    cv2.putText(img, prediction_name, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)

            # Create the output directory if it doesn't exist
            class_dir = os.path.join(output_dir, class_name)
            if not os.path.exists(class_dir):
                os.makedirs(class_dir)
            
            # Save the image
            output_path = os.path.join(class_dir, output_name)
            cv2.imwrite(output_path, img)

def main(mode, output_dir, output_text_file, source_images_dir, annotation_dir):
    if mode == 'summarize':
        summarize(output_dir, output_text_file)
    elif mode == 'desummarize':
        desummarize(output_text_file, source_images_dir, annotation_dir, output_dir)
    else:
        print("Invalid mode. Please use 'summarize' or 'desummarize'.")

if __name__ == '__main__':
    output_dir = "./output"
    output_text_file = "./output/middle.txt"
    source_images_dir = "./images/images_water_mark"
    annotation_dir = "./data"

    # Change mode to 'summarize' or 'desummarize'
    mode = 'desummarize'  # or 'desummarize'

    main(mode, output_dir, output_text_file, source_images_dir, annotation_dir)
