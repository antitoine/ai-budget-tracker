.PHONY: all build install run status json clean help

all: build

build:
	@chmod +x Scripts/build.sh
	@./Scripts/build.sh

install:
	@chmod +x Scripts/install.sh
	@./Scripts/install.sh

run: build
	@./build/AIBudgetBar

status: build
	@./build/AIBudgetBar --status

widget: build
	@./build/AIBudgetBar --widget

json: build
	@./build/AIBudgetBar --json

config: build
	@./build/AIBudgetBar --config

clean:
	@rm -rf build
	@echo "Build directory cleaned."

help:
	@echo "Available commands:"
	@echo "  make build    - Compile AIBudgetBar and create AIBudgetBar.app bundle"
	@echo "  make install  - Compile, install into ~/Applications and launch the app"
	@echo "  make status   - Display budget summary in the terminal"
	@echo "  make json     - Export summary in JSON format"
	@echo "  make run      - Launch the application directly"
	@echo "  make clean    - Remove build artifacts"
