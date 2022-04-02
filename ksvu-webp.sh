#!/usr/bin/env bash
#
# This file is part of the ksvu-webp distribution:
# https://github.com/klimaschutz-von-unten-de/webp
#
# Version: ksvu-webp.sh 0.9
#
# Copyright (c) 2022 Stefan Ruppert <webp@klimaschutz-von-unten.de>.
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3.
#
# This script is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script. If not, see <https://www.gnu.org/licenses/>.
#
# pre-conditions
# required tools: imagemagick (convert, identity)
# optional installed tools: gimp, cwebp, pngquant, cjpeg, awk, sed,
#     firefox or google-chrome for comparing converted and original images
#

# start script options
opt_all=0
opt_browser=firefox
opt_compare=0
opt_compare_psnr=0
opt_compare_ssim=0
opt_compare_ssim_target=0
opt_directory=.
opt_fixhtml=0
opt_force=0
opt_height=0
opt_jpeg=0
opt_keep=0
opt_list=0
opt_lossless=-1
opt_midfix=""
opt_overview=0
opt_pngcolors=256
opt_pngquant=0
opt_quality=70
opt_scale=0
opt_timing=0
opt_verbose=1
opt_webp=1
opt_width=0
# end script options

# script variables
var_quality=0
var_lossless=0
var_png=0
var_print=0
var_psnr=0
var_ssim=0
var_timeinfo=""
LC_ALL=C

function ksvu-check-tool()
{
    echo $((1 - $(which $1 >/dev/null; echo $?) ))
}

function ksvu-check-metric()
{
    echo $(compare -list metric | egrep "^$1$" | wc -l)
}

# commands used
if test ! -f $HOME/.ksvu-webp; then
    cat > $HOME/.ksvu-webp <<EOF
# tool section (available)
has_magick=$(ksvu-check-tool convert)
has_gimp=$(ksvu-check-tool gimp)
has_cwebp=$(ksvu-check-tool cwebp)
has_cjpeg=$(ksvu-check-tool cjpeg)
has_pngquant=$(ksvu-check-tool pngquant)
has_firefox=$(ksvu-check-tool firefox)
has_gchrome=$(ksvu-check-tool google-chrome)
has_metric_ssim=$(ksvu-check-metric SSIM)
has_metric_psnr=$(ksvu-check-metric PSNR)
# option section copied from script; change these values to use your personal defaults
EOF
    sed -n '/^# start script options/,/^# end script options/p' <$0 | grep -v "#" >> $HOME/.ksvu-webp
fi

# source user default options
if test -f $HOME/.ksvu-webp; then
    source $HOME/.ksvu-webp
fi

if test $(ksvu-check-tool identify) -ne 1; then
    echo "$0 identify tool from imagemagick not found. This tool is needed therefore aborting"
    exit 1
fi

if test "$opt_browser"; then
    if test "$opt_browser" = "firefox" -a ${has_firefox:-0} -ne 1; then
	echo "$0 warning browser $opt_browser is uses but not installed"
	opt_browser=""
    fi
    if test "$opt_browser" = "google-chrome" -a ${has_gchrome:-0} -ne 1; then
	echo "$0 warning browser $opt_browser is uses but not installed"
	opt_browser=""
    fi
fi

if test -z "$opt_browser" -a ${has_firefox:-0} -eq 1; then
    opt_browser=firefox
fi
if test -z "$opt_browser" -a ${has_gchrome:-0} -eq 1; then
    opt_browser=google-chrome
fi

clock_ticks=$(getconf CLK_TCK)

declare -A measure_stamp
declare -A measure_cpu

function ksvu-proc-stat()
{
    stat=$(cat /proc/$$/stat)
    stat_array=( `echo $stat | sed -E 's/(\([^\s)]+)\s([^)]+\))/\1_\2/g'` )
    stat_stamp=$(date +"%s.%N")
    stat_cpu=$(( ${stat_array[13]} + ${stat_array[14]} + ${stat_array[15]} + ${stat_array[16]} ))
}

function ksvu-measure-start()
{
    if test $opt_timing -eq 0; then
	return
    fi
    ksvu-proc-stat
    measure_stamp[$1]=$stat_stamp
    measure_cpu[$1]=$stat_cpu
}

function ksvu-measure-stop()
{
    var_timeinfo=""
    if test $opt_timing -eq 0; then
	return
    fi
    ksvu-proc-stat
    duration=$( awk 'BEGIN {printf "%.2f", ('$stat_stamp' - '${measure_stamp[$1]}') }')
    cpu_duration=$( awk 'BEGIN {printf "%.2f", ('$stat_cpu' - '${measure_cpu[$1]}') / '$clock_ticks'}' )
    cpu_usage=$( awk 'BEGIN {printf "%.0f", ('$cpu_duration' / '${duration}') * 100.0}' )

    var_timeinfo="$2timing: duration=${duration}s, cpu duration=${cpu_duration}s usage=${cpu_usage}%%$3"
}

function ksvu-webp-print-options()
{
    sed -n '/^# start script options/,/^# end script options/p' <./$0 | grep -v "#" | cut -d"=" -f1 | \
	while read var; do
	    v="$var=\${$var}";
	    eval echo $v;
	done
}
function ksvu-webp-help()
{
    echo "ksvu-webp [options] image1 [image2] [...]"
    echo "Options:"
    echo "-a, --all"
    echo "    use all available encoders"
    echo "-c, --compare"
    echo "    compare original and converted image(s) using new firefox or chrome windows"
    echo "-P, --compare-psnr"
    echo "    calculate PSNR value between original and generated image"
    echo "-S, --compare-ssim"
    echo "    calculate SSIM value between original and generated image"
    echo "-d<outdir>, --directory=<outdir>"
    echo "    directory used to store converted images (default $opt_directory)"
    echo "-f, --fixhtml"
    echo "    change any reference from .jpg, .gif, .png to .webp using sed within passed"
    echo "    html files"
    echo "--force"
    echo "    force installing gimp ksvu-scale-webp.scn script"
    echo "--help"
    echo "    prints this help page"
    echo "-h[pixel], --height[=pixel]"
    echo "    specifies the height number of pixel to scale the image"
    echo "-j, --jpeg"
    echo "    only convert passed images using to jpeg using cjpeg (mozjpeg) encoder"
    echo "-k, --keep"
    echo "    do not delete generated files (from different tools)"
    echo "-l[0|1], --lossless[=0|1]"
    echo "    specifies lossless (=1) or none lossless (=0) encoding"
    echo "-L, --list"
    echo "    list original and converted image showing file size using ls -l"
    echo "-m[string], --midfix[=string]"
    echo "    specifies the midfix string used for constructing the filename of"
    echo "    the converted image"
    echo "-o, --overview"
    echo "    prints overview of old (jpg, png, gif) and new webp image file size"
    echo "-q[value], --quality[=value]"
    echo "    specifies the quality value (range from -100 to 100) used for lossy compression."
    echo "    Zero equals to use quality of input image, uses the input image quality reduced"
    echo "    by the specified negative value."
    echo "    Default is 70."
    echo "-Q, --pngquant"
    echo "    for png images run pngquant tool"
    echo "--quiet"
    echo "    sets verbose mode to zero avoiding any output"
    echo "-s[percent], --scale[=percent]"
    echo "    specifies the scaling factor in percent"
    echo "-t, --timing"
    echo "    for each conversion measure timing information (e.g. real and cpu time)"
    echo "--pngcolors[=colors]"
    echo "    number of colors to use for pngquant"
    echo "--print-options"
    echo "    print all options and their (default) values"
    echo "-v[#], --verbose[=#]"
    echo "    sets verbose mode with optionally passed verbose level (0 to 5). Default is $opt_verbose."
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
    shift 1
    if test $opt_verbose -ge $level; then
	printf "$*"
	var_print=1
    fi
}

function ksvu-webp-convert-gimp()
{
    gimp -i -b "(ksvu-scale-webp \"$1\" \"$2\" $imgwidth $imgheight $var_quality $var_lossless)" -b "(gimp-quit 0)" 2>/dev/null
}

function ksvu-webp-convert-cwebp()
{
    cwebp_lossless=""
    if test $var_lossless -eq 1; then
	cwebp_lossless="-lossless"
    fi
    cwebp -quiet -f 100 -pass 5 -m 6 -mt -q $var_quality $cwebp_lossless -resize $imgwidth $imgheight "$1" -o "$2"
}

function ksvu-webp-convert-cjpeg()
{
    if test $imgheight -eq $inpheight -a $imgwidth -eq $inpwidth; then
	cjpeg -quality $var_quality -outfile "$2" "$1"
    elif test $imgheight -eq $inpwidth -a $imgwidth -eq $inpheight; then
	cjpeg -quality $var_quality -outfile "$2" "$1"
    else
	ksvu-printf 2 "\n      (cjpeg scaling to ${imgwidth}x${imgheight})"
	convert -resize "${imgwidth}x${imgheight}" "$1" "$2.jpg"
	cjpeg -quality $var_quality -outfile "$2" "$2.jpg"
	rm -f "$2.jpg"
    fi
}

function ksvu-webp-convert-magick()
{
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
    convert -quality $var_quality -scale "${imgwidth}x${imgheight}" $magick_lossless -define webp:thread-level=0 -define webp:pass=10 -define webp:preprocessing=1 -define webp:method=6 -define webp:image-hint:photo "$1" "$2"

}

function ksvu-webp-convert-ssim-target()
{
    var_ssim_target=$(awk 'BEGIN {printf "%.2f", ('$opt_compare_ssim_target' / 100.0);}' )
    var_ssim_diff=$(awk 'BEGIN {printf "%.3f", ('$var_ssim_target' - '${var_ssim:-0}');}' )
    var_ssim_abs=$(awk 'BEGIN { printf "%.3f", ('$var_ssim_diff'<0 ? - '$var_ssim_diff' : '$var_ssim_diff');}' )
    var_quality_max=-1
    var_quality_min=-1

    while (( $(echo "$var_ssim_abs > 0.002 || $var_ssim_diff < -0.002" |bc -l) )); do
	var_quality_add=$(awk 'BEGIN {printf "%d", ('$var_ssim_diff' * 1000 / 2.5);}' )
	if test $var_quality_add -eq 0; then
	    var_quality_add=$(awk 'BEGIN { printf "%d", ('$var_ssim_diff'<0 ? -1:1);}' )
	fi
	if test $var_quality_max -eq -1; then
	    var_quality_max=$var_quality
	elif test $var_quality_max -lt $var_quality; then
	    var_quality_max=$var_quality
	fi

	if test $((var_quality + var_quality_add)) -ge $var_quality_max; then
	    if test $var_quality_add -gt 0; then
		var_quality=$((var_quality_max - 1))
		var_quality_max=$var_quality
	    else
		var_quality=$((var_quality + var_quality_add))
	    fi
	elif test $((var_quality + var_quality_add)) -le $var_quality_min; then
	    if test $var_quality_add -gt 0; then
		var_quality=$((var_quality_min + 1))
		var_quality_min=$var_quality
	    else
		var_quality=$((var_quality + var_quality_add))
	    fi
	else
	    var_quality=$((var_quality + var_quality_add))
	fi

	if test $var_quality_min -eq -1; then
	    var_quality_min=$var_quality
	elif test $var_quality_min -gt $var_quality; then
	    var_quality_min=$var_quality
	fi
	if test $var_quality_add -lt 0; then
	    ssim_is="greater"
	else
	    ssim_is="less"
	fi
	ksvu-printf 4 "\n        (current ssim=${var_ssim:-0} is $ssim_is than target ssim=$var_ssim_target, diff=$var_ssim_diff, quality_add=$var_quality_add,quality=$var_quality[min:$var_quality_min,max=$var_quality_max])"
	ksvu-webp-convert-$1 "$3" "$4"
	ksvu-compress-ratio $1 "$2" "$4"
	ksvu-conversion-info $1
	var_ssim_diff=$(awk 'BEGIN {printf "%.3f", ('$var_ssim_target' - '${var_ssim:-0}');}' )
	var_ssim_abs=$(awk 'BEGIN { printf "%.3f", ('$var_ssim_diff'<0 ? - '$var_ssim_diff' : '$var_ssim_diff');}' )
	if test $var_quality_min -eq $var_quality_max; then
	    break;
	fi
    done
}

function ksvu-webp-min-size()
{
    if test ${opt_compare_ssim:-0} -eq 1 -a "$3" != "0"; then
	ssimsize=$(printf "scale=0\n$2/$3\n" | bc -l)
	if test ${webp_ssimsize:-0} -eq 0; then
	    webp_tool="$1"
	    webp_size=$2
	    webp_ssim=$3
	    webp_ssimsize=$ssimsize
	fi
	if (( $(echo "$ssimsize < ${webp_ssimsize:-0}" |bc -l) )); then
	    webp_tool="$1"
	    webp_size=$2
	    webp_ssim=$3
	    webp_ssimsize=$ssimsize
	fi
	return
    fi
    if test ${webp_size:-0} -eq 0; then
	webp_tool="$1"
	webp_size=$2
    fi
    if test $2 -gt 0 -a $2 -lt ${webp_size:-0}; then
	webp_tool="$1"
	webp_size=$2
    fi
}
function ksvu-imagesize-get()
{
    imgwidth=$opt_width
    imgheight=$opt_height
    # get image width and height
    inpwidth=$(identify -format "%w" "$1")
    inpheight=$(identify -format "%h" "$1")
    inpquality=$(identify -format "%Q" "$1")
    inporient=$(identify -format "%[orientation]" "$1")

    ksvu-printf 2 "\n   "
    var_print=0
    if test $opt_scale -gt 0; then
	imgwidth=$(awk -v iw=$inpwidth -v p=$opt_scale 'BEGIN { printf "%.0f", (iw*p)/100 }')
	ksvu-printf 2 " (scale=$opt_scale%%: $inpwidth => $imgwidth)"
    fi
    if test $imgwidth -eq 0; then
	imgwidth=$inpwidth
    fi
    if test $imgheight -eq 0; then
	tmppercent=$(awk -v iw=$inpwidth -v w=$imgwidth 'BEGIN { printf "%d", w*100/iw }')
	imgheight=$(awk -v iw=$inpwidth -v ih=$inpheight -v w=$imgwidth 'BEGIN { printf "%d", ih*w/iw }')
	ksvu-printf 2 " (height=0: width:$inpwidth => $opt_width [$tmppercent%%], height:$imgheight)"
    else
	imgwidth=$(awk -v iw=$inpwidth -v ih=$inpheight -v h=$imgheight 'BEGIN { printf "%d", iw*h/ih }')
    fi
    if test $var_print -eq 1; then
	ksvu-printf 2 "\n   "
    fi
    if test $var_lossless -eq 1; then
	if test "$inpquality"; then
	    inparams="quality=$inpquality"
	else
	    inparams="lossless=1"
	fi
	outparams="lossless=1"
    else
	inparams="quality=$inpquality"
	outparams="quality=$var_quality"
    fi
    ksvu-printf 2 " ($1[$inpwidth,$inpheight,$inparams]"
    if test "$inporient" != "TopLeft" -a $inporient != "Undefined"; then
	ksvu-printf 2 " -> perform auto orientation"
	convert -auto-orient "$1" "$3"
	tmp=$imgwidth
	imgwidth=$imgheight
	imgheight=$tmp
	if test ! -s "$3"; then
	    echo "$0: auto orientation failed" 1>&2
	fi
    fi
    ksvu-printf 2 " -> $2[$imgwidth,$imgheight,$outparams])"
}

function ksvu-compress-ratio()
{
    inpsize=$(ls -l "$2" | sed -e 's/  */ /g' | cut -d" " -f5)
    outsize=$(ls -l "$3" | sed -e 's/  */ /g' | cut -d" " -f5)
    ratio=$(awk -v is=$inpsize -v os=$outsize 'BEGIN { printf "%.1f", (1-(os/is))*100 }')
    var_ssim=0
    var_ssiminfo=""
    var_qualityinfo=""
    if test $opt_compare_ssim -eq 1; then
	var_ssim=$(compare -auto-orient -metric SSIM "$2" "$3" "null:" 2>&1)
	var_ssiminfo=", ssim=$var_ssim"
	var_qualityinfo=", quality=$var_quality"
    fi
    var_psnr=0
    var_psnrinfo=""
    if test $opt_compare_psnr -eq 1; then
	var_psnr=$(compare -auto-orient -metric PSNR "$inp" "$out.webp" "null:" 2>&1)
	var_psnrinfo=", psnr=$var_psnr"
    fi
}

function ksvu-conversion-info()
{
    if test -z "$1"; then
	ksvu-printf 1 " ($webp_tool: $inpsize -> $outsize = ${ratio}%%$var_qualityinfo$var_ssiminfo$var_psnrinfo$var_timeinfosep$var_timeinfo)"
    else
	ksvu-printf 2 "."
	ksvu-printf 3 "\n      ($1: $inpsize -> $outsize = ${ratio}%%$var_qualityinfo$var_ssiminfo$var_psnrinfo$var_timeinfosep$var_timeinfo)"
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
    ls ${opt_directory}/*.webp | xargs ls -l | cut -b 29-36 | ksvu-imagesize-sum
}

function ksvu-overview-size()
{
    ksvu-imagesize-old
    ksvu-imagesize-webp

    oldsize=$(ksvu-imagesize-old | cut -d";" -f 2 | cut -d"=" -f2)
    newsize=$(ksvu-imagesize-webp | cut -d";" -f 2 | cut -d"=" -f2)

    awk -v os=$oldsize -v ns=$newsize 'BEGIN { printf "Reduction: %.1f%%\n", (1 - ns/os)*100; }'
}

function ksvu-overview-ssim()
{
    total_in=0
    total_out=0
    files=0
    for i in *.jpg; do
	n=$(basename $i .jpg);
	ksvu-compress-ratio overview $i ${opt_directory}/$n.webp
	printf "$i -> $n.webp, size=$inpsize => $outsize ($ratio%%)$var_ssiminfo\n"
	total_in=$((total_in + inpsize))
	total_out=$((total_out +  outsize))
	files=$((files + 1))
    done
    total_ratio=$(awk -v is=$total_in -v os=$total_out 'BEGIN { printf "%.1f", (1-(os/is))*100 }')
    printf "Total: files=$files, $total_in => $total_out ($total_ratio%%)\n"
}

OPTS=$(getopt -o v::acd:PS::jkl:Ls:tT:tw:h:oq:Qfm: --long verbose::,help,all,compare,compare-psnr,compare-ssim::,directory:,jpeg,keep,lossless:,list,scale:,timing,tools:,width:,height:,overview,quality:,pngquant,pngcolors:,midfix:,fixhtml,force,quiet,print-options -n "ksvu-webp" -- "$@")

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
	--print-options)
	    ksvu-webp-print-options
	    exit 0
	    ;;
	--quiet)
	    opt_verbose=0
	    shift
	    ;;
	-a|--all)
	    opt_all=1
	    shift
	    ;;
	-c|--compare)
	    opt_compare=1
	    shift
	    ;;
	-P|--compare-psnr)
	    opt_compare_psnr=1
	    shift
	    ;;
	-S|--compare-ssim)
	    opt_compare_ssim=1
	    case "$2" in
		"")
		    ;;
		*)
		    opt_compare_ssim_target=$2
		    ;;
	    esac
	    shift 2
	    ;;
	-d|--directory)
	    opt_directory="$2"
	    shift 2
	    ;;
	-j|--jpeg)
	    opt_jpeg=1
	    opt_webp=0
	    shift 1
	    ;;
	-k|--keep)
	    opt_keep=1
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
	-t|--timing)
	    opt_timing=1
	    shift 1
	    ;;
	-T|--tools)
	    has_magick=0
	    has_gimp=0
	    has_cwebp=0
	    has_cjpeg=0
	    has_pngquant=0
	    for t in $2; do
		case "$t" in
		    magick)
			has_magick=1
			;;
		    gimp)
			has_gimp=1
			;;
		    cwebp)
			has_cwebp=1
			;;
		    cjpeg)
			has_cjpeg=1
			;;
		    pngquant)
			has_pngquant=1
			;;		    
		esac
	    done
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

if test $opt_compare_ssim -eq 1 -a $has_metric_ssim -ne 1; then
    echo "$0: error SSIM comparison not available. ImageMagick version 7 needed." 1>&2
    exit 1
fi
ksvu-measure-start "tool"

if test $opt_fixhtml -eq 1; then
    for arg; do
	echo "$arg: fixing html images to .webp"
	sed -i -e 's/\.png/\.webp/g' -e 's/\.jpg/\.webp/g' -e 's/\.gif/\.webp/g' $arg
    done
    exit 0
elif test $opt_overview -eq 1; then
    if test $opt_compare_ssim -eq 1; then
	ksvu-overview-ssim
    else
	ksvu-overview-size
    fi
    exit 0
fi


ksvu-printf 5 "Parameters used:\n"
ksvu-printf 5 "    width: $opt_width\n"
ksvu-printf 5 "    height: $opt_height\n"
ksvu-printf 5 "    lossless: $opt_lossless\n"
ksvu-printf 5 "    quality: $opt_quality\n"
ksvu-printf 5 "    scale: $opt_scale\n"
ksvu-printf 5 "    midfix: $opt_midfix\n"
ksvu-printf 5 "    ssim: $opt_compare_ssim (target=$opt_compare_ssim_target)\n"

ksvu-gimp-prepare

declare -A usage
for arg; do
    ksvu-measure-start "file"
    webp_tool=""
    webp_size=0

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
    inp2="$name-work.$suffix"
    if test $opt_compare_ssim_target -gt 0; then
	if test $opt_compare_ssim_target -lt 88; then
	    opt_compare_ssim_target=88
	elif test $opt_compare_ssim_target -gt 95; then
	    opt_compare_ssim_target=95
	fi
	if test $opt_compare_ssim_target -lt 89; then
	    opt_quality=50
	elif test $opt_compare_ssim_target -lt 90; then
	    opt_quality=75
	elif test $opt_compare_ssim_target -lt 91; then
	    opt_quality=80
	elif test $opt_compare_ssim_target -lt 92; then
	    opt_quality=85
	elif test $opt_compare_ssim_target -lt 93; then
	    opt_quality=87
	elif test $opt_compare_ssim_target -lt 94; then
	    opt_quality=89
	else
	    opt_quality=90
	fi
    fi
    if test $var_lossless -eq 0 -a $opt_quality -le 0; then
	var_quality=$(($(identify -format %Q $inp) + opt_quality))
    else
	var_quality=$opt_quality
    fi
    ksvu-printf 1 "Converting $inp"
    out="${name}${opt_midfix}"
    outwork="${opt_directory}/.${name}${opt_midfix}"
    outfile="${opt_directory}/${out}.webp"
    ksvu-printf 1 " -> $outfile ..."
    ksvu-imagesize-get "$inp" "${outfile}" "$inp2" "$suffix"

    if test $var_png -eq 1 -a $opt_pngquant -eq 1; then
	if test ${has_pngquant:-0} -eq 1; then
	    src="$inp"
	    if test -s "$inp2"; then
		src="$inp2"
	    fi
	    ksvu-printf 2 "\n    (pngquant: $name-q.png colors=$opt_pngcolors)"
	    pngquant --speed 1 --nofs $opt_pngcolors -o "$name-q.png" "$src"
	    if test -s "$name-q.png"; then
		mv -f "$name-q.png" "$inp2"
	    fi
	else
	    echo "$0 warning: pngquant not installed" 1>&2
	fi
    fi
    
    if test ! -f $inp2; then
	ln -s $inp $inp2
    fi

    if test ${opt_jpeg:-0} -eq 1 -o ${opt_all:-0} -eq 1; then
	size_cjpeg=0
	if test ${has_cjpeg:-0} -eq 1 -a $var_lossless -eq 0 ; then
	    ksvu-measure-start "cjpeg"
	    ksvu-webp-convert-cjpeg "$inp2" "$out-cjpeg.jpg"
	    ksvu-compress-ratio cjpeg "$inp" "$out-cjpeg.jpg"
	    ksvu-measure-stop "cjpeg" ", " ""
	    ksvu-conversion-info cjpeg
	    size_cjpeg=$outsize
	    ssim_cjpeg=$var_ssim
	    usage[cjpeg]=$((usage[cjpeg] + 1))
	    
	    if test $opt_compare_ssim_target -gt 0; then
		ksvu-webp-convert-ssim-target cjpeg "$inp" "$out-cjpeg.jpg" "$outwork-$webp_tool.jpg"
	    fi
	fi
    fi

    if test ${opt_webp:-1} -eq 1 -o ${opt_all:-0} -eq 1; then
	# reset ssim value
	webp_ssim=0
	webp_ssimsize=0

	size_gimp=0
	ssim_gimp=0
	if test ${has_gimp:-0} -eq 1; then
	    ksvu-measure-start "gimp-webp"
	    ksvu-webp-convert-gimp "$inp2" "$outwork-gimp.webp"
	    ksvu-compress-ratio gimp "$inp" "$outwork-gimp.webp"
	    ksvu-measure-stop "gimp-webp" ", " ""
	    ksvu-conversion-info gimp
	    size_gimp=$outsize
	    ssim_gimp=$var_ssim
	fi

	size_cwebp=0
	ssim_cwebp=0
	if test ${has_cwebp:-0} -eq 1; then
	    ksvu-measure-start "cwebp-webp"
	    ksvu-webp-convert-cwebp "$inp2" "$outwork-cwebp.webp"
	    ksvu-compress-ratio cwebp "$inp" "$outwork-cwebp.webp"
	    ksvu-measure-stop "cwebp-webp" ", " ""
	    ksvu-conversion-info cwebp
	    size_cwebp=$outsize
	    ssim_cwebp=$var_ssim
	fi

	size_magick=0
	ssim_magick=0
	if test ${has_magick:-0} -eq 1; then
	    ksvu-measure-start "magick-webp"
	    ksvu-webp-convert-magick "$inp2" "$outwork-magick.webp"
	    ksvu-compress-ratio magick "$inp" "$outwork-magick.webp"
	    ksvu-measure-stop "magick-webp" ", " ""
	    ksvu-conversion-info magick
	    size_magick=$outsize
	    ssim_magick=$var_ssim
	fi
    
	ksvu-webp-min-size "gimp"   ${size_gimp:-0}   ${ssim_gimp:-0}
	ksvu-webp-min-size "magick" ${size_magick:-0} ${ssim_magick:-0}
	ksvu-webp-min-size "cwebp"  ${size_cwebp:-0}  ${ssim_cwebp:-0}

	if test $opt_compare_ssim_target -gt 0; then
	    ksvu-printf 2 "\n    (using $webp_tool tool for ssim=0.${opt_compare_ssim_target} target conversion (ssimsize=${webp_ssimsize:-0.0})"
	    var_ssim=$webp_ssim
	    ksvu-webp-convert-ssim-target $webp_tool "$inp" "$inp2" "$outwork-$webp_tool.webp"
	fi

	if test -f $outwork-${webp_tool}.webp; then
	    ksvu-printf 2 "\n    (using $webp_tool $outfile version; size: $inpsize -> $outsize = ${ratio}%%; ssim=${var_ssim:-0.0})\n"
	    cp -f "$outwork-${webp_tool}.webp" "$outfile"
	    usage[$webp_tool]=$((usage[$webp_tool] + 1))
	fi

	if test $opt_verbose -eq 1; then
	    ksvu-compress-ratio "" "$inp" "$out.webp"
	    ksvu-printf 1 " "
	fi
    fi
    if test $opt_compare -eq 1; then
	$opt_browser --new-window "$inp"
	if test -f "$outwork-magick.webp"; then
	    $opt_browser --new-window "$outwork-magick.webp"
	fi
	if test -f "$outwork-gimp.webp"; then
	    $opt_browser --new-window "$outwork-gimp.webp"
	fi
	if test -f "$outwork-cwebp.webp"; then
	    $opt_browser --new-window "$outwork-cwebp.webp"
	fi
	if test -f "$out-cjpeg.jpg"; then
	    $opt_browser --new-window "$out-cjpeg.jpg"
	fi
	sleep 5
    fi
    # cleanup
    if test $opt_keep -eq 0; then
	rm -f "${outwork}-"*.webp
    fi
    if test -e "$inp2"; then
	rm -f "$inp2"
    fi
    # list input and output files
    if test $opt_list -eq 1; then
	ls -lrt "${name}"*
    fi
    ksvu-measure-stop "file" " (" ") "
    ksvu-printf 2 "Conversion ${inp}$var_timeinfo "
    ksvu-printf 1 "done\n"
done

ksvu-measure-stop "tool" " (" ") "

if test $opt_verbose -gt 0; then
    ksvu-printf 1 "Conversion summary: "
    sep=""
    for i in ${!usage[@]}; do
	ksvu-printf 1 "$sep$i=${usage[$i]}"
	sep=", "
    done
    ksvu-printf 1 "$var_timeinfo\n"
fi
