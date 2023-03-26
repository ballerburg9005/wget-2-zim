<h1 align="center">
  <img width=320 src="logo_400.png" alt="wget-2-zim logo">
</h1>

# about
Wget-2-zim is a simple bash script with some nifty tricks that can be used to archive websites on the internet. It does not require ServiceWorkers and will drop a [ZIM file](https://wiki.openzim.org/) that can be read with any [Kiwix](https://www.kiwix.org/en/) reader anywhere. The script does several things that go very much beyond what wget alone would do. For example it deletes large files and it grabs embedded images and media files from external URLs, it injects anti-cookie-banner CSS and all sorts of other useful things. 

Please note that wget has very very limited ability to deal with Javascript, which may cause rendering issues with some pages. [Zimit](https://github.com/openzim/zimit) is an alternative that uses the Web ARChive standard, but it does require ServiceWorkers, which currently (2022) does not work with Kiwix-Desktop (only kiwix-android and kiwix-serve).

# how to use 

**Install those dependencies: wget, imagemagick, zim-tools (git)**

> ./wget-2-zim.sh https://ballerburg.us.to

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
2. [MSYS2](https://www.msys2.org/) (even easier and faster) - tons of Linux programs and tools compiled for Windows to create a Linux-alike environment for devs

## MSYS2 

1. Download and click though the [installer](https://www.msys2.org/) 
2. Open MSYS2 MINGW64 (drops you into Linux shell)
3. pacman -S wget imagemagick git
4. git clone https://github.com/openzim/zim-tools
5. cd zim-tools; meson . build; ninja -C build; ninja -C build install; cd ~/
6. git clone https://github.com/ballerburg9005/wget-2-zim
7. ~/wget-2-zim/wget-2-zim.sh https://example.com

*I have not actually tested this, but it is really that simple. If pacman complains when downloading try pacman -Sy first.*

# troubleshooting for beginners

If you get the error "convert: command not found" or "zimwriterfs: command not found" it means that you did not install the necessary dependencies as instructed in the "how to use" section. In order to fix this, follow the steps 3-7 outlined in the "MSYS2" section. However, you have to understand that the first step (#3) will only work on Archlinux, since every Linux distribution uses a different package manager. On Debian or Ubuntu for example, you would use "apt install" instead of "pacman -S" to install those packages.
