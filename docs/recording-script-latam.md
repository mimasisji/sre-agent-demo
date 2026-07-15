# Guion de Grabación — Demo de Azure SRE Agent (Latam / PowerShell)

**Duración objetivo:** 10–12 minutos de video final
**Formato:** Grabación de pantalla + voz en off
**Audiencia:** Tomadores de decisión técnicos (SREs, DevOps, arquitectos, líderes de plataforma)
**Idioma de narración:** Español neutro (Latam)

> **¿Cuál guion usar?**
> - **Este (PowerShell)** → audiencia técnica: SREs, DevOps, quienes valoran ver el `az` CLI y scripts en acción
> - `recording-script-latam-dashboard.md` (Dashboard) → audiencia ejecutiva / negocio: más visual, cinemático, botones en pantalla
>
> Ambos guiones producen exactamente la misma investigación del agente y la misma narrativa. La única diferencia es **cómo se introduce y se resuelve la falla** — con PowerShell aquí, con botones en el navegador allá.

> **Sobre los prompts al agente:**
> El agente Azure SRE Agent puede responder en español si le hablas en español. Sin embargo, sus respuestas están indexadas con archivos de conocimiento en inglés (los `.md` que subiste), por lo que las respuestas en inglés tienden a ser **más precisas y con mejores citas al código**.
>
> **Recomendación:** ensaya ambas versiones y elige. Este guion incluye los prompts en **ambos idiomas** — decide antes de grabar cuál prefieres.

> **Leyenda**
> - 🎬 **CORTE** — punto natural para pausar/reanudar la grabación
> - 🖥️ **EN PANTALLA** — lo que ve el espectador
> - 🗣️ **NARRACIÓN** — lo que dices (palabra por palabra; adáptalo con naturalidad)
> - ⚡ **ACCIÓN** — clicks o comandos que ejecutas
> - 💡 **NOTA DEL PRESENTADOR** — coaching para ti, no va al aire

---

## 0. Preparación — hazlo 15 minutos antes de grabar

### 0.1 Telemetría fresca
Deja la app en estado limpio para que la falla se introduzca en vivo:

```powershell
cd C:\Projects\sre-agent-demo
.\scripts\toggle-failure.ps1 -FailureMode $false
.\scripts\toggle-failure.ps1 -DbTimeout $false
```

Espera ~2 minutos para que la app se estabilice antes de grabar.

💡 **NO** ejecutes `seed-telemetry.ps1` justo antes de grabar. Necesitas un baseline limpio.

### 0.2 Pestañas del navegador — ábrelas en este orden

| # | URL | Uso |
|---|---|---|
| 1 | `https://sredemo-mim-app.azurewebsites.net` | Vista de la app (traffic light) |
| 2 | Azure Portal — SRE Agent chat | Superficie principal de la demo |
| 3 | Azure Portal — Application Insights `sredemo-mim-ai` (Failures) | Referencia cruzada |
| 4 | `https://github.com/mimasis_microsoft/sre-agent-demo` | Repo, para cuando el agente cite código |
| 5 | Windows Terminal / PowerShell en `C:\Projects\sre-agent-demo` | Para el toggle en vivo |

💡 En la pestaña #2 del SRE Agent, abre un **New Chat Thread** para empezar con historial limpio.

### 0.3 Entorno de grabación

- Cierra Teams, Outlook, cualquier app con notificaciones
- Activa **No molestar** (Focus mode) en Windows
- Sube el zoom del display a 125–150 % para legibilidad en 1080p
- Pantalla completa del navegador (F11)

### 0.4 Copia el admin token al portapapeles

```powershell
az webapp config appsettings list -g rg-sredemo-swe -n sredemo-mim-app --query "[?name=='ADMIN_TOKEN'].value" -o tsv | Set-Clipboard
```

### 0.5 Abre el Plan B en un segundo monitor

Ten `C:\Projects\sre-agent-demo\docs\demo-backup-screenshots\` abierto en otro monitor (no compartido en la grabación) por si el agente da una respuesta débil.

---

## 🎬 CORTE 1 — Apertura (0:00 – 0:30)

🖥️ **EN PANTALLA:** Pantalla completa del Portal de Azure en la pestaña #2 — la vista del SRE Agent con las cuatro tarjetas ✅ (Code, Logs, Azure resources, Knowledge files).

🗣️ **NARRACIÓN:**
> "Este es Azure SRE Agent. En los próximos diez minutos, les voy a mostrar cómo toma un incidente de producción desconocido, lo investiga de punta a punta, correlaciona configuración, código y telemetría, y escribe un post-mortem completo — sin que un humano escriba una sola consulta."

⚡ **ACCIÓN:** Pasa el mouse lento por las cuatro tarjetas ✅. No hagas click.

🗣️ **NARRACIÓN (continúa):**
> "El agente ya está conectado a una aplicación en vivo, su Application Insights, su workspace de Log Analytics, su repositorio de GitHub, y nuestra documentación operativa. Veamos qué pasa cuando algo se rompe."

🎬 **CORTE**

---

## 🎬 CORTE 2 — Baseline sano (0:30 – 1:15)

🖥️ **EN PANTALLA:** Cambia a la pestaña #1 (la URL de la app).

⚡ **ACCIÓN:** Refresca la página. El dashboard debe mostrar semáforo verde, latencia "fast", flags OFF.

🗣️ **NARRACIÓN:**
> "Esta es nuestra aplicación — un API de checkout corriendo en Azure App Service en Sweden Central. Semáforo verde, respuestas sub-segundo, flags apagadas. Todo saludable."

⚡ **ACCIÓN:** Abre `https://sredemo-mim-app.azurewebsites.net/health` en una pestaña temporal para que se vea el JSON con `"status":"healthy"`. Ciérrala y regresa al dashboard.

🗣️ **NARRACIÓN:**
> "Ahora, simulemos lo que pasa en el mundo real. Un cambio de configuración malo está a punto de llegar a producción."

🎬 **CORTE**

---

## 🎬 CORTE 3 — Introducir la falla (1:15 – 2:00)

🖥️ **EN PANTALLA:** Cambia a la pestaña #5 (PowerShell).

⚡ **ACCIÓN:** Escribe despacio, para que se lea:

```powershell
.\scripts\toggle-failure.ps1 -FailureMode $true
```

Enter.

🗣️ **NARRACIÓN (mientras corre):**
> "Estoy activando un feature flag que hace que aproximadamente un tercio de las requests de producción fallen — el tipo de cambio que un ingeniero apurado podría desplegar un viernes por la tarde."

⚡ **ACCIÓN:** Cuando aparezca `failureMode : True`, cambia a la pestaña #1 (app) y refresca varias veces. Algunas requests devolverán 500. El semáforo pasa a rojo.

🗣️ **NARRACIÓN:**
> "Y ahí está. El semáforo se pone en rojo. Pero el dashboard solo nos dice que *algo* está mal. No nos dice *qué*, ni *por qué*, ni *a quién* afecta, ni *cómo arreglarlo*. Aquí es donde la mayoría de los equipos abren un puente de guerra y empiezan a apagar incendios."

💡 **NOTA:** No abras App Insights todavía. Todo el punto de la demo es que el agente hace la investigación. Aguanta las ganas.

🎬 **CORTE**

---

## 🎬 CORTE 4 — Prompt 1: Investigar (2:00 – 3:30)

🖥️ **EN PANTALLA:** Cambia a la pestaña #2 (chat del SRE Agent).

⚡ **ACCIÓN:** Pega el prompt (elige uno de los dos):

**Versión inglés (respuesta más precisa, ya validada):**
```
Investigate the spike in 500 errors in the last 10 minutes.
```

**Versión español (mejor para la audiencia, prueba en ensayo):**
```
Investiga el aumento de errores 500 en los últimos 10 minutos.
```

Enter. El agente tarda 30–90 segundos. No hables sobre el indicador de "pensando" — deja que el espectador lo vea trabajar.

🗣️ **NARRACIÓN (mientras piensa):**
> "Le estoy dando al agente una sola línea — la misma línea que un ingeniero de guardia agotado escribiría a las 2 de la mañana. Fíjense que no le digo qué herramientas usar, qué consultas correr, ni dónde buscar. El agente lo decide solo."

⚡ **ACCIÓN:** Cuando aparezca la respuesta, haz scroll lento para que se lean las partes clave. Detente en el timeline (`19:31 UTC → 19:34 UTC`), los 30/75 requests, y la evidencia `SIM_FAILURE_001`.

🗣️ **NARRACIÓN:**
> "En menos de dos minutos, el agente ha: identificado el minuto exacto en que empezó el problema, cuantificado el impacto — 40 por ciento de tasa de falla, nombrado los tres endpoints afectados, citado las entradas de log exactas como evidencia, y — esto es importante — encontró un *segundo* bug, no relacionado, en el handler de orders que ni siquiera sabíamos que existía."

⚡ **ACCIÓN:** Click en el link a GitHub (`FailureModeMiddleware.cs#L27`) en la respuesta del agente. Se abre el repo en la línea exacta.

🗣️ **NARRACIÓN (viendo el código):**
> "Cada afirmación del agente es trazable hasta una línea de código en su repo. Esto no es una alucinación — es evidencia forense."

⚡ **ACCIÓN:** Regresa a la pestaña #2.

🎬 **CORTE**

---

## 🎬 CORTE 5 — Prompt 2: Impacto en clientes (3:30 – 4:30)

⚡ **ACCIÓN:** Pega:

**Inglés:**
```
What customers are impacted by the degradation?
```

**Español:**
```
¿Qué clientes están siendo afectados por la degradación?
```

Enter, espera la respuesta.

🗣️ **NARRACIÓN (mientras piensa):**
> "La siguiente pregunta que sus ejecutivos van a hacer: ¿a quién le está pegando esto? Y aquí es donde uno se entera si puede confiar en el agente."

⚡ **ACCIÓN:** Cuando aparezca, resalta la línea: "I can't identify named customers from the current telemetry" (o la equivalente en español).

🗣️ **NARRACIÓN:**
> "Miren esto. El agente se niega a adivinar. Nos dice exactamente qué campos de telemetría están vacíos — user ID, session ID, client IP — y sugiere cómo cerrar esa brecha de observabilidad para la próxima vez. Este es el comportamiento que uno quiere en una herramienta que el liderazgo va a confiar con incidentes reales. Es honesto sobre los límites de lo que los datos pueden probar."

🎬 **CORTE**

---

## 🎬 CORTE 6 — Prompt 3: Cambios recientes de código (4:30 – 5:30)

⚡ **ACCIÓN:** Pega:

**Inglés:**
```
Were there any recent code changes that correlate with this incident?
```

**Español:**
```
¿Hubo cambios recientes de código que se correlacionen con este incidente?
```

🗣️ **NARRACIÓN (mientras piensa):**
> "El noventa por ciento de los incidentes de producción vienen de un deploy reciente. ¿O no? Veamos."

⚡ **ACCIÓN:** Cuando aparezca la respuesta, haz scroll a la oración: "No **recent deployed code change** correlates with the spike. What does correlate is a **configuration change**, not a code rollout."

🗣️ **NARRACIÓN:**
> "Esta es una distinción que los SREs senior hacen y que la mayoría de las herramientas se equivocan. El agente inspeccionó el historial de deploys, mapeó el SHA del commit que está corriendo a su mensaje de commit real, y *descartó* un commit más nuevo en main porque no está desplegado. No está adivinando. Está razonando."

🎬 **CORTE**

---

## 🎬 CORTE 7 — Prompt 4: Causa raíz (5:30 – 6:15)

⚡ **ACCIÓN:** Pega:

**Inglés:**
```
What is the most likely root cause?
```

**Español:**
```
¿Cuál es la causa raíz más probable?
```

⚡ **ACCIÓN:** Cuando aparezca, resalta la primera oración decisiva.

🗣️ **NARRACIÓN:**
> "Una oración para la causa raíz. Tres piezas de evidencia. Separación limpia entre el problema primario y el bug secundario. Ese es el estándar que le exigimos a un incident commander. El agente lo cumplió."

🎬 **CORTE**

---

## 🎬 CORTE 8 — Prompt 5: Mitigación (6:15 – 7:15)

⚡ **ACCIÓN:** Pega:

**Inglés:**
```
Recommend immediate mitigation and long-term remediation.
```

**Español:**
```
Recomienda mitigación inmediata y remediación de largo plazo.
```

⚡ **ACCIÓN:** Cuando aparezca, haz scroll mostrando ambas secciones. Detente en la última línea: "If you want, I can patch the /orders bug now..."

🗣️ **NARRACIÓN:**
> "Dos niveles — qué hacer ahora, y qué hacer para que esto nunca vuelva a pasar. Fíjense en la lista de largo plazo: guardrails, TTL en el flag, alertas, tests de integración. Esto es lo que una organización de ingeniería madura pone en su tracker de acciones post-mortem. Y fíjense en la última línea — el agente está ofreciendo hacer el fix por sí mismo. Esta es la diferencia entre un asistente y un operador."

🎬 **CORTE**

---

## 🎬 CORTE 9 — Mitigar en vivo (7:15 – 8:00)

🖥️ **EN PANTALLA:** Cambia a la pestaña #5 (PowerShell).

⚡ **ACCIÓN:** Escribe despacio:

```powershell
.\scripts\toggle-failure.ps1 -FailureMode $false
```

Enter.

🗣️ **NARRACIÓN:**
> "Siguiendo la mitigación inmediata del agente, desactivamos el flag. Una línea."

⚡ **ACCIÓN:** Cambia a la pestaña #1, refresca varias veces. El semáforo vuelve a verde.

🗣️ **NARRACIÓN:**
> "Servicio restaurado. Tiempo total del incidente al verde: menos de diez minutos, la mayor parte de los cuales fue el agente pensando, no humanos."

🎬 **CORTE**

---

## 🎬 CORTE 10 — Prompt 6: Post-mortem (8:00 – 10:30)

🖥️ **EN PANTALLA:** Cambia a la pestaña #2 (SRE Agent).

⚡ **ACCIÓN:** Pega:

**Inglés:**
```
Generate a complete post-incident report.
```

**Español:**
```
Genera un reporte post-mortem completo.
```

Enter. Este es el más largo — hasta 2 minutos.

🗣️ **NARRACIÓN (mientras piensa):**
> "Lo último que todo equipo odia de los incidentes es escribir el post-mortem. Toma horas, a veces días, y nunca sale tan rápido como el liderazgo quisiera. Miren esto."

⚡ **ACCIÓN:** Cuando renderice, haz scroll lento de arriba a abajo, deteniéndote brevemente en cada sección: Executive Summary, Customer Impact, Timeline, Root Cause, Mitigation, What Went Well, What Went Poorly, Action Items.

🗣️ **NARRACIÓN (durante el scroll):**
> "Clasificación Sev 2. Resumen ejecutivo. Impacto en clientes — con una nota honesta sobre las brechas de telemetría. Timeline al segundo. Causa raíz con un link a la línea exacta de GitHub. Mitigación inmediata y de largo plazo. Qué salió bien, qué salió mal, lecciones aprendidas, action items. Este es un post-mortem de calidad producción escrito en menos de dos minutos, por una máquina que leyó su código, sus logs y sus runbooks."

⚡ **ACCIÓN:** Detén el scroll al llegar a "Action items". No hagas scroll más allá.

🎬 **CORTE**

---

## 🎬 CORTE 11 — Cierre (10:30 – 11:30)

🖥️ **EN PANTALLA:** Regresa a la vista Overview del SRE Agent (la del CORTE 1).

🗣️ **NARRACIÓN:**
> "Todo lo que vieron hoy corrió sobre una aplicación real de Azure en Sweden Central. El agente está conectado a Application Insights, Log Analytics, un grupo de recursos de Azure, un repositorio de GitHub, y ocho archivos de conocimiento. Todo el entorno cuesta menos de quince dólares al mes."
>
> "Para sus clientes, esto significa: incidentes resueltos más rápido, post-mortems que efectivamente se escriben, y un copiloto de SRE permanente que no duerme y que no se va de la empresa."
>
> "Ese es Azure SRE Agent. Hablemos de su entorno."

🎬 **CORTE** — fin de la grabación.

---

## Después de grabar

- [ ] Revisa el raw por titubeos, movimientos del cursor y pausas de carga del portal
- [ ] Corta las pausas de "agent thinking" a ~5 segundos cada una
- [ ] Agrega textos superpuestos / lower-thirds en:
  - Prompt 1 → el número "40% de tasa de falla"
  - Prompt 1 → el click al link de GitHub
  - Prompt 3 → la frase "no es un cambio de código, es un cambio de configuración"
  - Prompt 6 → la afirmación "escrito en menos de 2 minutos"
- [ ] Mantén el runtime total en 10 minutos o menos
- [ ] Agrega tarjeta de título de 3 segundos al inicio y tarjeta de CTA de 3 segundos al final
- [ ] Exporta en 1080p60, H.264, y revísalo antes de publicar

---

## Plan B — si una toma sale mal

Como esto es una grabación, puedes regrabar cualquier CORTE por separado. Si un prompt devuelve una respuesta más débil que en el ensayo:

1. Detén la grabación de ese segmento
2. Abre un nuevo chat thread en el agente
3. Vuelve a correr el prompt
4. Splicea el nuevo segmento en la edición

Si el agente da respuestas materialmente peores en un prompt específico en varias tomas:
- Usa la captura verbatim en `docs/demo-backup-screenshots/prompt-N-*.md` como overlay visible en el editor
- Narra sobre un frame estático usando la respuesta capturada
- Solo hazlo como último recurso — la investigación en vivo es el punto de la demo

---

## Adaptaciones opcionales para Latam

Si quieres darle más cercanía al público Latam durante la narración:

- Reemplaza "puente de guerra" (más argentino/formal) por "call de incidente" o "call de guerra" según región
- Ajusta "flag" a "bandera de feature" solo si tu audiencia es menos técnica; si es SRE/DevOps, "flag" está aceptado
- Al mencionar el costo mensual, considera convertir "quince dólares" a la moneda local si tu audiencia es de un país específico (ej: "menos de veinte mil pesos mexicanos al mes")
- Si tu audiencia es Costa Rica / Centroamérica y tú eres tica, considera decir "flag" y "post-mortem" en inglés — así suena natural para tu voz sin forzar traducciones incómodas
