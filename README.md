[![Automatic version updates](https://github.com/zopencommunity/libarchiveport/actions/workflows/bump.yml/badge.svg)](https://github.com/zopencommunity/libarchiveport/actions/workflows/bump.yml)

# libarchive

The libarchive project develops a portable, efficient C library that can read and write streaming archives in a variety of formats. It also includes implementations of the common tar, cpio, and zcat command-line tools that use the libarchive library.

# `bsdtar` compression and decompression was verified for the following formats
* ustar pax cpio zip 7zip
* Please run the script `./manual_tests.sh` to verify the same

```
Test ustar format
a ./manual_tests/test.txt
Compression OK
-rw-------  0 IN005HF TSOUSER    42 May  8 06:04 ./manual_tests/test.txt
x ./manual_tests/test.txt
Extraction OK
Test pax format
a ./manual_tests/test.txt
Compression OK
-rw-------  0 IN005HF TSOUSER    42 May  8 06:04 ./manual_tests/test.txt
x ./manual_tests/test.txt
Extraction OK
Test cpio format
a ./manual_tests/test.txt
Compression OK
?rwsrwsrwt  1 223    5          42 May  8 06:04 ./manual_tests/test.txt
x ./manual_tests/test.txt
Extraction OK
Test zip format
a ./manual_tests/test.txt
Compression OK
?rw-------  0 223    5          42 May  8 06:04 ./manual_tests/test.txt
x ./manual_tests/test.txt
Extraction OK
Test 7zip format
a ./manual_tests/test.txt
Compression OK
?rw-------  0 0      0          42 May  8 06:04 ./manual_tests/test.txt
x ./manual_tests/test.txt
Extraction OK
```
