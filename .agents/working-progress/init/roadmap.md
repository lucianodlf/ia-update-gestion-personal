# Roadmap — Ideas y Opciones Futuras

> Registro de funcionalidades descartadas para v1 pero que se quieren explorar en iteraciones futuras. Referenciado desde `research-init.md` y `plan.md`.

---

## Funcionalidades futuras (post v1)

### Entrada de datos
- **Reconocimiento de voz:** integrar Whisper API para enviar mensajes de voz via Telegram. El bot transcribe y procesa como texto.
- **Comando slash + texto libre:** permitir registrar gastos rápidos con formato `/gasto 500 supermercado` o similar, con soporte para indicar moneda distinta (USD, etc.).
- **Múltiples monedas:** actualmente solo ARS. A futuro, soportar USD y otras monedas. Probablemente integrado con el ingreso por texto/comando slash.

### Seguridad y acceso
- **Filtro por chat_id:** que el bot solo acepte mensajes del usuario propietario.
- **Autenticación adicional:** pin o confirmación de identidad para operaciones sensibles.

### Almacenamiento de comprobantes
- **Flujo de decisión de persistencia:** no todos los comprobantes se guardan. Definir criterio (monto, tipo, categoría) para decidir cuáles van a Drive.
- **Nomenclatura en Drive:** naming convention por tipo/fecha/comercio en carpeta específica.
- **Telegram → Drive directo:** investigar si se puede enviar el archivo de Telegram a Drive sin descargarlo localmente en n8n.

### OCR alternativo
- **OpenRouter con modelos de visión gratuitos:** `qwen/qwen2.5-vl-72b-instruct:free` (~75% OCRBench). Un solo request hace OCR + estructuración JSON. No soporta PDFs nativamente.
  - Usar si los límites del plan Experiment de Mistral resultan insuficientes, o si se busca costo cero absoluto.
- **Claude Code CLI como OCR:** wrapper shell que invoque `claude` con imagen como input. Actualmente frágil y sin documentación de soporte headless. Requiere prueba experimental separada.
- **Modelos locales (Ollama + LLaVA):** para máxima privacidad. Mayor complejidad de setup.

### Agente 2 — opciones alternativas
- **Todo en n8n (Propuesta C):** AI Agent node con OpenRouter free + conector nativo de Google Sheets. Fallback si la invocación de Claude CLI headless no resulta viable. Más pragmático, sin Claude Pro.
- **Google Workspace CLI (gws):** herramienta oficial de Google, MCP experimental. Investigar si requiere facturación GCP (ya hay cuenta, pero no se quiere pagar). Si es gratuito, es candidato para reemplazar sheets-cli por cobertura más amplia (Drive, Gmail, etc.).
- **Service Account para Google Sheets:** autenticación sin interacción, ideal para automatización en producción. OAuth2 es suficiente para v1.

### Versionado de workflows n8n
- Investigar si la API de n8n permite exportar workflows automáticamente para nombrarlos con versionado semántico y trackearlos con git en `workflows/n8n/`.

### Análisis y reportes
- Generación periódica de resúmenes de gastos via Telegram (semanal/mensual).
- Alertas de presupuesto superado por categoría.

### Producción
- Reverse proxy (Nginx/Traefik) con HTTPS para usar webhook real de Telegram en lugar de polling.
- Dominio propio + SSL (Let's Encrypt).
- Backup automático de volúmenes n8n y PostgreSQL.

---

## Decisiones descartadas para v1 (con justificación)

| Decisión | Alternativa elegida | Razón |
|---|---|---|
| OpenRouter para OCR | Mistral Document AI | Mistral tiene OCR dedicado, mejor para PDFs, más simple de integrar |
| Claude CLI como OCR | Mistral Document AI | Frágil, sin soporte documentado para uso headless |
| Webhook HTTPS en desarrollo | Polling de Telegram | No requiere ngrok ni URL pública |
| Service Account para Sheets | OAuth2 | Más simple para comenzar |
| AI Agent en n8n (Propuesta C) | Claude CLI + n8n (Propuesta B) | Se prefiere usar Claude Pro para la lógica de decisión |
| Filtro por chat_id en Telegram | Sin filtro en v1 | Uso personal, complejidad innecesaria por ahora |
| Multi-moneda | Solo ARS en v1 | Fuera del alcance inicial |
| Voz/Whisper | No incluido en v1 | Feature de segunda iteración |
