# Sheet Structure — Finanzas Generales

> Sheet ID: `1tcj7kkWHhmZyNaWw48UB_Qkh-mF5zt4v2UW-UsDyv7c`
> Locale: `es_AR` | Timezone: `America/Buenos_Aires`
> Relevado: 2026-03-21

---

## 1. Tabs

| Tab | sheetId | Agente 2 |
|-----|---------|----------|
| Egresos | 2079541688 | ✅ Leer + Escribir |
| Ingresos | 0 | ⛔ No tocar |
| Balance | 1090492635 | ⛔ No tocar |
| Tablas | 1860172647 | 👁 Solo leer |

---

## 2. Tab Egresos — Estructura

- Fila 1: encabezado año — no tocar
- Filas 2–3: vacías — no tocar
- Fila 4: headers — no tocar
- **Filas 5+:** datos. El agente escribe columnas A–I únicamente.

### Columnas

| Col | Nombre | Agente 2 | Notas |
|-----|--------|----------|-------|
| A | Fecha | ✅ Escribir | String `dd/mm/yyyy` con `USER_ENTERED` |
| B | Mes | ❌ NO escribir | Fórmula automática desde Fecha |
| C | Tipo | ✅ Escribir | `Fijo` o `Variable` |
| D | Concepto | ✅ Escribir | Ver lista en sección 4 |
| E | Importe | ✅ Escribir | Número. Ver patrones de importe abajo |
| F | Total | ✅ condicional | Solo en Patrón 2 y 3. Vacío en Patrón 1 |
| G | Detalle | ✅ Escribir | Texto libre descriptivo |
| H | Observación | ✅ condicional | Solo en Patrón 2 y 3. Vacío en Patrón 1 |
| I | Estado | ✅ Escribir | `ok` o `P` |
| J | — | ❌ NO tocar | Separador visual |
| K | Mes resumen | ❌ NO tocar | Tabla "Total / Mes" |
| L | Total/Mes | ❌ NO tocar | Fórmula SUMIF |

### Patrones de Importe

**Patrón 1 — Valor directo** (default):
- E: número directo | F: vacío | H: vacío
- Ejemplo: Alquiler $340.000, Monotributo $63.358

**Patrón 2 — División** (gasto compartido):
- E: `=F{row}/N` | F: total de factura | H: `"Divido N"`
- Detalle: `"<== Mitad | Total ==>"`
- Ejemplo: Gas total $15.365 → E = $7.683 (dividido 2)

**Patrón 3 — Por unidad** (gasto variable por cantidad):
- E: `=F{row}*N` | F: valor por unidad | H: `"Sesiones al mes: N"`
- Detalle: `"<== Valor x Secion"`
- Ejemplo: Terapia $45.000/sesión × N sesiones

---

## 3. Tipos de registro

Cada tipo define: qué concepto+detalle identifica el registro, qué operación puede ejecutar el Agente 2, y cómo manejar el importe.

El conjunto de registros fijos del inicio de mes (template) es:

| Concepto | Detalle | Tipo | Patrón importe | Estado inicial |
|----------|---------|------|----------------|----------------|
| Gas | (vacío) | Fijo | Patrón 2 (÷2) | P |
| Agua | (vacío) | Fijo | Patrón 2 (÷2) | P |
| Internet/Celular | (vacío) | Fijo | Patrón 2 (÷2) | P |
| Luz | (vacío) | Fijo | Patrón 2 (÷2) | P |
| Alquiler | (vacío) | Fijo | Patrón 1 | P |
| Terapia | (vacío) | Fijo | Patrón 3 (×N sesiones) | P |
| Monot+Impuestos | IB Mensual (Reg. Simp) | Fijo | Patrón 1 | P |
| Monot+Impuestos | Monotributo | Fijo | Patrón 1 | P |
| Varios | Telefono Meli | Fijo | Patrón 1 | P |
| Varios | Tarjeta Visa - Santa Fe | Fijo | Patrón 1 | P |
| Varios | Capoeira - Coperadora | Fijo | Patrón 1 | P |
| Varios | Mariano Djembe | Fijo | Patrón 1 | P |
| Varios | Gimnasio | Fijo | Patrón 1 | P |
| Hogar/Autocuidado | Psiquiatra | Variable | Patrón 1 | P |
| Varios | Tarjeta MP | Variable | Patrón 1 | ok |
| Varios | Obra Social | Fijo | Patrón 1 | P |

> Nota: Gas, Agua, Luz, Internet/Celular, Alquiler — el usuario ajusta el Total (col F) manualmente cuando llega la factura. El Agente 2 no necesita conocer ese valor de antemano; solo actualiza estado e importe cuando se lo indica.

### Fase-int-01 — Monot+Impuestos (primera automatización)

**Alcance:** registros con Concepto=`Monot+Impuestos` y Detalle=`IB Mensual (Reg. Simp)` o `Monotributo`.

**Fuente del mensaje:** texto descriptivo o comprobante (imagen/PDF).

**Lógica de fecha:**
- Si el mensaje incluye fecha → usar esa fecha
- Si incluye comprobante → usar fecha del comprobante
- Default → fecha del momento en que llega el mensaje

**Flujo de operación:**

1. Determinar el mes de referencia (desde la fecha)
2. Buscar en Egresos si ya existe una fila con ese Concepto+Detalle para ese mes (col B = mes derivado de la fecha)
3. **Si no existe:** insertar fila nueva completa con todos los campos
4. **Si ya existe (caso más frecuente):**
   - Actualizar col A (Fecha) con la fecha del mensaje/comprobante
   - Verificar col E (Importe): si el mensaje/comprobante indica un importe → actualizarlo; si no → dejar el existente
   - Col H (Observación): NO modificar
   - Actualizar col I (Estado): cambiar `P` → `ok`

**Términos equivalentes reconocidos (aprendizaje incremental):**

| Término recibido | Mapea a |
|-----------------|---------|
| "Monotributo" | Monot+Impuestos / Monotributo |
| "Monot" | Monot+Impuestos / Monotributo |
| "IB", "Ingresos Brutos", "IIBB" | Monot+Impuestos / IB Mensual (Reg. Simp) |
| "Monot ok", "Monot listo" | Confirmar pago, actualizar estado |

> Esta lista crece con el uso. Agregar aquí nuevas variantes detectadas.

**Respuesta ante errores o ambigüedad:**
- Si el registro no existe y el importe no está claro → responder describiendo el problema y preguntar
- Si el importe del mensaje no coincide con el registrado → informar la discrepancia y preguntar si actualizar

---

## 4. Valores válidos

### Concepto (col D)
```
Comida/Bebida | Super | Varios | Luz | Gas | Alquiler
Internet/Celular | Agua | Terapia | Hogar/Autocuidado
Fer/Her | Alcohol | Gustos/Salidas | Monot+Impuestos
```

### Tipo (col C)
```
Fijo | Variable
```

### Mapeo Concepto → Tipo

| Concepto | Tipo |
|----------|------|
| Gas, Agua, Luz, Internet/Celular, Alquiler, Terapia, Monot+Impuestos | Fijo |
| Comida/Bebida, Super, Gustos/Salidas, Alcohol, Hogar/Autocuidado, Varios, Fer/Her | Variable |

### Mapeo texto libre → Concepto

| Texto recibido | Concepto |
|---------------|---------|
| Supermercado, almacén, verdulería | `Super` |
| Restaurant, delivery, café | `Comida/Bebida` |
| Luz, electricidad | `Luz` |
| Gas, Metrogas | `Gas` |
| Agua, ASSA | `Agua` |
| WiFi, internet, celular, plan datos | `Internet/Celular` |
| Alquiler, expensas | `Alquiler` |
| Psicólogo, terapeuta, terapia | `Terapia` |
| Monotributo, AFIP, impuestos, IIBB | `Monot+Impuestos` |
| Limpieza, hogar, farmacia, autocuidado | `Hogar/Autocuidado` |
| Bar, alcohol, cerveza, vino | `Alcohol` |
| Cine, teatro, salida, entretenimiento | `Gustos/Salidas` |
| Sin categoría clara | `Varios` |

---

## 5. Técnica de escritura

1. **Append con INSERT_ROWS** — nunca OVERWRITE
2. **Fecha** — string `"dd/mm/yyyy"` + `valueInputOption: USER_ENTERED`
3. **Importe** — número sin `$` ni separadores de miles
4. **Columna B** — nunca escribir (fórmula automática)
5. **Columnas J, K, L** — nunca tocar
6. **Ancla de append** — `Egresos!A5` para buscar primera fila vacía

---

## 6. Fases de automatización

| Fase | Concepto/Detalle | Estado |
|------|-----------------|--------|
| Fase-int-01 | Monot+Impuestos (IB Mensual + Monotributo) | 📋 Definida |
| Fase-int-02+ | A definir en sesiones posteriores | — |

> Criterio de priorización: gastos con importe repetible mes a mes, sin dependencia de ajuste manual previo.
