package robin

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

const (
	V1 = "V1"
	V2 = "V2"
	V3 = "V3"
	V4 = "V4"
)

type elementer string

func (e elementer) ID() string      { return string(e) }
func (e elementer) Priority() int64 { panic("not implemented") }

func TestRoundRobin(t *testing.T) {
	testCases := []struct {
		name     string
		initial  []Element
		actions  func(r RoundRobin, ack chan struct{})
		expected func(r RoundRobin)
	}{
		{
			name:    "Round Progression",
			initial: []Element{elementer(V1), elementer(V2), elementer(V3), elementer(V4)},
			actions: func(r RoundRobin, ack chan struct{}) {
				ack <- struct{}{}
				ack <- struct{}{}
				ack <- struct{}{}
				ack <- struct{}{}
			},
			expected: func(r RoundRobin) {
				assert.Equal(t, int64(4), r.Round())
				assert.Equal(t, V4, r.Current().ID())
			},
		},
		{
			name:    "Reset",
			initial: []Element{elementer(V1), elementer(V2), elementer(V3), elementer(V4)},
			actions: func(r RoundRobin, ack chan struct{}) {
				ack <- struct{}{}
				ack <- struct{}{}
				r.Reset()
				ack <- struct{}{}
			},
			expected: func(r RoundRobin) {
				assert.Equal(t, int64(1), r.Round())
				assert.Equal(t, V4, r.Current().ID())
			},
		},
		{
			name:    "Add Element",
			initial: []Element{elementer(V1), elementer(V2), elementer(V3)},
			actions: func(r RoundRobin, ack chan struct{}) {
				ack <- struct{}{}
				assert.NoError(t, r.Add(elementer(V4)))
				ack <- struct{}{}
				ack <- struct{}{}
			},
			expected: func(r RoundRobin) {
				assert.Equal(t, int64(3), r.Round())
				assert.Equal(t, V1, r.Current().ID())
			},
		},
		{
			name:    "Stop and Restart",
			initial: []Element{elementer(V1), elementer(V2), elementer(V3)},
			actions: func(r RoundRobin, ack chan struct{}) {
				ack <- struct{}{}
				r.Stop()
				r.Start()
				ack <- struct{}{}
			},
			expected: func(r RoundRobin) {
				assert.Equal(t, int64(2), r.Round())
				assert.Equal(t, V1, r.Current().ID())
			},
		},
		{
			name:    "Round Reset After Loop",
			initial: []Element{elementer(V1), elementer(V2), elementer(V3), elementer(V4)},
			actions: func(r RoundRobin, ack chan struct{}) {
				ack <- struct{}{}
				ack <- struct{}{}
				ack <- struct{}{}
				ack <- struct{}{}
				ack <- struct{}{}
			},
			expected: func(r RoundRobin) {
				assert.Equal(t, int64(5), r.Round())
				assert.Equal(t, V3, r.Current().ID())
			},
		},
		{
			name:    "Update Priority",
			initial: []Element{elementer(V1), elementer(V2), elementer(V3), elementer(V4)},
			actions: func(r RoundRobin, ack chan struct{}) {
				ack <- struct{}{}
				assert.NoError(t, r.Update(V2, 100))
				ack <- struct{}{}
			},
			expected: func(r RoundRobin) {
				assert.Equal(t, int64(2), r.Round())
				assert.Equal(t, V2, r.Current().ID())
			},
		},
		{
			name:    "Update Priorities",
			initial: []Element{elementer(V1), elementer(V2), elementer(V3)},
			actions: func(r RoundRobin, ack chan struct{}) {
				assert.NoError(t, r.Update(V2, 50))
				assert.NoError(t, r.Update(V1, 100))
				assert.NoError(t, r.Update(V3, 0))
				ack <- struct{}{}
				ack <- struct{}{}
			},
			expected: func(r RoundRobin) {
				assert.Equal(t, int64(2), r.Round())
				assert.Equal(t, V2, r.Current().ID())
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			var (
				wg      = sync.WaitGroup{}
				ack     = make(chan struct{})
				rounder = NewRoundRobin(ack, tc.initial...)
			)
			wg.Add(1)

			go func() {
				rounder.Start()
				tc.actions(rounder, ack)
				rounder.Stop()
				wg.Done()
			}()

			wg.Wait()

			tc.expected(rounder)
		})
	}
}

// TestMultiple might be used to check race condition issue in wide selection.
// Was an issue when different test cases failed from time to time due to bad
// blocking/unblocking tracking. This test is useful in order not to run default
// one manually multiple times
func TestMultiple(t *testing.T) {
	wg := sync.WaitGroup{}
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			TestRoundRobin(t)
			wg.Done()
		}()
	}

	wg.Wait()
}
