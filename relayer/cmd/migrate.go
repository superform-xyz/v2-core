package cmd

import (
	"context"

	"github.com/pkg/errors"
	"github.com/rs/zerolog/log"
	migrate "github.com/rubenv/sql-migrate"
	"github.com/superform-xyz/v2-core/relayer/pkg/assets"
	"github.com/urfave/cli/v3"
)

var migrationCmd = &cli.Command{
	Name:  "migrate",
	Usage: "Schema components manipulation for Superform platform",
	Commands: []*cli.Command{
		{
			Name:   "up",
			Usage:  "Set up schema components",
			Action: MigrateUp,
		},
		{
			Name:   "down",
			Usage:  "Disassemble database components",
			Action: MigrateDown,
		},
	},
}

var migrations = &migrate.EmbedFileSystemMigrationSource{
	FileSystem: assets.Migrations,
	Root:       "migrations",
}

func MigrateUp(_ context.Context, _ *cli.Command) error {
	cfg := setUpApp()
	applied, err := migrate.Exec(cfg.DB.RawDB(), "postgres", migrations, migrate.Up)
	if err != nil {
		return errors.Wrap(err, "failed to apply migrations")
	}
	log.Info().Int("applied", applied).Msg("migrations applied")
	return nil
}

func MigrateDown(_ context.Context, _ *cli.Command) error {
	cfg := setUpApp()
	applied, err := migrate.Exec(cfg.DB.RawDB(), "postgres", migrations, migrate.Down)
	if err != nil {
		return errors.Wrap(err, "failed to apply migrations")
	}
	log.Info().Int("applied", applied).Msg("migrations applied")
	return nil
}
