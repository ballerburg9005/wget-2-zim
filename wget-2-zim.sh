#!/bin/bash
# License: 	GPLv3
# Author:	Ballerburg9005
# Website: 	https://github.com/ballerburg9005/wget-2-zim

# parse command line options and print info

WGETREJECT='*.img,*.md*,*.dsk,*.nrg,*.iso,*.cue,*.pk*,*.pk0,*.pk1,*.pk2,*.pk3,*.pk4,*.pak*,*.daa,*.ass,*.ipa,*.ace,*.toast,*.vcd,*.vol,*.bak,*.cab,*.tmp'
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
	echo "	--include-zip 			Includes all sorts of archives (zip, rar, 7z, gz, etc)."
	echo "	--include-exe			Includes all sorts of program files (exe, msi, deb, rpm, etc)."
	echo "	--include-any			Download any file type."
	echo "	--no-overreach-media		Don't overreach by downloading media files from external domains (might affect images directly visible on the page)."
	echo "	--overreach-any			Overreach by downloading any sort of src= and href= content from external domains."
	echo "	--turbo				Disable all download delays (will probably result in half the files missing due to throttling with false 404s)"

	exit -1
fi

echo ""

URL="$(echo "$@" | grep -o "[^[:space:]]*://[^[:space:]]*")"

if [[ "$URL" == "" ]]; then echo "ERROR. Can't find URL in arguments. Try adding http:// perhaps?"; exit 2; fi

if ! [[ " $@ " =~ " --include-zip " ]]; then WGETREJECT="$WGETREJECT$WGETREJECT_ARCHIVE"; fi
if ! [[ " $@ " =~ " --include-exe " ]]; then WGETREJECT="$WGETREJECT$WGETREJECT_PROGRAM"; fi
if   [[ " $@ " =~ " --include-any " ]]; then WGETREJECT=""; fi

WGGETWAIT="0.4"
if   [[ " $@ " =~ " --turbo " ]]; then WGGETWAIT="0"; fi

NOOVERREACH="a"
if   [[ " $@ " =~ " --no-overreach-media " ]]; then NOOVERREACH="${NOOVERREACH}m"; fi
if   [[ " $@ " =~ " --overreach-any "   ]]; then NOOVERREACH="$(echo "${NOOVERREACH}" | sed "s/a//g")"; fi

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

DOMAIN="$(echo "$@" | grep -o "[^[:space:]]*://[^[:space:]]*" | sed 's#^[^/]*//##g;s#/.*$##g')" 
WELCOME="$(echo "$URL" | sed 's#^[^/]*//##g;' | grep -o "/.*$" | sed 's/\?/%3F/g')"


# download with wget

function thewget {
wget -r -p -k -c --trust-server-names --level="${OPTS[wget-depth]}" --timeout=3s --no-check-certificate -e robots=off --wait=$WGGETWAIT --tries=6 \
	--reject "$WGETREJECT" \
	--user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.41 Safari/537.36" \
	--header="X-Requested-With: XMLHttpRequest" --referer="$DOMAIN" --header='Accept-Language: en' \
	$URL

echo "Wget finished."
}


# various URL repairs & anti GDRP stuff, plus manual wget download of images, documents, media files that are linked to external domains

function postwget {

iterscript=$(mktemp);


# TODO: ../../ at the beginning is ignored sometimes: /2013/08/make-this-ultra-violet-uv-water-filter.html has url: ../../wp-content/uploads/2013/08/UVwaterpurifiercircuitdevice.png -becomes> /2013/08/wp-content/uploads/2013/08/UVwaterpurifiercircuitdevice.png
# so we could just get ".*/[^/]*" from filename and then subtract the last two folders for "../../ 

cat <<- "THEREISNOPLACELIKEHOME" > "$iterscript"
#!/bin/bash
DOMAIN="$1"
FILE="$2"
EXTERNALURLS="$3"
WGETREJECT="$4"
NOOVERREACH="$5"
bogus_regex="unmatchable-CBMBKUasdjkhksjh34543jkl54598278933k(1)(2)(3)(4)(5)(6)(7)(8)(9)"


### first we download missing external content that's somehow present in the page (e.g. embedded as images)
### then we fixes links and do some anti-cookie CSS

urlregex_media="(<[^>]*\")(https*:/)(/[^/\"]*/[^\"]*\.)(png|jpe*g|gif|webm|ogg|mp3|aac|wav|mpe*g|flac|fla|flv|ac3|au|mka|m.v|swf|mp4|f4v|ogv|3g.|avi|h26.|wmv|mkv|divx|ogv|aif|svg|epub|pdf|pbd)(\?[^\"]*)*(\"[^>]*>)"
urlregex_any="(<[^>]*)(href=\"|src=\")(https*:/)(/[^\"]*\.[^\"]*)(\"[^>]*>)"
urlregx_idx1="(<[^>]*)(href=\"|src=\")(https*:/)(/[^\"]*\.[^/\"]*)(\"[^>]*>)"
urlregx_idx2="(<[^>]*)(href=\"|src=\")([^\"]*)/(\"[^>]*>)"
urlmod="s#<[^>]*\"(https*://[^\"[:space:]]*)\".*#\1#g"

if echo "$NOOVERREACH" | grep -q "m"; then urlregex_media="$bogus_regex"; fi
if echo "$NOOVERREACH" | grep -q "a"; then urlregex_any="$bogus_regex"; urlregx_idx1="$bogus_regex"; fi

# - grep image, media and document URLs from external sites
urls_double="$(cat "$FILE" | tr '\n' 'ɰ' | grep -oaE -e "$urlregex_media" -e "$urlregex_any" | sed -E "$urlmod")"
urls_single="$(cat "$FILE" | tr '\n' 'ɰ' | grep -oaE -e "${urlregex_media//\"/\'}" -e "${urlregex_any//\"/\'}" | sed -E "${urlmod//\"/\'}")"

# - loop over URLs and fetch them with wget

for url in $(printf "%s\n%s" "$urls_single" "$urls_double"); do
	# don't wget stuff from 1. same domain, 2. if already downloaded, 3. if having a file extension that we otherwise would exlude in recursive wget
	if ! {  echo "$url" | grep -qE  "https*://(www\.)*${DOMAIN//./\.}" \
		|| grep -qFoax "$url" $EXTERNALURLS \
		|| echo "$WGETREJECT" | grep -Foaq "$(echo "$url" | sed -E 's#(.*)(\.[^\?\.]*)(\?.*)*$#\2#g')" ; }; then
		echo "DEBUG: $url ( requested by: $FILE )"
		wget --trust-server-names --timeout=3s --no-check-certificate -e robots=off --tries=6 -p \
			--user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.41 Safari/537.36" \
			--header="X-Requested-With: XMLHttpRequest" --referer="$DOMAIN" \
			--reject "$WGETREJECT" \
			--directory-prefix="$DOMAIN/wget-2-zim-overreach" "$url"
	fi
	echo "$url" >> $EXTERNALURLS
done

# - "http://example.com/asdf/asdf" -> /asdf/asdf or http://example.com -> / (same domain)
nodomain='s#(["])http[s]*://'"$DOMAIN"'/*([^"]*")#\1\2//#g'

# - this seems to be bullshit, does not solve the problem with some wordpress installations
# - "../../index.html" -> /the/path/index.html - at this point, kiwix does not understand relative paths ... it somehow only worked in test pages but not real-world websites
#absurl1="$(echo "$FILE" | sed -E "s#^[^/]*##g;s#/[^/]*\$#/#g;s#[^/]*/\$##g;s#[^/]*/\$##g;s#[^/]*/\$##g;s#[^/]*/\$##g" | sed -E "s#^\$#/#g" )"		# for ../../../../
#absurl2="$(echo "$FILE" | sed -E "s#^[^/]*##g;s#/[^/]*\$#/#g;s#[^/]*/\$##g;s#[^/]*/\$##g;s#[^/]*/\$##g" | sed -E "s#^\$#/#g" )"			# for ../../../
#absurl3="$(echo "$FILE" | sed -E "s#^[^/]*##g;s#/[^/]*\$#/#g;s#[^/]*/\$##g;s#[^/]*/\$##g" | sed -E "s#^\$#/#g" )"					# for ../../
#absurl4="$(echo "$FILE" | sed -E "s#^[^/]*##g;s#/[^/]*\$#/#g;s#[^/]*/\$##g" | sed -E "s#^\$#/#g" )"							# for ../
#absurl5="$(echo "$FILE" | sed -E "s#^[^/]*##g;s#/[^/]*\$#/#g" | sed -E "s#^\$#/#g" )"									# for ./
#norelative1="(<[^>]*)(href=\"|src=\")(\.\./\.\./\.\./\.\./)([^\"]*)(\"[^>]*>)"
#norelative2="(<[^>]*)(href=\"|src=\")(\.\./\.\./\.\./)([^\"]*)(\"[^>]*>)"
#norelative3="(<[^>]*)(href=\"|src=\")(\.\./\.\./)([^\"]*)(\"[^>]*>)"
#norelative4="(<[^>]*)(href=\"|src=\")(\.\./)([^\"]*)(\"[^>]*>)"
#norelative5="(<[^>]*)(href=\"|src=\")(\./){1,10}([^\"]*)(\"[^>]*>)"
#		| sed -E "s#$norelative1#\1\2${absurl1}\4\5#g;s#${norelative1//\"/\'}#\1\2${absurl1}\4\5#g" \
#		| sed -E "s#$norelative2#\1\2${absurl2}\4\5#g;s#${norelative2//\"/\'}#\1\2${absurl2}\4\5#g" \
#		| sed -E "s#$norelative3#\1\2${absurl3}\4\5#g;s#${norelative3//\"/\'}#\1\2${absurl3}\4\5#g" \
#		| sed -E "s#$norelative4#\1\2${absurl4}\4\5#g;s#${norelative4//\"/\'}#\1\2${absurl4}\4\5#g" \
#		| sed -E "s#$norelative5#\1\2${absurl5}\4\5#g;s#${norelative5//\"/\'}#\1\2${absurl5}\4\5#g" \

# - replace all ".css?asdfasdfsdf" with ".css" - stylesheets must not have any other ending
stylesheet='s/(<[^>]+"[^"]+)\.css\?([^"]*)("[^>]*>)/\1.css\3/g'

# - index.html?asdf -> index.html%3Fasdf  - files won't load otherwise
qmark='s/(<[^>]+"[^"]+)\?([^"]*"[^>]*>)/\1%3F\2/g'

# this useless(?) tag can cause a segfault in zimwriterfs
zimwriterfsbug='s#<meta[^>]*http-equiv="refresh"[^>]*>##g'

# - inject css to forcefully hide all elements where class or id is *cookie* *banner* *consent* etc sort of cheap but better than nothing
antishit='s#<[[:space:]]*head[[:space:]]*>#<head><style type="text/css">[class*="__useless__"]'
for word in cookie banner disclaimer consent gdpr privacy popup adsby adsense advert sponsored adcontainer  -ads- -ad- ads_ ads- _ads leaderboard- ad-wrapper adholder adslot adspace adspot adv- boxad contentad footer-ad header-ad; do 
	antishit="$antishit, [id*='$word'], [class*='$word']"
done
antishit="$antishit { display: none !important; } body { overflow: auto !important; }</style>#g"

# final command removes http:/ with urlregex_ to make relative URLs -> /asdf

# Kiwix does not understand autoloading index.html, this hack produces the following issues: 1. the "l" could be missing in .html, 2. http://example.com/mydir will not be interepreted as being a directory,, 3. it probably damages external links (only this really makes sense due to erratic wget behavior)
# urlregx_idx1 : http://external.com -> http://external.com/index.html
# urlregx_idx2 : /mydir/ -> /mydir/index.html
 
tmpfile=$(mktemp); cat "$FILE" | tr '\n' 'ɰ' \
		| sed -E "s#$urlregx_idx1#\1\2\3\4/index.html\5#g;s#${urlregx_idx1//\"/\'}#\1\2\3\4/index.html\5#g" \
		| sed -E "$nodomain;${nodomain//\"/\'}" \
		| sed -E "s#$urlregex_media#\1\3\4\5\6#g;s#${urlregex_media//\"/\'}#\1\3\4\5\6#g" \
		| sed -E "s#$urlregex_any#\1\2\4\5#g;s#${urlregex_any//\"/\'}#\1\2\4\5#g" \
		| sed -E "s#$urlregx_idx2#\1\2\3/index.html\4#g;s#${urlregx_idx2//\"/\'}#\1\2\3/index.html\4#g" \
		| sed -E "$stylesheet;${stylesheet//\"/\'}" \
		| sed -E "$qmark;${qmark//\"\'}" \
		| sed -E "$zimwriterfsbug;${zimwriterfsbug//\"/\'}" \
		| sed -E "$antishit" \
		|  tr 'ɰ' '\n' > ${tmpfile} ; cat ${tmpfile} > "$FILE"
rm ${tmpfile}


THEREISNOPLACELIKEHOME

echo "iterating over .html files to fix links, css and stuff"
chmod 755 $iterscript
EXTERNALURLS=$(mktemp)
find $DOMAIN -type f \( -name '*.htm*' -or -name '*.php*' \) -exec "$iterscript" "$DOMAIN" '{}' "$EXTERNALURLS" "$WGETREJECT" "$NOOVERREACH" -not -path "./$DOMAIN/wget-2-zim-overreach/*" \;
find $DOMAIN/wget-2-zim-overreach/ -type f \( -name '*.htm*' -or -name '*.php*' \) -exec "$iterscript" "$DOMAIN" '{}' "$EXTERNALURLS" "$WGETREJECT" "ma" \;
mv $DOMAIN/wget-2-zim-overreach/* $DOMAIN/
rm $EXTERNALURLS $iterscript
echo "iteration finished"
}

echo "renaming .css?xxx files to .css"
find $DOMAIN -name '*\.css\?*' -exec sh -c 'mv '"'"'{}'"'"' "$(echo '"'"'{}'"'"' | sed -E "s#\.css\?.*#.css#g")" ' \;


# various shenanegans to deal with media and large files

function largedelete {

echo "deleting files deemed too large"

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

echo "deleting files finished"
}

# I made those functions to easily switch off for debugging

thewget
#rsync -ra $DOMAIN/ ${DOMAIN}_debug/
postwget
largedelete

# favicon
 
MYFAVICON="$(command ls -w 1 $DOMAIN/favicon*.{png,ico,gif,jpg,bmp} 2>/dev/null | tail -n 1)"

if [ -f "$MYFAVICON" ]; then
	convert -resize 48x48 "$MYFAVICON" $DOMAIN/zim_favicon.png
else  
	convert -size 48x48 xc:white $DOMAIN/zim_favicon.png
fi


# choose index page (welcome)

if [ ! -f "$DOMAIN/$WELCOME" ]; then
	LISTHTML="$(find "$DOMAIN" -type f -maxdepth 1 \( -name 'index.htm*' -or -name 'index.php*' \) -printf '%f\n' 2>/dev/null | sort)"
 	LISTHTML="$LISTHTML"$'\n'"$(find "$DOMAIN" -type f -maxdepth 1 \( -name '*.htm*' -or -name '*.php*' \) -printf '%f\n' 2>/dev/null | sort)"
	WELCOME="$(echo "$LISTHTML" | sed '/^$/d' | cat - <(echo "$DOMAIN/index.html") | head -n 1 | sed "s#^[^/]*/##g")"
fi


# write ZIM

rm ${DOMAIN}.zim >&/dev/null

echo "writing ZIM"
DESCRIPTION="$(cat $DOMAIN/index.html | tr '\n' ' ' | grep -oaE "<title>[^>]*</title>" | sed "s/<[^>]*>//g;s/[[:space:]]\+/\ /g;s/^[[:space:]]*//g;s/[[:space:]]*$//g" | cat - <(echo "no description") | head -n 1 )" 

if zimwriterfs --welcome="$WELCOME" --illustration=zim_favicon.png --language=eng --title="$DOMAIN" --description "$DESCRIPTION" --longDescription="$DESCRIPTION (created by wget-2-zim)" --creator="https://github.com/ballerburg9005/wget-2-zim" --publisher "wget-2-zim, a simple easy to use script that just works" --name "$DOMAIN" --source="$DOMAIN" --scraper "wget-2-zim `date` , `wget --version |head -n 1`" ./$DOMAIN $DOMAIN.zim; then
	echo "Success in creating ZIM file!"
#	rm -rf ./$DOMAIN
else
	echo "FAILURE! Left $DOMAIN download directory in place."
fi

