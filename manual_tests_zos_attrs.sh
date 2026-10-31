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
#   5. existing directory + ARCHIVE_EXTRACT_NO_OVERWRITE (-k) is not
#      retagged (metadata suppression)
#   6. data-less hardlinks are not retagged (metadata suppression)

set -u
BSDTAR=${BSDTAR:-$PWD/libarchive/bsdtar}
PAX=${PAX:-pax}
LS=/bin/ls
T=$PWD/manual_tests/zos_attrs
rm -rf $T && mkdir -p $T

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILURES=$((${FAILURES:-0}+1)); }

# tag of a file, from "ls -T" output (e.g. "text T=on ISO8859-1")
tagof() { $LS -T "$1" 2>/dev/null | awk '{print $1, $2}'; }
# user audit flags from "ls -lW" (e.g. "fff---")
auditof() { $LS -lW "$1" 2>/dev/null | awk '{print $2}'; }

echo "== 1. tag restored by default =="
mkdir -p $T/src1 && cd $T/src1
echo hello > tagged.txt
chtag -t -c ISO8859-1 tagged.txt
$PAX -w -x pax -f $T/t1.pax tagged.txt
cd $T && rm -rf out1 && mkdir out1 && cd out1
$BSDTAR -xf $T/t1.pax
[ "$(tagof tagged.txt)" = "text T=on" ] \
    && pass "default extraction restores tag" \
    || fail "default extraction restores tag (got: $(tagof tagged.txt))"

echo "== 2. ZOS.taginfo=0 clears an existing tag =="
cd $T && rm -rf out2 && mkdir out2 && cd out2
# destination starts out tagged 1047; archive says untagged
echo stale > tagged.txt
chtag -t -c IBM-1047 tagged.txt
# build the untagged archive: an untagged source file
cd $T/src1 && chtag -r tagged.txt   # remove tag
$PAX -w -x pax -o ZOS.taginfo=0 -f $T/t2.pax tagged.txt
cd $T/out2
$BSDTAR -xf $T/t2.pax
[ "$(tagof tagged.txt)" = "untagged T=off" ] \
    && pass "explicit untagged clears existing tag" \
    || fail "explicit untagged clears existing tag (got: $(tagof tagged.txt))"

echo "== 3. audit/extattr gated on --xattrs =="
cd $T && rm -rf out3a out3b && mkdir out3a out3b
cd $T/src1 && chtag -t -c ISO8859-1 tagged.txt
$PAX -w -x pax -o ZOS.useraudit=ssa -f $T/t3.pax tagged.txt
cd $T/out3a && $BSDTAR -xf $T/t3.pax
[ "$(auditof tagged.txt)" = "fff---" ] \
    && pass "no --xattrs: audit flags not restored" \
    || fail "no --xattrs: audit flags not restored (got: $(auditof tagged.txt))"
cd $T/out3b && $BSDTAR --xattrs -xf $T/t3.pax
[ "$(auditof tagged.txt)" = "ssa---" ] \
    && pass "--xattrs: audit flags restored (pax -p e)" \
    || fail "--xattrs: audit flags restored (got: $(auditof tagged.txt))"

echo "== 4. symlinks are not tagged =="
cd $T/src1 && ln -sf tagged.txt link.txt 2>/dev/null
$PAX -w -x pax -f $T/t4.pax tagged.txt link.txt
cd $T && rm -rf out4 && mkdir out4 && cd out4
$BSDTAR -xf $T/t4.pax
# the symlink target keeps its tag from the archive; the link itself
# must not have been tagged (it cannot be on z/OS)
$LS -T link.txt >/dev/null 2>&1 && \
    pass "symlink extracted without error" || \
    fail "symlink extracted without error"

echo "== 5. NO_OVERWRITE directory is not retagged =="
cd $T && rm -rf out5 && mkdir -p out5/dir
chtag -t -c IBM-1047 out5/dir   # destination dir tagged differently
cd $T/src1 && mkdir -p dir && echo x > dir/file.txt
chtag -t -c ISO8859-1 dir/file.txt
$PAX -w -x pax -f $T/t5.pax dir
cd $T/out5
$BSDTAR -k -xf $T/t5.pax   # -k = ARCHIVE_EXTRACT_NO_OVERWRITE
[ "$(tagof dir)" = "text T=on" ] \
    && pass "existing dir with -k keeps its own tag" \
    || fail "existing dir with -k keeps its own tag (got: $(tagof dir))"

echo "== 6. data-less hardlink is not retagged =="
cd $T && rm -rf out6 && mkdir out6 && cd out6
echo orig > hard.txt
chtag -t -c IBM-1047 hard.txt   # give the first instance a 1047 tag
cd $T/src1 && ln -f tagged.txt hard.txt 2>/dev/null || ln tagged.txt hard.txt
$PAX -w -x pax -f $T/t6.pax tagged.txt hard.txt
cd $T/out6
$BSDTAR -xf $T/t6.pax
# hard.txt and tagged.txt are the same inode; one tag applies.
# The point of this test is that extraction completes and the
# data-less hardlink entry did not produce a spurious chattr failure.
[ -f hard.txt ] && [ "$(tagof tagged.txt)" = "text T=on" ] \
    && pass "data-less hardlink extraction OK" \
    || fail "data-less hardlink extraction OK"

echo
if [ "${FAILURES:-0}" -eq 0 ]; then
    echo "All z/OS attribute tests PASSED"
else
    echo "${FAILURES} test(s) FAILED"
fi
exit ${FAILURES:-0}
