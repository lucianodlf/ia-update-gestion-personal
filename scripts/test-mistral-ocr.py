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

# PDF de entrada (argumento o default)
pdf_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT_DIR / "samples" / "20260319-PagoMonot.pdf"
if not pdf_path.exists():
    print(f"ERROR: Archivo no encontrado: {pdf_path}", file=sys.stderr)
    sys.exit(1)

print(f"Procesando: {pdf_path.name}")

# Leer PDF y encodar en base64
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
                    "description": "Tipo de impuesto o servicio pagado. Ej: MONOTRIBUTO, IIBB, GANANCIAS"
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
                    "description": "Información adicional: organismo emisor, número de comprobante, etc."
                }
            },
            "required": ["concepto", "fecha", "importe", "observacion"]
        }
    }
}

# Prompt de extracción flexible
annotation_prompt = """Eres un extractor de datos de comprobantes de pago argentinos.
Extrae los siguientes datos del comprobante:
- concepto: identifica el tipo de impuesto o servicio pagado. Buscá palabras clave como MONOTRIBUTO, IIBB, IMPUESTO A LAS GANANCIAS, etc. Si no aparece explícitamente, usá la descripción más clara disponible.
- fecha: la fecha del pago o emisión del comprobante en formato DD/MM/YYYY. Si aparece hora también, ignorala.
- importe: el monto total pagado como número sin símbolo de moneda ni puntos de miles. Usá punto decimal si aplica.
- observacion: información adicional útil como número de comprobante, organismo emisor (ARCA, AFIP, banco), o cualquier dato de contexto relevante. Si no hay nada relevante, devolvé string vacío."""

# Llamada a Mistral OCR
client = Mistral(api_key=API_KEY)

print("Llamando a Mistral OCR...")
response = client.ocr.process(
    model="mistral-ocr-latest",
    document={
        "type": "document_url",
        "document_url": f"data:application/pdf;base64,{pdf_base64}"
    },
    document_annotation_format=json_schema,
    document_annotation_prompt=annotation_prompt,
    include_image_base64=False
)

# Extraer el JSON del resultado
# La annotation estructurada está en response.document_annotation
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
