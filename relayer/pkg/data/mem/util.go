package mem

import (
	"golang.org/x/exp/constraints"
)

func contains[T constraints.Ordered](src []T, value T) bool {
	for _, v := range src {
		if v == value {
			return true
		}
	}

	return false
}

type filterer[T any] func(value T) bool

func filterKeys[T any, Y constraints.Ordered](mapping map[Y]T, filters []filterer[T]) []Y {
	keys := make([]Y, 0, len(mapping))

	for key, value := range mapping {
		if filter(filters, value) {
			keys = append(keys, key)
		}
	}

	return keys
}

func filter[T any](filters []filterer[T], value T) bool {
	for _, fil := range filters {
		if !fil(value) {
			return false
		}
	}

	return true
}
