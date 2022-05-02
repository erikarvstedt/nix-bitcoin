#!/usr/bin/env bash
set -euo pipefail

testDir=/tmp/setup-dirs-test/dirs
rm -rf $testDir
mkdir -p $testDir
cd $testDir

if [[ -v SETUP_DIRS_TEST_USER ]]; then
    # This is executed in the local test
    user=$SETUP_DIRS_TEST_USER
    if ! id -u $user &>/dev/null; then
        echo "User $user doesn't exist"
        exit 1
    fi
else
    # This is executed in the VM test
    user=test
    groupadd test
    useradd -g test test
    groupadd root
    usermod -g root root

    # This is missing in the VM
    ln -s /proc/self/fd /dev/fd
fi
group=$(id -gn $user)

backtrace () {
    echo "Backtrace (most recent calls first):"
    i=0
    while read line fn file < <(caller $i); do
        echo "$file:$line: in function $fn"
        i=$((i+1))
    done
}
set -o errtrace
trap backtrace ERR

assertFile() {
    file=$1
    uidgid=$2
    mode=$3
    if [[ ! -e $file ]]; then
        echo "error: file '$file' does not exist"
        return 1
    fi
    stat=$(stat -c '%U:%G:%a' "$file")
    expected="$uidgid:$mode"
    if [[ $stat != $expected ]]; then
        echo "error: wrong file owner or mode"
        echo "expected: $expected"
        echo "actual: $stat"
        return 1
    fi
}

runAndCheck() {
    config
    setup-dirs <(echo "a/b:root:root:700")
}

### Tests

if [[ $user == root || $group == root ]]; then
    echo "error: test user/group must differ from root"
    exit 1
fi

setup-dirs <(echo "a:root:root:701")
assertFile a root:root 701

setup-dirs <(echo "a/b:root:root:750")
assertFile a root:root 701
assertFile a/b root:root 750

setup-dirs <(echo "a/b2:root::700")
assertFile a/b2 root:root 700

# Create user dir above a
setup-dirs <(echo "a/user/x/y:$user:root:740")
assertFile a root:root 701
assertFile a/user $user:root 740
assertFile a/user/x $user:root 740
assertFile a/user/x/y $user:root 740

touch a/user/f
touch a/user/f2
touch a/user/x/f

# Change group and mode of user dir
setup-dirs <(echo "a/user:$user::700")
assertFile a root:root 701
assertFile a/user $user:$group 700
assertFile a/user/x $user:$group 740
assertFile a/user/x/y $user:$group 740
assertFile a/user/f $user:$group 644
assertFile a/user/f2 $user:$group 644
assertFile a/user/x/f $user:$group 644

# 1. Chown user dir to root
# 2. Create more dirs
setup-dirs <(
    echo "a/user:root::600"
    echo "b/c:$user::700"
    echo "b/c/d/e:root::710"
)
# Check 1.
assertFile a/user root:root 600
assertFile a/user/x root:root 740
assertFile a/user/x/y root:root 740
assertFile a/user/f2 root:root 644
# Check 2.
assertFile b $user:$group 700
assertFile b/c $user:$group 700
assertFile b/c/d root:root 710
assertFile b/c/d/e root:root 710
