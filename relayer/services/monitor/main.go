package monitor

import (
	"context"
	"sync"
)

type Processor interface {
	Start(ctx context.Context)
	Stop(ctx context.Context)
}

type monitor struct {
	wg         sync.WaitGroup
	processors []Processor
}

func New(processors []Processor) (Processor, error) {
	return &monitor{
		processors: processors,
	}, nil
}

func (m *monitor) Start(ctx context.Context) {
	for _, processor := range m.processors {
		m.wg.Add(1)

		go func() {
			processor.Start(ctx)
			defer m.wg.Done()
		}()
	}
	m.wg.Wait()
}

func (m *monitor) Stop(ctx context.Context) {
	for _, processor := range m.processors {
		processor.Stop(ctx)
	}
}
