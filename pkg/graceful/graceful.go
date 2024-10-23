package graceful

import (
	"os"
	"os/signal"
	"syscall"
)

// ShutDown calls cb after receiving a shutdown signal
func ShutDown(cb func() error) error {
	// Waiting for the stop signal
	termChan := make(chan os.Signal, 1)
	signal.Notify(termChan, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)
	<-termChan // Blocks here until either SIGINT or SIGTERM is received.
	return cb()
}
