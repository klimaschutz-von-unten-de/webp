#!/usr/bin/env bash

# pre-conditions
# installed tools: gimp, imagemagick (convert, identity), pngquant,
#                  awk, sed and firefox for comparing converted and
#                  original images 
#

# script variables
compare=0
compare_conv=0
verbose=1
list=0
width=0
height=0
percent=0
quality=70
lossless=0
png=0
cmd_lossless=-1
cmd_pngquant=0
midfix=""
overview=0
fixhtml=0
force=0

function ksvu-webp-help()
{
    echo "ksvu-webp [options] image1 [image2] [...]"
    echo "Options:"
    echo "-c, --compare"
    echo "    compare original and converted image using 2 new firefox windows"
    echo "-C, --compare-conv"
    echo "    compare imagemagick and gimp converted images using 2 new firefox windows"
    echo "-f, --fixhtml"
    echo "    change any reference from .jpg, .gif, .png to .webp using sed"
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
    echo "    disables lossless encoding"
    echo "-Q, --pngquant"
    echo "    for png images run pngquant tool"
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
	if test ! -f $confdir/ksvu-scale-webp.scm -o $force -eq 1; then
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
    if test $verbose -ge $level; then
	printf "$*"
    fi
}

function ksvu-webp-convert-gimp()
{
    imgwidth=$width
    imgheight=$height
    # get image width and height
    inpwidth=$(identify -format "%w" "$1")
    inpheight=$(identify -format "%h" "$1")
    if test $percent -gt 0; then
	imgwidth=$(echo "" | awk -v iw=$inpwidth -v p=$percent 'END { printf "%.0f", (iw*p)/100 }')
	ksvu-printf 2 " (percent=$percent: $inpwidth => $imgwidth)"
    fi
    if test $imgwidth -eq 0; then
	imgwidth=$inpwidth
    fi
    if test $imgheight -eq 0; then
	tmppercent=$(echo "" | awk -v iw=$inpwidth -v w=$imgwidth 'END { printf "%d", w*100/iw }')
	imgheight=$(echo "" | awk -v iw=$inpwidth -v ih=$inpheight -v w=$imgwidth 'END { printf "%d", ih*w/iw }')
	ksvu-printf 2 " (height=0: $inpwidth => $imgwidth [$tmppercent%%], height:$imgheight)"
    fi
    ksvu-printf 2 " ($1[$inpwidth,$inpheight,lossless=$lossless] -> $2[$imgwidth,$imgheight])"
    gimp -i -b "(ksvu-scale-webp \"$1\" \"$2\" $imgwidth $imgheight $quality $lossless)" -b "(gimp-quit 0)" 2>/dev/null
}

function ksvu-webp-convert-magick()
{
    imgwidth=$width
    imgheight=$height
    # get image width and height
    inpwidth=$(identify -format "%w" "$1")
    inpheight=$(identify -format "%h" "$1")
    if test $percent -gt 0; then
	imgwidth=$(echo "" | awk -v iw=$inpwidth -v p=$percent 'END { printf "%.0f", (iw*p)/100 }')
	ksvu-printf 2 " (percent=$percent: $inpwidth => $imgwidth)"
    fi
    if test $imgwidth -eq 0; then
	imgwidth=$inpwidth
    fi
    if test $imgheight -eq 0; then
	tmppercent=$(echo "" | awk -v iw=$inpwidth -v w=$imgwidth 'END { printf "%d", w*100/iw }')
	imgheight=$(echo "" | awk -v iw=$inpwidth -v ih=$inpheight -v w=$imgwidth 'END { printf "%d", ih*w/iw }')
	ksvu-printf 2 " (height=0: $inpwidth => $width [$tmppercent%%], height:$imgheight)"
    fi

    magick_lossless=""
    if test $lossless -eq 1; then
	magick_lossless="-define webp:lossless=true"
    fi
    if test $cmd_lossless -ne -1; then
	if test $lossless -eq 1; then
	    magick_lossless="-define webp:lossless=true"
	else
	    magick_lossless="-define webp:lossless=false"
	fi
    fi
    ksvu-printf 2 " ($1[$inpwidth,$inpheight,lossless=$lossless] -> $2[$imgwidth,$imgheight])"
    convert -quality $quality -resize "${imgwidth}x${imgheight}" $magick_lossless -define webp:thread-level=0 -define webp:pass=10 -define webp:preprocessing=1 -define webp:method=6 -define webp:image-hint:photo "$1" "$2"
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

OPTS=$(getopt -o v::cCl:Ls:w:h:oq:Qfm: --long verbose::,help,compare,compare-conv,lossless:,list,scale:,width:,height:,overview,quality:,pngquant,midfix:,fixhtml,force,quiet -n "ksvu-webp" -- "$@")

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
		    verbose=1
		    ;;
		*)
		    verbose=$2
		    ;;
	    esac
	    shift 2
	    ;;
	--help)
	    ksvu-webp-help
	    ;;
	--quiet)
	    verbose=0
	    shift
	    ;;
	-c|--compare)
	    compare=1
	    shift
	    ;;
	-C|--compare-conv)
	    compare_conv=1
	    shift
	    ;;
	-l|--lossless)
	    cmd_lossless=$2
	    shift 2
	    ;;
	-L|--list)
	    list=1
	    shift
	    ;;
	-s|--scale)
	    percent=$2
	    shift 2
	    ;;
	-w|--width)
	    width=$2
	    shift 2
	    ;;
	-h|--height)
	    height=$2
	    shift 2
	    ;;
	-o|--overview)
	    overview=1
	    shift 1
	    ;;
	-q|--quality)
	    cmd_lossless=0
	    quality=$2
	    shift 2
	    ;;
	-Q|--pngquant)
	    cmd_pngquant=1;
	    shift 1
	    ;;
	-m|--midfix)
	    midfix="$2"
	    shift 2
	    ;;
	--force)
	    force=1
	    shift
	    ;;
	-f|--fixhtml)
	    fixhtml=1
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

if test $fixhtml -eq 1; then
    for arg; do
	echo "$arg: fixing html images to .webp"
	sed -i -e 's/\.png/\.webp/g' -e 's/\.jpg/\.webp/g' -e 's/\.gif/\.webp/g' $arg
    done
    exit 0
elif test $overview -eq 1; then
    ksvu-size-overview
    exit 0
fi

ksvu-printf 3 "Parameters used:\n"
ksvu-printf 3 "    width: $width\n"
ksvu-printf 3 "    height: $height\n"
ksvu-printf 3 "    lossless: $cmd_lossless\n"
ksvu-printf 3 "    quality: $quality\n"
ksvu-printf 3 "    percent: $percent\n"
ksvu-printf 3 "    midfix: $midfix\n"

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
	    png=1
	    lossless=1
	    ;;
	gif)
	    lossless=1
	    ;;
	jpg|jpeg)
	    lossless=0
	    ;;
	*)
	    lossless=0
	    ;;
    esac
    if test $cmd_lossless -ne -1; then
	lossless=$cmd_lossless
    fi
    name=$(basename "$arg" .$suffix)
    inp="$arg"
    inp2="$inp"
    
    ksvu-printf 1 "Converting $inp"
    if test $png -eq 1 -a $cmd_pngquant -eq 1; then
	ksvu-printf 1 " -> $name-q.png "
	pngquant --speed 1 --nofs 256 -o "$name-q.png" "$inp"
	inp2="$name-q.png"
    fi
    out="${name}${midfix}"
    outfile="${out}.webp"
    ksvu-printf 1 " -> $outfile ..."
    ksvu-webp-convert-gimp "$inp2" "$out-gimp.webp"
    ksvu-compress-ratio gimp "$inp2" "$out-gimp.webp"
    size_gimp=$outsize

    ksvu-webp-convert-magick "$inp2" "$out-magick.webp"
    ksvu-compress-ratio magick "$inp2" "$out-magick.webp"
    size_magick=$outsize

    if test $compare_conv -eq 1; then
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
    if test $compare -eq 1; then
	firefox --new-window "$inp" --new-window "$out.webp"
    fi
    if test $verbose -eq 1; then
	ksvu-compress-ratio "" "$inp" "$out.webp"
    fi
    ksvu-printf 1 " done\n"
    if test $list -eq 1; then
	ls -lrt "${name}"*
    fi
    if test -f "$name-q.png"; then
	rm -f "$name-q.png"
    fi
done




