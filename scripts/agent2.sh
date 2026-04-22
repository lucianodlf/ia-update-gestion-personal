#!/usr/bin/env bash
# agent2.sh — Wrapper para invocar el Agente 2 (Claude Code CLI)
# Uso: ./agent2.sh [--verbose] "texto del usuario"
# Env opcionales: TELEGRAM_CHAT_ID, BOT_TOKEN (o desde .env)

set -euo pipefail

# ── PATH — necesario cuando se invoca desde SSH no-interactivo ────────────────
export PATH="$PATH:$HOME/.local/bin:/usr/local/bin:$(ls -d $HOME/.nvm/versions/node/*/bin 2>/dev/null | tail -1)"

# ── Capturar args originales antes de cualquier shift ─────────────────────────
ORIGINAL_CALL="$0 $*"

# ── Flags ─────────────────────────────────────────────────────────────────────
VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
  VERBOSE=true
  shift
fi

# ── Configuración ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AGENT2_SYSTEM_PROMPT_FILE="${AGENT2_SYSTEM_PROMPT_FILE:-$SCRIPT_DIR/agent2-system-prompt-latest.txt}"
AGENT2_MCP_CONFIG="${AGENT2_MCP_CONFIG:-$SCRIPT_DIR/agent2-mcp.json}"
AGENT2_SETTINGS="${AGENT2_SETTINGS:-$SCRIPT_DIR/agent2-settings.json}"
AGENT2_MODEL="${AGENT2_MODEL:-claude-sonnet-4-6}"
AGENT2_LOG_FILE="${AGENT2_LOG_FILE:-$PROJECT_DIR/logs/agent2.log}"
AGENT2_TIMEOUT="${AGENT2_TIMEOUT:-120}"
INPUT_TEXT="${1:-}"

# ── Cargar .env para BOT_TOKEN (si no está ya en el entorno) ─────────
ROOT_ENV="$PROJECT_DIR/.env"
if [[ -f "$ROOT_ENV" ]]; then
  set +u
  # shellcheck source=/dev/null
  source "$ROOT_ENV"
  set -u
fi

# ── Logging ───────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$AGENT2_LOG_FILE")"
log() {
  echo "[$(date -Iseconds)] $*" >> "$AGENT2_LOG_FILE"
}

log "════════════════════════════════════════"
log "CALL:  $ORIGINAL_CALL"
log "INPUT: $INPUT_TEXT"

# ── Validaciones ──────────────────────────────────────────────────────────────
[[ -z "$INPUT_TEXT" ]] && { echo "❌ Error: input vacío" >&2; exit 1; }

if ! echo "$INPUT_TEXT" | grep -qP '\p{L}'; then
  echo "❌ Error: el texto no contiene palabras reconocibles" >&2
  exit 1
fi

[[ ! -f "$AGENT2_SYSTEM_PROMPT_FILE" ]] && { echo "❌ Error: system prompt no encontrado en $AGENT2_SYSTEM_PROMPT_FILE" >&2; exit 1; }
[[ ! -f "$AGENT2_MCP_CONFIG" ]]         && { echo "❌ Error: MCP config no encontrado en $AGENT2_MCP_CONFIG" >&2; exit 1; }
[[ ! -f "$AGENT2_SETTINGS" ]]           && { echo "❌ Error: agent settings no encontrado en $AGENT2_SETTINGS" >&2; exit 1; }

SYSTEM_PROMPT=$(cat "$AGENT2_SYSTEM_PROMPT_FILE")

# Inyectar Sheet ID desde env (permite alternar test ↔ producción sin editar el prompt)
if [[ -z "${AGENT2_SHEET_ID:-}" ]]; then
  echo "❌ Error: AGENT2_SHEET_ID no definido en .env" >&2
  exit 1
fi
SYSTEM_PROMPT="${SYSTEM_PROMPT//SHEET_ID_PLACEHOLDER/$AGENT2_SHEET_ID}"

# ── Indicador de progreso en Telegram ─────────────────────────────────────────
PROGRESS_PID=""
PROGRESS_MSG_ID=""

if [[ -n "${TELEGRAM_CHAT_ID:-}" && -n "${BOT_TOKEN:-}" ]]; then
  # Enviar mensaje inicial y capturar message_id
  SEND_RESP=$(curl -s --max-time 5 \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}&text=⏳ Actualizando sheet con Agente..." 2>/dev/null || echo '{}')
  PROGRESS_MSG_ID=$(echo "$SEND_RESP" | jq -r '.result.message_id // empty' 2>/dev/null || echo '')

  if [[ -n "$PROGRESS_MSG_ID" ]]; then
    # Subproceso: edita el mensaje cada 5s con tiempo transcurrido
    (
      elapsed=5
      while true; do
        sleep 5
        curl -s --max-time 5 \
          "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
          -d "chat_id=${TELEGRAM_CHAT_ID}&message_id=${PROGRESS_MSG_ID}&text=⏳ Actualizando sheet con Agente... (${elapsed}s)" \
          > /dev/null 2>&1 || true
        elapsed=$((elapsed + 5))
      done
    ) &
    PROGRESS_PID=$!
    log "PROGRESS: mensaje Telegram iniciado (msg_id=$PROGRESS_MSG_ID, pid=$PROGRESS_PID)"
  fi
fi

# ── Limpieza: matar subproceso y borrar mensaje de progreso ───────────────────
cleanup_progress() {
  [[ -n "$PROGRESS_PID" ]] && kill "$PROGRESS_PID" 2>/dev/null || true
  if [[ -n "$PROGRESS_MSG_ID" && -n "${TELEGRAM_CHAT_ID:-}" && -n "${BOT_TOKEN:-}" ]]; then
    curl -s --max-time 5 \
      "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}&message_id=${PROGRESS_MSG_ID}" \
      > /dev/null 2>&1 || true
  fi
}

STREAM_TMP=$(mktemp)
trap 'cleanup_progress; rm -f "$STREAM_TMP"' EXIT

# ── Flags de claude ───────────────────────────────────────────────────────────
COMMON_FLAGS=(
  --print
  --model "$AGENT2_MODEL"
  --system-prompt "$SYSTEM_PROMPT"
  --mcp-config "$AGENT2_MCP_CONFIG"
  --strict-mcp-config
  --settings "$AGENT2_SETTINGS"
  --no-session-persistence
  --permission-mode dontAsk
  --allowedTools "Read,Write,mcp__mcp-gsheets__sheets_get_values,mcp__mcp-gsheets__sheets_update_values,mcp__mcp-gsheets__sheets_insert_rows"
)

VERBOSE_FLAG=(--verbose)
if [[ "$VERBOSE" == true ]]; then
  VERBOSE_FLAG=(--verbose --include-partial-messages)
fi

# ── Ejecutar claude con timeout ───────────────────────────────────────────────
set +e
echo "$INPUT_TEXT" | timeout "$AGENT2_TIMEOUT" claude "${COMMON_FLAGS[@]}" \
  --output-format stream-json \
  "${VERBOSE_FLAG[@]}" \
  2>>"$AGENT2_LOG_FILE" | tee "$STREAM_TMP" | \
  stdbuf -oL "$SCRIPT_DIR/agent2-stream-parse.sh" >> "$AGENT2_LOG_FILE" 2>&1
CLAUDE_EXIT=${PIPESTATUS[1]}
set -e

# ── Manejar timeout ───────────────────────────────────────────────────────────
if [[ $CLAUDE_EXIT -eq 124 ]]; then
  log "TIMEOUT: proceso terminado después de ${AGENT2_TIMEOUT}s"
  echo "⏱️ El agente tardó más de ${AGENT2_TIMEOUT}s y fue cancelado. Intentá de nuevo."
  exit 0
fi

if [[ $CLAUDE_EXIT -ne 0 ]]; then
  log "ERROR: exit $CLAUDE_EXIT"
  echo "❌ Error al ejecutar el agente (exit $CLAUDE_EXIT)" >&2
  exit $CLAUDE_EXIT
fi

# ── Extraer resultado del stream ──────────────────────────────────────────────
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
