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

# This creates an AVD and puts it in /private/<account-id> for DEV@cloud, then starting it.
# Alternatively, it installs and runs an AVD if one of the name already exists.
# The AVD is installed in ${WORKSPACE}/avd/ instead of ${HOME}/.android/avd/.
#
# Running on m1.large is recommended, as it took _____________ total.
# It will take much much longer on m1.small.
#
# Requires /private/<account-id>/.netrc to exist for cadaver, with the lines:
# machine repository-{account-id}.forge.cloudbees.com
# login USERNAME
# password PASSWORD
#
# Requires the folder /private/<account-id>/avd to already exist.
#
# Non-android external programs called: netstat, cadaver, daemonize; as well as things that should
# certainly be there such as perl, tar, echo, ls, ps, mkdir, copy, chmod, cat, sleep, kill, cd
# daemonize: https://github.com/bmc/daemonize
#
# Optionally, can be run locally, without private storage. Environment variables PRIVATE and
# WORKSPACE need to exist -- i set them to $HOME. Also, "tantrum" in this script needs to be changed
# to whatever your $HOSTNAME is.
#
# TODO: Make default output significantly less verbose, with option to make it more verbose.
#       Allow custom hardware profiles.
#       Make AVD names more descriptive (like the Jenkins plugin does).
#       Change .adbports to .adbports.${AVD_NAME}


usage=$(
cat <<EOF
$0 [OPTIONS]
       Same short options as "android create avd".
       --force, --path, and --snapshot are assumed.
       Custom hardware profiles currently not supported.
  -c : Size of a new sdcard for the new AVD.
  -n : Name of the new AVD. [required]
  -s : Skin for the new AVD.
  -t : Target ID of the new AVD. [required]
  -b : The ABI to use for the AVD.

Alternatively, you can pass only -n NAME to load an existing AVD.
$0 version 0.100, Copyright 2012 Ashley Willis <ashley.github@gmail.com>
EOF
)

myexit () {
    echo myexit $1 ...
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb emu kill;
    if [[ -z "$1" ]]; then
        exit 255
    else
        exit $1
    fi
}

create_avd () {
    # create avd and copy the ini file to ${WORKSPACE}/avd/:
    echo creating AVD ${AVD_NAME}...
    # "echo |" is to press enter to: "Do you wish to create a custom hardware profile [no]"
    echo | android create avd --force --snapshot --path "${WORKSPACE}/avd/${AVD_NAME}.avd" \
            --name "${AVD_NAME}" --target "${OPT_TARGET}" ${OPT_SDCARD} ${OPT_SKIN} ${OPT_ABI} || exit 7
    cp -f ~/.android/avd/${AVD_NAME}.ini ${WORKSPACE}/avd/ || exit 8
    EMULATOR_OPTS="-no-snapshot-load -wipe-data"
    TIMEOUT=720 # this should be an option.
    sleep=5
}

extract_avd () {
    # extract the archive if the ini file or directory does not exist:
    if [[ ! -e ${WORKSPACE}/avd/${AVD_NAME}.ini ]] || [[ ! -e ${WORKSPACE}/avd/${AVD_NAME}.avd ]]; then
        echo extracting ${PRIVATE}/avd/${AVD_NAME}.tar.gz
        tar -C ${WORKSPACE}/avd/ -x -v -f ${PRIVATE}/avd/${AVD_NAME}.tar.gz || exit 9
        # change the path in the ini files from the ${WORKSPACE} (${JOB_NAME}) they were created in to the current ${WORKSPACE}:
        perl -pi -e 's|/scratch/hudson/workspace/.+?/|$ENV{WORKSPACE}/|' \
                ${WORKSPACE}/avd/${AVD_NAME}.ini ${WORKSPACE}/avd/${AVD_NAME}.avd/*.ini || exit 10
    fi
    # copy the ini file to where the emulator expects it to be:
    cp -f ${WORKSPACE}/avd/${AVD_NAME}.ini ~/.android/avd/${AVD_NAME}.ini || exit 11
    EMULATOR_OPTS=""
    TIMEOUT=30 # this should be an option.
    sleep=2
}

set_ports () {
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
}

start_emulator () {
    # start emulator:
    echo starting emulator ${AVD_NAME}
    daemonize -o /tmp/${USER}-${AVD_NAME}.stdout -e /tmp/${USER}-${AVD_NAME}.stderr \
            -p /tmp/${USER}-${AVD_NAME}.pid -l /tmp/${USER}-${AVD_NAME}.lock \
            $ANDROID_HOME/tools/emulator-arm -avd ${AVD_NAME} -no-audio -no-window -no-snapshot-save \
            -ports ${ANDROID_AVD_USER_PORT},${ANDROID_AVD_ADB_PORT} -no-boot-anim ${EMULATOR_OPTS} || exit 12
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb start-server
    echo cat /tmp/${USER}-${AVD_NAME}.stderr
    cat /tmp/${USER}-${AVD_NAME}.stderr
    echo cat /tmp/${USER}-${AVD_NAME}.stdout
    cat /tmp/${USER}-${AVD_NAME}.stdout
    ls -l /tmp/${USER}-${AVD_NAME}.*
    ps ux | grep -f /tmp/${USER}-${AVD_NAME}.pid | grep emulator || myexit 13 # die if the emulator isn't running
}

wait_for_boot () {
    # wait for dev.bootcomplete:
    time=0
    while [[ $time -lt ${TIMEOUT} ]]; do
        ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb connect ${ANDROID_AVD_DEVICE}
        ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb -s ${ANDROID_AVD_DEVICE} shell getprop dev.bootcomplete | grep 1 && break
        ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb connect ${ANDROID_AVD_DEVICE}
        ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb -s ${ANDROID_AVD_DEVICE} shell getprop dev.bootcomplete | grep 1 && break
        ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb disconnect ${ANDROID_AVD_DEVICE}
        time=$[$time+$sleep]
        sleep $sleep
    done
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb -s ${ANDROID_AVD_DEVICE} shell getprop dev.bootcomplete | grep 1 || myexit 14
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb connect ${ANDROID_AVD_DEVICE}
    echo Took $time to $[$time+$sleep] seconds for emulator to be online.
}

start_avd () {
    # start logging logcat:
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} daemonize -o ${WORKSPACE}/${AVD_NAME}-logcat.txt \
            -e /tmp/${USER}-logcat.err -p /tmp/${USER}-logcat.pid -l /tmp/${USER}-logcat.lock \
            $ANDROID_HOME/platform-tools/adb -s ${ANDROID_AVD_DEVICE} logcat -v time

    # save ports to file for later "source ./.adbports" :
    echo ANDROID_ADB_SERVER_PORT=${PORTS[0]} > ${WORKSPACE}/.adbports || myexit 15
    echo ANDROID_AVD_USER_PORT=${PORTS[1]} >> ${WORKSPACE}/.adbports
    echo ANDROID_AVD_ADB_PORT=${PORTS[2]} >> ${WORKSPACE}/.adbports
    echo ANDROID_AVD_DEVICE=localhost:${ANDROID_AVD_ADB_PORT} >> ${WORKSPACE}/.adbports
    echo
    cat ${WORKSPACE}/.adbports
    echo
    echo Remember to \"source ${WORKSPACE}/.adbports\" to access the emulator.
    echo Prepend \"ANDROID_ADB_SERVER_PORT=\${ANDROID_ADB_SERVER_PORT}\" to adb calls.
    echo Kill emulator by \""echo kill | nc localhost \${ANDROID_AVD_USER_PORT}"\" or \"kill \`cat /tmp/${USER}-${AVD_NAME}.pid\`\"
    echo Kill adb by \"ANDROID_ADB_SERVER_PORT=\${ANDROID_ADB_SERVER_PORT} adb kill-server\"
    exit 0
}

create_snapshot () {
    # wait for stability, start logging logcat, unlock the screen, stop logging logcat, clear logcat, put a tag in logcat:
    echo Waiting $[($time+$sleep)*4/5] seconds for system to stabilize before unlocking screen...
    sleep $[($time+$sleep)*4/5]
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb connect ${ANDROID_AVD_DEVICE}
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} daemonize -o ${WORKSPACE}/avd/${AVD_NAME}.avd/initial-logcat.txt \
            -e /tmp/${USER}-logcat.err -p /tmp/${USER}-logcat.pid -l /tmp/${USER}-logcat.lock \
            $ANDROID_HOME/platform-tools/adb -s ${ANDROID_AVD_DEVICE} logcat -v time
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb -s ${ANDROID_AVD_DEVICE} shell input keyevent 82 # unlocks emulator screen
    echo Waiting $[($time+$sleep)/10] seconds for system to stabilize before creating snapshot...
    sleep $[($time+$sleep)/10] # dunno what this should be -- it took 1.473 seconds on my machine for android-7
    kill `cat /tmp/${USER}-logcat.pid`
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb connect ${ANDROID_AVD_DEVICE}
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb -s ${ANDROID_AVD_DEVICE} logcat -c
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb -s ${ANDROID_AVD_DEVICE} shell log -p v -t Jenkins "Creating snapshot..."

    # save the snapshot, and kill the emulator and adb:
    echo saving snapshot
    perl -e 'use IO::Socket::INET;
             print "opening connection to $ENV{ANDROID_AVD_USER_PORT}\n";
             $s = IO::Socket::INET->new(PeerAddr => "localhost", PeerPort => "$ENV{ANDROID_AVD_USER_PORT}", Blocking => 0);
             $s->syswrite("avd stop\r\navd snapshot save default-boot\r\nkill\r\n");
             sleep 1;
             foreach ($s->getlines) { print };
             $s->close;' # n[et]c[at] and telnet are lacking on the system
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb disconnect ${ANDROID_AVD_DEVICE}
    kill `cat /tmp/${USER}-${AVD_NAME}.pid` # just to make sure
    ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT} adb kill-server
    echo waiting for emulator lockfiles to disappear...
    while ls ${WORKSPACE}/avd/${AVD_NAME}.avd/*.lock >& /dev/null
    do
        sleep .1
    done

    echo creating archive ${AVD_NAME}.tar.gz...
    tar -C ${WORKSPACE}/avd/ -z -c -p -v -f ${AVD_NAME}.tar.gz ${AVD_NAME}.ini ${AVD_NAME}.avd || exit 16

    # quit if running locally (for testing):
#    if [[ "${HOSTNAME}" == "tantrum" ]]; then
        mkdir -p ${PRIVATE}/avd
        mv ${AVD_NAME}.tar.gz ${PRIVATE}/avd/
        extract_avd
        set_ports
        start_emulator
        wait_for_boot
        start_avd
#    fi

    # copy the archive to private storage via cadaver and then delete it from the workspace:
#    chmod u+w ~/.netrc
#    if [[ /private/k9mail/.netrc -nt ~/.netrc ]]; then
#        cp -f /private/k9mail/.netrc ~/.netrc
#        chmod u+w ~/.netrc
#    fi
#    echo copying ${AVD_NAME}.tar.gz to /private/k9mail/
#    (echo -e "put ${AVD_NAME}.tar.gz\nquit" | cadaver https://repository-k9mail.forge.cloudbees.com/private/avd/) || exit 17
#    rm -f ~/.netrc
#    ls -l ${AVD_NAME}.tar.gz /private/k9mail/avd/${AVD_NAME}.tar.gz # these should be the same size if successful
#    rm -f ${AVD_NAME}.tar.gz
#    extract_avd
#    set_ports
#    start_emulator
#    wait_for_boot
#    start_avd
}





OPT_SDCARD=""
AVD_NAME=""
OPT_SKIN=""
OPT_TARGET=""
OPT_ABI=""
verbosity=0

while getopts "c:n:s:t:b:v" OPTION; do
    case "$OPTION" in
        c)
            OPT_SDCARD="--sdcard $OPTARG"
            ;;
        n)
            AVD_NAME="$OPTARG"
            ;;
        s)
            OPT_SKIN="--skin $OPTARG"
            ;;
        t)
            OPT_TARGET="$OPTARG"
            ;;
        b)  # i have no idea why you'd specify a different one than the default.
            OPT_ABI="--abi $OPTARG"
            ;;
        v)  # this is currently unused.
            verbosity=$(($verbosity+1))
            ;;
        *)
            echo "unrecognized option"
            echo "$usage"
            exit 1
            ;;
    esac
done

if [[ "${AVD_NAME}" == "" ]]; then
    echo -e "Option -n required.\n"
    echo "$usage"
    exit 2
fi

#PATH=$PATH:$ANDROID_HOME/platform-tools # .../tools is in the path, but .../platform-tools is not

if [[ -z ${PRIVATE} ]]; then
    PRIVATE=${JENKINS_HOME/home/private} # s|home|private|;
    PRIVATE=${PRIVATE%/hudson_home}      # s|/hudson_home||; i.e. PRIVATE=/private/k9mail, for example.
fi

# make sure needed directories exist:
mkdir -p ~/.android/avd/ ${WORKSPACE}/avd || exit 3
chmod -R u+w ~/.android ${WORKSPACE}/avd || exit 4

# create or extract avd:
if [[ "${OPT_TARGET}" != "" ]] && [[ ! -e ${PRIVATE}/avd/${AVD_NAME}.tar.gz ]]; then
    create_avd
else
    extract_avd
fi

set_ports
start_emulator
wait_for_boot

# finalize startup or create snapshot:
if [[ "${OPT_TARGET}" == "" ]] || [[ -e ${PRIVATE}/avd/${AVD_NAME}.tar.gz ]]; then
    start_avd
else
    create_snapshot
fi

# this should not be reached:
exit 254
