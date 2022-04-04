# webp - tool for automated image conversion to webp

Todays internet browsers support the webp format for a long time now. However most
of the images are stored using jpg, png or still gif file format. This results in
big image sizes which is not necessary today anymore.

The ksvu-webp tool uses well known image processing tools like gimp and imagemagick
to automate the conversion of existing jpg, png or gif images to the webp format.
The final step is choosing the file with the smallest file size after converting an
image from selected conversion tools.

## Prerequisites

The following tools are used and therefore need to be installed before using
**ksvu-webp.sh** script:

* **ImageMagick** (required) - https://imagemagick.org/
* **GIMP** (optional)        - https://www.gimp.org/
* **cwebp** (optional)       - https://developers.google.com/speed/webp/docs/cwebp
* **cjpeg**  (optional)      - https://github.com/mozilla/mozjpeg
* **pngquant** (optional)    - https://pngquant.org/

During script execution **sed** and **awk** are used for calculating various strings
and numbers. For visual comparison **firefox** or **google-chrome** can be used to
open original and converted images.

## Basic usage

Converting all jpg images within current directory using compression quality of 40 (-q40),
enabling verbose mode 2 (-v2) and showing conversion results using *ls -l* (-L):

    ksvu-webp.sh -q40 -v2 -L *.jpg

## An example

Converting a photo of the Perito Moreno glacier in Patagonia, Argentina shot in december
2013 by my self using SSIM metric target 0.95:

    ksvu-webp.sh -S95 -v4 -t -L Perito-Moreno-2013.jpg

Results in the following output:

    Converting Perito-Moreno-2013.jpg -> ./Perito-Moreno-2013.webp ...
        (height=0: width:2000 => 0 [100%], height:1500)
    	(Perito-Moreno-2013.jpg[2000,1500,quality=94] -> ./Perito-Moreno-2013.webp[2000,1500,quality=90]).
          (gimp: 898152 -> 401950 = 55.2%, quality=90, ssim=0.960801, timing: duration=5.46s, cpu duration=11.06s usage=203%).
      	  (cwebp: 898152 -> 325542 = 63.8%, quality=90, ssim=0.958907, timing: duration=7.08s, cpu duration=12.50s usage=177%).
          (magick: 898152 -> 365442 = 59.3%, quality=90, ssim=0.960608, timing: duration=10.00s, cpu duration=16.22s usage=162%)
	(using cwebp tool for ssim=0.95 target conversion (ssimsize=339492)
            (current ssim=0.958907 is greater than target ssim=0.95, diff=-0.009, quality_add=-3,quality=87[min:87,max=90]).
          (cwebp: 898152 -> 236470 = 73.7%, quality=87, ssim=0.948939, timing: duration=10.00s, cpu duration=16.22s usage=162%)
        (using cwebp ./Perito-Moreno-2013.webp version; size: 898152 -> 236470 = 73.7%; ssim=0.948939)
    -rw-rw-r-- 1 ruppert ruppert 898152 Mär 26 22:17 Perito-Moreno-2013.jpg
    -rw-rw-r-- 1 ruppert ruppert 236470 Apr  2 20:24 Perito-Moreno-2013.webp
    Conversion Perito-Moreno-2013.jpg (timing: duration=28.66s, cpu duration=52.07s usage=182%)  done
    Conversion summary: cwebp=1 (timing: duration=28.80s, cpu duration=52.19s usage=181%) 

![Perito Moreno glacier](https://github.com/klimaschutz-von-unten-de/webp/blob/main/Perito-Moreno-2013.webp "Perito-Moreno glacier in 2013")

## Main Options

With **ksvu-webp.sh --help** a complete list of available options are printed out. To start
converting images quickly here are the basic options to do so:

* **-q\<val>** or **--quality=\<val>** specifying the compression quality value as known from jpg images
* **-s\<val>** or **--scale=\<val>** specifying an image scale percentage value to scale down the image
* **-S[\<val>]** or **--compare-ssim[=\<val>]** if present SSIM metric is calculated for each conversion. If \<val> is specified try to convert using the specified target SSIM value.
* **-h\<val>** or **--height=\<val>** specifying the number of pixel for image height to scale down the image
* **-w\<val>** or **--width=\<val>** specifying the number of pixel for image width to scale down the image
* **-v[\<val>]** or **--verbose=\<val>** specifying the verbose level (range from 0 to 5). Defaults to 1. Zero indicates no output at all
* **-Q** or **--pngquant**: use pngquant with 256 colors for png images before converting to webp

## Contact

Stefan Ruppert <webp@klimaschutz-von-unten.de>  
Web:     https://ksvu.de/webp
Blog:    https://klimaschutz-von-unten.de/ (in german)  
Twitter: https://twitter.com/unten_de  

## License

ksvu-webp.sh tool is licensed under the GPLv3.
