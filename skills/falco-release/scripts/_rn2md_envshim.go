// _rn2md_envshim.go - build helper for release-body-build.sh.
//
// rn2md accepts the GitHub token through its -t/--token flag (cmd/root.go in both workflow-pinned
// revisions documented by release-body-build.sh). Putting a token on a command line exposes it
// to every process listing. This shim is copied into <tool-dir>/envshim/main.go and built inside
// the rn2md module; it reads RN2MD_TOKEN from the environment and appends the flag to the in-process
// argument slice (os.Args is a Go copy; /proc/<pid>/cmdline keeps the original argv), then runs the
// unmodified rn2md command. With RN2MD_TOKEN unset it behaves exactly like rn2md.
package main

import (
	"os"

	"github.com/leodido/rn2md/cmd"
	logger "github.com/sirupsen/logrus"
)

func main() {
	if tok := os.Getenv("RN2MD_TOKEN"); tok != "" {
		os.Args = append(os.Args, "--token", tok)
	}
	if err := cmd.Run(); err != nil {
		logger.WithError(err).Fatal("exiting")
	}
}
