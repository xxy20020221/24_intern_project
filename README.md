图片放在./image/images_water_mark下
标注放在./data下
模板放在./templates下，命名格式"[label]_[imgName].jpg"
输出放在./output下，errors.txt是id错误，middle.txt是匹配错误

先运行filesort，手动筛选模板，然后运行final。
如果需要文件输出和图片输出相互转换，运行summarize，其中图片转文字参数为"summarize"，文字转图片参数为"desummarize"