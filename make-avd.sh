#!/bin/sh

# this creates an AVD and puts it in /private/<account-id> for DEV@cloud.
# running on m1.large is recommended, as it took 3 minutes 14 seconds total
# (including a 30 second sleep after bootanimation stops for safety).
# it will take much much longer on m1.small.

# it will overwrite an AVD of the same name.

# requires /private/<account-id>/.netrc to exist for cadaver, with the lines:
# machine repository-{account-id}.forge.cloudbees.com
# login USERNAME
# password PASSWORD

# requires the folder /private/<account-id>/avd to already exist.

PATH=$PATH:$ANDROID_HOME/platform-tools # .../tools is in the path, but .../platform-tools is not

PRIVATE=${JENKINS_HOME/home/private}
PRIVATE=${PRIVATE%/hudson_home} # this should result in being "/private/k9mail", for example.

if [ -z $1 ]; then
    echo "Usage: $0 API_LEVEL"            # i.e. 3, 7, 10, 15
    echo "       $0 AVD_NAME TARGET_NAME" # i.e. api7 android-7
    exit 1
else
    if [ -z $2 ]; then
        MYAPI=$1
        AVD_NAME=api${MYAPI}
        TARGET_NAME=android-${MYAPI}
    else
        AVD_NAME=$1
        TARGET_NAME=$2
    fi
fi

#MYAPI="7"
#AVD_NAME=api${MYAPI}
#TARGET_NAME=android-${MYAPI}

myexit () {
    echo myexit $1 ...
    adb emu kill;
    if [ -z "$1" ]; then
        exit 255;
    else
        exit $1;
    fi
}


# THIS WHOLE SECTION SHOULD CREATE AN AVD WITH A STARTED SNAPSHOT AND ARCHIVE IT
echo creating ${AVD_NAME} avd...
mkdir -p ${WORKSPACE}/avd || exit 1
echo | android create avd -c 10M -n ${AVD_NAME} -a -t ${TARGET_NAME} -p ${WORKSPACE}/avd/${AVD_NAME}.avd --force || exit 2
cp -f ~/.android/avd/${AVD_NAME}.ini ${WORKSPACE}/avd/ || exit 3
#cd ~/.android/avd/  


# install daemonize
if [ /private/k9mail/daemonize -nt ${WORKSPACE}/daemonize ]; then
    echo copying daemonize to ${WORKSPACE}/daemonize
    cp -f /private/k9mail/daemonize ${WORKSPACE}/daemonize || exit 4
fi
if [ ! -x ${WORKSPACE}/daemonize ]; then
    chmod 755 ${WORKSPACE}/daemonize || exit 5
fi

# start emulator
echo starting emulator ${AVD_NAME}
adb kill-server
${WORKSPACE}/daemonize -o /tmp/${AVD_NAME}.stdout -e /tmp/${AVD_NAME}.stderr -p /tmp/${AVD_NAME}.pid -l /tmp/${AVD_NAME}.lock \
        $ANDROID_HOME/tools/emulator-arm -avd ${AVD_NAME} -no-audio -no-window -no-snapshot-load -wipe-data || exit 6
sleep 1;
echo cat /tmp/${AVD_NAME}.stderr
cat /tmp/${AVD_NAME}.stderr
echo cat /tmp/${AVD_NAME}.stdout
cat /tmp/${AVD_NAME}.stdout
ls -l /tmp/${AVD_NAME}.*
ps ux | grep -f /tmp/${AVD_NAME}.pid | grep emulator || myexit 7 # die if the emulator isn't running

# give emulator some time to be available
echo sleep 15
sleep 15
echo starting adb
time adb start-server
adb devices
echo sleep 7
sleep 7
adb devices | grep emulator || myexit 8 # die if emulator not showing up at all
echo adb -e wait-for-device
time adb -e wait-for-device
adb devices

# loop until bootanimation starts
# the following step (73 cycles) took 1m45.711s on m1.small for android-7, and 29.289s on m1.large
while ! adb -e shell ps | grep /system/bin/bootanimation
do
    echo -n "booting "
    date
    sleep 1
done

# loop until bootanimation stops
# on m1.small the following step (90 cycles) was cancelled because the total time reached 5 minutes,
# but on m1.large it took 59.360s, so an estimate of 3m34.244s based on above.
while adb -e shell ps | grep /system/bin/bootanimation
do
    echo -n "booting splash "
    date
    sleep 1
done

# give it more time to finish booting. 30 seconds is not enough on m1.large, and certainly not on m1.small.
# i can't find out when it's actually done, short of downloading the avd and running locally.
echo sleep 30
sleep 30
# save the snapshot (n[et]c[at] is lacking on the system)
echo saving snapshot
perl -e 'use IO::Socket::INET; $s = IO::Socket::INET->new(PeerAddr => "localhost", PeerPort => "5554", Blocking => 0); $s->syswrite("avd snapshot save default\r\nquit\r\n"); sleep 1; foreach ($s->getlines) { print }; $s->close;'
adb emu kill
echo sleep 5
sleep 5
adb emu kill # just to make sure
echo waiting for lockfiles to disappear
time while ls ${WORKSPACE}/avd/${AVD_NAME}.avd/*.lock >& /dev/null
do
    sleep .1;
done

cd ${WORKSPACE}/avd/
echo creating archive ${AVD_NAME}.tar.gz...
time tar zcpvf ${AVD_NAME}.tar.gz ${AVD_NAME}.ini ${AVD_NAME}.avd || myexit 9

# THIS SECTION COPIES THE ARCHIVE TO WEBDAV AND THEN DELETES THE LOCAL ARCHIVE.
chmod u+w ~/.netrc
if [ /private/k9mail/.netrc -nt ~/.netrc ]; then
    cp -f /private/k9mail/.netrc ~/.netrc
    chmod u+w ~/.netrc
fi
echo copying ${AVD_NAME}.tar.gz to /private/k9mail/
time (echo -e "put ${AVD_NAME}.tar.gz\nquit" | cadaver https://repository-k9mail.forge.cloudbees.com/private/avd/) || myexit 10
rm -f ~/.netrc
ls -l ${AVD_NAME}.tar.gz /private/k9mail/avd/${AVD_NAME}.tar.gz
rm -f ${AVD_NAME}.tar.gz
