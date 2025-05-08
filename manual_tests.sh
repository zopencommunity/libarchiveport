#!/bin/bash

MANUAL_TESTS_DIR=./manual_tests
mkdir -p ${MANUAL_TESTS_DIR}

BSDTAR=$PWD/libarchive/bsdtar
FORMATS=( ustar pax cpio zip 7zip )

for fmt in ${FORMATS[@]}
do
    rm -f ${MANUAL_TESTS_DIR}/test.${fmt} ${MANUAL_TESTS_DIR}/test.txt
    echo "Test file : $PWD" > ${MANUAL_TESTS_DIR}/test.txt

    echo "Test ${fmt} format"
    $BSDTAR -cvf ${MANUAL_TESTS_DIR}/test.${fmt} --format=${fmt} ${MANUAL_TESTS_DIR}/test.txt
    
    if [ $? != "0" ]
    then
        echo "Compression failed for ${fmt} format"
    else
        echo "Compression OK"
    fi


    $BSDTAR -tvf ${MANUAL_TESTS_DIR}/test.${fmt}

    $BSDTAR -xvf ${MANUAL_TESTS_DIR}/test.${fmt}

    if [ $? != "0" ]
    then
        echo "Extraction failed for ${fmt} format"
    else
        echo "Extraction OK"
    fi
done

