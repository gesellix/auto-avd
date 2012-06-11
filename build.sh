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

# This script below is meant to be copied into the "Command" section of
# "Execute shell". Jenkins will stop a pasted script when a command fails,
# whereas if ran as a file (i.e. "bash $PRIVATE/build.sh") it will run
# everything. Also, Jenkins outputs what it's doing in a pasted script,
# which is quite useful for the console logging.

# THIS SETS UP THE ANT ANDROID BUILD PROPERTIES
rm -f local.properties;
$ANDROID_HOME/tools/android update project --path ./;
cp -f  local.properties tests/;

# path to cloudbees private storage:
export PRIVATE=${JENKINS_HOME/home/private}
PRIVATE=${PRIVATE%/hudson_home}

# always sign with the same debug key:
mkdir -p  ~/.android
cp -f $PRIVATE/debug.keystore ~/.android/

# build the project:
cd tests/
ant all clean
bash $PRIVATE/build-cb.sh emma debug artifacts

# start/create the emulator:
export AVD_NAME=android-7
export AVD_TARGET=android-7
bash $PRIVATE/auto-avd.sh -n $AVD_NAME -t $AVD_TARGET -c 10M
source $WORKSPACE/.adbports

# do tests and such:
ANDROID_ADB_SERVER_PORT=$ANDROID_ADB_SERVER_PORT bash $PRIVATE/build-cb.sh -Dadb.device.arg=-e emma installd test
cd ..
bash $PRIVATE/build-cb.sh javadoc > javadoc.log # the log is ignored, but building javadoc spews tons of junk in general
ANDROID_ADB_SERVER_PORT=$ANDROID_ADB_SERVER_PORT bash $PRIVATE/build-cb.sh lint-xml #monkey

# fix output from running as beta:
eval `grep -P '^(DIST|BETA)_' $PRIVATE/build-cb.sh`
find javadoc/ lint-results.xml monkey.txt tests/coverage.xml tests/junit-report.xml -type f -print0 | \
        xargs -0 perl -pi -e"s|$BETA_TLD/$BETA_DOMAIN/$BETA_PROJECT|$DIST_TLD/$DIST_DOMAIN/$DIST_PROJECT|g"
find javadoc/ lint-results.xml monkey.txt tests/coverage.xml tests/junit-report.xml -type f -print0 | \
        xargs -0 perl -pi -e"s|$BETA_TLD\.$BETA_DOMAIN\.$BETA_PROJECT|$DIST_TLD.$DIST_DOMAIN.$DIST_PROJECT|g"
find javadoc/ -type f -print0 | xargs -0 perl -pi -e"s|$BETA_LOGTAG|$DIST_LOGTAG|g"
if [[ "${DIST_TLD}" != "${BETA_TLD}" ]]; then
    mv javadoc/${BETA_TLD} javadoc/${DIST_TLD}
fi
if [[ "${DIST_DOMAIN}" != "${BETA_DOMAIN}" ]]; then
    mv javadoc/${DIST_TLD}/${BETA_DOMAIN} javadoc/${DIST_TLD}/${DIST_DOMAIN}
fi
if [[ "${DIST_PROJECT}" != "${BETA_PROJECT}" ]]; then
    mv javadoc/${DIST_TLD}/${DIST_DOMAIN}/${BETA_PROJECT} javadoc/${DIST_TLD}/${DIST_DOMAIN}/${DIST_PROJECT}
fi

# kill the emulator:
kill `cat /tmp/$USER-$AVD_NAME.pid`
ANDROID_ADB_SERVER_PORT=$ANDROID_ADB_SERVER_PORT $ANDROID_HOME/platform-tools/adb kill-server
