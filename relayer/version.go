package relayer

import (
	"runtime"

	"github.com/rs/zerolog/log"
)

// Populated during build, don't touch!
var (
	Version   = "v0.1.0"
	GitRev    = "undefined"
	GitBranch = "undefined"
	BuildDate = "Fri, 17 Jun 1988 01:58:00 +0200"
)

// PrintVersion prints version info into the provided io.Writer.
func PrintVersion() {
	log.Info().
		Str("version", Version).
		Str("git_rev", GitRev).
		Str("git_branch", GitBranch).
		Str("build_date", BuildDate).
		Str("go_version", runtime.Version()).
		Str("os", runtime.GOOS).
		Str("arch", runtime.GOARCH).
		Msg("version info")
}
