#!/usr/bin/env bash
# agent2.sh — Wrapper para invocar el Agente 2 (Claude Code CLI)
# Uso: ./agent2.sh [--verbose] "texto del usuario"

set -euo pipefail

# ── PATH — necesario cuando se invoca desde SSH no-interactivo (sin .bashrc) ───
export PATH="$PATH:/home/rafiki/.local/bin:/usr/local/bin:/home/rafiki/.nvm/versions/node/v22.13.0/bin"

# ── Flags ──────────────────────────────────────────────────────────────────────
VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=true
  shift
fi

# ── Configuración ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AGENT2_SYSTEM_PROMPT_FILE="${AGENT2_SYSTEM_PROMPT_FILE:-$SCRIPT_DIR/agent2-system-prompt-v2.txt}"
AGENT2_MCP_CONFIG="${AGENT2_MCP_CONFIG:-$SCRIPT_DIR/agent2-mcp.json}"
AGENT2_SETTINGS="${AGENT2_SETTINGS:-$SCRIPT_DIR/agent2-settings.json}"
AGENT2_MODEL="${AGENT2_MODEL:-claude-sonnet-4-6}"
AGENT2_LOG_FILE="${AGENT2_LOG_FILE:-$PROJECT_DIR/logs/agent2.log}"
INPUT_TEXT="${1:-}"

# ── Logging helpers ────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$AGENT2_LOG_FILE")"
TIMESTAMP=$(date -Iseconds)

log() {
  echo "[$TIMESTAMP] $*" >> "$AGENT2_LOG_FILE"
}

# ── Validaciones básicas ───────────────────────────────────────────────────────
if [[ -z "$INPUT_TEXT" ]]; then
  echo "❌ Error: input vacío" >&2
  exit 1
fi

if ! echo "$INPUT_TEXT" | grep -qP '\p{L}'; then
  echo "❌ Error: el texto no contiene palabras reconocibles" >&2
  exit 1
fi

if [[ ! -f "$AGENT2_SYSTEM_PROMPT_FILE" ]]; then
  echo "❌ Error: system prompt no encontrado en $AGENT2_SYSTEM_PROMPT_FILE" >&2
  exit 1
fi

if [[ ! -f "$AGENT2_MCP_CONFIG" ]]; then
  echo "❌ Error: MCP config no encontrado en $AGENT2_MCP_CONFIG" >&2
  exit 1
fi

if [[ ! -f "$AGENT2_SETTINGS" ]]; then
  echo "❌ Error: agent settings no encontrado en $AGENT2_SETTINGS" >&2
  exit 1
fi

# ── Log de inicio ──────────────────────────────────────────────────────────────
log "INPUT: $INPUT_TEXT"

SYSTEM_PROMPT=$(cat "$AGENT2_SYSTEM_PROMPT_FILE")

# ── Invocar Agente 2 ───────────────────────────────────────────────────────────
COMMON_FLAGS=(
  --print
  --model "$AGENT2_MODEL"
  --system-prompt "$SYSTEM_PROMPT"
  --mcp-config "$AGENT2_MCP_CONFIG"
  --strict-mcp-config
  --settings "$AGENT2_SETTINGS"
  --no-session-persistence
  --permission-mode dontAsk
  --allowedTools "mcp__mcp-gsheets__sheets_get_values,mcp__mcp-gsheets__sheets_update_values,mcp__mcp-gsheets__sheets_append_values"
)

# Archivo temporal para capturar el resultado final del stream
STREAM_TMP=$(mktemp)
trap 'rm -f "$STREAM_TMP"' EXIT

# Modo unificado: stream-json siempre → log en tiempo real + resultado limpio a stdout
# --verbose activa eventos intermedios (tool calls, reasoning) en el log
# --verbose es requerido por --output-format stream-json (siempre activo)
# --include-partial-messages agrega eventos intermedios solo cuando se pide verbosidad explícita
VERBOSE_FLAG=(--verbose)
if [[ "$VERBOSE" == true ]]; then
  VERBOSE_FLAG=(--verbose --include-partial-messages)
fi

# stderr separado al log — no mezclar con el stream JSON
echo "$INPUT_TEXT" | claude "${COMMON_FLAGS[@]}" \
  --output-format stream-json \
  "${VERBOSE_FLAG[@]}" \
  2>>"$AGENT2_LOG_FILE" | tee "$STREAM_TMP" | "$SCRIPT_DIR/agent2-stream-parse.sh" >> "$AGENT2_LOG_FILE" 2>&1

EXIT_CODE=${PIPESTATUS[0]}

if [[ $EXIT_CODE -ne 0 ]]; then
  log "ERROR: exit $EXIT_CODE"
  echo "❌ Error al ejecutar el agente (exit $EXIT_CODE)" >&2
  exit $EXIT_CODE
fi

# Extraer result y tokens — buscar línea JSON válida con "type":"result"
RESULT_LINE=$(grep -m1 '"type":"result"' "$STREAM_TMP" || true)
if [[ -n "$RESULT_LINE" ]]; then
  RESULT=$(echo "$RESULT_LINE" | jq -r '.result // empty')
  INPUT_TOKENS=$(echo "$RESULT_LINE" | jq -r '.usage.input_tokens // "?"')
  OUTPUT_TOKENS=$(echo "$RESULT_LINE" | jq -r '.usage.output_tokens // "?"')
else
  RESULT="❌ No se encontró resultado en el stream"
  INPUT_TOKENS="?"
  OUTPUT_TOKENS="?"
fi

log "RESULT: $RESULT"
log "TOKENS: input=$INPUT_TOKENS output=$OUTPUT_TOKENS"

echo "$RESULT"
