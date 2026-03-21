.PHONY: help n8n-up n8n-down n8n-logs n8n-status

help: ## Muestra esta ayuda
	@echo ""
	@echo "  ia-update-cuentas-personales — Comandos disponibles"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""

n8n-up: ## Levanta n8n + PostgreSQL
	@$(MAKE) -C services/n8n up

n8n-down: ## Detiene n8n + PostgreSQL
	@$(MAKE) -C services/n8n down

n8n-logs: ## Logs de n8n en tiempo real
	@$(MAKE) -C services/n8n logs

n8n-status: ## Estado de los contenedores n8n
	@$(MAKE) -C services/n8n status
