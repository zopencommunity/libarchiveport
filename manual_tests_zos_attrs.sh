#!/bin/bash
#
# Manual tests for z/OS ZOS.* pax extended attribute restoration.
# Requires: IBM pax (to build test archives), chtag, the zopen-built
# bsdtar, and a z/OS filesystem.  Run from the libarchiveport root
# after building (libarchive/bsdtar must exist).
#
# Covers:
#   1. ZOS.taginfo restored by default (no --xattrs needed)
#   2. ZOS.taginfo=0 clears an existing tag on the destination
#   3. audit/filefmt/extattr only restored with ARCHIVE_EXTRACT_XATTR
#      (bsdtar --xattrs), matching IBM "pax -r -p e"
#   4. symlinks are never tagged
#   5. existing entries + ARCHIVE_EXTRACT_NO_OVERWRITE (-k) are not
#      overwritten or retagged (metadata suppression)
#   6. data-less hardlink entries do not disturb the first instance

set -e
set -u
BSDTAR=${BSDTAR:-$PWD/libarchive/bsdtar}
PAX=${PAX:-pax}
LS=/bin/ls
T=$PWD/manual_tests/zos_attrs
rm -rf $T && mkdir -p $T

FAILURES=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((FAILURES+1)); }

# Full tag of a file/directory from "ls -T" output.  IBM ls -T prints
# e.g. "t ISO8859-1   T=on  file" (fields: tag marker, CCSID or
# "untagged", T=on/off) or "- untagged    T=off file".  -d makes the
# query work for directories too.
tagof() { $LS -Td "$1" | awk '{print $2, $3}'; }
# user audit flags from "ls -lW" (e.g. "fff---")
auditof() { $LS -lW "$1" | awk '{print $2}'; }

echo "== 1. tag restored by default =="
mkdir -p $T/src1 && cd $T/src1
echo hello > tagged.txt
chtag -t -c ISO8859-1 tagged.txt
$PAX -w -x pax -f $T/t1.pax tagged.txt
cd $T && rm -rf out1 && mkdir out1 && cd out1
# --no-xattrs: audit/extattr must NOT be restored even when running
# as root (root enables ARCHIVE_EXTRACT_XATTR by default); the tag
# pass is independent of that flag and must still run.
$BSDTAR --no-xattrs -xf $T/t1.pax
[ "$(tagof tagged.txt)" = "ISO8859-1 T=on" ] \
    && pass "default extraction restores tag" \
    || fail "default extraction restores tag (got: $(tagof tagged.txt))"

echo "== 2. ZOS.taginfo=0 clears an existing tag =="
cd $T && rm -rf out2 && mkdir out2 && cd out2
# destination starts out tagged 1047; the archive says untagged
echo stale > tagged.txt
chtag -t -c IBM-1047 tagged.txt
cd $T/src1 && chtag -r tagged.txt 2>/dev/null || true   # remove tag
$PAX -w -x pax -o ZOS.taginfo=0 -f $T/t2.pax tagged.txt
cd $T/out2
$BSDTAR --no-xattrs -xf $T/t2.pax
[ "$(tagof tagged.txt)" = "untagged T=off" ] \
    && pass "explicit untagged clears existing tag" \
    || fail "explicit untagged clears existing tag (got: $(tagof tagged.txt))"

echo "== 3. audit flags gated on --xattrs =="
cd $T/src1 && chtag -t -c ISO8859-1 tagged.txt
$PAX -w -x pax -o ZOS.useraudit=ssa -f $T/t3.pax tagged.txt
cd $T && rm -rf out3a out3b && mkdir out3a out3b
cd $T/out3a
# --no-xattrs keeps the disabled-XATTR branch testable even as root
$BSDTAR --no-xattrs -xf $T/t3.pax
[ "$(auditof tagged.txt)" = "fff---" ] \
    && pass "no --xattrs: audit flags not restored" \
    || fail "no --xattrs: audit flags not restored (got: $(auditof tagged.txt))"
cd $T/out3b
$BSDTAR --xattrs -xf $T/t3.pax
[ "$(auditof tagged.txt)" = "ssa---" ] \
    && pass "--xattrs: audit flags restored (pax -p e)" \
    || fail "--xattrs: audit flags restored (got: $(auditof tagged.txt))"

echo "== 4. symlinks are not tagged =="
cd $T/src1 && ln -sf tagged.txt link.txt
$PAX -w -x pax -f $T/t4.pax tagged.txt link.txt
cd $T && rm -rf out4 && mkdir out4 && cd out4
$BSDTAR --no-xattrs -xf $T/t4.pax
# the link target keeps its archive tag; the link itself must not
# have been tagged (z/OS cannot tag symlinks)
[ "$(tagof tagged.txt)" = "ISO8859-1 T=on" ] && [ -L link.txt ] \
    && pass "symlink extracted, target tagged, link untouched" \
    || fail "symlink extracted, target tagged, link untouched"

echo "== 5. NO_OVERWRITE leaves existing entries alone =="
# Note: directories cannot be tagged on z/OS, so the suppression is
# observed through the pre-existing file inside the directory: with
# -k, neither its contents nor its 1047 tag may change, even though
# the archive carries an ISO8859-1 tagged version of it.
cd $T && rm -rf out5 && mkdir -p out5/dir
echo keepme > out5/dir/file.txt
chtag -t -c IBM-1047 out5/dir/file.txt
BEFORE="$(tagof $T/out5/dir/file.txt)"
cp $T/out5/dir/file.txt $T/before5.bin   # raw bytes (cat would convert)
cd $T/src1 && mkdir -p dir && echo archived > dir/file.txt
chtag -t -c ISO8859-1 dir/file.txt
$PAX -w -x pax -f $T/t5.pax dir
cd $T/out5
$BSDTAR -k --no-xattrs -xf $T/t5.pax
AFTER="$(tagof $T/out5/dir/file.txt)"
[ "$BEFORE" = "$AFTER" ] && cmp -s $T/out5/dir/file.txt $T/before5.bin \
    && pass "-k: existing file content and tag unchanged ($AFTER)" \
    || fail "-k: existing file content and tag unchanged (was '$BEFORE', now '$AFTER')"

echo "== 6. data-less hardlink does not disturb the first instance =="
cd $T && rm -rf out6 && mkdir out6
cd $T/src1 && rm -f hard.txt
ln tagged.txt hard.txt
$PAX -w -x pax -f $T/t6.pax tagged.txt hard.txt
cd $T/out6
$BSDTAR --no-xattrs -xf $T/t6.pax
# hard.txt and tagged.txt are the same inode; the data-less hardlink
# entry must not fail or disturb the tag restored by the first entry
[ "$(tagof tagged.txt)" = "ISO8859-1 T=on" ] && [ "$(tagof hard.txt)" = "ISO8859-1 T=on" ] \
    && pass "data-less hardlink extraction OK" \
    || fail "data-less hardlink extraction OK (tag: $(tagof tagged.txt))"

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "All z/OS attribute tests PASSED"
else
    echo "${FAILURES} test(s) FAILED"
fi
exit $FAILURES
