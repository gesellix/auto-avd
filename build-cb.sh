#!/bin/bash

# The MIT License
#
# Copyright 2012 Ashley Willis <ashley.github@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Based off tools/build-beta (part of the K9 Mail repo) by Jesse Vincent.

# This script adds about 1 second of time on my horribly slow harddrive.

# Temporarily rename an Android project for building.
# Set the first 5 or 6 DIST_* and BETA_* to whatever you are going from and to.
# Set PROJECT_DIR to the absolute path pf the main project.
# Set TEST_DIR to the absolute path of the test project.
# Then run this script with the same arguments you'd pass to ant. It can be
# run from either $PROJECT_DIR or $TEST_DIR. It might require tweaks
# depending on how your project is laid out.

PROJECT_DIR=${WORKSPACE}
TEST_DIR=${PROJECT_DIR}/tests

DIST_TLD=com
DIST_DOMAIN=fsck
DIST_PROJECT=k9
DIST_LOGTAG=k9
DIST_PROJ_NAME=K9
DIST_APP_NAME='\@string/app_name'

BETA_TLD=com
BETA_DOMAIN=fsck
BETA_PROJECT=k9cloud
BETA_LOGTAG=k9cloud
BETA_PROJ_NAME=K9Cloud
BETA_APP_NAME='K-9 CloudBees'

# Nothing below here should need to be changed.

DIST_PACKAGE="${DIST_TLD}.${DIST_DOMAIN}.${DIST_PROJECT}"
DIST_PATH="${DIST_TLD}/${DIST_DOMAIN}/${DIST_PROJECT}"

BETA_PACKAGE="${BETA_TLD}.${BETA_DOMAIN}.${BETA_PROJECT}"
BETA_PATH="${BETA_TLD}/${BETA_DOMAIN}/${BETA_PROJECT}"

# convert to beta project:
perl -pi -e"s|${DIST_APP_NAME}|${BETA_APP_NAME}|g" ${PROJECT_DIR}/AndroidManifest.xml
perl -pi -e"s|${DIST_PACKAGE}|${BETA_PACKAGE}|g" ${PROJECT_DIR}/AndroidManifest.xml ${TEST_DIR}/AndroidManifest.xml
perl -pi -e"s|${DIST_PROJ_NAME}|${BETA_PROJ_NAME}|g" ${PROJECT_DIR}/build.xml ${TEST_DIR}/build.xml
perl -pi -e"s|LOG_TAG = \"${DIST_LOGTAG}\"|LOG_TAG = \"${BETA_LOGTAG}\"|" ${PROJECT_DIR}/src/${DIST_PATH}/${DIST_PROJ_NAME}.java
find ${PROJECT_DIR}/src/${DIST_TLD}/${DIST_DOMAIN} ${PROJECT_DIR}/res ${TEST_DIR}/src/${DIST_TLD}/${DIST_DOMAIN} ${TEST_DIR}/res \
        -type f -print0 | xargs -0 perl -pi -e"s/${DIST_PACKAGE}(?=\W)/${BETA_PACKAGE}/g"
if [[ "${DIST_PROJECT}" != "${BETA_PROJECT}" ]]; then
    mv ${PROJECT_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}/${DIST_PROJECT} ${PROJECT_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}/${BETA_PROJECT}
    mv ${TEST_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}/${DIST_PROJECT} ${TEST_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}/${BETA_PROJECT}
fi
if [[ "${DIST_DOMAIN}" != "${BETA_DOMAIN}" ]]; then
    mv ${PROJECT_DIR}/src/${DIST_TLD}/${DIST_DOMAIN} ${PROJECT_DIR}/src/${DIST_TLD}/${BETA_DOMAIN}
    mv ${TEST_DIR}/src/${DIST_TLD}/${DIST_DOMAIN} ${TEST_DIR}/src/${DIST_TLD}/${BETA_DOMAIN}
fi
if [[ "${DIST_TLD}" != "${BETA_TLD}" ]]; then
    mv ${PROJECT_DIR}/src/${DIST_TLD} ${PROJECT_DIR}/src/${BETA_TLD}
    mv ${TEST_DIR}/src/${DIST_TLD} ${TEST_DIR}/src/${BETA_TLD}
fi

# do ant and save exit status:
ant $@
MYEXIT=$?

# convert back to normal project:
if [[ "${DIST_TLD}" != "${BETA_TLD}" ]]; then
    mv ${PROJECT_DIR}/src/${BETA_TLD} ${PROJECT_DIR}/src/${DIST_TLD}
    mv ${TEST_DIR}/src/${BETA_TLD} ${TEST_DIR}/src/${DIST_TLD}
fi
if [[ "${DIST_DOMAIN}" != "${BETA_DOMAIN}" ]]; then
    mv ${PROJECT_DIR}/src//${DIST_TLD}/${BETA_DOMAIN} ${PROJECT_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}
    mv ${TEST_DIR}/src//${DIST_TLD}/${BETA_DOMAIN} ${TEST_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}
fi
if [[ "${DIST_PROJECT}" != "${BETA_PROJECT}" ]]; then
    mv ${PROJECT_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}/${BETA_PROJECT} ${PROJECT_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}/${DIST_PROJECT}
    mv ${TEST_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}/${BETA_PROJECT} ${TEST_DIR}/src/${DIST_TLD}/${DIST_DOMAIN}/${DIST_PROJECT}
fi
find ${PROJECT_DIR}/src/${DIST_TLD}/${DIST_DOMAIN} ${PROJECT_DIR}/res ${TEST_DIR}/src/${DIST_TLD}/${DIST_DOMAIN} ${TEST_DIR}/res \
        -type f -print0 | xargs -0 perl -pi -e"s/${BETA_PACKAGE}(?=\W)/${DIST_PACKAGE}/g"
perl -pi -e"s|LOG_TAG = \"${BETA_LOGTAG}\"|LOG_TAG = \"${DIST_LOGTAG}\"|" ${PROJECT_DIR}/src/${DIST_PATH}/${DIST_PROJ_NAME}.java
perl -pi -e"s|${BETA_PROJ_NAME}|${DIST_PROJ_NAME}|g" ${PROJECT_DIR}/build.xml ${TEST_DIR}/build.xml
perl -pi -e"s|${BETA_PACKAGE}|${DIST_PACKAGE}|g" ${PROJECT_DIR}/AndroidManifest.xml ${TEST_DIR}/AndroidManifest.xml
perl -pi -e"s|${BETA_APP_NAME}|${DIST_APP_NAME}|g" ${PROJECT_DIR}/AndroidManifest.xml

# exit with value from ant:
exit ${MYEXIT}
