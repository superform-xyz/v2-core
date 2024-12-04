package cmd

import (
	"fmt"
	"net/http"
	"os"
	"runtime"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/superform-xyz/v2-core/relayer/config"
	"github.com/superform-xyz/v2-core/relayer/pkg/healthcheck"
	"github.com/superform-xyz/v2-core/relayer/pkg/zlogsentry"
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

func startHealthcheckServer(port int) {
	http.HandleFunc("/health", healthcheck.HealthCheck())

	go func() {
		if err := http.ListenAndServe(fmt.Sprintf(":%d", port), nil); err != nil {
			log.Fatal().Err(err).Msg("failed to start healthcheck server")
		}
	}()
}

func setupLogger(conf *config.Config) {
	zerolog.SetGlobalLevel(conf.LogLevel)

	// Init sending logs to sentry if DSN is provided
	if conf.SentryDSN != "" {
		w, err := zlogsentry.New(
			conf.SentryDSN,
			zlogsentry.WithEnvironment(conf.Env),
			zlogsentry.WithRelease(Version),
		)
		if err != nil {
			log.Fatal().Err(err).Msg("failed to init zerolog Sentry plugin")
		}

		log.Logger = zerolog.New(zerolog.MultiLevelWriter(os.Stdout, w)).With().Timestamp().Logger()
	}
}

func setUpApp() config.Config {
	conf := config.Load(configPath)
	setupLogger(&conf)
	conf.Print()
	PrintVersion()
	return conf
}
