package automation

import (
	"bytes"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pkg/errors"
	"github.com/stretchr/testify/require"
	"github.com/superform-xyz/v2-core/relayer/config"
	"github.com/superform-xyz/v2-core/relayer/pkg/data"
	"github.com/superform-xyz/v2-core/relayer/pkg/data/mem"
	"github.com/superform-xyz/v2-core/relayer/pkg/data/pg"
	"gitlab.com/distributed_lab/kit/pgdb"
)

var (
	//dbUrl           = "postgres://relayer-pg:relayer-pg@localhost:5432/relayer-db?sslmode=disable"
	runnerTimeout   = 1 * time.Second
	errInvalidInput = errors.New("invalid input")
	automationCfg   = config.Automation{
		Timeout: runnerTimeout,
	}
)

func createTask(id string, name string, input []byte, execTime time.Time, repeat time.Duration, now time.Time) data.Task {
	return data.Task{
		ID:            id,
		Name:          name,
		Input:         input,
		Output:        []byte{},
		ExecutionTime: execTime,
		Repeat:        repeat,
		Status:        data.CreatedTaskStatus,
		CreatedAt:     now,
		UpdatedAt:     now,
	}
}

func createHandlers(t *testing.T, name string) map[string]TaskHandler {
	return map[string]TaskHandler{
		name: func(input []byte) (output []byte, err error) {
			t.Log("Handler started:", name, string(input))
			if !bytes.Equal(input, []byte(name)) {
				t.Log("Handler error:", name, string(input))
				return nil, errInvalidInput
			}
			t.Log("Handler finished:", name, string(input))
			return []byte(name), nil
		},
	}
}

func createDefaultVariables(name string, t *testing.T, dbUrl *string) (data.TasksQ, map[string]TaskHandler, Automation, time.Time, []byte) {
	tasksQ := mem.NewTasksQ(map[string]data.Task{})
	if dbUrl != nil {
		db, _ := pgdb.Open(pgdb.Opts{
			URL:                *dbUrl,
			MaxOpenConnections: 12,
			MaxIdleConnections: 12,
		})

		tasksQ = pg.NewTasksQ(db.Clone())
	}

	handlers := createHandlers(t, name)
	automate := New(tasksQ, handlers, automationCfg)
	now := time.Now()

	return tasksQ, handlers, automate, now, []byte(name)
}

func Test_AutomationOneTimeTask(t *testing.T) {
	handler := fmt.Sprintf("handler-%d", time.Now().UnixNano())
	tasksQ, handlers, automate, now, handlerBytes := createDefaultVariables(handler, t, nil)

	automate.Start()
	defer automate.Stop()

	task := createTask(uuid.NewString(), handler, handlerBytes, now.Add(runnerTimeout*10), 0, now)
	require.NoError(t, automate.Add(task, handlers[handler]), "Failed to add task")

	t.Log("Inserted new task:", task.ID)
	time.Sleep(runnerTimeout * 15)

	dbTask, err := tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.FinishedTaskStatus, dbTask.Status, "Task status mismatch")
	require.Equal(t, handlerBytes, []byte(dbTask.Output), "Task output mismatch")
}

func Test_AutomationOneTimeTaskInvalidInput(t *testing.T) {
	handler := fmt.Sprintf("handler-%d", time.Now().UnixNano())
	tasksQ, handlers, automate, now, _ := createDefaultVariables(handler, t, nil)

	automate.Start()
	defer automate.Stop()

	task := createTask(uuid.NewString(), handler, []byte{}, now.Add(runnerTimeout*10), 0, now)
	require.NoError(t, automate.Add(task, handlers[handler]), "Failed to add task")

	t.Log("Inserted new task with invalid input:", task.ID)
	time.Sleep(runnerTimeout * 15)

	dbTask, err := tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.FailedTaskStatus, dbTask.Status, "Task status mismatch")
	require.Equal(t, errInvalidInput.Error(), dbTask.Error.Error(), "Task error mismatch")
}

func Test_AutomationOneTimeTaskStartInThePast(t *testing.T) {
	handler := fmt.Sprintf("handler-%d", time.Now().UnixNano())
	tasksQ, handlers, automate, now, _ := createDefaultVariables(handler, t, nil)

	automate.Start()
	defer automate.Stop()

	task := createTask(uuid.NewString(), handler, []byte{}, now.Add(runnerTimeout*-10), 0, now)
	require.NoError(t, automate.Add(task, handlers[handler]), "Failed to add task")

	t.Log("Inserted new task with past execution time:", task.ID)
	time.Sleep(runnerTimeout * 15)

	dbTask, err := tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.FailedTaskStatus, dbTask.Status, "Task status mismatch")
	require.Contains(t, dbTask.Error.Error(), "execution time", "Task error mismatch")
	require.Contains(t, dbTask.Error.Error(), "is in past", "Task error mismatch")
}

func Test_AutomationOneTimeExecutionTerminated(t *testing.T) {
	handler := fmt.Sprintf("handler-%d", time.Now().UnixNano())
	tasksQ, handlers, automate, now, handlerBytes := createDefaultVariables(handler, t, nil)

	automate.Start()

	task := createTask(uuid.NewString(), handler, handlerBytes, time.Now().Add(runnerTimeout*15), 0, now)
	require.NoError(t, automate.Add(task, handlers[handler]), "Failed to add task")

	t.Log("Inserted new task:", task.ID)
	time.Sleep(runnerTimeout * 5)
	automate.Stop()
	time.Sleep(runnerTimeout * 5)

	dbTask, err := tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.FinishedTaskStatus, dbTask.Status, "Task status mismatch")
	require.Equal(t, ErrExecutionTerminated.Error(), dbTask.Error.Error(), "Task error mismatch")
}

func Test_AutomationRepeatTask(t *testing.T) {
	handler := fmt.Sprintf("handler-%d", time.Now().UnixNano())
	tasksQ, handlers, automate, now, handlerBytes := createDefaultVariables(handler, t, nil)

	automate.Start()

	task := createTask(uuid.NewString(), handler, handlerBytes, now.Add(runnerTimeout*10), 5*time.Second, now)
	require.NoError(t, automate.Add(task, handlers[handler]), "Failed to add task")
	t.Log("Inserted new task:", task.ID)
	time.Sleep(runnerTimeout * 5)

	dbTask, err := tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.ProcessingTaskStatus, dbTask.Status, "Task status mismatch")

	time.Sleep(runnerTimeout * 11)
	dbTask, err = tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.ProcessingTaskStatus, dbTask.Status, "Task status mismatch")
	require.Equal(t, handlerBytes, []byte(dbTask.Output), "Task output mismatch")
	firstIteration := now.Add(runnerTimeout * 10)
	require.True(t, firstIteration.Sub(dbTask.UpdatedAt) <= runnerTimeout, "Task update time is invalid")

	time.Sleep(runnerTimeout * 7)
	dbTask, err = tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.ProcessingTaskStatus, dbTask.Status, "Task status mismatch")
	require.Equal(t, handlerBytes, []byte(dbTask.Output), "Task output mismatch")
	secondIteration := firstIteration.Add(5 * time.Second)
	require.True(t, secondIteration.Sub(dbTask.UpdatedAt) <= runnerTimeout, "Task update time is invalid")

	time.Sleep(runnerTimeout * 7)
	dbTask, err = tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.ProcessingTaskStatus, dbTask.Status, "Task status mismatch")
	require.Equal(t, handlerBytes, []byte(dbTask.Output), "Task output mismatch")
	thirdIteration := secondIteration.Add(5 * time.Second)
	require.True(t, thirdIteration.Sub(dbTask.UpdatedAt) <= runnerTimeout, "Task update time is invalid")

	automate.Stop()

	time.Sleep(runnerTimeout * 10)
	dbTask, err = tasksQ.FilterByIds(task.ID).Get()
	require.NoError(t, err, "Failed to retrieve task")
	require.Equal(t, data.FinishedTaskStatus, dbTask.Status, "Task status mismatch")
	require.Equal(t, ErrExecutionTerminated.Error(), dbTask.Error.Error(), "Task error mismatch")
}
