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

myexit () {
    echo myexit $1 ...
    adb emu kill;
    if [ -z "$1" ]; then
        exit 255;
    else
        exit $1;
    fi
}

# make sure needed directories exist:
mkdir -p ~/.android/avd/ ${WORKSPACE}/avd || exit 2
chmod -R u+w ~/.android ${WORKSPACE}/avd || exit 3

# extract the archive if the ini file or directory does not exist:
if [ ! -e ${AVD_NAME}.ini -o ! -e ${AVD_NAME}.avd ]; then
    echo extracting ${PRIVATE}/avd/${AVD_NAME}.tar.gz
    tar -C ${WORKSPACE}/avd/ -x -v -f ${PRIVATE}/avd/${AVD_NAME}.tar.gz || exit 4
    # change the path in the ini files from the ${WORKSPACE} (${JOB_NAME}) they were created in to the current ${WORKSPACE}:
    perl -pi -e 's|/scratch/hudson/workspace/.+?/|$ENV{WORKSPACE}/|' \
            ${WORKSPACE}/avd/${AVD_NAME}.ini ${WORKSPACE}/avd/${AVD_NAME}.avd/*.ini || exit 5
fi

# copy the ini file to where the emulator expects it to be:
cp -f ${WORKSPACE}/avd/${AVD_NAME}.ini ~/.android/avd/${AVD_NAME}.ini || exit 6

# copy daemonize to workspace:
if [ ${PRIVATE}/daemonize -nt ${WORKSPACE}/daemonize ]; then
    echo copying daemonize to ${WORKSPACE}/daemonize
    cp -f ${PRIVATE}/daemonize ${WORKSPACE}/daemonize || exit 7
fi

# make sure daemonize is executable:
if [ ! -x ${WORKSPACE}/daemonize ]; then
    chmod 755 ${WORKSPACE}/daemonize || exit 8
fi

# find three random available ports to use between 32768 and 65535:
PORTS=(`perl -e '%p = {};
                 open(NS, "netstat -tln --inet |");
                 while (<NS>) {
                     @l = split(/\s+/);
                     if ($l[3] =~ /^(?:127\.0\.0\.1|0\.0\.0\.0):(\d+)$/ && $1 >= 32768) { $p{$1} = 1; }
                 }
                 for ($i=0;$i<3;$i++) {
                     do { $a[$i] = int rand()*32767+32768;
                     } while (exists $p{$a[$i]});
                     $p{$a[$i]} = 1;
                 }
                 print "@a";'`) # bash calling perl calling netstat... i know.
export ANDROID_ADB_SERVER_PORT=${PORTS[0]} # 5037
export ANDROID_AVD_USER_PORT=${PORTS[1]} # 5554
export ANDROID_AVD_ADB_PORT=${PORTS[2]} # 5555
export ANDROID_AVD_DEVICE=localhost:${ANDROID_AVD_ADB_PORT}

# start emulator:
echo starting emulator ${AVD_NAME}
${WORKSPACE}/daemonize -o /tmp/${USER}-${AVD_NAME}.stdout -e /tmp/${USER}-${AVD_NAME}.stderr \
        -p /tmp/${USER}-${AVD_NAME}.pid -l /tmp/${USER}-${AVD_NAME}.lock \
        $ANDROID_HOME/tools/emulator-arm -avd ${AVD_NAME} -no-audio -no-window -no-snapshot-save \
        -ports ${ANDROID_AVD_USER_PORT},${ANDROID_AVD_ADB_PORT} -no-boot-anim || exit 6
adb start-server
echo cat /tmp/${USER}-${AVD_NAME}.stderr
cat /tmp/${USER}-${AVD_NAME}.stderr
echo cat /tmp/${USER}-${AVD_NAME}.stdout
cat /tmp/${USER}-${AVD_NAME}.stdout
ls -l /tmp/${USER}-${AVD_NAME}.*
ps ux | grep -f /tmp/${USER}-${AVD_NAME}.pid | grep emulator || myexit 7 # die if the emulator isn't running

# wait for dev.bootcomplete:
TIMEOUT=30 # this should be an option.
time=0;
sleep=2;
while [ $time -lt ${TIMEOUT} ]; do
    adb connect ${ANDROID_AVD_DEVICE}
    adb -s ${ANDROID_AVD_DEVICE} shell getprop dev.bootcomplete | grep 1 && break
    adb connect ${ANDROID_AVD_DEVICE}
    adb -s ${ANDROID_AVD_DEVICE} shell getprop dev.bootcomplete | grep 1 && break
    adb disconnect ${ANDROID_AVD_DEVICE}
    time=$[$time+$sleep]
    sleep $sleep
done
adb -s ${ANDROID_AVD_DEVICE} shell getprop dev.bootcomplete | grep 1 || myexit 8
adb connect ${ANDROID_AVD_DEVICE}
echo Took $time to $[$time+$sleep] for emulator to be online.

# start logging logcat:
${WORKSPACE}/daemonize -o ${WORKSPACE}/${AVD_NAME}-logcat.txt \
        -e /tmp/${USER}-logcat.err -p /tmp/${USER}-logcat.pid -l /tmp/${USER}-logcat.lock \
        $ANDROID_HOME/platform-tools/adb -s ${ANDROID_AVD_DEVICE} logcat -v time

# save ports to file for later "source ./.adbports" :
echo ANDROID_ADB_SERVER_PORT=${PORTS[0]} > .adbports
echo ANDROID_AVD_USER_PORT=${PORTS[1]} >> .adbports
echo ANDROID_AVD_ADB_PORT=${PORTS[2]} >> .adbports
echo ANDROID_AVD_DEVICE=localhost:${ANDROID_AVD_ADB_PORT} >> .adbports

exit 0;

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
