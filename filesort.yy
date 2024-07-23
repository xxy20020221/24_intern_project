# -*- coding: utf-8 -*-
import json
import os
import random
from tqdm import tqdm
from PIL import Image
import argparse

classes = {"LiquidLevel", "RotaryButton", "WaterDrop", "GateValveLabelInner", "GateValveLabelOuter", "DigitalMeter", "BallValve","PointMeter"}
subClasses = {"LiquidLevel": 3, "RotaryButton": 2, "BallValve": 2, "GateValveLabelInner": 2, "GateValveLabelOuter": 2}

file_dir = "./data"
image_dir = "./images/images_water_mark"
output_dir = "./output"
template_dir = "./templates"

def checkIdConsistency(labels, subClasses, image_name):
    group_ids = set()
    extra_ids = {}
    class_name_mapping = {}

    errors = []

    # First pass: record all necessary information
    for label in labels:
        label_text = label["label"]

        if '-group_' in label_text and 'visibility_' not in label_text:
            parts = label_text.split('-group_')
            class_name = parts[0]
            group_id = int(parts[1])

            if group_id in group_ids:
                errors.append(f"图片 {image_name}: 标注 {label_text} 中存在重复的 group id {group_id}")
            group_ids.add(group_id)

            if class_name in subClasses:
                if group_id not in extra_ids:
                    extra_ids[group_id] = []
                class_name_mapping[group_id] = class_name

        elif '-group_' in label_text and 'visibility_' in label_text:
            parts = label_text.split('-group_')
            class_part = parts[0]
            visibility_part = parts[1].split('-visibility_')
            class_name, extra_id = class_part.rsplit('_', 1)
            group_id = int(visibility_part[0])
            visibility = int(visibility_part[1])

            extra_id = int(extra_id)

            if group_id not in extra_ids:
                extra_ids[group_id] = []
            extra_ids[group_id].append(extra_id)

    # Second pass: process recorded information
    if group_ids:
        sorted_group_ids = sorted(group_ids)
        expected_group_ids = list(range(1, max(sorted_group_ids) + 1))
        if sorted_group_ids != expected_group_ids:
            errors.append(f"图片 {image_name}: group id 不连续，期望 {expected_group_ids}，实际 {sorted_group_ids}")

    for group_id, extra_id_list in extra_ids.items():
        if group_id in class_name_mapping:
            class_name = class_name_mapping[group_id]
            extra_id_list.sort()
            expected_extra_ids = list(range(subClasses[class_name]))
            if extra_id_list != expected_extra_ids:
                errors.append(f"图片 {image_name}: 标注 {class_name}-group_{group_id} 的额外标注 id 不正确，期望 {expected_extra_ids}，实际 {extra_id_list}")

    return errors


def main(args):
    sample_size = args.sample_size
    files = [f for f in os.listdir(file_dir) if f.endswith('.json')]
    image_files = [f for f in os.listdir(image_dir) if f.endswith('.jpg')]
    all_errors = []
    total_images = len(files)
    error_images = set()
    valid_images = []

    for file_name in tqdm(files):
        with open(os.path.join(file_dir, file_name), 'r') as f:
            annotation = json.load(f)
        
        image_name = annotation['imagePath']
        labels = annotation['shapes']
        if labels == None:
            continue
        errors = checkIdConsistency(labels, subClasses, image_name)
        if errors:
            error_images.add(image_name)
        else:
            valid_images.append(image_name)
        all_errors.extend(errors)

    

    # 裁剪并保存子图
    if args.generate_templates:
        selected_images = random.sample(valid_images, min(sample_size, len(valid_images)))
        for image_name in tqdm(selected_images):
            json_file_name = image_name.replace('.jpg', '.json')
            with open(os.path.join(file_dir, json_file_name), 'r') as f:
                annotation = json.load(f)

            labels = annotation['shapes']
            image_path = os.path.join(image_dir, image_name)
            image = Image.open(image_path)

            for label in labels:
                if label['shape_type'] == 'rectangle':
                    points = label['points']
                    x1, y1 = points[0]
                    x2, y2 = points[1]
                    cropped_image = image.crop((x1, y1, x2, y2))
                    output_image_path = os.path.join(template_dir, f"{label['label']}_{os.path.basename(image_path)}")
                    cropped_image.save(output_image_path)

    with open(os.path.join(output_dir, 'errors.txt'), 'w') as f:
        for error in all_errors:
            f.write(error + '\n')

    print(f"检测了 {total_images} 张图片，出错的图片数量为 {len(error_images)} 张。")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process some images.')
    parser.add_argument('--generate_templates',action="store_true")
    parser.add_argument('--sample_size', type=int, default=100, help='Number of images to sample for sub-image templates')
    
    args = parser.parse_args()
    main(args)
