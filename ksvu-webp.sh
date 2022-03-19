#!/usr/bin/env bash
#
# Author: Stefan Ruppert <webp@klimaschutz-von-unten.de>
# License: GNU GENERAL PUBLIC LICENSE Version 3
#
# pre-conditions
# installed tools: gimp, imagemagick (convert, identity), pngquant,
#                  awk, sed and firefox for comparing converted and
#                  original images 
#

# script options
opt_compare=0
opt_compare_conv=0
opt_fixhtml=0
opt_force=0
opt_height=0
opt_list=0
opt_lossless=-1
opt_midfix=""
opt_overview=0
opt_pngcolors=256
opt_pngquant=0
opt_quality=70
opt_scale=0
opt_verbose=1
opt_width=0

# script variables

var_lossless=0
var_png=0

function ksvu-webp-help()
{
    echo "ksvu-webp [options] image1 [image2] [...]"
    echo "Options:"
    echo "-c, --compare"
    echo "    compare original and converted image using 2 new firefox windows"
    echo "-C, --compare-conv"
    echo "    compare imagemagick and gimp converted images using 2 new firefox windows"
    echo "-f, --fixhtml"
    echo "    change any reference from .jpg, .gif, .png to .webp using sed within passed"
    echo "    html files"
    echo "--force"
    echo "    force installing gimp ksvu-scale-webp.scn script"
    echo "--help"
    echo "    prints this help page"
    echo "-h[pixel], --height[=pixel]"
    echo "    specifies the height number of pixel to scale the image"
    echo "-l[0|1], --lossless[=0|1]"
    echo "    specifies lossless (=1) or none lossless (=0) encoding"
    echo "-L, --list"
    echo "    list original and converted image showing file size using ls -l"
    echo "-m[string], --midfix[=string]"
    echo "    specifies the midfix string used for constructing the filename of"
    echo "    the converted image"
    echo "-o, --overview"
    echo "    prints overview of old (jpg, png, gif) and new webp image file size"
    echo "-q[percent], --quality[=percent]"
    echo "    specifies the quality factor used lossy compression mode,"
    echo "    disables lossless encoding. Default is 70."
    echo "-Q, --pngquant"
    echo "    for png images run pngquant tool"
    echo "--pngcolors[=colors]"
    echo "    number of colors to use for pngquant"
    echo "--quiet"
    echo "    sets verbose mode to zero avoiding any output"
    echo "-s[percent], --scale[=percent]"
    echo "    specifies the scaling factor in percent"
    echo "-v[#], --verbose[=#]"
    echo "    sets verbose mode with optionally passed verbose level"
    echo "-w[pixel], --width[=pixel]"
    echo "    specifies the width number of pixel to scale the image"
    exit 0
}
function ksvu-gimp-prepare()
{
    version=$(gimp --version | cut -d" " -f6 | cut -d"." -f1-2)
    confdir=$HOME/.config/GIMP/$version/scripts
    if test -d $confdir; then
	if test ! -f $confdir/ksvu-scale-webp.scm -o $opt_force -eq 1; then
	    echo "Installing ksvu-scale-webp.scm into $confdir directory"
	    cat >$confdir/ksvu-scale-webp.scm <<EOF
(define (ksvu-scale-webp in_filename out_filename width height quality lossless)
  (let* (
	 (image (car (gimp-file-load RUN-NONINTERACTIVE in_filename in_filename)))
	 (drawable (car (gimp-image-get-active-layer image)))
	 )
    (gimp-image-scale image width height)
    (file-webp-save RUN-NONINTERACTIVE image drawable out_filename out_filename 2 lossless quality 100 0 0 0 1 1 1 1 0 0)
    (gimp-image-delete image)
    )
)
EOF
	fi
    fi
}

function ksvu-printf()
{
    level=$1
    shift
    if test $opt_verbose -ge $level; then
	printf "$*"
    fi
}

function ksvu-webp-convert-gimp()
{
    imgwidth=$opt_width
    imgheight=$opt_height
    # get image width and height
    inpwidth=$(identify -format "%w" "$1")
    inpheight=$(identify -format "%h" "$1")
    if test $opt_scale -gt 0; then
	imgwidth=$(echo "" | awk -v iw=$inpwidth -v p=$opt_scale 'END { printf "%.0f", (iw*p)/100 }')
	ksvu-printf 2 " (scale=$opt_scale%%: $inpwidth => $imgwidth)"
    fi
    if test $imgwidth -eq 0; then
	imgwidth=$inpwidth
    fi
    if test $imgheight -eq 0; then
	tmppercent=$(echo "" | awk -v iw=$inpwidth -v w=$imgwidth 'END { printf "%d", w*100/iw }')
	imgheight=$(echo "" | awk -v iw=$inpwidth -v ih=$inpheight -v w=$imgwidth 'END { printf "%d", ih*w/iw }')
	ksvu-printf 2 " (height=0: width:$inpwidth => $imgwidth [$tmppercent%%], height:$imgheight)"
    else
	imgwidth=$(echo "" | awk -v iw=$inpwidth -v ih=$inpheight -v h=$imgheight 'END { printf "%d", iw*h/ih }')
    fi
    ksvu-printf 2 " ($1[$inpwidth,$inpheight,lossless=$var_lossless] -> $2[$imgwidth,$imgheight])"
    gimp -i -b "(ksvu-scale-webp \"$1\" \"$2\" $imgwidth $imgheight $opt_quality $var_lossless)" -b "(gimp-quit 0)" 2>/dev/null
}

function ksvu-webp-convert-magick()
{
    imgwidth=$opt_width
    imgheight=$opt_height
    # get image width and height
    inpwidth=$(identify -format "%w" "$1")
    inpheight=$(identify -format "%h" "$1")
    if test $opt_scale -gt 0; then
	imgwidth=$(echo "" | awk -v iw=$inpwidth -v p=$opt_scale 'END { printf "%.0f", (iw*p)/100 }')
	ksvu-printf 2 " (scale=$opt_scale%%: $inpwidth => $imgwidth)"
    fi
    if test $imgwidth -eq 0; then
	imgwidth=$inpwidth
    fi
    if test $imgheight -eq 0; then
	tmppercent=$(echo "" | awk -v iw=$inpwidth -v w=$imgwidth 'END { printf "%d", w*100/iw }')
	imgheight=$(echo "" | awk -v iw=$inpwidth -v ih=$inpheight -v w=$imgwidth 'END { printf "%d", ih*w/iw }')
	ksvu-printf 2 " (height=0: width:$inpwidth => $opt_width [$tmppercent%%], height:$imgheight)"
    else
	imgwidth=$(echo "" | awk -v iw=$inpwidth -v ih=$inpheight -v h=$imgheight 'END { printf "%d", iw*h/ih }')
    fi

    magick_lossless=""
    if test $var_lossless -eq 1; then
	magick_lossless="-define webp:lossless=true"
    fi
    if test $opt_lossless -ne -1; then
	if test $var_lossless -eq 1; then
	    magick_lossless="-define webp:lossless=true"
	else
	    magick_lossless="-define webp:lossless=false"
	fi
    fi
    ksvu-printf 2 " ($1[$inpwidth,$inpheight,lossless=$var_lossless] -> $2[$imgwidth,$imgheight])"
    convert -quality $opt_quality -resize "${imgwidth}x${imgheight}" $magick_lossless -define webp:thread-level=0 -define webp:pass=10 -define webp:preprocessing=1 -define webp:method=6 -define webp:image-hint:photo "$1" "$2"
}

function ksvu-compress-ratio()
{
    inpsize=$(ls -l "$2" | sed -e 's/  */ /g' | cut -d" " -f5)
    outsize=$(ls -l "$3" | sed -e 's/  */ /g' | cut -d" " -f5)
    ratio=$(echo "" | awk -v is=$inpsize -v os=$outsize 'END { printf "%.1f", (1-(os/is))*100 }')
    if test -z "$1"; then
	ksvu-printf 1 " ($inpsize -> $outsize = ${ratio}%%)"
    else
	ksvu-printf 2 " ($1: $inpsize -> $outsize = ${ratio}%%)"
    fi
}

function ksvu-imagesize-sum()
{
    awk 'BEGIN { sum=0; num=0; } // { sum += $1; num++;} END { printf "files=%d;size=%d\n", num, sum; }'
}
function ksvu-imagesize-old()
{
    printf "Image size old: "
    ls *.jpg *.gif *.png 2>/dev/null | xargs ls -l | cut -b 29-36 | ksvu-imagesize-sum
}
function ksvu-imagesize-webp()
{
    printf "Image size webp: "
    ls *.webp | xargs ls -l | cut -b 29-36 | ksvu-imagesize-sum
}

function ksvu-size-overview()
{
    ksvu-imagesize-old
    ksvu-imagesize-webp

    oldsize=$(ksvu-imagesize-old | cut -d";" -f 2 | cut -d"=" -f2)
    newsize=$(ksvu-imagesize-webp | cut -d";" -f 2 | cut -d"=" -f2)

    echo "" | awk -v os=$oldsize -v ns=$newsize ' END { printf "Reduction: %.1f%%\n", (1 - ns/os)*100; }'
}

OPTS=$(getopt -o v::cCl:Ls:w:h:oq:Qfm: --long verbose::,help,compare,compare-conv,lossless:,list,scale:,width:,height:,overview,quality:,pngquant,pngcolors:,midfix:,fixhtml,force,quiet -n "ksvu-webp" -- "$@")

if test $? != 0; then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$OPTS"

while true ; do
    case "$1" in
	-v|--verbose)
	    case "$2" in
		"")
		    opt_verbose=1
		    ;;
		*)
		    opt_verbose=$2
		    ;;
	    esac
	    shift 2
	    ;;
	--help)
	    ksvu-webp-help
	    ;;
	--quiet)
	    opt_verbose=0
	    shift
	    ;;
	-c|--compare)
	    opt_compare=1
	    shift
	    ;;
	-C|--compare-conv)
	    opt_compare_conv=1
	    shift
	    ;;
	-l|--lossless)
	    opt_lossless=$2
	    shift 2
	    ;;
	-L|--list)
	    opt_list=1
	    shift
	    ;;
	-s|--scale)
	    opt_scale=$2
	    shift 2
	    ;;
	-w|--width)
	    opt_width=$2
	    shift 2
	    ;;
	-h|--height)
	    opt_height=$2
	    shift 2
	    ;;
	-o|--overview)
	    opt_overview=1
	    shift 1
	    ;;
	-q|--quality)
	    opt_lossless=0
	    opt_quality=$2
	    shift 2
	    ;;
	-Q|--pngquant)
	    opt_pngquant=1;
	    shift 1
	    ;;
	--pngcolors)
	    opt_pngcolors=$2
	    shift 2
	    ;;
	-m|--midfix)
	    opt_midfix="$2"
	    shift 2
	    ;;
	--force)
	    opt_force=1
	    shift
	    ;;
	-f|--fixhtml)
	    opt_fixhtml=1
	    shift
	    ;;
	--)
	    shift
	    break;
	    ;;
	*)
	    echo "Unknown option: $1"
	    exit 1
	    ;;
    esac
done

if test $opt_fixhtml -eq 1; then
    for arg; do
	echo "$arg: fixing html images to .webp"
	sed -i -e 's/\.png/\.webp/g' -e 's/\.jpg/\.webp/g' -e 's/\.gif/\.webp/g' $arg
    done
    exit 0
elif test $opt_overview -eq 1; then
    ksvu-size-overview
    exit 0
fi

ksvu-printf 3 "Parameters used:\n"
ksvu-printf 3 "    width: $opt_width\n"
ksvu-printf 3 "    height: $opt_height\n"
ksvu-printf 3 "    lossless: $opt_lossless\n"
ksvu-printf 3 "    quality: $opt_quality\n"
ksvu-printf 3 "    scale: $opt_scale\n"
ksvu-printf 3 "    midfix: $opt_midfix\n"

ksvu-gimp-prepare

for arg; do
    if test ! -f "$arg"; then
	ksvu-printf -1 "Error: file \"$arg\" not found\n"
	continue
    fi
    suffix=$(echo "$arg"| tr "." "\012" | tail -1)
    lsuffix=$(echo $suffix | tr "[A-Z]" "[a-z]")
    case $suffix in
	png)
	    var_png=1
	    var_lossless=1
	    ;;
	gif)
	    var_lossless=1
	    ;;
	jpg|jpeg)
	    var_lossless=0
	    ;;
	*)
	    var_lossless=0
	    ;;
    esac
    if test $opt_lossless -ne -1; then
	var_lossless=$opt_lossless
    fi
    name=$(basename "$arg" .$suffix)
    inp="$arg"
    inp2="$inp"
    
    ksvu-printf 1 "Converting $inp"
    if test $var_png -eq 1 -a $opt_pngquant -eq 1; then
	ksvu-printf 1 " -> $name-q.png "
	pngquant --speed 1 --nofs $opt_pngcolors -o "$name-q.png" "$inp"
	inp2="$name-q.png"
    fi
    out="${name}${opt_midfix}"
    outfile="${out}.webp"
    ksvu-printf 1 " -> $outfile ..."
    ksvu-webp-convert-gimp "$inp2" "$out-gimp.webp"
    ksvu-compress-ratio gimp "$inp2" "$out-gimp.webp"
    size_gimp=$outsize

    ksvu-webp-convert-magick "$inp2" "$out-magick.webp"
    ksvu-compress-ratio magick "$inp2" "$out-magick.webp"
    size_magick=$outsize

    if test $opt_compare_conv -eq 1; then
	firefox --new-window "$out-magick.webp" --new-window "$out-gimp.webp"
	sleep 5
    fi
    if test $size_gimp -lt $size_magick; then
	ksvu-printf 2 " (using gimp $outfile version)"
	mv "$out-gimp.webp" "$outfile"
	rm "$out-magick.webp"
    else
	ksvu-printf 2 " (using imagemagick $outfile version)"
	mv "$out-magick.webp" "$outfile"
	rm "$out-gimp.webp"
    fi
    if test $opt_compare -eq 1; then
	firefox --new-window "$inp" --new-window "$out.webp"
    fi
    if test $opt_verbose -eq 1; then
	ksvu-compress-ratio "" "$inp" "$out.webp"
    fi
    ksvu-printf 1 " done\n"
    if test $opt_list -eq 1; then
	ls -lrt "${name}"*
    fi
    if test -f "$name-q.png"; then
	rm -f "$name-q.png"
    fi
done




