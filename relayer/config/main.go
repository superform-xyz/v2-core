package config

import (
	"fmt"
	"reflect"
	"strings"

	"github.com/joho/godotenv"
	"github.com/mitchellh/mapstructure"
	"github.com/rs/zerolog/log"
	"github.com/spf13/viper"
)

const (
	mapstructureTag = "mapstructure"
	defaultTag      = "default"
	envTag          = "env"
)

// Load loads configuration from envs
func Load(config string) Config {
	loadOnce.Do(func() {
		viper.AutomaticEnv()
		viper.SetConfigFile(config)

		if err := godotenv.Load(); err != nil {
			log.Warn().Err(err).Msg("failed to load .env file into variables")
		}

		if err := viper.ReadInConfig(); err != nil {
			log.Fatal().Err(err).Str("config_file", config).Msg("unable to read config file")
		}

		if err := viper.Unmarshal(&conf, viper.DecodeHook(mapstructure.ComposeDecodeHookFunc(
			mapstructure.StringToTimeDurationHookFunc(),
			mapstructure.StringToSliceHookFunc(","),
			EthHooks(),
			ZeroLogHooks(),
		))); err != nil {
			log.Fatal().Err(err).Msg("unable to unmarshal config")
		}
	})

	return conf
}

func init() {
	initConfig("", reflect.TypeOf(Config{}))
}

func initConfig(prefix string, t reflect.Type) {
	for i := 0; i < t.NumField(); i++ {
		field := t.Field(i)

		mapStructure, ok := field.Tag.Lookup(mapstructureTag)
		if !ok {
			log.Warn().Msgf("config field %s does not have a mapstructure tag", field.Name)
			continue
		}

		//Default values won't be set for map/slice types since it requires knowing keys in advance to setDefault
		if field.Type.Kind() == reflect.Struct {
			initConfig(combinePrefix(prefix, mapStructure), field.Type)
			continue
		}

		if defaultVal, ok := field.Tag.Lookup(defaultTag); ok {
			viper.SetDefault(combinePrefix(prefix, mapStructure), defaultVal)
		}

		bindEnvironmentVariables(prefix, mapStructure, field)
	}
}

func combinePrefix(prefix, key string) string {
	if prefix == "" {
		return key
	}

	return fmt.Sprintf("%s.%s", prefix, key)
}

func bindEnvironmentVariables(prefix, mapStructure string, field reflect.StructField) {
	env := field.Tag.Get(envTag)
	envVars := strings.Split(env, ",")
	configKey := combinePrefix(prefix, mapStructure)

	if env == "" {
		envVars = []string{strings.ToUpper(mapStructure)}
	}

	inputs := append([]string{configKey}, envVars...)
	if err := viper.BindEnv(inputs...); err != nil {
		log.Fatal().Err(err).Msgf("unable to bind env vars %v to config field %s", envVars, configKey)
	}
}
