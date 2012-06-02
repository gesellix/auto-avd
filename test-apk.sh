#!/bin/sh

# this is for DEV@cloud. for other Jenkins/Hudson setups, it will require some modification.
# it requires an AVD built with make-avd.sh.

PATH=$PATH:$ANDROID_HOME/platform-tools # .../tools is in the path, but .../platform-tools is not

PRIVATE=${JENKINS_HOME/home/private}
PRIVATE=${PRIVATE%/hudson_home} # this should result in being "/private/k9mail", for example.

if [ -z $1 ]; then
    echo "Usage: $0 AVD_NAME" # i.e. the base name of the tar.gz file.
    exit 1
else
    AVD_NAME=$1
fi

# ${PWD} == ${WORKSPACE} == /scratch/hudson/workspace/${JOB_NAME}

myexit () {
    echo myexit $1 ...
    adb emu kill;
    if [ -z "$1" ]; then
        exit 255;
    else
        exit $1;
    fi
}

#if [ -e ~/.android/avd/${AVD_NAME}.avd ]; then
#    echo ${AVD_NAME} already installed
#else
#    if [ ! -e ~/.android/avd ]; then
#        echo making directory ~/.android/avd
#        mkdir -p ~/.android/avd || exit 1
#    fi
#    echo copying ${AVD_NAME}.ini and ${AVD_NAME}.avd into ~/.android/avd/
#    cp -af ${PRIVATE}/avd/${AVD_NAME}.ini ~/.android/avd/ || exit 2
#    time cp -afr ${PRIVATE}/avd/${AVD_NAME}.avd ~/.android/avd/ || exit 3
#fi


mkdir -p ${WORKSPACE}/avd
cd ${WORKSPACE}/avd/

echo $PWD
ls -l ${PRIVATE}/avd/

if [ ! -e ${AVD_NAME}.ini -o ! -e ${AVD_NAME}.avd ]; then
    echo extracting ${PRIVATE}/avd/${AVD_NAME}.tar.gz
    tar xvf ${PRIVATE}/avd/${AVD_NAME}.tar.gz || exit 1
fi

perl -pi -e 's|/scratch/hudson/workspace/.+?/|$ENV{WORKSPACE}/|' ${WORKSPACE}/avd/${AVD_NAME}.ini ${WORKSPACE}/avd/${AVD_NAME}.avd/*.ini

#chmod -R u+w ~/.android/avd || exit 2
#rm -rf ~/.android/avd/${AVD_NAME}.ini ~/.android/avd/${AVD_NAME}.avd || exit 3
chmod -R u+w ~/.android # don't fail on this -- if it's not writable it's not removable below.
rm -rf ~/.android || exit 3
mkdir -p ~/.android/avd/ || exit 4

#ln -sf ${WORKSPACE}/avd/${AVD_NAME}.ini ${WORKSPACE}/avd/${AVD_NAME}.avd ~/.android/avd/ || exit 3
cp -f ${WORKSPACE}/avd/${AVD_NAME}.ini ~/.android/avd/${AVD_NAME}.ini || exit 5

#if [ ! -e ${WORKSPACE}/avd/sdcard.img ]; then
#    echo making sdcard.img
#    mksdcard 10M ${WORKSPACE}/avd/sdcard.img || exit 16
#fi


echo ls -lR ${WORKSPACE}/avd/
ls -lR ${WORKSPACE}/avd/

echo ls -lR ~/.android/avd/
ls -lR ~/.android/avd/

####
#
#if [ ! -e ~/.android/avd/${AVD_NAME}.avd ]; then
#    echo making directory ~/.android/avd/${AVD_NAME}.avd
#    mkdir -p ~/.android/avd/${AVD_NAME}.avd || exit 1
#fi
#
#chmod -R u+w ~/.android/avd || exit 14
#
#ls -laR ~/.android
#
#cd ${PRIVATE}/avd/${AVD_NAME}.avd || exit 2
#
#if [ ${PRIVATE}/avd/${AVD_NAME}.ini -nt ~/.android/avd/${AVD_NAME}.ini ]; then
#    echo updating ${AVD_NAME}.ini
#    cp -af ${PRIVATE}/avd/${AVD_NAME}.ini ~/.android/avd/ || exit 3
#fi
#
#for f in *; do
#    if [ ${PRIVATE}/avd/${AVD_NAME}.avd/$f -nt ~/.android/avd/${AVD_NAME}.avd/$f ]; then
#        echo updating $f
#        cp -afr ${PRIVATE}/avd/${AVD_NAME}.avd/$f ~/.android/avd/${AVD_NAME}.avd/ || exit 15
#    fi
#done
#
#if [ ! -e ~/.android/avd/sdcard.img ]; then
#    echo making sdcard.img
#    mksdcard 10M ~/.android/avd/sdcard.img || exit 16
#fi
#
#chmod -R u+w ~/.android/avd || exit 17
#
####

if [ ${PRIVATE}/daemonize -nt ${WORKSPACE}/daemonize ]; then
    echo copying daemonize to ${WORKSPACE}/daemonize
    cp -f ${PRIVATE}/daemonize ${WORKSPACE}/daemonize || exit 4
fi

if [ ! -x ${WORKSPACE}/daemonize ]; then
    chmod 755 ${WORKSPACE}/daemonize || exit 5
fi

#if [ -e ~/bin/daemonize ]; then
#    echo daemonize already installed
#    ls -l ~/bin/daemonize
#else
#    if [ ! -e ~/bin ]; then
#    	echo making directory ~/bin
#        mkdir ~/bin || exit 4
#    fi
#    echo copying daemonize to ~/bin/daemonize
#    cp ${PRIVATE}/daemonize ~/bin/daemonize || exit 5
#    chmod 755 ~/bin/daemonize || exit 6
#fi

#find ~/

echo starting emulator ${AVD_NAME}
${WORKSPACE}/daemonize -o /tmp/${AVD_NAME}.stdout -e /tmp/${AVD_NAME}.stderr -p /tmp/${AVD_NAME}.pid -l /tmp/${AVD_NAME}.lock \
        $ANDROID_HOME/tools/emulator-arm -avd ${AVD_NAME} -no-audio -no-window -no-snapshot-save || exit 7
sleep 1;
echo cat /tmp/${AVD_NAME}.stderr
cat /tmp/${AVD_NAME}.stderr
echo cat /tmp/${AVD_NAME}.stdout
cat /tmp/${AVD_NAME}.stdout
ls -l /tmp/${AVD_NAME}.*
ps ux | grep -f /tmp/${AVD_NAME}.pid | grep emulator || myexit 8
adb kill-server
time adb start-server
adb devices
sleep 7
adb devices | grep emulator || myexit 9
echo adb -e wait-for-device
time adb -e wait-for-device
adb devices
# FIXME BELOW. HARDCODED FOR INITIAL TESTING. NOT PRODUCTION.
echo installing bin/K9-debug.apk
time adb -e install ${PRIVATE}/K9-debug.apk || myexit 10
echo installing tests/bin/K9-debug.apk
time adb -e install ${PRIVATE}/K9-debug-tests.apk || myexit 11
echo running tests
time adb -e shell am instrument -w -e coverage false com.fsck.k9.tests/android.test.InstrumentationTestRunner || myexit 12
echo killing emulator
time adb emu kill || exit 13
sleep 1
! ps ux | grep -f /tmp/${AVD_NAME}.pid | grep emulator || exit 13
