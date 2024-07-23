import sys
import json
import os
import numpy as np
from PyQt5.QtWidgets import QApplication, QLabel, QLineEdit, QPushButton, QVBoxLayout, QHBoxLayout, QWidget, QFileDialog
from PyQt5.QtGui import QPixmap, QImage
from PyQt5.QtCore import Qt
from PIL import Image, ImageDraw, ImageFont

class ImageLabeler(QWidget):
    def __init__(self, annotation_file, annotation_dir, image_dir, output_dir):
        super().__init__()
        self.annotation_file = annotation_file
        self.annotation_dir = annotation_dir
        self.image_dir = image_dir
        self.output_dir = output_dir
        self.annotations = self.load_annotations()
        self.current_index = 0
        self.scale_factor = 1.0

        # 缓存
        self.image_cache = {}
        self.annotation_cache = {}

        self.initUI()

    def load_annotations(self):
        annotations = []
        with open(self.annotation_file, 'r') as f:
            lines = f.readlines()
            for line in lines:
                img_name = line.split('&')[0]
                json_file = os.path.join(self.annotation_dir, img_name.replace('.jpg', '.json'))
                if os.path.exists(json_file):
                    annotations.append(img_name)
        return annotations

    def load_image_and_annotation(self, img_name):
        # 检查缓存
        if img_name in self.image_cache and img_name in self.annotation_cache:
            return self.image_cache[img_name], self.annotation_cache[img_name]

        # 加载图像
        img_path = os.path.join(self.image_dir, img_name)
        image = Image.open(img_path)

        # 加载注释
        json_file = os.path.join(self.annotation_dir, img_name.replace('.jpg', '.json'))
        with open(json_file, 'r') as jf:
            annotation = json.load(jf)

        # 缓存图像和注释
        self.image_cache[img_name] = image
        self.annotation_cache[img_name] = annotation

        return image, annotation

    def initUI(self):
        self.setWindowTitle('Image Labeler')

        self.layout = QVBoxLayout()

        self.image_label = QLabel(self)
        self.image_label.setAlignment(Qt.AlignCenter)
        self.layout.addWidget(self.image_label)

        self.input_field = QLineEdit(self)
        self.layout.addWidget(self.input_field)

        button_layout = QHBoxLayout()

        self.prev_button = QPushButton('上一张', self)
        self.prev_button.clicked.connect(self.prev_image)
        button_layout.addWidget(self.prev_button)

        self.next_button = QPushButton('下一张', self)
        self.next_button.clicked.connect(self.next_image)
        button_layout.addWidget(self.next_button)

        self.zoom_in_button = QPushButton('放大', self)
        self.zoom_in_button.clicked.connect(self.zoom_in)
        button_layout.addWidget(self.zoom_in_button)

        self.zoom_out_button = QPushButton('缩小', self)
        self.zoom_out_button.clicked.connect(self.zoom_out)
        button_layout.addWidget(self.zoom_out_button)

        self.layout.addLayout(button_layout)

        self.setLayout(self.layout)

        self.display_image()

    def display_image(self):
        if self.current_index < len(self.annotations):
            img_name = self.annotations[self.current_index]
            image, annotation = self.load_image_and_annotation(img_name)

            # Draw annotations
            annotated_image = image.copy()
            draw = ImageDraw.Draw(annotated_image)

            # Set font size
            font = ImageFont.truetype("arial.ttf", 40)

            for shape in annotation.get('shapes', []):
                if shape['shape_type'] == 'rectangle':
                    points = shape['points']
                    label = shape['label'].split("-")[0]
                    draw.rectangle([tuple(points[0]), tuple(points[1])], outline="red", width=3)
                    draw.text((points[0][0]-20, points[0][1] - 20), label, fill="red", font=font)

            # Convert PIL image to QPixmap using NumPy
            image_np = np.array(annotated_image)
            if image_np.ndim == 2:  # grayscale image
                height, width = image_np.shape
                qimage = QImage(image_np.data, width, height, QImage.Format_Grayscale8)
            elif image_np.shape[2] == 3:  # RGB image
                height, width, channel = image_np.shape
                bytes_per_line = 3 * width
                qimage = QImage(image_np.data, width, height, bytes_per_line, QImage.Format_RGB888)
            elif image_np.shape[2] == 4:  # RGBA image
                height, width, channel = image_np.shape
                bytes_per_line = 4 * width
                qimage = QImage(image_np.data, width, height, bytes_per_line, QImage.Format_RGBA888)

            pixmap = QPixmap.fromImage(qimage)
            self.image_label.setPixmap(pixmap.scaled(self.image_label.size() * self.scale_factor, Qt.KeepAspectRatio))

    def next_image(self):
        if self.current_index < len(self.annotations) - 1:
            img_name = self.annotations[self.current_index]
            text = self.input_field.text()
            if text:
                with open(os.path.join(self.output_dir, 'final_error.txt'), 'a') as f:
                    f.write(f"{img_name}_{text}\n")
            self.current_index += 1
            self.input_field.clear()
            self.scale_factor = 1.0  # Reset scale factor
            self.display_image()
        else:
            self.image_label.setText("没有更多图片")
            self.input_field.setDisabled(True)
            self.next_button.setDisabled(True)

    def prev_image(self):
        if self.current_index > 0:
            self.current_index -= 1
            self.scale_factor = 1.0  # Reset scale factor
            self.display_image()

    def zoom_in(self):
        self.scale_factor *= 1.2
        self.display_image()

    def zoom_out(self):
        self.scale_factor /= 1.2
        self.display_image()

if __name__ == '__main__':
    app = QApplication(sys.argv)

    annotation_file = QFileDialog.getOpenFileName(None, "选择错误文件", "", "Text Files (*.txt)")[0]
    annotation_dir = QFileDialog.getExistingDirectory(None, "选择标注文件夹")
    image_dir = QFileDialog.getExistingDirectory(None, "选择图片文件夹")
    output_dir = QFileDialog.getExistingDirectory(None, "选择输出文件夹")

    if annotation_file and annotation_dir and image_dir and output_dir:
        labeler = ImageLabeler(annotation_file, annotation_dir, image_dir, output_dir)
        labeler.show()
        sys.exit(app.exec_())
