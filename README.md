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

*ImageMagick* - https://imagemagick.org/
*GIMP*        - https://www.gimp.org/
*pngquant*    - https://pngquant.org/

During script execution *sed* and *awk* are used for calculating various strings
and numbers. For visual comparison *firefox* is used to open original and converted
images.
