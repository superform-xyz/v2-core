package pg

import (
	"time"

	sq "github.com/Masterminds/squirrel"
	"github.com/pkg/errors"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"gitlab.com/distributed_lab/kit/pgdb"
)

const (
	tasksTable = "tasks"

	idTasksColumn     = "id"
	statusTasksColumn = "status"
)

var (
	ErrDuplicateKeyConstraint = errors.New("duplicate key value violates unique constraint")
)

type taskModel struct {
	ID            string          `db:"id"`
	Name          string          `db:"name"`
	Input         []byte          `db:"input"`
	Output        []byte          `db:"output"`
	ExecutionTime time.Time       `db:"execution_time"`
	Repeat        time.Duration   `db:"repeat"`
	Status        data.TaskStatus `db:"status"`
	Error         *string         `db:"error"`
	CreatedAt     time.Time       `db:"created_at"`
	UpdatedAt     time.Time       `db:"updated_at"`
}

type tasksQ struct {
	db       *pgdb.DB
	selector sq.SelectBuilder
	updater  sq.UpdateBuilder
	deleter  sq.DeleteBuilder
}

func NewTasksQ(db *pgdb.DB) data.TasksQ {
	return &tasksQ{
		db:       db,
		selector: sq.Select("*").From(tasksTable),
		updater:  sq.Update(tasksTable),
		deleter:  sq.Delete(tasksTable),
	}
}

func (q tasksQ) New() data.TasksQ {
	return NewTasksQ(q.db.Clone())
}

func (q tasksQ) Insert(task data.Task) error {
	var err *string = nil
	if task.Error != nil {
		err = ptr(task.Error.Error())
	}

	return q.db.Exec(sq.Insert(tasksTable).SetMap(map[string]interface{}{
		"id":             task.ID,
		"name":           task.Name,
		"input":          task.Input,
		"output":         task.Output,
		"execution_time": task.ExecutionTime,
		"repeat":         task.Repeat,
		"status":         task.Status,
		"error":          err,
		"created_at":     task.CreatedAt,
		"updated_at":     task.CreatedAt,
	}))
}

func (q tasksQ) Update(task data.Task) error {
	var err *string = nil
	if task.Error != nil {
		err = ptr(task.Error.Error())
	}

	return q.db.Exec(q.updater.SetMap(map[string]interface{}{
		"input":          task.Input,
		"output":         task.Output,
		"execution_time": task.ExecutionTime,
		"repeat":         task.Repeat,
		"status":         task.Status,
		"error":          err,
		"created_at":     task.CreatedAt,
		"updated_at":     task.UpdatedAt,
	}))
}

func (q tasksQ) Delete() error {
	return q.db.Exec(q.deleter)
}

func (q tasksQ) Select() ([]data.Task, error) {
	var (
		models []taskModel
		result []data.Task
	)

	if err := q.db.Select(&models, q.selector); err != nil {
		return nil, errors.Wrap(err, "failed to select tasks")
	}

	for _, model := range models {
		var newErr error
		if model.Error != nil {
			newErr = errors.New(*model.Error)
		}

		result = append(result, data.Task{
			ID:            model.ID,
			Name:          model.Name,
			Input:         model.Input,
			Output:        model.Output,
			ExecutionTime: model.ExecutionTime,
			Repeat:        model.Repeat,
			Status:        model.Status,
			Error:         newErr,
			CreatedAt:     model.CreatedAt,
			UpdatedAt:     model.UpdatedAt,
		})
	}

	return result, nil
}

func (q tasksQ) Get() (*data.Task, error) {
	var model taskModel

	if err := q.db.Get(&model, q.selector); err != nil {
		return nil, errors.Wrap(err, "failed to get transaction")
	}

	var newErr error
	if model.Error != nil {
		newErr = errors.New(*model.Error)
	}

	return &data.Task{
		ID:            model.ID,
		Name:          model.Name,
		Input:         model.Input,
		Output:        model.Output,
		ExecutionTime: model.ExecutionTime,
		Repeat:        model.Repeat,
		Status:        model.Status,
		Error:         newErr,
		CreatedAt:     model.CreatedAt,
		UpdatedAt:     model.UpdatedAt,
	}, nil
}

func (q tasksQ) FilterByIds(ids ...string) data.TasksQ {
	return q.withFilters(sq.Eq{idTasksColumn: ids})
}

func (q tasksQ) FilterByStatus(status data.TaskStatus) data.TasksQ {
	return q.withFilters(sq.Eq{statusTasksColumn: status})
}

func (q tasksQ) withFilters(stmt interface{}) data.TasksQ {
	q.selector = q.selector.Where(stmt)
	q.updater = q.updater.Where(stmt)
	q.deleter = q.deleter.Where(stmt)

	return q
}
