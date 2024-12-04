package mem

import (
	"database/sql"
	"sync"

	"github.com/superform-xyz/v2-core/relayer/pkg/data"
)

type taskQ struct {
	*sync.Mutex

	tasks   map[string]data.Task
	filters []filterer[data.Task]
}

func NewTasksQ(tasks map[string]data.Task) data.TasksQ {
	return &taskQ{
		Mutex: new(sync.Mutex),
		tasks: tasks,
	}
}

func (t taskQ) New() data.TasksQ {
	return NewTasksQ(t.tasks)
}

func (t taskQ) Insert(task data.Task) error {
	t.Lock()
	defer t.Unlock()

	t.tasks[task.ID] = task
	return nil
}

func (t taskQ) Update(task data.Task) error {
	t.Lock()
	defer t.Unlock()

	for _, key := range filterKeys(t.tasks, t.filters) {
		_, ok := t.tasks[key]
		if !ok {
			return sql.ErrNoRows
		}

		t.tasks[key] = task
	}
	return nil
}

func (t taskQ) Delete() error {
	t.Lock()
	defer t.Unlock()

	for _, key := range filterKeys(t.tasks, t.filters) {
		delete(t.tasks, key)
	}

	return nil
}

func (t taskQ) Select() ([]data.Task, error) {
	result := make([]data.Task, 0, len(t.tasks))

	for _, value := range t.tasks {
		if filter(t.filters, value) {
			result = append(result, value)
		}
	}

	return result, nil
}

func (t taskQ) Get() (*data.Task, error) {
	for _, value := range t.tasks {
		if filter(t.filters, value) {
			return &value, nil
		}
	}

	return nil, sql.ErrNoRows
}

func (t taskQ) FilterByIds(ids ...string) data.TasksQ {
	t.filters = append(t.filters, func(value data.Task) bool {
		return contains(ids, value.ID)
	})

	return t
}

func (t taskQ) FilterByStatus(status data.TaskStatus) data.TasksQ {
	t.filters = append(t.filters, func(value data.Task) bool {
		return value.Status == status
	})

	return t
}
