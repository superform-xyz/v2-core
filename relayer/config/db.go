package config

import (
	"database/sql"
	"time"

	"github.com/lib/pq"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"github.com/superform-xyz/v2-core/relayer/pkg/data/mem"
	"github.com/superform-xyz/v2-core/relayer/pkg/data/pg"
	"gitlab.com/distributed_lab/kit/pgdb"

	"github.com/pkg/errors"
)

type Database struct {
	URL                      string        `mapstructure:"url"`
	MaxOpenConnections       int           `mapstructure:"max_open_connection" default:"12"`
	MaxIdleConnections       int           `mapstructure:"max_idle_connections" default:"12"`
	ListenerMinRetryDuration time.Duration `mapstructure:"listener_min_retry_duration" default:"1s"`
	ListenerMaxRetryDuration time.Duration `mapstructure:"listener_max_retry_duration" default:"1m"`
}

func (d *Database) DB() *pgdb.DB {
	db, err := pgdb.Open(pgdb.Opts{
		URL:                d.URL,
		MaxOpenConnections: d.MaxOpenConnections,
		MaxIdleConnections: d.MaxIdleConnections,
	})
	if err != nil {
		panic(errors.Wrap(err, "failed to open database"))
	}

	return db
}

func (d *Database) NewListener() *pq.Listener {
	listener := pq.NewListener(d.URL, d.ListenerMinRetryDuration, d.ListenerMaxRetryDuration, nil)
	return listener
}

func (d *Database) RawDB() *sql.DB {
	return d.DB().RawDB()
}

func (d *Database) TransactionsQ() data.TransactionsQ {
	if d.URL != "" {
		return pg.NewTransactionsQ(d.DB().Clone())
	}

	return mem.NewTransactionsQ(make(map[string]data.Transaction))
}

func (d *Database) BlocksQ() data.BlocksQ {
	if d.URL != "" {
		return pg.NewBlocksQ(d.DB().Clone())
	}

	return mem.NewBlocksQ(make(map[string]data.Block))
}

func (d *Database) TasksQ() data.TasksQ {
	if d.URL != "" {
		return pg.NewTasksQ(d.DB().Clone())
	}

	return mem.NewTasksQ(make(map[string]data.Task))
}

func (d *Database) PricesQ() data.PricesQ {
	if d.URL != "" {
		return pg.NewPricesQ(d.DB().Clone())
	}

	return mem.NewPricesQ(make(map[string]data.Price))
}
