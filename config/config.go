package config

import (
	"encoding/json"
	"reflect"
	"strings"
	"sync"

	"github.com/rs/zerolog/log"
	"github.com/spf13/viper"
)

var (
	loadOnce sync.Once
	conf     Config
)

// Config contains app config
type Config struct {
	// LogLevel is the log level value
	LogLevel string `mapstructure:"log_level" env:"LOG_LEVEL" default:"info"`

	// Environment is the environment the app is running in
	Env string `mapstructure:"environment" env:"ENVIRONMENT" default:"development"`

	// SentryDSN is the DSN for Sentry
	SentryDSN string `mapstructure:"sentry_dsn" env:"SENTRY_DSN"`

	// PrivateKey is the private key of the address for updating an oracle
	PrivateKey string `mapstructure:"private_key" env:"PRIVATE_KEY"`

	// KMSPrivateKeyID is the private key ID stored in AWS KMS
	KMSPrivateKeyID string `mapstructure:"kms_private_key_id" env:"KMS_PRIVATE_KEY_ID"`

	// HealthcheckServerHost is the HTTP server port to serve a healthcheck
	HealthcheckServerHost int `mapstructure:"healthcheck_server_port" env:"HEALTHCHECK_SERVER_PORT" default:"6060"`
}

// String returns the string representation of the config
func (c *Config) String() string {
	raw, err := json.Marshal(c)
	if err != nil {
		log.Fatal().Err(err).Msg("unable to marshal config to string")
	}

	return string(raw)
}

// Print prints the config to the console
func (c *Config) Print() {
	// TODO: Do not print secrets
	log.Debug().Interface("config", c).Msg("config")
}

// Load loads configuration from envs
func Load() Config {
	loadOnce.Do(func() {
		viper.SetConfigFile(".env")
		viper.SetConfigFile("./config.yaml")

		// Read configuration from environment
		if err := viper.ReadInConfig(); err != nil {
			log.Warn().Str("msg", err.Error()).Msg("unable to read config file")
		}

		if err := viper.Unmarshal(&conf); err != nil {
			log.Fatal().Err(err).Msg("unable to unmarshal config")
		}
	})

	return conf
}

func bindEnv(name string, defaultVal interface{}, envs ...string) {
	inputs := append([]string{name}, envs...)
	if err := viper.BindEnv(inputs...); err != nil {
		log.Fatal().Err(err).Msgf("unable to bind envs %v to config field %s", envs, name)
	}

	viper.SetDefault(name, defaultVal)
}

func init() {
	// Initializes configuration based on tags defined for each field
	types := []interface{}{Config{}}
	for _, obj := range types {
		t := reflect.TypeOf(obj)
		for i := 0; i < t.NumField(); i++ {
			f := t.Field(i)
			mapStructure, ok := f.Tag.Lookup("mapstructure")
			if !ok {
				log.Warn().Msgf("config field %s does not have mapstructure tag", f.Name)
				continue
			}

			defaultVal := f.Tag.Get("default")

			if env := f.Tag.Get("env"); env == "" {
				bindEnv(mapStructure, defaultVal, strings.ToUpper(mapStructure))
			} else {
				bindEnv(mapStructure, defaultVal, strings.Split(env, ",")...)
			}
		}
	}
}
