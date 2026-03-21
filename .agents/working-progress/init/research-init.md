# Research Inicial: Automatización de Registro de Gastos Personales

> Documento de investigación inicial. Las decisiones tomadas y próximos pasos se consolidan en `plan.md`. Las ideas y opciones futuras en `roadmap.md`.

---

## Descripción del Proyecto

Automatizar el registro de gastos personales sobre una planilla de Google Sheets en Drive personal, integrando Telegram con un flujo de n8n para poder subir comprobantes (imágenes/PDF), extraer información relevante en formato JSON, y en función a ciertas reglas y patrones que sigue la planilla, decidir cómo debe ser agregado el nuevo registro de gasto. El trabajo es realizado por dos agentes de IA en conjunto con n8n como orquestador.

---

## 1. Casos similares encontrados en la web

Existe una cantidad significativa de proyectos y templates públicos que abordan objetivos muy similares. Es una señal positiva: hay infraestructura probada sobre la cual construir.

**Templates de n8n directamente relevantes (marketplace oficial):**

| Template | Descripción |
|---|---|
| [Automatic expense tracking with Telegram, AI, and Google Sheets](https://n8n.io/workflows/6210) | Telegram + AI + Sheets. Flujo base completo. |
| [Automated expense tracking with AI receipt analysis & Google Sheets](https://n8n.io/workflows/5442) | Análisis de foto de recibo con AI, Sheets. |
| [Extract & store receipt data with GPT-4, OCR, Google Sheets & Notion via Telegram Bot](https://n8n.io/workflows/8279) | GPT-4 + OCR + Sheets + Notion + Drive para almacenar imagen original. |
| [Process receipts with Google Vision OCR, AI & Telegram to Google Sheets](https://n8n.io/workflows/6359) | Google Vision API + LLM + Sheets. |
| [Track expenses from receipt photos with Telegram & Google Sheets using OCR.space](https://n8n.io/workflows/6686) | OCR.space (gratuito) + Sheets. |
| [Extract & categorize receipt data with Google OCR, OpenRouter AI & Telegram](https://n8n.io/workflows/4020) | OpenRouter + Google OCR + Telegram. |
| [Extract Details from Receipts via Telegram with Tesseract and Llama](https://n8n.io/workflows/4361) | Tesseract (local) + Llama via OpenRouter. |
| [Auto invoice & receipt OCR to Google Sheets – Drive, Gmail, & Telegram triggers](https://n8n.io/workflows/3618) | Multi-trigger: Drive, Gmail y Telegram. |
| [Track expenses automatically with Telegram Bot using GPT-4o, OCR and voice recognition](https://n8n.io/workflows/11368) | Incluye reconocimiento de voz (Whisper). |

**Patrón común que adoptan estos proyectos:**
1. Telegram recibe imagen/PDF/texto → n8n webhook
2. Download del archivo o uso del texto directo
3. OCR del documento (vía API externa o modelo visión)
4. Estructuración en JSON con AI (GPT-4, Gemini, Mistral, Llama)
5. Validación y categorización
6. Append a Google Sheets

**Diferenciadores de este proyecto:**
- Mistral Document AI como OCR especializado (no solo visión genérica)
- Lógica de decisión basada en la estructura específica del sheet real
- Claude Code CLI como Agente 2 (aprovechando suscripción Pro)
- Soporte nativo para PDFs

---

## 2. Integración con n8n-shbase

**Estrategia:** git submodule dentro de este proyecto apuntando a `git@github.com:lucianodlf/n8n-shbase.git`.

**Puerto asignado:** `5679` ya reservado para `gastos-personal` en la tabla de puertos del README de n8n-shbase.

**Flujo de setup:**
```
git submodule add git@github.com:lucianodlf/n8n-shbase.git services/n8n
cd services/n8n && make init
# editar services/n8n/.env: PROJECT_NAME=gastos-personal, N8N_PORT=5679
make up → crear usuario admin → generar API key en Settings → agregar al .env
make init  # segunda pasada: configura .mcp.json con API key
# reiniciar Claude Code → n8n-mcp activo
```

**Integración n8n-mcp:** El submodule incluye `.mcp.json` pre-configurado con `n8n-mcp` (via npx). Con la API key configurada, Claude Code puede crear y modificar workflows directamente.

**Puntos a investigar en Fase 1:**
- Confirmar si Claude Code lee el `.mcp.json` del submodule automáticamente. Si no, se toma como modelo y se crea uno propio en la raíz del repo.
- Estrategia de versionado de workflows: n8n permite exportar JSON. Evaluar si la API de n8n permite exportar automáticamente para trackear con git en `workflows/n8n/`.
- Modo de conexión de Telegram en desarrollo: se usará **polling** (no requiere HTTPS ni ngrok). Ver detalles en `pregunta-2-guia.md`.

---

## 3. Integración con Telegram via n8n

**Configuración del bot:**
1. Crear bot via BotFather → obtener `BOT_TOKEN`
2. n8n: nodo "Telegram Trigger" configurado en modo polling para desarrollo local

**Tipos de entrada soportados (v1):**
- **Foto** (llega comprimida por Telegram)
- **Documento** (PDF, imagen sin comprimir — mejor calidad para OCR)
- **Texto** libre (ingreso manual: "gasté $500 en supermercado")

> Nota: la compresión de fotos puede afectar la calidad del OCR. Se evaluará con pruebas reales usando comprobantes propios. El flujo manejará ambos casos (foto y documento).

**Manejo del archivo en n8n:**
- Se evaluará nodo nativo "Telegram Get File" vs HTTP Request manual según pro/contras en implementación.
- Los comprobantes que deban persistirse se guardarán en Drive con nomenclatura definida por tipo/fecha. Se investigará si se puede hacer Telegram → Drive sin descargar localmente.

**Respuesta al usuario:**
- El bot confirma el resultado al usuario: mensaje de éxito o descripción básica del error.
- Usuario único (uso personal). Sin autenticación adicional en v1.

---

## 4. OCR y Extracción de Datos

### Decisión: Mistral Document AI (plan Experiment)

**API Endpoint:** `POST /v1/ocr` con `mistral-ocr-latest`

**Formatos soportados:** PDF, PPTX, DOCX / PNG, JPEG, AVIF

**Input:** URL pública, Base64, o upload directo

**Respuesta:**
```json
{
  "pages": [{ "index": 0, "markdown": "...", "tables": [...], "header": "...", "footer": "..." }],
  "model": "mistral-ocr-latest",
  "usage_info": {}
}
```

**Plan Experiment:** solo requiere teléfono verificado, sin tarjeta. Rate limits conservadores, suficientes para el volumen de uso personal. Los requests pueden usarse para entrenamiento de Mistral — aceptado para esta fase.

**Integración en n8n:**
- Nodo HTTP Request con Bearer token (API key de Mistral)
- Archivo de Telegram convertido a Base64 → enviado al endpoint OCR
- Respuesta markdown → siguiente nodo para estructuración JSON

### Opciones documentadas (futuro)

**OpenRouter con modelos de visión gratuitos:**
- Modelos: `qwen/qwen2.5-vl-72b-instruct:free` (~75% OCRBench), `llama-3.2-11b-vision-instruct:free`, Gemma 3.
- Un solo request hace OCR + estructuración JSON. No soporta PDF nativamente (requiere conversión a imagen).
- Documentado para usar si los límites de Mistral resultan insuficientes. Ver roadmap.

**Claude Code CLI como OCR:**
- Técnicamente posible via wrapper shell pero frágil, sin documentación de soporte para uso headless.
- Claude se reserva para el Agente 2. Ver roadmap para exploración futura.

---

## 5. Agente 2: Decisión y Escritura en Google Sheets

> La integración con el sheet se refinará al analizar el documento real (fase posterior). En el flujo de prueba inicial, el Agente 2 puede limitarse a retornar el JSON parseado via Telegram.

**Objetivo del agente:**
1. Recibir JSON extraído del comprobante
2. Validar campos completos
3. Determinar tab del mes activo y estructura de columnas
4. Agregar fila en el sheet

### Arquitectura elegida: Propuesta B — Claude Code CLI externo, orquestado desde n8n

```
n8n → [JSON estructurado] → Execute Command (wrapper shell)
    → claude CLI lee JSON + estructura del sheet (via MCP)
    → decide y escribe en Sheets
    → stdout → n8n → respuesta Telegram
```

Se prefiere que el Agente 2 viva **fuera** de n8n para poder usar Claude (suscripción Pro). n8n lo invoca via nodo Execute Command y recibe el resultado por stdout. Este punto requiere prueba experimental documentada en `pregunta-1-guia.md`.

### Herramientas para el Agente 2 (a evaluar en implementación)

| Opción | Descripción | Estado |
|---|---|---|
| **Claude Sheets MCP** (`ringo380/claude-google-sheets-mcp`) | MCP nativo para Claude Code + Sheets. OAuth2 / Service Account. | Preferida para v1 |
| **sheets-cli** (`gmickel/sheets-cli`) | CLI determinista con Agent Skills para Claude Code. JSON output. | Alternativa simple |
| **gws CLI** (`googleworkspace/cli`) | CLI oficial de Google Workspace. MCP experimental. Requiere GCP. | Investigar facturación |
| **AI Agent en n8n** | Todo dentro de n8n, sin Claude Pro. Conector nativo de Sheets. | Fallback si CLI no funciona |

**Autenticación Google Sheets:** OAuth2 para comenzar. Service Account documentado como opción futura.

### Opciones futuras documentadas — ver roadmap
- Google Workspace CLI (gws): investigar si requiere facturación GCP
- Service Account para automatización sin interacción
- OpenRouter como LLM alternativo para el AI Agent en n8n

---

## 6. Arquitectura del Sistema — Decisión

**Arquitectura elegida: Propuesta B** (n8n orquesta, Claude Code como Agente 2)

```
Telegram → n8n Webhook (polling)
  → Condicional: ¿imagen/PDF o texto?
  → [Si imagen/PDF] HTTP Request Mistral OCR → markdown
  → Mistral/nodo AI → JSON estructurado
  → Execute Command: wrapper shell invoca Claude Code CLI
      → Claude + Claude Sheets MCP lee estructura del sheet
      → Claude decide tab, columnas, categoría
      → Claude escribe en Sheets
      → devuelve resultado JSON via stdout
  → n8n recibe resultado
  → Telegram: confirmación o error
```

**Propuesta C** (todo en n8n con AI Agent nativo) queda documentada como **fallback** si la invocación headless de Claude no resulta viable. Ver roadmap.

---

## 7. Estructura del Google Sheet — A analizar

> Pendiente de análisis del documento real. Se hará en Fase 2.

**Patrón hipotético (a confirmar):**
```
Documento principal
├── Tab: "Resumen" — dashboard con SUMIF y gráficos
├── Tab: "Enero 2026" — transacciones del mes
│   ├── Columna A: Fecha
│   ├── Columna B: Descripción / Comercio
│   ├── Columna C: Categoría (dropdown)
│   ├── Columna D: Monto
│   └── Columna E: Notas
└── Tab: "Febrero 2026", etc.
```

**Lo que el agente necesitará saber:**
- Nombre del tab activo (convención de nombres)
- Estructura y orden de columnas
- Lista de categorías válidas
- Reglas de append (evitar romper totales automáticos)

El análisis del sheet generará `docs/sheet-structure.md` que alimenta el system prompt del Agente 2.

---

## 8. Consideraciones de Privacidad y Seguridad

- Plan Experiment de Mistral puede usar los datos para entrenamiento — aceptado en esta fase
- Credenciales en `.env` ignorado por git. `N8N_ENCRYPTION_KEY` crítico, no perder
- Bot de Telegram: usuario único, sin filtro por chat_id en v1
- Para monedas: solo ARS en v1. Funcionalidades multi-moneda en roadmap

---

## 9. Estructura de Directorios del Repositorio

```
ia-update-cuentas-personales/
├── services/
│   └── n8n/                      ← git submodule n8n-shbase (puerto 5679)
├── samples/
│   ├── receipts/                 ← comprobantes de ejemplo para tests
│   └── extracted/                ← JSONs de ejemplo post-OCR
├── workflows/
│   └── n8n/                      ← exports JSON de workflows de n8n
├── scripts/
│   └── agent-sheets.sh           ← wrapper para invocar Claude Code CLI
├── docs/
│   └── sheet-structure.md        ← análisis del sheet real (Fase 2)
├── .env.example
├── .gitmodules
├── Makefile
└── .agents/
    └── working-progress/
        └── init/
            ├── research-init.md  ← este documento
            ├── roadmap.md        ← ideas y opciones futuras
            ├── plan.md           ← plan de implementación por fases
            ├── pregunta-1-guia.md
            └── pregunta-2-guia.md
```

---

## Fuentes de Referencia

### Infraestructura base
- [n8n-shbase — README](https://github.com/lucianodlf/n8n-shbase)
- [n8n-shbase — Integración multi-repo](https://github.com/lucianodlf/n8n-shbase/blob/main/docs/integracion-multi-repo.md)
- [n8n-mcp (czlonkowski)](https://github.com/czlonkowski/n8n-mcp)
- [n8n-mcp en DeepWiki](https://deepwiki.com/czlonkowski/n8n-mcp)
- [n8n en DeepWiki](https://deepwiki.com/n8n-io/n8n)
- [n8n-docs en DeepWiki](https://deepwiki.com/n8n-io/n8n-docs)

### OCR y Document AI
- [Mistral Document AI — Docs oficiales](https://docs.mistral.ai/capabilities/document_ai)
- [Mistral Document AI — OCR básico](https://docs.mistral.ai/capabilities/document_ai/basic_ocr)
- [Mistral en DeepWiki](https://deepwiki.com/mistralai/platform-docs-public)
- [Mistral OCR 3 — Anuncio](https://mistral.ai/news/mistral-ocr-3)
- [Mistral — Plan Experiment](https://help.mistral.ai/en/articles/455206-how-can-i-try-the-api-for-free-with-the-experiment-plan)
- [Mistral — Rate limits](https://docs.mistral.ai/deployment/ai-studio/tier)
- [OpenRouter — Docs](https://openrouter.ai/docs/quickstart)
- [OpenRouter — Modelos gratuitos](https://openrouter.ai/collections/free-models)
- [OpenRouter — Multimodal](https://openrouter.ai/docs/guides/overview/multimodal/overview)
- [Free LLM Image to Text via OpenRouter](https://github.com/ceodaniyal/free-llm-image-to-text)
- [Qwen 2.5 VL + OpenRouter para facturas](https://medium.com/@tententgc/extracting-invoice-data-with-qwen2-5-vl-and-openrouter-an-ocr-walkthrough-in-python-7b5490578cad)

### Google Sheets — Integración con agentes
- [Google Workspace CLI (gws)](https://github.com/googleworkspace/cli)
- [gws — skills.md](https://github.com/googleworkspace/cli/blob/main/docs/skills.md)
- [gws en DeepWiki](https://deepwiki.com/googleworkspace/cli)
- [sheets-cli (gmickel)](https://github.com/gmickel/sheets-cli)
- [Claude Google Sheets MCP (ringo380)](https://github.com/ringo380/claude-google-sheets-mcp)
- [Google Sheets MCP — Composio](https://composio.dev/toolkits/googlesheets/framework/claude-code)
- [Using Claude Code with Google Sheets](https://code.dblock.org/2025/07/30/using-claude-code-with-google-sheets.html)
- [How to Use Google Workspace CLI with Claude Code](https://www.mindstudio.ai/blog/google-workspace-cli-claude-code-automation)

### Telegram
- [Telegram API — Docs oficiales](https://core.telegram.org/api)
- [Telegram Bot API](https://core.telegram.org/bots/api)

### Templates de n8n — Casos similares
- [Automatic expense tracking with Telegram, AI, and Google Sheets](https://n8n.io/workflows/6210-automatic-expense-tracking-with-telegram-ai-and-google-sheets/)
- [Automated expense tracking with AI receipt analysis & Google Sheets](https://n8n.io/workflows/5442-automated-expense-tracking-with-ai-receipt-analysis-and-google-sheets/)
- [Extract & store receipt data with GPT-4, OCR, Google Sheets & Notion via Telegram Bot](https://n8n.io/workflows/8279-extract-and-store-receipt-data-with-gpt-4-ocr-google-sheets-and-notion-via-telegram-bot/)
- [Process receipts with Google Vision OCR, AI & Telegram to Google Sheets](https://n8n.io/workflows/6359-process-receipts-with-google-vision-ocr-ai-and-telegram-to-google-sheets/)
- [Track expenses from receipt photos with Telegram & Google Sheets using OCR.space](https://n8n.io/workflows/6686-track-expenses-from-receipt-photos-with-telegram-and-google-sheets-using-ocrspace/)
- [Extract & categorize receipt data with Google OCR, OpenRouter AI & Telegram](https://n8n.io/workflows/4020-extract-and-categorize-receipt-data-with-google-ocr-openrouter-ai-and-telegram/)
- [Extract Details from Receipts via Telegram with Tesseract and Llama](https://n8n.io/workflows/4361-extract-details-from-receipts-via-telegram-with-tesseract-and-llama/)
- [Auto invoice & receipt OCR to Google Sheets – Drive, Gmail, & Telegram triggers](https://n8n.io/workflows/3618-auto-invoice-and-receipt-ocr-to-google-sheets-drive-gmail-and-telegram-triggers/)
- [Track expenses automatically with Telegram Bot using GPT-4o, OCR and voice recognition](https://n8n.io/workflows/11368-track-expenses-automatically-with-telegram-bot-using-gpt-4o-ocr-and-voice-recognition/)
- [AI-driven personal finance automation (GitHub)](https://github.com/mativallej/ai-expense-tracker-n8n)
- [MistralAI n8n Integration: OCR Action](https://hackceleration.com/mistralai-n8n/)
