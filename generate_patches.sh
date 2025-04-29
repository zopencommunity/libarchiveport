#!/bin/bash

# Script to generate the diff files/patches from libarchive repo to be committed to the libarchiveport repo
# Steps
# 1. Apply all the patches and generate libarchive repo using zopen build command
# 2. Commit the files modified by applying patches. Dev/bug fix changes should be done on top of this commit
# 3. Once changes are ready, create new commit(s)
# 4. Use this script to generate patch for files modified in step 3

echo_error()
{
    echo "ERROR: $1"
}

run_checks()
{
    if [ ! -d ${LIBARCHIVE_DIR} ]
    then
        echo_error "${LIBARCHIVE_DIR} does not exist"
        exit
    fi

    if [ ! -d ${LIBARCHIVE_PORT_DIR} ]
    then
        echo_error "${LIBARCHIVE_PORT_DIR} does not exist"
        exit
    fi

    if [[ -z ${BASE_COMMIT} || -z ${PATCHED_COMMIT} || -z ${CURRENT_COMMIT} ]]
    then
        echo_error "BASE_COMMIT, PATCHED_COMMIT and CURRENT_COMMIT needed but not set"
        exit
    fi
}

# Generate patches for the first time after running zopen generate
gen_patches_first_time()
{
    MODIFIED_FILES=$(git diff-tree --no-commit-id --name-only ${BASE_COMMIT} ${CURRENT_COMMIT} -r)
    
    echo "Modified files:" 
    echo "{MODIFIED_FILES}"
    
    for file in ${MODIFIED_FILES}
    do
        echo "Generating diff for ${file}"
    
        #Save the patch files to libarchiveport/patches/
        PATCH_FILE=${LIBARCHIVE_PORT_DIR}/patches/${file}.patch
        PATCH_FILE_DIR=$(dirname ${PATCH_FILE})
    
        if [ ! -d ${PATCH_FILE_DIR} ]
        then
            echo "${PATCH_FILE_DIR} does not exist, creating one"
    	    mkdir -p ${PATCH_FILE_DIR}
        fi
    
        if [ -f ${PATCH_FILE} ]
        then
            echo "WARNING: ${PATCH_FILE} already exist, contents will be overwritten"
        fi
    
        #Generate patch file
        git diff ${BASE_COMMIT} -- ${file} > ${PATCH_FILE}
    
        #Add the file to the staging area
        cd ${LIBARCHIVE_PORT_DIR} ; git add ${PATCH_FILE} ; cd - 
    done
}

gen_patches()
{
    MODIFIED_FILES=$(git diff-tree --no-commit-id --name-only ${PATCHED_COMMIT} ${CURRENT_COMMIT} -r)
    
    echo "Modified files:" 
    echo "{MODIFIED_FILES}"
    
    for file in ${MODIFIED_FILES}
    do
        echo "Generating diff for ${file}"
    
        #Save the patch files to libarchiveport/patches/
        PATCH_FILE=${LIBARCHIVE_PORT_DIR}/patches/${file}.patch
        PATCH_FILE_DIR=$(dirname ${PATCH_FILE})
    
        if [ ! -d ${PATCH_FILE_DIR} ]
        then
            echo "${PATCH_FILE_DIR} does not exist, creating one"
    	    mkdir -p ${PATCH_FILE_DIR}
        fi
    
        if [ -f ${PATCH_FILE} ]
        then
            echo "WARNING: ${PATCH_FILE} already exist, contents will be overwritten"
        fi
    
        #Generate patch file
        git diff ${BASE_COMMIT} -- ${file} > ${PATCH_FILE}
    
        #Add the file to the staging area
        cd ${LIBARCHIVE_PORT_DIR} ; git add ${PATCH_FILE} ; cd - 
    done


}

LIBARCHIVE_DIR=${LIBARCHIVE_DIR}                          # Path to libarchive repo
LIBARCHIVE_PORT_DIR=${LIBARCHIVE_PORT_DIR}                # Path to libarchiveport repo
BASE_COMMIT=dcbf1e0ededa95849f098d154a25876ed5754bcf      # libarchive gets cloned with this latest commit
PATCHED_COMMIT=7a28dfded2c08621efc77ca746c6007be66e328e   # Run zopen build to apply all the patches in libarchiveport
CURRENT_COMMIT=be0c514a064ee11e2a6f7eb5a67991ab117b01ee   # Commit with further dev changes

## main() STARTS HERE ##
echo "LIBARCHIVE_DIR      ${LIBARCHIVE_DIR}"
echo "LIBARCHIVE_PORT_DIR ${LIBARCHIVE_PORT_DIR}"
echo "BASE_COMMIT         ${BASE_COMMIT}"
echo "PATCHED_COMMIT      ${PATCHED_COMMIT}"
echo "CURRENT_COMMIT      ${CURRENT_COMMIT}"

run_checks

pushd ${LIBARCHIVE_DIR}

# Generate patches for the first time after running zopen generate
#gen_patches_first_time

# Generate patches later
gen_patches

popd
