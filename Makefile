.PHONY: help init start stop activate-workflows deactivate-workflows n8n-up n8n-down n8n-logs n8n-status

-include .env

ZROK     ?= 0
ACTIVATE ?= 0

help: ## Muestra esta ayuda
	@echo ""
	@echo "  ia-update-cuentas-personales — Comandos disponibles"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""

init: ## Genera scripts/agent2-mcp.json desde credenciales Google  [CREDENTIALS=/ruta/al/key.json]
	@if [ -z "$(CREDENTIALS)" ]; then \
		echo "❌ Uso: make init CREDENTIALS=/ruta/al/service-account-key.json"; \
		exit 1; \
	fi
	@if [ ! -f "$(CREDENTIALS)" ]; then \
		echo "❌ Archivo no encontrado: $(CREDENTIALS)"; \
		exit 1; \
	fi
	@PROJECT_ID=$$(jq -r '.project_id' "$(CREDENTIALS)"); \
	CREDS_ABS=$$(realpath "$(CREDENTIALS)"); \
	jq -n \
		--arg pid "$$PROJECT_ID" \
		--arg creds "$$CREDS_ABS" \
		'{"mcpServers":{"mcp-gsheets":{"command":"npx","args":["-y","mcp-gsheets@latest"],"env":{"GOOGLE_PROJECT_ID":$$pid,"GOOGLE_APPLICATION_CREDENTIALS":$$creds}}}}' \
		> scripts/agent2-mcp.json; \
	echo "✅ scripts/agent2-mcp.json generado (project: $$PROJECT_ID, creds: $$CREDS_ABS)"

start: ## Levanta el entorno completo  [ZROK=1] [ACTIVATE=1]
	@$(MAKE) -C services/n8n up
	@if [ "$(ZROK)" = "1" ]; then $(MAKE) -C services/n8n zrok2-start ZROK_NAME=$(ZROK_NAME); fi
	@if [ "$(ACTIVATE)" = "1" ]; then $(MAKE) activate-workflows; fi

stop: ## Detiene el entorno completo  [ZROK=1] [ACTIVATE=1]
	@if [ "$(ACTIVATE)" = "1" ]; then $(MAKE) deactivate-workflows; fi
	@if [ "$(ZROK)" = "1" ]; then $(MAKE) -C services/n8n zrok2-stop; fi
	@$(MAKE) -C services/n8n down

activate-workflows: ## Activa los workflows en N8N_ACTIVATE_WORKFLOWS (ver .env)
	@$(MAKE) -C services/n8n activate-workflows N8N_ACTIVATE_WORKFLOWS=$(N8N_ACTIVATE_WORKFLOWS)

deactivate-workflows: ## Desactiva los workflows en N8N_ACTIVATE_WORKFLOWS (ver .env)
	@$(MAKE) -C services/n8n deactivate-workflows N8N_ACTIVATE_WORKFLOWS=$(N8N_ACTIVATE_WORKFLOWS)

n8n-up: ## Levanta n8n + PostgreSQL (docker compose only)
	@$(MAKE) -C services/n8n up

n8n-down: ## Detiene n8n + PostgreSQL
	@$(MAKE) -C services/n8n down

n8n-logs: ## Logs de n8n en tiempo real
	@$(MAKE) -C services/n8n logs

n8n-status: ## Estado de los contenedores n8n
	@$(MAKE) -C services/n8n status
