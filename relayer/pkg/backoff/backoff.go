package backoff

import "time"

// Exponential performs exponential backoff attempts on a given action
func Exponential(action func() error, max uint, wait time.Duration, errCh chan<- error) {
	var err error
	for i := uint(0); i < max; i++ {
		if err = action(); err == nil {
			errCh <- nil
		}
		time.Sleep(wait)
		wait *= 2
	}
	errCh <- err
}
