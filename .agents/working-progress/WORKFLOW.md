# Workflow de trabajo — Resumen operativo

Directorio base: leer `WORKFLOW_DIR` en `.env` (default: `.agents/working-progress`)

Nomenclatura de sesiones: `init` · `feat-[nombre]` · `feat-[nombre]-[issue]` · `fix-[nombre]` · `refactor-[nombre]`

Archivos estándar por sesión: `prompt.md` (objetivo) · `research.md` (si aplica) · `plan.md` (fases + TODO checklist) · `fase-N-plan.md` (detalle de cada fase) · `roadmap.md` (ideas futuras)

Al iniciar sesión nueva: `/ns` — crea el subdirectorio y abre `prompt.md`.
Al retomar sesión existente: leer `prompt.md` y el `plan.md` vigente para obtener contexto.
Actualizar TODOs: editar directamente el archivo de plan activo marcando `[x]`.
No incluir credenciales, tokens ni datos sensibles en ningún documento de trabajo.

---

# Guía completa

## Propósito

Sistema de trabajo estructurado para proyectos de software desarrollados en conjunto con Claude Code CLI. Permite mantener contexto entre sesiones, registrar decisiones, y progresar de forma ordenada a través de fases de investigación, planificación e implementación.

## Estructura de directorios

```
{WORKFLOW_DIR}/                        ← directorio base (de .env)
├── WORKFLOW.md                        ← esta guía
├── init/                              ← sesión inicial del proyecto
│   ├── prompt.md                      ← objetivo e instrucciones iniciales
│   ├── research.md                    ← investigación y hallazgos
│   ├── plan.md                        ← plan general por fases
│   ├── roadmap.md                     ← ideas y opciones futuras
│   └── fase-N-plan.md                 ← detalle de cada fase
├── feat-[nombre]/                     ← sesión de feature
│   ├── prompt.md
│   └── plan.md
└── fix-[nombre]/                      ← sesión de bug fix
    └── prompt.md
```

## Ciclo de vida de una sesión

### Primera vez en el proyecto
1. Ejecutar `/init-workflow` — crea estructura base, `.env`, y `CLAUDE.md` local mínimo
2. Completar `init/prompt.md` con el objetivo del proyecto
3. Claude lee el prompt y comienza investigación → genera `research.md`
4. De la investigación emerge el `plan.md` con fases y TODO checklist
5. Cada fase tiene su `fase-N-plan.md` con TODO detallado, notas de implementación, decisiones y referencias

### Sesiones posteriores (features, fixes, etc.)
1. Renombrar la sesión: `/rename feat-[nombre]` o `/rename fix-[nombre]`
2. Ejecutar `/ns` — crea `{WORKFLOW_DIR}/feat-[nombre]/prompt.md` y lo abre
3. Completar el prompt o dictar el objetivo directamente en el chat
4. Claude lee el contexto existente del proyecto y trabaja sobre él

### Retomar sesión existente
- Abrir Claude Code con `-c` (continuar sesión) o `-r [nombre]` (resumir por nombre)
- Si es sesión nueva pero el trabajo ya empezó: mencionar el directorio de sesión — Claude lee los archivos existentes

## Documentos estándar

### `prompt.md`
Punto de entrada de cada sesión. Secciones: **Idea/Objetivo** · **Contexto** · **Referencias** · **Restricciones**. Puede completarse antes de hablar con Claude o dictarse directamente en el chat.

### `research.md`
Generado durante la fase de investigación. Contiene hallazgos, casos similares, opciones evaluadas, comparaciones y fuentes. Las decisiones tomadas se consolidan en `plan.md`; las ideas descartadas van a `roadmap.md`.

### `plan.md`
Plan general del proyecto con:
- TODO checklist de fases (`- [ ] Fase N — descripción → [fase-N-plan.md]`)
- Tabla de decisiones arquitecturales tomadas
- Referencias al `research.md` y `roadmap.md`

### `fase-N-plan.md`
Un archivo por fase. Contiene:
- **TODO checklist** detallado de la fase
- **Notas de implementación** (se agregan durante la ejecución)
- **Decisiones tomadas** (registro del por qué de cada decisión)
- **Referencias** (URLs, archivos clave, issues vinculados)

### `roadmap.md`
Ideas futuras, opciones descartadas para la versión actual con justificación, y funcionalidades planificadas. No es un plan de acción — es un registro de posibilidades.

## Convenciones

- Todos los documentos son Markdown
- Los TODOs usan `- [ ]` (pendiente) y `- [x]` (completado)
- Los archivos entre sesiones distintas pueden enlazarse con rutas relativas dentro de `{WORKFLOW_DIR}/`
- El `CLAUDE.md` local del proyecto es mínimo — solo referencia este `WORKFLOW.md`
- Las credenciales y datos sensibles van en `.env` (no trackeado por git), nunca en documentos de trabajo

## Configuración por proyecto

El archivo `.env` en la raíz del proyecto puede sobrescribir el directorio base:
```
WORKFLOW_DIR=.agents/working-progress   # valor por defecto
```

Para proyectos con estructura diferente, cambiar el valor en `.env`. El `.env` no debe ser commiteado — verificar que `.gitignore` lo incluya.
