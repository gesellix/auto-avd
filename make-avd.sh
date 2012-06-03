#!/bin/sh

# this creates an AVD and puts it in /private/<account-id> for DEV@cloud.
# the AVD is later installed in ${WORKSPACE}/avd/ for access.
# running on m1.large is recommended, as it took 3 minutes 14 seconds total
# (including a 30 second sleep after bootanimation stops for safety).
# it will take much much longer on m1.small.

# it will overwrite an AVD of the same name.

# requires /private/<account-id>/.netrc to exist for cadaver, with the lines:
# machine repository-{account-id}.forge.cloudbees.com
# login USERNAME
# password PASSWORD

# requires the folder /private/<account-id>/avd to already exist.

# non-android external programs called: netstat, cadaver, daemonize; as well as things that should
# certainly be there such as perl, tar, echo, ls, ps, mkdir, copy, chmod, cat, sleep, kill, cd

PATH=$PATH:$ANDROID_HOME/platform-tools # .../tools is in the path, but .../platform-tools is not

PRIVATE=${JENKINS_HOME/home/private} # s|home|private|;
PRIVATE=${PRIVATE%/hudson_home}      # s|/hudson_home||; i.e. PRIVATE=/private/k9mail, for example.

if [ -z $1 ]; then
    echo "Usage: $0 API_LEVEL"            # i.e. 3, 7, 10, 15
    echo "       $0 AVD_NAME TARGET_NAME" # i.e. api7 android-7
    exit 254
else
    if [ -z $2 ]; then
        MYAPI=$1
        AVD_NAME=android-${MYAPI}
        TARGET_NAME=android-${MYAPI}
    else
        AVD_NAME=$1
        TARGET_NAME=$2
    fi
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

# create avd and copy the ini file to ${WORKSPACE}/avd/:
echo creating AVD ${AVD_NAME}...
mkdir -p ${WORKSPACE}/avd || exit 1
echo | android create avd --sdcard 10M --name ${AVD_NAME} --snapshot --target ${TARGET_NAME} \
        --path ${WORKSPACE}/avd/${AVD_NAME}.avd --force || exit 2
cp -f ~/.android/avd/${AVD_NAME}.ini ${WORKSPACE}/avd/ || exit 3

# install daemonize:
if [ /private/k9mail/daemonize -nt ${WORKSPACE}/daemonize ]; then
    echo copying daemonize to ${WORKSPACE}/daemonize
    cp -f /private/k9mail/daemonize ${WORKSPACE}/daemonize || exit 4
fi
if [ ! -x ${WORKSPACE}/daemonize ]; then
    chmod 755 ${WORKSPACE}/daemonize || exit 5
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
        $ANDROID_HOME/tools/emulator-arm -avd ${AVD_NAME} -no-audio -no-window -no-snapshot-load \
        -ports ${ANDROID_AVD_USER_PORT},${ANDROID_AVD_ADB_PORT} -no-snapshot-save -no-boot-anim -wipe-data || exit 6
adb start-server
echo cat /tmp/${USER}-${AVD_NAME}.stderr
cat /tmp/${USER}-${AVD_NAME}.stderr
echo cat /tmp/${USER}-${AVD_NAME}.stdout
cat /tmp/${USER}-${AVD_NAME}.stdout
ls -l /tmp/${USER}-${AVD_NAME}.*
ps ux | grep -f /tmp/${USER}-${AVD_NAME}.pid | grep emulator || myexit 7 # die if the emulator isn't running

# wait for dev.bootcomplete:
TIMEOUT=720 # this should be an option.
time=0;
sleep=5;
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

# wait for stability, start logging logcat, unlock the screen, stop logging logcat, clear logcat, put a tag in logcat:
echo Waiting $[($time+$sleep)*4/5] seconds for system to stabilize before unlocking screen...
sleep $[($time+$sleep)*4/5]
adb connect ${ANDROID_AVD_DEVICE}
${WORKSPACE}/daemonize -o ${WORKSPACE}/avd/${AVD_NAME}.avd/initial-logcat.txt \
        -e /tmp/${USER}-logcat.err -p /tmp/${USER}-logcat.pid -l /tmp/${USER}-logcat.lock \
        $ANDROID_HOME/platform-tools/adb -s ${ANDROID_AVD_DEVICE} logcat -v time
adb -s ${ANDROID_AVD_DEVICE} shell input keyevent 82 # unlocks emulator screen
echo Waiting $[($time+$sleep)/10] seconds for system to stabilize before creating snapshot...
sleep $[($time+$sleep)/10] # dunno what this should be -- it took 1.473 seconds on my machine for android-7
kill `cat /tmp/${USER}-logcat.pid`
adb -s ${ANDROID_AVD_DEVICE} logcat -c
adb -s ${ANDROID_AVD_DEVICE} shell log -p v -t Jenkins "Creating snapshot..."

# save the snapshot, and kill the emulator and adb:
echo saving snapshot
perl -e 'use IO::Socket::INET;
         print "opening connection to $ENV{ANDROID_AVD_USER_PORT}\n";
         $s = IO::Socket::INET->new(PeerAddr => "localhost", PeerPort => "$ENV{ANDROID_AVD_USER_PORT}", Blocking => 0);
         $s->syswrite("avd stop\r\navd snapshot save default-boot\r\nkill\r\n");
         sleep 1;
         foreach ($s->getlines) { print };
         $s->close;' # n[et]c[at] and telnet are lacking on the system
adb disconnect ${ANDROID_AVD_DEVICE}
kill `cat /tmp/${USER}-${AVD_NAME}.pid` # just to make sure
adb kill-server
echo waiting for emulator lockfiles to disappear...
while ls ${WORKSPACE}/avd/${AVD_NAME}.avd/*.lock >& /dev/null
do
    sleep .1;
done

cd ${WORKSPACE}/avd/
echo creating archive ${AVD_NAME}.tar.gz...
tar zcpvf ${AVD_NAME}.tar.gz ${AVD_NAME}.ini ${AVD_NAME}.avd || exit 9

# quit if running locally (for testing):
if [ "${HOSTNAME}" == "tantrum" ]; then
    exit 0
fi

# copy the archive to private storage via cadaver and then delete it from the workspace:
chmod u+w ~/.netrc
if [ /private/k9mail/.netrc -nt ~/.netrc ]; then
    cp -f /private/k9mail/.netrc ~/.netrc
    chmod u+w ~/.netrc
fi
echo copying ${AVD_NAME}.tar.gz to /private/k9mail/
(echo -e "put ${AVD_NAME}.tar.gz\nquit" | cadaver https://repository-k9mail.forge.cloudbees.com/private/avd/) || exit 10
rm -f ~/.netrc
ls -l ${AVD_NAME}.tar.gz /private/k9mail/avd/${AVD_NAME}.tar.gz # these should be the same size if successful
rm -f ${AVD_NAME}.tar.gz
