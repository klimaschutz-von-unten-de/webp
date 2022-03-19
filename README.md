# webp - tool for automated image conversion to webp

Todays internet browsers support the webp format for a long time now.
However most of the images are stored using jpg, png or still gif file
format. This results in big image sizes which is not necessary today
anymore.

The ksvu-webp tool uses the well known image processing tools gimp and
imagemagick to automate the conversion of existing jpg, png or gif images
to the webp format by choosing the file with the smallest file size after
converting an image with both tools.

## Prerequisites

The following tools are used and therefore need to be installed before using
ksvu-webp.sh script:

* **ImageMagick** - https://imagemagick.org/
* **GIMP**        - https://www.gimp.org/
* **pngquant**    - https://pngquant.org/

During script execution **sed** and **awk** are used for calculating various strings
and numbers. For visual comparison **firefox** is used to open original and converted
images.

## Basic usage

Converting all jpg images within current directory using compression quality of 40 (-q40),
enabling verbose mode 2 (-v2) and showing conversion results using *ls -l* (-L):

    ksvu-webp.sh -q40 -v2 -L *.jpg

## An example

Converting a photo of the Perito Moreno glacier in Patagonia, Argentina shot in december
2013 by my self:

    ksvu-webp.sh -q40 -v2 -L Perito-Moreno-2013.jpg

Results in the following output:

    Converting Perito-Moreno-2013.jpg -> Perito-Moreno-2013.webp ... (height=0: 2000 => 2000 [100%], height:1500)
    (Perito-Moreno-2013.jpg[2000,1500,lossless=0] -> Perito-Moreno-2013-gimp.webp[2000,1500])
    (gimp: 898152 -> 70258 = 92.2%) (height=0: 2000 => 0 [100%], height:1500)
    (Perito-Moreno-2013.jpg[2000,1500,lossless=0] -> Perito-Moreno-2013-magick.webp[2000,1500])
    (magick: 898152 -> 67518 = 92.5%) (using imagemagick Perito-Moreno-2013.webp version) done
    -rw-rw-r-- 1 ruppert ruppert 898152 Mär 19 12:18 Perito-Moreno-2013.jpg
    -rw-rw-r-- 1 ruppert ruppert  67518 Mär 19 14:23 Perito-Moreno-2013.webp

## Main Options

With **ksvu-webp.sh --help** a complete list of available options are printed out. To start
converting images quickly here are the basic options to do so:

* **-q<val>** or **--quality <val>** specifying the compression quality value as known from jpg images
* **-s<val>** or **--scale <val>** specifying an image scale percentage value to scale down the image
* **-h<val>** or **--height <val>** specifying the number of pixel for image height to scale down the image
* **-w<val>** or **--width <val>** specifying the number of pixel for image width to scale down the image
* **-v<val>** or **--verbose <val>** specifying the verbose level (range from 0 to 3). Defaults to 1. Zero indicates no output at all
* **-Q** or **--pngquant**: use pngquant with 256 colors for png images before converting to webp

## Contact

Stefan Ruppert <webp@klimaschutz-von-unten.de>
Web:     https://klimaschutz-von-unten.de/
Twitter: https://twitter.com/unten_de
