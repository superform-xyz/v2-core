package config

import (
	"crypto/ecdsa"
	"reflect"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/mitchellh/mapstructure"
	"github.com/pkg/errors"
	"github.com/rs/zerolog"
)

var (
	ErrInvalidAddr     = errors.New("invalid address")
	ErrInvalidDataType = errors.New("invalid data type")
)

func EthHooks() mapstructure.DecodeHookFunc {
	return mapstructure.ComposeDecodeHookFunc([]mapstructure.DecodeHookFunc{
		func(f reflect.Type, t reflect.Type, data interface{}) (interface{}, error) {
			if t != reflect.TypeOf(common.Address{}) {
				return data, nil
			}

			if f.Kind() != reflect.String {
				return data, errors.Wrapf(ErrInvalidDataType, "expected=%s, acutal=%s", reflect.String.String(), f.Kind().String())
			}

			addr := data.(string)
			if !common.IsHexAddress(addr) {
				return data, ErrInvalidAddr
			}

			return common.HexToAddress(addr), nil
		},
		func(f reflect.Type, t reflect.Type, data interface{}) (interface{}, error) {
			addrType := reflect.TypeOf(ethclient.Client{})
			if t != addrType {
				return data, nil
			}

			if f.Kind() != reflect.String {
				return data, errors.Wrapf(ErrInvalidDataType, "expected=%s, acutal=%s", reflect.String.String(), f.Kind().String())
			}

			rpc := data.(string)
			client, err := ethclient.Dial(rpc)
			if err != nil {
				return data, errors.Wrapf(err, "failed to dial connection %s", rpc)
			}

			return client, nil
		},
		func(f reflect.Type, t reflect.Type, data interface{}) (interface{}, error) {
			addrType := reflect.TypeOf(ecdsa.PrivateKey{})
			if t != addrType {
				return data, nil
			}

			if f.Kind() != reflect.String {
				return data, errors.Wrapf(ErrInvalidDataType, "expected=%s, acutal=%s", reflect.String.String(), f.Kind().String())
			}

			pk, err := crypto.HexToECDSA(data.(string))
			if err != nil {
				return data, errors.Wrap(err, "failed to init keypair")
			}

			return pk, nil
		},
	}...)
}

func ZeroLogHooks() mapstructure.DecodeHookFunc {
	return mapstructure.ComposeDecodeHookFunc([]mapstructure.DecodeHookFunc{
		func(f reflect.Type, t reflect.Type, data interface{}) (interface{}, error) {
			a := reflect.TypeOf(zerolog.TraceLevel)
			if t != a {
				return data, nil
			}

			if f.Kind() != reflect.String {
				return data, errors.Wrapf(ErrInvalidDataType, "expected=%s, acutal=%s", reflect.String.String(), f.Kind().String())
			}

			logLevel := data.(string)
			parsedLevel, err := zerolog.ParseLevel(logLevel)
			if err != nil {
				return data, errors.Wrapf(err, "failed to parse log level %s", logLevel)
			}

			if parsedLevel == zerolog.NoLevel {
				parsedLevel = zerolog.InfoLevel
			}

			return parsedLevel, nil
		},
	}...)
}
