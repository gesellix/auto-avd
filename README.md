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
