#!/usr/bin/env bash

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump | gzip`
set -o pipefail

_contains() {
	[ "${1#*$2}" != "$1" ] && return 0 || return 1
}

_get_stretch() {
	{ _contains "$1" "UltraCondensed" || _contains "$1" "Ultra Condensed" ;} &&
		printf "ultra-condensed\\n" && return 0

	{ _contains "$1" "ExtraCondensed" || _contains "$1" "Extra Condensed" ;} &&
		printf "extra-condensed\\n" && return 0

	{ _contains "$1" "SemiCondensed" || _contains "$1" "Semi Condensed" ;} &&
		printf "semi-condensed\\n" && return 0

	_contains "$1" "Condensed" && printf "condensed\\n" && return 0

	{ _contains "$1" "SemiExpanded" || _contains "$1" "Semi Expanded" ;} &&
		printf "semi-expanded\\n" && return 0

	{ _contains "$1" "ExtraExpanded" || _contains "$1" "Extra Expanded" ;} &&
		printf "extra-expanded\\n" && return 0

	{ _contains "$1" "UltraExpanded" || _contains "$1" "Ultra Expanded" ;} &&
		printf "ultra-expanded\\n" && return 0

	_contains "$1" "Expanded" && printf "expanded\\n" && return 0

	printf "normal\\n" && return 0
}

_get_style() {
	_contains "$1" "Italic" && printf "italic\\n" && return 0

	_contains "$1" "Oblique" && printf "oblique\\n" && return 0

	printf "normal\\n" && return 0
}

_get_weight() {
	{ _contains "$1" "Thin" || _contains "$1" "Hairline" ;} &&
		printf "100\\n" && return 0

	{ _contains "$1" "ExtraLight" || _contains "$1" "Extra Light" ||
	  _contains "$1" "UltraLight" || _contains "$1" "Ultra Light" ;} &&
		printf "200\\n" && return 0

	_contains "$1" "Light" && printf "300\\n" && return 0

	_contains "$1" "Medium" && printf "500\\n" && return 0

	{ _contains "$1" "SemiBold" || _contains "$1" "Semi Bold" ||
	  _contains "$1" "DemiBold" || _contains "$1" "Demi Bold" ;} &&
		printf "600\\n" && return 0

	{ _contains "$1" "ExtraBold" || _contains "$1" "Extra Bold" ||
	  _contains "$1" "UltraBold" || _contains "$1" "Ultra Bold" ;} &&
		printf "800\\n" && return 0

	_contains "$1" "Bold" && printf "700\\n" && return 0

	{ _contains "$1" "Black" || _contains "$1" "Heavy" ;} &&
		printf "900\\n" && return 0

	printf "400\\n" && return 0
}


base="$1"
file="$2"
out="$3"
BASEDIR="$(dirname "$(readlink -f "$0")")"

echo "Generating CSS for ${file}"
basen="$(basename "$file")"
family="$(fontforge -lang=ff -c "Open(\$1); Print(\$familyname);" "${file}" 2>/dev/null)"
stretch="$(_get_stretch "${file}")"
style="$(_get_style "${file}")"
weight="$(_get_weight "${file}")"

awk_script="$(readlink -f "$BASEDIR/scripts/$(printf "%s" "${base}" | tr '[:upper:] ' '[:lower:]-').awk")"
[ -f "$awk_script" ] && builder="awk -f $awk_script" || builder="cat"
css="$($builder << EOF
@font-face {
    font-family: "${family}";
    src:    local(${basen%.*}),
            url("fonts/${basen%.*}.woff2") format("woff2"),
            url("fonts/${basen}") format("truetype");
    font-stretch: ${stretch};
    font-style: ${style};
    font-weight: ${weight};
}
EOF
)"

printf "$css\\n" >> "${out}/$(printf "${family}" | tr '[:upper:] ' '[:lower:]-').css"
