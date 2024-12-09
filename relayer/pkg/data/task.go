package data

import (
	"encoding/json"
	"time"
)

type TaskStatus string

const (
	CreatedTaskStatus    TaskStatus = "created"
	ProcessingTaskStatus TaskStatus = "processing"
	FinishedTaskStatus   TaskStatus = "finished"
	FailedTaskStatus     TaskStatus = "failed"
)

type TasksQ interface {
	New() TasksQ

	Insert(task Task) error
	Update(task Task) error
	Delete() error

	Select() ([]Task, error)
	Get() (*Task, error)

	FilterByIds(ids ...string) TasksQ
	FilterByStatus(status TaskStatus) TasksQ
}

type Task struct {
	ID string `json:"id"`
	// Name - represents task name to execute, should be unique
	Name   string          `json:"name"`
	Input  json.RawMessage `json:"input"`
	Output json.RawMessage `json:"output"`
	// ExecutionTime - sets the time to execute task on or start repeatable executions on
	ExecutionTime time.Time `json:"execution_time"`
	// Repeat - timeout to wait for the task to execute, e.g. once a day, once a week etc.
	Repeat    time.Duration `json:"repeat"`
	Status    TaskStatus    `json:"status"`
	Error     error         `json:"error"`
	CreatedAt time.Time     `json:"created_at"`
	UpdatedAt time.Time     `json:"updated_at"`
}
