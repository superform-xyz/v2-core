package main

import (
	"os"

	"github.com/superform-xyz/v2-core/relayer/cmd"
)

func main() {
	if !cmd.Run() {
		os.Exit(1)
	}
}
