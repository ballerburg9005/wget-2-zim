#!/bin/bash

if [[ " --help -help -h " =~ " $1 " || "$1" == "" ]]; then
	echo "$0 URL"
	echo "Makes ZIM file from URL with recursive wget and lots of tricks. There are no options."
	exit -1
else
	URL="$1"
fi

# extract strings from URL

DOMAIN="$(echo "$URL" | sed 's#^[^/]*//##g;s#/.*$##g')" 
WELCOME="$(echo "$URL" | sed 's#^[^/]*//##g;' | grep -osa "/.*$" | sed 's/\?/-questionmark-/g')"

# download with wget

#function asdf {
wget -r -p -k -c --timeout=3s --no-check-certificate \
	--user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.41 Safari/537.36" \
	--header="X-Requested-With: XMLHttpRequest" --header="Referer: $DOMAIN" --header='Accept-Language: en' \
	$URL

# various URL repairs

find $DOMAIN -name '*\.css\?*' -exec sh -c 'mv '"'"'{}'"'"' $(echo '"'"'{}'"'"' | sed -E "s#\.css\?.*#.css#g") ' \;

find $DOMAIN -type f \( -name '*.htm*' -or -name '*.php*' \) \
	-exec sh -c 'tmpfile=$(mktemp); cat '"'"'{}'"'"' | tr '"'"'\n'"'"' '"'"'ɰ'"'"' | sed -E '"'"'s/(<[^>]+"[^"]+)\.css\?([^"]*)"([^>]*>)/\1.css"\3/g'"'"'";s/(<[^>]+'"'"'[^'"'"']+)\.css\?([^'"'"']*)'"'"'([^>]*>)/\1.css'"'"'\3/g" | sed -E '"'"'s/(<[^>]+"[^"]+)\?([^"]*"[^>]*>)/\1%3F\2/g'"'"'";s/(<[^>]+'"'"'[^'"'"']+)\?([^'"'"']*'"'"'[^>]*>)/\1%3F\2/g" | sed -E '"'"'s#(["])http[s]*://'"$DOMAIN"'/*(["])#"/"#g;'"'"'"s#(['"'"'])http[s]*://'"$DOMAIN"'/*(['"'"'])#'"'"'/'"'"'#g;" | sed -E '"'"'s#(["])http[s]*://'"$DOMAIN"'/#\1#g'"'"'";s#(['"'"'])http[s]*://'"$DOMAIN"'/#\1#g" | sed -E '"'"'s#<[[:space:]]*head[[:space:]]*>#<head><style type="text/css">[class*="cookie"], [id*="cookie"], [id*="banner"], [class*="banner"], [id*="disclaimer"], [class*="disclaimer"], [id*="consent"], [class*="consent"], [id*="gdpr"], [class*="gdpr"], [id*="privacy"], [class*="privacy"]  { display: none !important; } </style>#g'"'"'	|  tr '"'"'ɰ'"'"' '"'"'\n'"'"' > ${tmpfile} ; cat ${tmpfile} > '"'"'{}'"'"'  ' \;
			#  replace all ".css?asdfasdfsdf" with ".css" - stylesheets must not have any other ending
			#  index.html?asdf -> index.html%3Fasdf (literally opens files with question marks in them, rather than making it a parameter)
			# "http://example.com" -> /
			# "http://example.com/asdf/asdf" -> asdf/asdf
			# inject css to forcefully hide all elements where class or id is *cookie* *banner* *consent* *disclaimer* *gdpr* *privacy* ... sort of cheap but better than nothing



#} 

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
	rm -rf ./$DOMAIN
else
	echo "FAILURE! Left $DOMAIN download directory in place."
fi

