#!/usr/bin/env bash
# agent2-stream-parse.sh — Parsea stream-json de claude y muestra salida legible + tokens
# Uso: claude ... --output-format stream-json | ./agent2-stream-parse.sh

jq -rj '
  if .type == "assistant" then
    (.message.content[]? |
      if .type == "text" then .text
      elif .type == "tool_use" then
        "\n→ TOOL: \(.name)\n   IN:  \(.input | tostring | .[0:400])\n"
      else empty end)
  elif .type == "tool_result" then
    "   OUT: \(
      .content |
      if . == null then "(vacío)"
      elif type == "array" then (map(.text? // tostring) | join(" ") | .[0:400])
      else (tostring | .[0:400])
      end
    )\n"
  elif .type == "result" then
    "\n---\n✔ RESULT: \(.result)\nTOKENS: input=\(.usage.input_tokens // "?") output=\(.usage.output_tokens // "?")\n"
  else empty end
'
