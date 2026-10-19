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
	@echo "Dossier build nettoyé."

help:
	@echo "Commandes disponibles :"
	@echo "  make build    - Compile AIBudgetBar et crée le bundle AIBudgetBar.app"
	@echo "  make install  - Compile, installe dans ~/Applications et lance l'app"
	@echo "  make status   - Affiche le résumé du budget dans le terminal"
	@echo "  make json     - Exporte le résumé au format JSON"
	@echo "  make run      - Lance l'application directement"
	@echo "  make clean    - Supprime les artefacts de compilation"
