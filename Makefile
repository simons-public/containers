# Taskfile shim
TASK_TARGETS := $(shell task --list | awk '/^*/ { printf "%s ", $$2 }' | sed -e 's/:/꞉/g')

.PHONY: .tasks $(TASK_TARGETS)
.DEFAULT_GOAL := .task

.tasks: $(TASK_TARGETS)

.task:
	@task

%:
	@task $@
