This is a collection of scripts for automatic building and testing of
Android projects, geared towards CloudBees and Jenkins. `auto-avd.sh` will
start clean AVD snapshots, creating them if necessary. `build-cb.sh` will
temporarily rename a project and call ant. `build.sh` is to control the
overall build, emulator startup, and testing.

### auto-avd.sh

Automatically create and start clean Android AVD snapshots for testing, with
an emphasis for DEV@cloud.

This creates an AVD and puts it in `/private/<account-id>` for DEV@cloud,
then starts it. Alternatively, it installs and runs an AVD if one of the
name already exists. The AVD is installed in `${WORKSPACE}/avd/` instead of
`${HOME}/.android/avd/`.

Requires `/private/<account-id>/.netrc` to exist for cadaver, with the lines:

    machine repository-{account-id}.forge.cloudbees.com
    login USERNAME
    password PASSWORD

Requires the folder `/private/<account-id>/avd` to already exist.

Optionally, can be run locally, without private storage. Environment
variables `PRIVATE` and `WORKSPACE` need to exist -- i set them to `$HOME`.
Also, `"tantrum"` in this script needs to be changed to whatever your
`$HOSTNAME` is.

### build-cb.sh

Temporarily rename an Android project for building.

Set the first 5 or 6 `DIST_*` and `BETA_*` to whatever you are going from and to.
Set `PROJECT_DIR` to the absolute path pf the main project.
Set `TEST_DIR` to the absolute path of the test project.
Then run this script with the same arguments you'd pass to `ant`. It can be
run from either `$PROJECT_DIR` or `$TEST_DIR`. It might require tweaks
depending on how your project is laid out.

### build.sh

This script is meant to be copied into the "Command" section of
"Execute shell". Jenkins will stop a pasted script when a command fails,
whereas if ran as a file (i.e. `bash $PRIVATE/build.sh`) it will run
everything. Also, Jenkins outputs what it's doing in a pasted script,
which is quite useful for the console logging.

### License:

The MIT License

Copyright 2012 Ashley Willis <ashley.github@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

`daemonize` is an included binary, copyright 2003-2011, Brian M. Clapper,
with the license here: http://software.clapper.org/daemonize/license.html
