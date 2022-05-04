# intro
Wget-2-zim is a simple bash script with some nifty tricks that can be used to archive websites on the internet. It does not require ServiceWorkers and will drop a [ZIM file](https://wiki.openzim.org/) that can be read with [Kiwix](https://www.kiwix.org/en/). The script does several things that go very much beyond what wget alone would do. For example it deletes large files and it grabs embedded images and media files from external URLs also.

# how to use 

**Install: wget imagemagick zim-tools**

> ./wget-2-zim.sh https://ballerburg.us.to

Now just open the ZIM file in Kiwix.

## options

There are quite some options now that you can use in order to reduce the file size and grab less content (or more). The default options are very very generous to archive as much as possible, even larger (up to 128MB) xls, epub or pdf files, video, audio and so forth are included by default. Archives and program files are excluded by default, however they can be included with a command line option. Ordinary files or files with unknown file type are deleted from the ZIM if they exceed 2 MB (this can be changed as well).

# notes

I will probably add docker later


