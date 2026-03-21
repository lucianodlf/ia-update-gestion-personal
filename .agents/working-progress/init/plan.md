# Plan de Implementación

> Documento vivo — se actualiza conforme avanzan las fases.
> Investigación base: [`research-init.md`](research-init.md) | Ideas futuras: [`roadmap.md`](roadmap.md)

---

## Visión general del sistema

```
Telegram Bot
    ↓ (foto / PDF / texto)
n8n Workflow (self-hosted, puerto 5679)
    ↓
Agente 1: Mistral OCR → JSON estructurado
    ↓
Agente 2: Claude Code CLI (via wrapper shell)
    → Lee estructura del sheet (Claude Sheets MCP)
    → Decide tab/columnas/categoría
    → Escribe en Google Sheets
    ↓
Telegram: confirmación al usuario
```

---

## Fases

- [ ] **Fase 1** — Setup de infraestructura (n8n + submodule) → [`fase-1-plan.md`](fase-1-plan.md)
- [ ] **Fase 2** — Análisis del Google Sheet real → [`fase-2-plan.md`](fase-2-plan.md)
- [ ] **Fase 3** — Bot Telegram + workflow OCR (Agente 1) → [`fase-3-plan.md`](fase-3-plan.md)
- [ ] **Fase 4** — Agente 2: decisión y escritura en Sheets → [`fase-4-plan.md`](fase-4-plan.md)
- [ ] **Fase 5** — Pruebas end-to-end y ajuste de reglas → [`fase-5-plan.md`](fase-5-plan.md)

---

## Fase 1 — Setup de infraestructura

**Objetivo:** Tener n8n corriendo localmente con n8n-mcp activo en Claude Code.

- [ ] Agregar submodule `n8n-shbase` en `services/n8n/`
- [ ] Configurar `.env` del submodule (PROJECT_NAME=gastos-personal, N8N_PORT=5679)
- [ ] Levantar n8n + PostgreSQL con `make up`
- [ ] Crear usuario admin en la UI
- [ ] Generar API key y agregarla al `.env`
- [ ] Ejecutar `make init` segunda pasada → `.mcp.json` configurado
- [ ] Verificar si Claude Code lee `.mcp.json` del submodule o se debe replicar en raíz
- [ ] Crear estructura de directorios del repo (`samples/`, `workflows/`, `scripts/`, `docs/`)

Ver detalle en → [`fase-1-plan.md`](fase-1-plan.md)

---

## Fase 2 — Análisis del Google Sheet real

**Objetivo:** Documentar la estructura del sheet para parametrizar el Agente 2.

- [ ] Conectar a Google Sheets (OAuth2 o manual)
- [ ] Documentar: nombres de tabs, convención de nombres, columnas, categorías
- [ ] Identificar reglas especiales (totales automáticos, dropdowns, etc.)
- [ ] Escribir `docs/sheet-structure.md`

Ver detalle en → [`fase-2-plan.md`](fase-2-plan.md)

---

## Fase 3 — Bot Telegram + Workflow OCR (Agente 1)

**Objetivo:** Workflow n8n que recibe comprobante de Telegram y retorna JSON estructurado.

- [ ] Crear bot via BotFather → obtener BOT_TOKEN
- [ ] Configurar nodo Telegram Trigger en n8n (modo polling para desarrollo)
- [ ] Implementar condicional: imagen/PDF vs. texto libre
- [ ] Nodo OCR: HTTP Request a Mistral Document AI
  - [ ] Convertir archivo a Base64
  - [ ] Enviar a `/v1/ocr` con API key de Mistral
  - [ ] Parsear respuesta markdown
- [ ] Nodo de estructuración: extraer JSON con campos (comercio, fecha, monto, categoría)
- [ ] Output de prueba: retornar JSON parseado via Telegram al usuario
- [ ] Directorio `samples/receipts/` con comprobantes de ejemplo para tests

Ver detalle en → [`fase-3-plan.md`](fase-3-plan.md)

---

## Fase 4 — Agente 2: Decisión y Escritura en Sheets

**Objetivo:** Claude Code CLI recibe el JSON, decide y escribe en el sheet.

- [ ] Prueba experimental: invocar `claude` en modo no-TTY desde script shell (ver `pregunta-1-guia.md`)
- [ ] Configurar Claude Sheets MCP (`ringo380/claude-google-sheets-mcp`)
  - [ ] Setup OAuth2 Google Sheets
  - [ ] Validar operaciones: leer rango, append fila
- [ ] Escribir `scripts/agent-sheets.sh`: wrapper que recibe JSON y devuelve resultado
- [ ] Conectar desde n8n via nodo Execute Command
- [ ] Definir system prompt del agente con reglas del sheet (basado en Fase 2)
- [ ] Lógica de persistencia de comprobantes en Drive (los que aplica)

Ver detalle en → [`fase-4-plan.md`](fase-4-plan.md)

---

## Fase 5 — Pruebas end-to-end y ajuste

**Objetivo:** Flujo completo funcionando con comprobantes reales.

- [ ] Pruebas con comprobantes de ejemplo (`samples/receipts/`)
- [ ] Ajuste del prompt de extracción de datos (categorías, campos)
- [ ] Ajuste de reglas del Agente 2 (system prompt)
- [ ] Manejo de errores básico: notificación al usuario en Telegram
- [ ] Exportar workflows de n8n a `workflows/n8n/`
- [ ] Documentación final básica

Ver detalle en → [`fase-5-plan.md`](fase-5-plan.md)

---

## Decisiones arquitecturales tomadas

| Decisión | Elección |
|---|---|
| Infraestructura n8n | git submodule de n8n-shbase, puerto 5679 |
| OCR (Agente 1) | Mistral Document AI, plan Experiment |
| Agente 2 | Claude Code CLI via wrapper shell, con Claude Sheets MCP |
| Autenticación Sheets | OAuth2 |
| Conexión Telegram en dev | Polling (sin ngrok) |
| Moneda | Solo ARS en v1 |
| Feedback al usuario | Confirmación success/error básica |
| Persistencia comprobantes | Flujo de decisión → carpeta específica en Drive (por tipo/fecha) |
| Versionado workflows | Export JSON manual a `workflows/n8n/` |
