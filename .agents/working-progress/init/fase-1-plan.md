# Fase 1 — Setup de Infraestructura

> Estado: completado
> Objetivo: Tener n8n corriendo localmente con n8n-mcp activo en Claude Code.
> Referencia general: [`plan.md`](plan.md)

---

## TODO

- [x] Agregar submodule `n8n-shbase` en `services/n8n/`
- [x] Configurar `.env` del submodule (PROJECT_NAME=gastos-personal, N8N_PORT=5679)
- [x] Levantar n8n + PostgreSQL con `make up`
- [x] Crear usuario admin en la UI de n8n
- [x] Generar API key en Settings → API y agregarla al `.env`
- [x] Ejecutar `make init` segunda pasada → `.mcp.json` configurado
- [x] Verificar comportamiento de `.mcp.json` del submodule en Claude Code
- [x] Crear estructura de directorios del repo (`samples/`, `workflows/`, `scripts/`, `docs/`)
- [x] Agregar `.env.example` y `Makefile` raíz básico

---

## Notas de implementación

_Se irán agregando durante la ejecución de la fase._

---

## Decisiones tomadas

_Se registrarán durante la fase._

---

## Referencias

- [n8n-shbase README](https://github.com/lucianodlf/n8n-shbase) — comandos `make init`, `make up`, tabla de puertos
- [n8n-shbase integración multi-repo](https://github.com/lucianodlf/n8n-shbase/blob/main/docs/integracion-multi-repo.md) — git submodules, redes Docker
- [n8n-mcp en DeepWiki](https://deepwiki.com/czlonkowski/n8n-mcp) — configuración `.mcp.json`
