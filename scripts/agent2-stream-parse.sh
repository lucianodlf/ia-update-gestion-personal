#!/usr/bin/env bash
# agent2-stream-parse.sh — Parsea stream-json de claude y muestra salida legible + tokens
# Uso: claude ... --output-format stream-json | ./agent2-stream-parse.sh

jq -rj '
  # Texto del agente (razonamiento y respuesta)
  if .type == "assistant" then
    (.message.content[]? |
      if .type == "text" then .text
      elif .type == "tool_use" then "\n→ TOOL: \(.name)\n"
      else empty end)
  # Resultado final con tokens
  elif .type == "result" then
    "\n---\n✔ RESULT: \(.result)\nTOKENS: input=\(.usage.input_tokens // "?") output=\(.usage.output_tokens // "?")\n"
  else empty end
'
