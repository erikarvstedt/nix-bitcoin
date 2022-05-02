package main

// Setup uid/gid and file mode for dirs
//
// Algorithm:
//
// for (dir, uid, gid, mode) in config_file_entry
//     if !dir_exists(dir):
//         mkdir_including_parents(dir, uid, gid, mode)
//     else:
//         stat = stat(dir)
//         if stat.uid != uid || stat.gid != gid:
//             # Set temporary mode to the minimum (&) of the current mode
//             # and the target mode
//             set_mode(dir, (stat.mode & mode))
//             chown_contents(dir, uid, gid)
//             chown(dir, uid, gid)
//             set_mode(dir, mode)
//         else if stat.mode != mode:
//             set_mode(dir, mode)

import (
	"bufio"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

func main() {
	if len(os.Args) != 2 {
		errorExit("usage: setup-dirs <config-file>")
	}
	configFilePath := os.Args[1]
	configFile, err := os.Open(configFilePath)
	if err != nil {
		errorExit("error opening file", configFilePath)
	}
	defer configFile.Close()

	success := true
	lineScanner := bufio.NewScanner(configFile)
	lineNum := 0
	for lineScanner.Scan() {
		lineNum++
		if err := handleDir(lineScanner.Text()); err != nil {
			fmt.Fprintf(os.Stderr, "%s:%d: %s\n", configFilePath, lineNum, err)
			success = false
		}
	}
	if !success {
		os.Exit(1)
	}
}

func handleDir(configLine string) error {
	dir, err := parseDir(configLine)
	if err != nil {
		return err
	}

	exists, err := dirExists(dir.path)
	if err != nil {
		return err
	}
	if exists {
		err = setupDir(dir)
		if err != nil {
			return err
		}
	} else {
		err = createDirAndParents(dir)
		if err != nil {
			return makeError("error creating dir: %s", err)
		}
	}

	return nil
}

func setupDir(dir dirItem) error {
	var stat syscall.Stat_t
	err := syscall.Stat(dir.path, &stat)
	currentMode := fs.FileMode(stat.Mode)
	if err != nil {
		return makeError("error calling stat() for %s", err)
	}
	if int(stat.Uid) != dir.uid || int(stat.Gid) != dir.gid {
		// While setting uid/gid, set mode to the minimum permissions of
		// the current mode and the target mode.
		// This way, the dir is never owned with more permissions than intended.
		commonMode := currentMode & dir.mode
		err = setMode(dir.path, commonMode)
		if err != nil {
			return err
		}
		err = chownAllDirContents(dir)
		if err != nil {
			return err
		}
		err = setOwner(dir.path, dir.uid, dir.gid)
		if err != nil {
			return err
		}
		err = setMode(dir.path, dir.mode)
		if err != nil {
			return err
		}
	} else if currentMode != dir.mode {
		err = setMode(dir.path, dir.mode)
		if err != nil {
			return err
		}
	}
	return nil
}

func chownAllDirContents(dir dirItem) error {
	uid, gid := dir.uid, dir.gid
	isFirstEntry := true
	return filepath.Walk(dir.path, func(path string, f os.FileInfo, e error) error {
		if e != nil {
			return e
		}
		// Skip the toplevel dir, which will be chowned by setupDir after
		// content chowning has succeeded.
		// This way, if content chowning fails, the binary will retry to
		// chown the content when it's called again.
		if isFirstEntry {
			isFirstEntry = false
			return nil
		}
		stat := f.Sys().(*syscall.Stat_t)
		if int(stat.Uid) != uid || int(stat.Gid) != gid {
			err := setOwner(path, uid, gid)
			if err != nil {
				return err
			}
		}
		return nil
	})
}

// Assumes that dir doesn't exist.
// Only sets uid/gid and mode for newly created dirs.
func createDirAndParents(dir dirItem) error {
	path := dir.path
	i := len(path)
	// Skip path separators
	for i > 0 && os.IsPathSeparator(path[i-1]) {
		i--
	}
	// Skip basename
	for i > 0 && !os.IsPathSeparator(path[i-1]) {
		i--
	}
	if i > 1 {
		parent := dir
		parent.path = path[:i-1]
		parentExists, err := dirExists(parent.path)
		if err != nil {
			return err
		}
		if !parentExists {
			err = createDirAndParents(parent)
			if err != nil {
				return err
			}
		}
	}

	err := os.Mkdir(dir.path, dir.mode)
	if err != nil {
		// Handle arguments like "foo/." by
		// double-checking that directory doesn't exist.
		stat, err2 := os.Stat(path)
		if err2 != nil || !stat.IsDir() {
			return err
		}
	}
	return os.Chown(dir.path, dir.uid, dir.gid)
}

func parseDir(configLine string) (dir dirItem, error error) {
	fields := strings.Split(configLine, ":")
	if len(fields) != 4 {
		error = makeError("parse error: invalid number of fields")
		return
	}
	dir.path = fields[0]
	userName := fields[1]
	groupName := fields[2]
	modeStr := fields[3]

	// Remove trailing slashes
	for i := len(dir.path) - 1; os.IsPathSeparator(dir.path[i]); {
		dir.path = dir.path[:i]
	}

	u, err := user.Lookup(userName)
	if err != nil {
		error = makeError("invalid user name: %s", userName)
		return
	}
	dir.uid, err = strconv.Atoi(u.Uid)
	if err != nil {
		error = makeError("error converting uid %s", u.Uid)
		return
	}

	var gidStr string
	if groupName == "" {
		// Use default group of user
		gidStr = u.Gid
	} else {
		group, err := user.LookupGroup(groupName)
		if err != nil {
			error = makeError("invalid group name: %s", userName)
			return
		}
		gidStr = group.Gid
	}
	dir.gid, err = strconv.Atoi(gidStr)
	if err != nil {
		error = makeError("error converting gid %s", gidStr)
		return
	}

	p, err := strconv.ParseInt(modeStr, 8, 32)
	if err != nil {
		error = makeError("error converting gid %s", gidStr)
		return
	}
	dir.mode = fs.FileMode(p)

	return
}

func setOwner(path string, uid int, gid int) error {
	err := os.Chown(path, uid, gid)
	if err != nil {
		return makeError("error setting uid/gid for %s", path)
	}
	return nil
}

func setMode(path string, mode fs.FileMode) error {
	err := os.Chmod(path, mode)
	if err != nil {
		return makeError("error setting file mode for %s", path)
	}
	return nil
}

func dirExists(path string) (bool, error) {
	stat, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		} else {
			return false, makeError("error calling stat() for %s", path)
		}
	} else {
		if stat.IsDir() {
			return true, nil
		} else {
			return false, makeError("error: target path exists, but is not a directory: %s", path)
		}
	}
}

type dirItem struct {
	path string
	uid  int
	gid  int
	mode fs.FileMode
}

func errorExit(a ...interface{}) {
	fmt.Fprintln(os.Stderr, a...)
	os.Exit(1)
}

func makeError(str string, a ...interface{}) error {
	return errors.New(fmt.Sprintf(str, a...))
}
