package automation

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/pkg/errors"
	"github.com/rs/zerolog/log"
	"github.com/superform-xyz/v2-core/relayer/config"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
)

var (
	ErrNoHandlerFound      = errors.New("no handler found")
	ErrExecutionTerminated = errors.New("execution terminated")
)

type Automation interface {
	Start()
	Stop()

	Add(task data.Task, handler TaskHandler) error
	Update(task data.Task, handler TaskHandler) error
	Remove(task data.Task) error
}

type TaskHandler func(input []byte) (output []byte, err error)

const serviceName = "automation"

type automation struct {
	tasksQ   data.TasksQ
	handlers map[string]TaskHandler
	tasks    map[string]context.CancelFunc
	running  *atomic.Bool
	close    chan struct{}
	mu       *sync.Mutex
	timeout  time.Duration
}

func New(tasksQ data.TasksQ, handlers map[string]TaskHandler, config config.Runner) Automation {
	return &automation{
		tasksQ:   tasksQ,
		handlers: handlers,
		running:  new(atomic.Bool),
		mu:       new(sync.Mutex),
		close:    make(chan struct{}),
		tasks:    make(map[string]context.CancelFunc),
		timeout:  config.Timeout,
	}
}

func (a automation) Add(task data.Task, handler TaskHandler) error {
	if err := a.tasksQ.Insert(task); err != nil {
		return errors.Wrap(err, "failed to insert new task")
	}

	a.handlers[task.Name] = handler
	return nil
}

func (a automation) Update(task data.Task, handler TaskHandler) error {
	a.mu.Lock()
	defer a.mu.Unlock()

	taskKey := fmt.Sprintf("%s/%s", task.ID, task.Name)
	if cancelFunc, exists := a.tasks[taskKey]; exists {
		cancelFunc()
		delete(a.tasks, taskKey)
	}

	// TODO: should we strictly put created status here or wait for it to come in update?
	// 	created status required for the task to be rescheduled
	task.Status = data.CreatedTaskStatus

	if err := a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
		return errors.Wrapf(err, "failed to update task id=%s", task.ID)
	}

	a.handlers[task.Name] = handler
	return nil
}

func (a automation) Remove(task data.Task) error {
	a.mu.Lock()
	defer a.mu.Unlock()

	if err := a.tasksQ.FilterByIds(task.ID).Delete(); err != nil {
		return errors.Wrapf(err, "failed to delete task id=%s", task.ID)
	}

	delete(a.handlers, task.Name)

	taskKey := fmt.Sprintf("%s/%s", task.ID, task.Name)
	cancelFunc, exists := a.tasks[taskKey]
	if exists {
		cancelFunc()
		delete(a.tasks, taskKey)
	}

	return nil
}

func (a automation) Stop() {
	if !a.running.Load() {
		return
	}

	a.mu.Lock()
	defer a.mu.Unlock()

	for _, cancelFunc := range a.tasks {
		cancelFunc()
	}
	a.tasks = make(map[string]context.CancelFunc)

	close(a.close)
	a.running.Store(false)
}

func (a automation) Start() {
	if a.running.Load() {
		log.Warn().Str("service", serviceName).Msg("already started")
		return
	}

	log.Info().Str("service", serviceName).Msg("starting service")
	a.running.Store(true)

	go func() {
		//TODO: think about subscribing to events from storage in order to schedule tasks without pinging storage
		// may be troubles with in-memory storage - creation custom notifier to implement interface
		ticker := time.NewTicker(a.timeout)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				if err := a.processTasks(); err != nil {
					log.Error().Err(err).Msg("failed to process tasks")
					continue
				}
			case <-a.close:
				log.Info().Str("service", serviceName).Msg("stopping service")
				return
			default:
				continue
			}
		}
	}()
}

func (a automation) processTasks() error {
	createdTasks, err := a.tasksQ.FilterByStatus(data.CreatedTaskStatus).Select()
	if err != nil {
		return errors.Wrap(err, "failed to select created tasks")
	}

	for _, task := range createdTasks {
		log.Info().Str("service", serviceName).Str("task", task.ID).Msg("processing task")
		if err = a.processTask(task); err != nil {
			return errors.Wrap(err, "failed to process task")
		}
		log.Info().Str("service", serviceName).Str("task", task.ID).Msg("processed task")
	}

	return nil
}

func (a automation) processTask(task data.Task) error {
	task.Status = data.ProcessingTaskStatus
	task.UpdatedAt = time.Now()
	if err := a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
		return errors.Wrapf(err, "failed to update task id=%s", task.ID)
	}

	now := time.Now()
	if task.ExecutionTime.Before(now) {
		task.Error = errors.Errorf("execution time (%s) is in past (%s)", task.ExecutionTime.UTC(), now.UTC())
		task.Status = data.FailedTaskStatus
		task.UpdatedAt = time.Now()
		if err := a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
			return errors.Wrapf(err, "failed to update task id=%s", task.ID)
		}

		return nil
	}

	handler, exists := a.handlers[task.Name]
	if !exists {
		task.Error = ErrNoHandlerFound
		task.Status = data.FailedTaskStatus
		task.UpdatedAt = time.Now()
		if err := a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
			return errors.Wrapf(err, "failed to update task id=%s", task.ID)
		}

		return nil
	}

	ctx, cancel := context.WithCancel(context.TODO())

	a.mu.Lock()
	a.tasks[fmt.Sprintf("%s/%s", task.ID, task.Name)] = cancel
	a.mu.Unlock()

	go a.scheduleTask(ctx, task, now, handler)

	return nil
}

func (a automation) scheduleTask(ctx context.Context, task data.Task, now time.Time, handler TaskHandler) {
	var taskKey = fmt.Sprintf("%s/%s", task.ID, task.Name)
	defer func() {
		a.mu.Lock()
		delete(a.tasks, taskKey)
		a.mu.Unlock()
	}()

	if task.Repeat == 0 {
		a.runTaskOnce(ctx, task, now, handler)
		return
	}

	a.runTaskRepeatedly(ctx, task, now, handler)
}

func (a automation) runTaskOnce(ctx context.Context, task data.Task, now time.Time, handler TaskHandler) {
	select {
	case <-ctx.Done():
		task.Status = data.FinishedTaskStatus
		task.Error = ErrExecutionTerminated
		task.UpdatedAt = time.Now()
		if err := a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
			log.Fatal().Err(err).Str("task_id", task.ID).Msg("failed to update task")
			return
		}
		log.Info().Str("task", fmt.Sprintf("%s/%s", task.ID, task.Name)).Msg("terminating task")
		return
	case <-time.After(task.ExecutionTime.Sub(now)):
		output, err := handler(task.Input)
		if err != nil {
			task.Status = data.FailedTaskStatus
			task.Error = err
			task.Output = output
			task.UpdatedAt = time.Now()
			if err = a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
				log.Fatal().Err(err).Str("task_id", task.ID).Msg("failed to update task")
			}
			return
		}

		task.Status = data.FinishedTaskStatus
		task.Output = output
		task.UpdatedAt = time.Now()
		if err = a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
			log.Fatal().Err(err).Str("task_id", task.ID).Msg("failed to update task")
		}
		return
	}
}

func (a automation) runTaskRepeatedly(ctx context.Context, task data.Task, now time.Time, handler TaskHandler) {
	var ticker *time.Ticker

	for {
		select {
		case <-ctx.Done():
			task.Status = data.FinishedTaskStatus
			task.Error = ErrExecutionTerminated
			task.UpdatedAt = time.Now()
			if err := a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
				log.Fatal().Err(err).Str("task_id", task.ID).Msg("failed to update task")
			}
			ticker.Stop()
			log.Info().Str("task", fmt.Sprintf("%s/%s", task.ID, task.Name)).Msg("terminating task")
			return
		case <-time.After(task.ExecutionTime.Sub(now)):
			ticker = time.NewTicker(task.Repeat)
			select {
			case <-ticker.C:
				output, err := handler(task.Input)
				if err != nil {
					task.Status = data.FailedTaskStatus
					task.Error = err
					task.Output = output
					task.UpdatedAt = time.Now()
					if err = a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
						log.Fatal().Err(err).Str("task_id", task.ID).Msg("failed to update task")
					}
					continue
				}

				task.Output = output
				task.UpdatedAt = time.Now()
				if err = a.tasksQ.FilterByIds(task.ID).Update(task); err != nil {
					log.Fatal().Err(err).Str("task_id", task.ID).Msg("failed to update task")
				}
			}
		}
	}
}
