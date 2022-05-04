#!/bin/bash
# License: 	GPLv3
# Author:	Ballerburg9005
# Website: 	https://github.com/ballerburg9005/wget-2-zim

# parse command line options and print info

WGETREJECT='*.img,*.md*,*.dsk,*.nrg,*.iso,*.cue,*.pk*,*.pak*,*.daa,*.ass,*.ipa,*.ace,*.toast,*.vcd,*.vol,*.bak,*.cab,*.tmp'
WGETREJECT_ARCHIVE=',*.lz,*.gz,*.zip,*.rar,*.7z,*.tar*,*.xz,*.bz2'
WGETREJECT_PROGRAM=',*.exe,*.deb,*.rpm,*.dmg,*.bin,*.msi,*.apk,*.tar.*z'

if [[ " --help -help -h " =~ " $1 " || "$1" == "" ]]; then
	echo "	$0 [OPTIONS] URL"
	echo "	Makes ZIM file from URL with recursive wget and lots of tricks."
	echo " "
	echo "	wget-2-zim tries to make a bunch of smart decisions what to include in the ZIM, but it still"
	echo "	tries to include as much as sanely possible (like PDFs, XLS files, music and video)."
	echo " "
	echo "	--any-max	[SIZE (MB)]	Any file larger will be deleted before doing the ZIM no matter what. Default = 128MB"
	echo "	--not-media-max [SIZE (MB)]	Any file larger that is not music, video, picture or epub, pdf, xls alike will be excluded. Default = 2MB"
	echo "	--picture-max 	[SIZE (MB)]	Any picture file larger will be excluded from ZIM. Default = unset"
	echo "	--document-max 	[SIZE (MB)]	Any document file larger will be excluded from ZIM (epub, pdf, xls, ods, etc.). Default = unset"
	echo "	--music-max 	[SIZE (MB)]	Any music file larger will be excluded from ZIM. Default = unset"
	echo "	--video-max 	[SIZE (MB)]	Any video file larger will be excluded from ZIM. Default = unset"
	echo "	--wget-depth			Set this to 1 or 3 if you want to make very shallow copies. Default = 7"
	echo "	--include-zip 			Includes all sorts of archives (zip, rar, 7z, gz, etc). Default = no"
	echo "	--include-exe			Includes all sorts of program files (exe, msi, deb, rpm, etc). Default = no"
	echo "	--include-any			Download any file type. Default = no"

	exit -1
fi

echo ""

URL="$(echo "$@" | grep -osa "[^[:space:]]*://[^[:space:]]*")"

if [[ "$URL" == "" ]]; then echo "ERROR. Can't find URL in arguments. Try adding http:// perhaps?"; exit 2; fi

if ! [[ " $@ " =~ " --include-zip " ]]; then WGETREJECT="$WGETREJECT$WGETREJECT_ARCHIVE"; fi
if ! [[ " $@ " =~ " --include-exe " ]]; then WGETREJECT="$WGETREJECT$WGETREJECT_PROGRAM"; fi
if   [[ " $@ " =~ " --include-any " ]]; then WGETREJECT=""; fi

declare -A OPTS=( [any-max]=128 [not-media-max]=2 [wget-depth]=7 )
for opt in any-max not-media-max picture-max document-max music-max video-max wget-depth; do
	if [[ " $@ " =~ "--$opt" ]]; then
		OPTS[$opt]="$(echo "$@" | sed -E "s#.*--$opt[[:space:]=]([^[:space:]]+).*#\1#g" )"
		if ! [[ "${OPTS[$opt]}" =~ ^[0-9]+$ ]]; then echo "Error: --$opt '${OPTS[$opt]}' is not an integer."; exit 2; fi
	fi

done


# print options

echo "+++++++++++++ INITIAL OPTIONS ++++++++++++"
echo -en "File types excluded: "
echo "$WGETREJECT"
echo -en "Size limits: "
for opt in "${!OPTS[@]}"; do echo -en "$COMMA$opt = ${OPTS[$opt]}"; COMMA=", "; done
echo ""
echo "+++++++++++++ BEGIN CRAWLING +++++++++++++"
echo ""


# extract strings from URL

DOMAIN="$(echo "$@" | grep "[^[:space:]]*://[^[:space:]]*" | sed 's#^[^/]*//##g;s#/.*$##g')" 
WELCOME="$(echo "$URL" | sed 's#^[^/]*//##g;' | grep -osa "/.*$" | sed 's/\?/%3F/g')"


# download with wget

wget -r -p -k -c --level="${OPTS[wget-depth]}" --timeout=3s --no-check-certificate -e robots=off --wait=0.2 --tries=6 \
	--reject "$WGETREJECT" \
	--user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.41 Safari/537.36" \
	--header="X-Requested-With: XMLHttpRequest" --header="Referer: $DOMAIN" --header='Accept-Language: en' \
	$URL

echo "Wget finished."

# various URL repairs & anti GDRP stuff, plus manual wget download of images, documents, media files that are linked to external domains

find $DOMAIN -name '*\.css\?*' -exec sh -c 'mv '"'"'{}'"'"' $(echo '"'"'{}'"'"' | sed -E "s#\.css\?.*#.css#g") ' \;

find $DOMAIN -type f \( -name '*.htm*' -or -name '*.php*' \) \
	-exec sh -c 'tmpfile=$(mktemp); cat '"'"'{}'"'"' | tr '"'"'\n'"'"' '"'"'ɰ'"'"' | sed -E '"'"'s/(<[^>]+"[^"]+)\.css\?([^"]*)"([^>]*>)/\1.css"\3/g'"'"'";s/(<[^>]+'"'"'[^'"'"']+)\.css\?([^'"'"']*)'"'"'([^>]*>)/\1.css'"'"'\3/g" | sed -E '"'"'s/(<[^>]+"[^"]+)\?([^"]*"[^>]*>)/\1%3F\2/g'"'"'";s/(<[^>]+'"'"'[^'"'"']+)\?([^'"'"']*'"'"'[^>]*>)/\1%3F\2/g" | sed -E '"'"'s#(["])http[s]*://'"$DOMAIN"'/*(["])#"/"#g;'"'"'"s#(['"'"'])http[s]*://'"$DOMAIN"'/*(['"'"'])#'"'"'/'"'"'#g;" | sed -E '"'"'s#(["])http[s]*://'"$DOMAIN"'/#\1#g'"'"'";s#(['"'"'])http[s]*://'"$DOMAIN"'/#\1#g" | sed -E '"'"'s#<[[:space:]]*head[[:space:]]*>#<head><style type="text/css">[class*="cookie"], [id*="cookie"], [id*="banner"], [class*="banner"], [id*="disclaimer"], [class*="disclaimer"], [id*="consent"], [class*="consent"], [id*="gdpr"], [class*="gdpr"], [id*="privacy"], [class*="privacy"], [id*="popup"], [class*="popup"] { display: none !important; } body { overflow: auto !important; }</style>#g'"'"' |  tr '"'"'ɰ'"'"' '"'"'\n'"'"' > ${tmpfile} ; cat ${tmpfile} > '"'"'{}'"'"' ; echo "the following part is about fetching external content" >&/dev/null; urls_double="$(cat '"'"'{}'"'"' | tr '"'"'\n'"'"' '"'"'ɰ'"'"' | grep -osa "<[^>]*\"https*://[^\"]*\.\(png\|jpe*g\|gif\|webm\|ogg\|mp3\|aac\|wav\|mpe*g\|flac\|fla\|flv\|ac3\|au\|mka\|m.v\|swf\|mp4\|f4v\|ogv\|3g.\|avi\|h26.\|wmv\|mkv\|divx\|ogv\|aif\|svg\|epub\|pdf\|pbd\|xls.\|doc.\|od.\|ppt.\)\"[^>]*>" | sed -E "s#<([^>]*\")(https*://)([^/]*/)([^\"]*)(\".*)#\2\3\4#g")"; urls_single="$(cat '"'"'{}'"'"' | tr '"'"'\n'"'"' '"'"'ɰ'"'"' | grep -osa "<[^>]*'"'"'https*://[^'"'"']*\.\(png\|jpe*g\|gif\|webm\|ogg\|mp3\|aac\|wav\|mpe*g\|flac\|fla\|flv\|ac3\|au\|mka\|m.v\|swf\|mp4\|f4v\|ogv\|3g.\|avi\|h26.\|wmv\|mkv\|divx\|ogv\|aif\|svg\|epub\|pdf\|pbd\|xls.\|doc.\|od.\|ppt.\)'"'"'[^>]*>" | sed -E "s#<([^>]*'"'"')(https*://)([^/]*/)([^'"'"']*)('"'"'.*)#\2\3\4#g")"; for url in $(printf "%s\n%s" "$urls_single" "$urls_double"); do wget --timeout=3s --no-check-certificate -e robots=off -p --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.41 Safari/537.36" --header="X-Requested-With: XMLHttpRequest" --wait=0.$(( RANDOM % 10 )) --header="Referer: '"$DOMAIN"'" --directory-prefix="'"$DOMAIN"'" "$url"; done; tmpfile=$(mktemp); cat '"'"'{}'"'"' | tr '"'"'\n'"'"' '"'"'ɰ'"'"' | sed -E "s#(<[^>]*\")(https*://)([^/]*/[^\"]*\.)(png|jpe*g|gif|webm|ogg|mp3|aac|wav|mpe*g|flac|fla|flv|ac3|au|mka|m.v|swf|mp4|f4v|ogv|3g.|avi|h26.|wmv|mkv|divx|ogv|aif|svg|epub|pdf|pbd|xls.|doc.|od.|ppt.)(\"[^>]*>)#\1\3\4\5#g" | sed -E "s#(<[^>]*'"'"')(https*://)([^/]*/[^'"'"']*\.)(png|jpe*g|gif|webm|ogg|mp3|aac|wav|mpe*g|flac|fla|flv|ac3|au|mka|m.v|swf|mp4|f4v|ogv|3g.|avi|h26.|wmv|mkv|divx|ogv|aif|svg|epub|pdf|pbd|xls.|doc.|od.|ppt.)('"'"'[^>]*>)#\1\3\4\5#g" |  tr '"'"'ɰ'"'"' '"'"'\n'"'"' > ${tmpfile} ; cat ${tmpfile} > '"'"'{}'"'"' ' \;
			#  replace all ".css?asdfasdfsdf" with ".css" - stylesheets must not have any other ending
			#  index.html?asdf -> index.html%3Fasdf (literally opens files with question marks in them, rather than making it a parameter)
			# "http://example.com" -> /
			# "http://example.com/asdf/asdf" -> asdf/asdf
			# inject css to forcefully hide all elements where class or id is *cookie* *banner* *consent* *disclaimer* *gdpr* *privacy* *popup* ... sort of cheap but better than nothing
			# external content part: (this is necessary, because a lot of sites use cross-domain content as their own. They embed images of their own from imgur, blogspot, etc.) 
			# 	grep image, media and document URLs from external sites
			#	loop over URLs and fetch them with wget
			#	make those URLs relative in original html file
			#	TODO could also be used to fetch iframes and external links non-recursively -> sounds quite useful to have as command line option
			#	TODO only fetches ...pdf" currently but not ...pdf?asdfasdf" -> really desirable?


# various shenanegans to deal with media and large files

if [[ "${OPTS[any-max]}" != "" ]]; then find $DOMAIN -type f -size "+${OPTS[any-max]}M" -delete; fi

if [[ "${OPTS[not-media-max]}" != "" ]]; then 	find $DOMAIN -type f -not \( \
				-name '*\.3g*' -or -name '*\.avi' -or -name '*\.flv*' -or -name '*\.h26*' -or -name '*\.m*v' -or -name '*\.mp*g' -or -name '*\.swf' -or -name '*\.wmv' -or -name '*\.mkv' -or -name '*\.mp4' -or -name '*\.divx' -or -name '*\.f4v' -or -name '*\.ogv' -or -name '*\.webm' \
				-or -name '*\.aif' -or -name '*\.ogg' -or -name '*\.wav' -or -name '*\.aac' -or -name '*\.mp3' -or -name '*\.flac'  -or -name '*\.wma' -or -name '*\.amr' -or -name '*\.fla' -or -name '*\.ac3' -or -name '*\.au' -or -name '*\.mka' \
				-or -name '*\.pdf' -or -name '*\.epub' -or -name '*\.pdb' -or -name '*\.xls*' -or -name '*\.doc*' -or -name '*\.od*' -or -name '*\.ppt*' \
				-or -name '*\.png' -or -name '*\.jp' -or -name '*\.gif' -or -name '*\.svg' \
									\) -size "+${OPTS[not-media-max]}M" -delete;
fi

if [[ "${OPTS[picture-max]}" != "" ]]; then 	find $DOMAIN -type f -not \( \
				-or -name '*\.png' -or -name '*\.jp' -or -name '*\.gif' -or -name '*\.svg' \
									\) -size "+${OPTS[picture-max]}M" -delete;
fi

if [[ "${OPTS[document-max]}" != "" ]]; then 	find $DOMAIN -type f \( \
				-name '*\.pdf' -or -name '*\.epub' -or -name '*\.pdb' -or -name '*\.xls*' -or -name '*\.doc*' -or -name '*\.od*' -or -name '*\.ppt*' \
									\) -size "+${OPTS[document-max]}M" -delete;
fi


if [[ "${OPTS[music-max]}" != "" ]]; then 	find $DOMAIN -type f \( \
				-or -name '*\.aif' -or -name '*\.ogg' -or -name '*\.wav' -or -name '*\.aac' -or -name '*\.mp3' -or -name '*\.flac'  -or -name '*\.wma' -or -name '*\.amr' -or -name '*\.fla' -or -name '*\.ac3' -or -name '*\.au' -or -name '*\.mka' \
									\) -size "+${OPTS[music-max]}M" -delete;
fi
if [[ "${OPTS[video-max]}" != "" ]]; then 	find $DOMAIN -type f \( \
				-name '*\.3g*' -or -name '*\.avi' -or -name '*\.flv*' -or -name '*\.h26*' -or -name '*\.m*v' -or -name '*\.mp*g' -or -name '*\.swf' -or -name '*\.wmv' -or -name '*\.mkv' -or -name '*\.mp4' -or -name '*\.divx' -or -name '*\.f4v' -or -name '*\.ogv' -or -name '*\.webm' \
									\) -size "+${OPTS[video-max]}M" -delete;
fi


# favicon
 
MYFAVICON="$(command ls -w 1 $DOMAIN/favicon*.{png,ico,gif,jpg,bmp} 2>/dev/null | tail -n 1)"

if [ -f "$MYFAVICON" ]; then
	convert -resize 48x48 "$MYFAVICON" $DOMAIN/zim_favicon.png
else  
	convert -size 48x48 xc:white $DOMAIN/zim_favicon.png
fi


# choose index page (welcome)

if [ ! -f "$DOMAIN/$WELCOME" ]; then
	WELCOME="$(command ls -w 1 $DOMAIN/index*.{htm*,php*} $DOMAIN/*.{htm*,php*} | cat - <(echo "$DOMAIN/index.html") | head -n 1 | sed "s#^[^/]*/##g")"
fi


# write ZIM

rm ${DOMAIN}.zim >&/dev/null

echo "writing ZIM"

if zimwriterfs --welcome="$WELCOME" --illustration=zim_favicon.png --language=eng --title="$DOMAIN" --description="$(awk '/<title>/,/<\/title\>/' $DOMAIN/index.html | tr '\n' ' ' | sed "s/<[^>]*>//g;s/[[:space:]]\+/\ /g;s/^[[:space:]]*//g;s/[[:space:]]*$//g")" --creator="https://github.com/ballerburg9005/wget-2-zim" --publisher "wget-2-zim, a simple easy to use script that just works" ./$DOMAIN $DOMAIN.zim; then
	echo "Success in creating ZIM file!"
	# Maybe clean up or not? Some sites were still throttling me with --wait=0.5, maybe running wget twice is safer
#	rm -rf ./$DOMAIN
else
	echo "FAILURE! Left $DOMAIN download directory in place."
fi

