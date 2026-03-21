## Proyecto
Automatización de gastos personales: Telegram → n8n (orquestador) → Mistral OCR → Google Sheets.
Stack: n8n self-hosted (puerto 5678, UI: http://localhost:5678), Mistral Document AI, Claude Code CLI como Agente 2.

## Comandos
```
make n8n-up      # Levanta n8n + PostgreSQL
make n8n-down    # Detiene n8n
make n8n-logs    # Logs en tiempo real
make n8n-status  # Estado de contenedores
```

## Workflow de trabajo
Directorio: `.agents/working-progress` (sobreescribible con `WORKFLOW_DIR` en `.env`)
Sesiones: `init` · `feat-[nombre]` · `feat-[nombre]-[issue]` · `fix-[nombre]` · `refactor-[nombre]`
Archivos por sesión: `prompt.md` · `research.md` · `plan.md` · `fase-N-plan.md` · `roadmap.md`
Nueva sesión: `/ns` — crea subdirectorio y `prompt.md`
Al retomar: leer `prompt.md` y `plan.md` de la sesión activa
TODOs: editar directamente el archivo de plan marcando `[x]`
No incluir credenciales ni datos sensibles en documentos de trabajo
Guía completa: `.agents/working-progress/WORKFLOW.md` (leer solo si hay dudas sobre el proceso)
Al iniciar sesión nueva (sin contexto de trabajo activo): sugerir al usuario ejecutar `/ns` para crear la sesión.

## n8n — Conocimiento operativo
Ver `services/n8n/n8n-knowledge.md` para aprendizajes sobre workflows, MCP y errores conocidos.
Actualizar ese archivo desde cualquier proyecto y hacer push a n8n-shbase para compartir el conocimiento.
