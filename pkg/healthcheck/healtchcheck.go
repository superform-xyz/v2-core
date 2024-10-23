package healthcheck

import (
	"net/http"
)

// HealthCheck returns a simple http.HandlerFunc that checks services and returns OK if everything is fine
func HealthCheck() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// TODO: Add checks here

		// All good
		_, _ = w.Write([]byte("ok"))
	}
}
