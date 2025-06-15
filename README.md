<h1 align="center">
  <img width=320 src="logo_400.png" alt="wget-2-zim logo">
</h1>

# about
Wget-2-zim is a simple bash script with some nifty tricks that can be used to archive websites on the internet. It does not require ServiceWorkers and will drop a [ZIM file](https://wiki.openzim.org/) that can be read with any [Kiwix](https://www.kiwix.org/en/) reader anywhere. The script does several things that go very much beyond what wget alone would do. For example it deletes large files and it grabs embedded images and media files from external URLs, it injects anti-cookie-banner CSS and all sorts of other useful things. 

Please note that wget has very very limited ability to deal with Javascript, which may cause rendering issues with some pages. [Zimit](https://github.com/openzim/zimit) is an alternative that uses the Web ARChive standard, but it does require ServiceWorkers, which currently (2022) does not work with Kiwix-Desktop (only kiwix-android and kiwix-serve).

# how to use 

**First install those dependencies: wget, imagemagick, zim-tools, zimwriterfs** (the latter might not exist as single package yet)

*(Beginners: read the "troubleshooting" section for possible command chain.)*

Then run this command:

> ./wget-2-zim.sh https://example.org

Now just open the ZIM file in Kiwix.

## options
```
./wget-2-zim.sh [OPTIONS] URL
Makes ZIM file from URL with recursive wget and lots of tricks.
 
wget-2-zim tries to make a bunch of smart decisions what to include in the ZIM, but it still
tries to include as much as sanely possible (like PDFs, XLS files, music and video).
 
--any-max	[SIZE (MB)]	Any file larger will be deleted before doing the ZIM no matter what. Default = 128MB
--not-media-max [SIZE (MB)]	Any file larger that is not music, video, picture or epub, pdf, xls alike will be excluded. Default = 2MB
--picture-max 	[SIZE (MB)]	Any picture file larger will be excluded from ZIM. Default = unset
--document-max 	[SIZE (MB)]	Any document file larger will be excluded from ZIM (epub, pdf, xls, ods, etc.). Default = unset
--music-max 	[SIZE (MB)]	Any music file larger will be excluded from ZIM. Default = unset
--video-max 	[SIZE (MB)]	Any video file larger will be excluded from ZIM. Default = unset
--wget-depth			Set this to 1 or 3 if you want to make very shallow copies. Default = 7
--include-zip 			Includes all sorts of archives (zip, rar, 7z, gz, etc).
--include-exe			Includes all sorts of program files (exe, msi, deb, rpm, etc).
--include-any			Download any file type.
--no-overreach-media		Don't overreach by downloading media files from external domains (might affect images directly visible on the page).
--overreach-any			Overreach by downloading any sort of src= and href= content from external domains.
--turbo				Disable all download delays (will probably result in half the files missing due to throttling with false 404s)
```

# running under Windows

[Please do not run Windows](https://ballerburg.us.to/about-your-obligation-to-boycott-windows-11/). However if you really must, then there are basically two easy methods to do it: 

1. [WSL2](https://docs.microsoft.com/en-us/windows/wsl/setup/environment) (fairly easy) - integrated Linux environment from Microsoft, more similar to a virtual machine (runs Linux binaries)
2. [MSYS2](https://www.msys2.org/) Great tool, but NOT VIABLE ANYMORE FOR ZIM-TOOLS! Don't try.

## WSL2 

Follow one of the many [tutorials](https://www.youtube.com/watch?v=pOZ5Pb4pHOY) to set up WSL2 on Windows. Make sure to use the latest image of Ubuntu and not Debian (or other distributions which might have severely outdated packages).

Then follow the steps in section "running on Ubuntu".

# running on Ubuntu

1. apt install wget imagemagick git zim-tools
2. apt install zimwriterfs # if this fails ignore it
3. git clone https://github.com/ballerburg9005/wget-2-zim
4. ./wget-2-zim/wget-2-zim.sh https://example.org

*I have not actually tested this!*

# troubleshooting for beginners

If you get the error "convert: command not found" or "zimwriterfs: command not found" it means that you did not install the necessary dependencies as instructed in the "how to use" section. 

If you look at the steps 1-4 in "running on Ubuntu" section, you can see what the exact commands for a proper installation should look like. However, you have to understand that the first step (#1) will only work on Ubuntu and Debian-alike systems, since "apt" is a specific package manager, and it differs between Linux distributions. Thus please adapt step #1 appropriately.

Another problem that might happen is, that zimwriterfs complains about "--illustration" option being unknown (or some other option). This is because you are using an outdated version of zim-tools. Please uninstall it and build zim-tools by hand. Unfortunately building zim-tools by hand has become increasingly challenging and prone to error nowadays.

Untested build chain for zim-tools:
```
# You need probably install a lot of dependencies along the way with your package manager!
git clone https://github.com/openzim/libzim
cd libzim; meson setup build -Dwerror=false; ninja -C build; ninja -C build install; cd ~/
git clone https://github.com/openzim/zim-tools
cd zim-tools; meson setup build -Dwerror=false; ninja -C build; ninja -C build install; cd ~/
git clone ttps://github.com/openzim/zimwriterfs
cd zimwriterfs; meson setup build -Dwerror=false; ninja -C build; ninja -C build install; cd ~/
```

# known issues

* The website can throttle you if you download too much too fast, rendering your archive incomplete. You will notice this when you suddenly only get 404 errors, or when it just hangs a lot. There are already (very necessary) delays inside the script in various places to prevent this. If you still experience throttling, it is probably due to total download volume per 24 hours. You could try making the delays even bigger, or you could try pausing the script with CTRL + Z in between, and continue it the next day or some time later with "fg" bit by bit.
* Due to cookie banner removing CSS, some sites might not scroll or only show a blank box that you can't click away. The solution is to modify or blank out "antishit" inside the script. This will however result in cookie banners showing on every page, and also ads if present.
