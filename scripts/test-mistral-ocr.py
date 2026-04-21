#!/usr/bin/env python3
"""
Prueba aislada de extracción de datos de comprobantes PDF con Mistral Document AI.
Uso: python scripts/test-mistral-ocr.py [ruta/al/archivo.pdf]
"""

import sys
import json
import base64
import os
from pathlib import Path
from dotenv import load_dotenv
from mistralai.client.sdk import Mistral

# Cargar variables de entorno desde .env en la raíz del proyecto
ROOT_DIR = Path(__file__).parent.parent
load_dotenv(ROOT_DIR / ".env")

API_KEY = os.getenv("API_KEY_MISTRAL")
if not API_KEY:
    print("ERROR: API_KEY_MISTRAL no encontrada en .env", file=sys.stderr)
    sys.exit(1)

# Cargar clasificación de gastos
classification_path = ROOT_DIR / "scripts" / "classification.json"
if not classification_path.exists():
    print(f"ERROR: classification.json no encontrado en {classification_path}", file=sys.stderr)
    sys.exit(1)

with open(classification_path, encoding="utf-8") as f:
    classification = json.load(f)


def build_classification_guide(classification: dict) -> str:
    """
    Genera el bloque de texto de la guía de clasificación para inyectar en el annotation_prompt.
    El valor de detalle_inferido es siempre la clave del item en el JSON de clasificación.
    Para items con detalle=null, la clave sirve como identificador que el Agente2 usará
    para buscar el item en classification.json (sabrá que detalle=null = no tocar col G).
    """
    lines = [
        'GUÍA DE CLASIFICACIÓN — completá "detalle_inferido" según lo que identifiques en el documento:',
        "",
    ]
    for section in ("lista_fijos", "lista_variables"):
        for item_key, item in classification.get(section, {}).items():
            keys = item.get("keys", [])
            if keys:
                keys_str = ", ".join(keys)
                lines.append(f'- Si encontrás: {keys_str} → detalle_inferido: "{item_key}"')
    lines.append('- Si no encontrás ninguna coincidencia → detalle_inferido: ""')
    return "\n".join(lines)


MIME_TYPES = {
    ".pdf": "application/pdf",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
}

# Argumentos: archivo (obligatorio) y caption opcional del usuario
pdf_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT_DIR / "samples" / "20260319-PagoMonot.pdf"
user_caption = sys.argv[2].strip() if len(sys.argv) > 2 else ""
if not pdf_path.exists():
    print(f"ERROR: Archivo no encontrado: {pdf_path}", file=sys.stderr)
    sys.exit(1)

ext = pdf_path.suffix.lower()
mime_type = MIME_TYPES.get(ext)
if not mime_type:
    print(f"ERROR: Extensión no soportada: {ext}", file=sys.stderr)
    sys.exit(1)

is_image = mime_type.startswith("image/")

print(f"Procesando: {pdf_path.name}" + (f" | caption: '{user_caption}'" if user_caption else ""))

# Leer archivo y encodar en base64
with open(pdf_path, "rb") as f:
    pdf_base64 = base64.standard_b64encode(f.read()).decode("utf-8")

# Schema JSON de salida
json_schema = {
    "type": "json_schema",
    "json_schema": {
        "name": "comprobante_pago",
        "schema": {
            "type": "object",
            "properties": {
                "concepto": {
                    "type": "string",
                    "description": "Tipo de impuesto o servicio pagado tal como aparece en el documento. Ej: MONOTRIBUTO, IIBB SANTA FE, GAS"
                },
                "detalle_inferido": {
                    "type": "string",
                    "description": "Clave del item de la guía de clasificación que coincide con cualquier parte del documento. Comparación flexible: sin distinción de mayúsculas, acentos ni puntuación. Vacío si no hay coincidencia."
                },
                "fecha": {
                    "type": "string",
                    "description": "Fecha del pago en formato DD/MM/YYYY"
                },
                "importe": {
                    "type": "number",
                    "description": "Monto total pagado como número sin símbolo de moneda ni puntos de miles"
                },
                "observacion": {
                    "type": "string",
                    "description": "Nombre del destinatario o empresa, CBU/alias, CUIT/DNI, número de cuenta, número de comprobante o referencia, período. Omitir IDs de operación largos o hashes aleatorios."
                }
            },
            "required": ["concepto", "detalle_inferido", "fecha", "importe", "observacion"]
        }
    }
}

# Prompt de extracción con guía de clasificación inyectada
classification_guide = build_classification_guide(classification)

caption_block = f"""
ETIQUETA DEL USUARIO: "{user_caption}"
→ Esta palabra es la descripción temática que el usuario asignó al comprobante. Es la señal más confiable disponible.
→ Usala como guía principal para completar detalle_inferido: si "{user_caption}" coincide con alguna clave de la GUÍA (comparación flexible) → asignala directamente, sin buscar en el documento.
→ Para concepto: si el documento no muestra claramente un nombre de comercio o destinatario, podés usar "{user_caption}" como valor de referencia.
""" if user_caption else ""

annotation_prompt = f"""Sos un extractor de datos de comprobantes de pago argentinos. Extraé exactamente los cinco campos indicados.
{caption_block}
ESTRATEGIA: Escaneá TODO el texto del documento antes de completar cada campo. Los datos pueden estar en cualquier parte: encabezado, cuerpo, pie, tablas, sellos.

concepto — Nombre del comercio, servicio, impuesto o destinatario del pago.
  • Priorizá el nombre del comercio o emisor, no el medio de pago.
  • En tickets de terminal POS (Fiserv, Posnet, Ingenico, Getnet): el nombre del comercio aparece
    en el encabezado — usá ese nombre. Ignorá el tipo de tarjeta (MC, Visa, Débito, Prepaga).
  • Si el banco dice "VAR" o "Pago de servicio" pero hay nombre de empresa → usá el nombre de empresa.
  • Si es transferencia a persona → usá el nombre del destinatario.
  • Si hay etiqueta del usuario (ver arriba) y el documento no muestra comercio claro → usá la etiqueta.
  • Ejemplos: "FARMACIA CANO", "MONOTRIBUTO", "Epe - Santa Fe", "Damian Raul Frontera".

detalle_inferido — Clave de clasificación del gasto (ver GUÍA más abajo).
  • Si hay etiqueta del usuario (ver arriba): buscá esa etiqueta primero en la GUÍA. Si coincide → usala directamente.
  • Si no hay etiqueta o no coincide: escaneá TODOS los campos del documento (nombre, destinatario, CBU, CUIT).
  • Comparación flexible: ignorá mayúsculas, acentos y puntuación.
    Ej: "Monica" = "Mónica" | "farmacia cano" = "Farmacia" | "epe santa fe" = "Epe - Santa Fe"
  • Si encontrás coincidencia → completá con la clave exacta de la GUÍA. Sin modificar la clave.
  • Si no hay coincidencia → dejá vacío "".

fecha — Fecha del pago o emisión.
  • Formato de salida: DD/MM/YYYY. Ignorar hora, zona horaria y segundos.
  • Si hay varias fechas → usar la de pago o acreditación, no la de vencimiento.
  • Excepción ARCA / IIBB: si el documento incluye etiqueta "Fecha y Hora" → usar ESA fecha.
    Ignorar "FECHA DE PAGO" (puede ser fecha de procesamiento bancario posterior).

importe — Monto total pagado como número.
  • Sin símbolo de moneda ni separadores de miles. Punto decimal si aplica.
  • Ejemplos: "$72.414,30" → 72414.3 | "$ 52.939,51" → 52939.51 | "$33.000" → 33000
  • Si hay subtotal + IVA + total → usar el TOTAL.
  • Si no se encuentra → 0.

observacion — Datos de trazabilidad. Incluir en este orden si están disponibles:
  1. Nombre del destinatario o empresa emisora
  2. CBU o alias
  3. CUIT / DNI / número de cuenta
  4. Número de comprobante, referencia o período
  • NO incluir: IDs de operación alfanuméricos largos (20+ caracteres), URLs, texto repetitivo.

{classification_guide}"""

# Llamada a Mistral OCR
client = Mistral(api_key=API_KEY)

print("Llamando a Mistral OCR...")
doc_url = f"data:{mime_type};base64,{pdf_base64}"
doc_type = "image_url" if is_image else "document_url"
doc_key = "image_url" if is_image else "document_url"

response = client.ocr.process(
    model="mistral-ocr-latest",
    document={
        "type": doc_type,
        doc_key: doc_url,
    },
    document_annotation_format=json_schema,
    document_annotation_prompt=annotation_prompt,
    include_image_base64=False
)

# Extraer el JSON del resultado
result = None

if hasattr(response, "document_annotation") and response.document_annotation:
    try:
        result = json.loads(response.document_annotation)
    except (json.JSONDecodeError, TypeError):
        result = response.document_annotation

if result is None:
    print("\nRespuesta completa (debug):")
    print(response)
    print("\nNo se encontró document_annotation en la respuesta. Revisar estructura.")
    sys.exit(1)

# Mostrar resultado
print("\n--- JSON extraído ---")
print(json.dumps(result, ensure_ascii=False, indent=2))

# Guardar en samples/extracted/
output_dir = ROOT_DIR / "samples" / "extracted"
output_dir.mkdir(exist_ok=True)
output_path = output_dir / (pdf_path.stem + ".json")
with open(output_path, "w", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, indent=2)

print(f"\nGuardado en: {output_path}")
