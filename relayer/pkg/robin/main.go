package robin

import (
	"math"
	"slices"
	"sync"

	"github.com/pkg/errors"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

const (
	serviceName   = "round-robin"
	priorityDelta = 100
)

var (
	ErrDuplicatedElement = errors.New("duplicated element")
	ErrCurrentElement    = errors.New("element is current now")
	ErrNoElement         = errors.New("no such element")
)

type Element interface {
	ID() string
	Priority() int64
}

type RoundRobin interface {
	Start()
	Stop()
	Reset()

	Add(el Element) error
	Remove(el Element) error
	// Update changes element weight, now it expects id and weight as separate parameters, but as soon as
	// Priority method is used, it should take el Element too and process them
	Update(id string, priority int) error

	Current() Element
	Round() int64
}

type robin struct {
	elements   []Element
	priorities map[string]int // isn't relied on in current implementation, but might be adjusted later

	index int
	round int64

	isRunning bool
	mu        sync.Mutex
	done      chan struct{}
	// ack is channel to indicate that some external task was finished by current element
	// and the algorithm can move to the next round
	ack <-chan struct{}

	log zerolog.Logger
}

func NewRoundRobin(ack <-chan struct{}, values ...Element) RoundRobin {
	// While there is no weight for elements, build them using "default" values.
	// In future take them from Priority() method
	priorities := make(map[string]int, len(values))
	for i, value := range values {
		//priorities[value.ID()] = value.Priority()
		priorities[value.ID()] = i
	}

	rr := &robin{
		elements:   values,
		priorities: priorities,
		done:       make(chan struct{}),
		ack:        ack,
	}

	rr.log = log.With().Str("service", serviceName).Logger().Hook(rr)

	return rr
}

// Run is zerolog hook implementation in order not to pass the same variables each time
func (r *robin) Run(e *zerolog.Event, l zerolog.Level, msg string) {
	e.Int64("round", r.round).Str("current_id", r.elements[r.index].ID())
}

func (r *robin) Start() {
	r.mu.Lock()

	if r.isRunning {
		r.log.Warn().Msg("is already running")
		r.mu.Unlock()
		return
	}

	r.isRunning = true
	r.setCurrent(r.nextKey())
	r.mu.Unlock()

	go func() {
		r.log.Info().Msg("starting service")
		for {
			select {
			case <-r.done:
				r.log.Info().Msg("stopping service")
				return
			case <-r.ack:
				r.mu.Lock()
				r.log.Debug().Msg("finishing")
				r.nextRound()
				r.log.Debug().Msg("starting")
				r.mu.Unlock()
			default:
				continue
			}
		}
	}()
}

func (r *robin) Stop() {
	r.mu.Lock()
	defer r.mu.Unlock()

	if !r.isRunning {
		r.log.Warn().Msg("is not running")
		return
	}

	close(r.done)
	r.done = make(chan struct{})
	r.isRunning = false
}

func (r *robin) Reset() {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.round = 0
	r.resetPriorities()
}

func (r *robin) resetPriorities() {
	for i, val := range r.elements {
		// init new elements with "default" weight to adjust in next iterations
		//r.priorities[val.ID()] = val.Priority()
		r.priorities[val.ID()] = i
	}
}

func (r *robin) Add(el Element) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, ok := r.priorities[el.ID()]; ok {
		return errors.Wrapf(ErrDuplicatedElement, "id=%s", el.ID())
	}

	r.elements = append(r.elements, el)

	// init new elements with "default" weight to adjust in next iterations
	//r.priorities[el.ID()] = el.Priority()
	r.priorities[el.ID()] = len(r.elements) - 1

	return nil
}

func (r *robin) Remove(el Element) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.elements[r.index].ID() == el.ID() {
		return errors.Wrapf(ErrCurrentElement, "id=%s", el.ID())
	}

	delete(r.priorities, el.ID())
	r.elements = slices.DeleteFunc(r.elements, func(element Element) bool {
		return element.ID() == el.ID()
	})

	return nil
}

func (r *robin) Update(id string, priority int) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	idx := slices.IndexFunc(r.elements, func(element Element) bool {
		return element.ID() == id
	})
	if idx == -1 {
		return errors.Wrapf(ErrNoElement, "id=%s", id)
	}

	// When .Priority is in use, store it in r.elements
	//r.priorities[el.ID()] = el.Priority()
	r.priorities[id] = priority

	return nil
}

func (r *robin) Current() Element {
	r.mu.Lock()
	defer r.mu.Unlock()

	return r.elements[r.index]
}

func (r *robin) Round() int64 {
	r.mu.Lock()
	defer r.mu.Unlock()

	return r.round
}

func (r *robin) nextRound() {
	r.round++
	r.adjustPriority()
}

func (r *robin) adjustPriority() {
	currentKey := r.elements[r.index].ID()
	r.priorities[currentKey] -= priorityDelta

	nextKey := r.nextKey()
	r.setCurrent(nextKey)

	if r.round%int64(len(r.elements)) == 0 {
		r.resetPriorities()
	}
}

func (r *robin) nextKey() string {
	var (
		maxPriority = math.MinInt64
		nextKey     = ""
	)

	for key, priority := range r.priorities {
		if priority > maxPriority {
			maxPriority = priority
			nextKey = key
		}
	}

	return nextKey
}

func (r *robin) setCurrent(key string) {
	for i := range r.elements {
		if r.elements[i].ID() == key {
			r.index = i
		}
	}
}
