# Guion de Grabación — Demo de Azure SRE Agent (Latam / Dashboard)

**Duración objetivo:** 10–12 minutos de video final
**Formato:** Grabación de pantalla + voz en off
**Audiencia:** Tomadores de decisión ejecutivos y de negocio (CIO, VP, líderes que no viven en la terminal)
**Idioma de narración:** Español neutro (Latam)

> **¿Cuál guion usar?**
> - **Este (dashboard)** → audiencia ejecutiva / negocio: más visual, cinemático, botones rojos y verdes en pantalla
> - `recording-script-latam.md` (PowerShell) → audiencia técnica: SREs, DevOps, quienes valoran ver el `az` CLI en acción
>
> Ambos guiones producen exactamente la misma investigación del agente y la misma narrativa. La única diferencia es **cómo se introduce y se resuelve la falla** — con botones en el navegador aquí, con PowerShell allá.

> **Leyenda**
> - 🎬 **CORTE** — punto natural para pausar/reanudar la grabación
> - 🖥️ **EN PANTALLA** — lo que ve el espectador
> - 🗣️ **NARRACIÓN** — lo que dices (palabra por palabra; adáptalo con naturalidad)
> - ⚡ **ACCIÓN** — clicks o comandos que ejecutas
> - 💡 **NOTA DEL PRESENTADOR** — coaching para ti, no va al aire
> - 🔒 **PRIVACIDAD** — pasos que evitan exponer secretos en el video

---

## 0. Preparación — hazlo 20 minutos antes de grabar

### 0.1 Telemetría fresca
Deja la app en estado limpio:

```powershell
cd C:\Projects\sre-agent-demo
.\scripts\toggle-failure.ps1 -FailureMode $false
.\scripts\toggle-failure.ps1 -DbTimeout $false
```

Espera ~2 minutos para que la app se estabilice.

### 0.2 🔒 Pre-cargar el admin token en el dashboard (CRÍTICO PARA PRIVACIDAD)

Este paso es la diferencia entre esta versión y la de PowerShell. El dashboard tiene un campo "Admin token" que persiste en `localStorage` del navegador. Lo pre-cargas **antes de grabar** para que durante la grabación **solo se vean los botones, nunca el token**.

**Pasos (todo esto ANTES de empezar a grabar):**

1. Obtén el token:
   ```powershell
   az webapp config appsettings list -g rg-sredemo-swe -n sredemo-mim-app --query "[?name=='ADMIN_TOKEN'].value" -o tsv
   ```

2. Abre `https://sredemo-mim-app.azurewebsites.net` en el navegador.

3. Baja hasta la sección **DEMO CONTROLS**.

4. Pega el token en el campo **"Paste ADMIN_TOKEN here"** y dale click a **Save**.

5. **Refresca la página (F5)** para verificar que el token quedó guardado — el badge debe indicarlo, o el botón de Save debe mostrar "Saved" o similar.

6. **Prueba un toggle** silencioso: click en "Enable Failure Mode" → verifica que las flags cambian → click en "Disable Failure Mode" → todo vuelve a verde.

7. Vuelve a refrescar (F5) para volver al estado limpio: **Healthy / Fast / FAILURE MODE: OFF / DB TIMEOUT: OFF**.

💡 Si en cualquier momento durante la grabación abres DevTools (F12), podría verse el token en `localStorage`. **NO abras DevTools mientras grabas.**

💡 Si tu grabación es **pública**, después de terminar rota el token:
   ```powershell
   $newToken = [guid]::NewGuid().ToString()
   az webapp config appsettings set -g rg-sredemo-swe -n sredemo-mim-app --settings "ADMIN_TOKEN=$newToken"
   ```

### 0.3 Pestañas del navegador — abrí en este orden

| # | URL / App | Uso |
|---|---|---|
| 1 | `https://sredemo-mim-app.azurewebsites.net` | Dashboard (baseline + toggle) — la protagonista visual |
| 2 | Azure Portal — SRE Agent chat (`sredemo-sre-agent`) | Chat del agente |
| 3 | Azure Portal — Application Insights `sredemo-mim-ai` | Referencia cruzada opcional |
| 4 | `https://github.com/mimasis_microsoft/sre-agent-demo` | Repo — para el click al link que cita el agente |

💡 **No necesitas pestaña de PowerShell** en esta versión. La demo es 100 % navegador.

💡 En la pestaña #2 del SRE Agent, abrí un **New Chat Thread** para empezar con historial limpio.

### 0.4 Entorno de grabación

- Cerrá Teams, Outlook, cualquier app con notificaciones
- Activá **No molestar** (Focus mode) en Windows
- Zoom del display: 125–150 % para legibilidad en 1080p
- Pantalla completa del navegador (F11)
- **NO abras DevTools durante la grabación** (revelaría el token)

### 0.5 Abrí el Plan B en un segundo monitor (opcional)

`C:\Projects\sre-agent-demo\docs\demo-backup-screenshots\` en otro monitor no compartido por si el agente da respuesta débil.

---

## 🎬 CORTE 1 — Apertura (0:00 – 0:30)

🖥️ **EN PANTALLA:** Pantalla completa del Portal de Azure en la pestaña #2 — la vista del SRE Agent con las cuatro tarjetas ✅ (Code, Logs, Azure resources, Knowledge files).

🗣️ **NARRACIÓN:**
> "Este es Azure SRE Agent. En los próximos diez minutos, les voy a mostrar cómo toma un incidente de producción desconocido, lo investiga de punta a punta, correlaciona configuración, código y telemetría, y escribe un post-mortem completo — sin que un humano escriba una sola consulta."

⚡ **ACCIÓN:** Pasá el mouse lento por las cuatro tarjetas ✅. No hagas click.

🗣️ **NARRACIÓN (continúa):**
> "El agente ya está conectado a una aplicación en vivo, su Application Insights, su workspace de Log Analytics, su repositorio de GitHub, y nuestra documentación operativa. Veamos qué pasa cuando algo se rompe."

🎬 **CORTE**

---

## 🎬 CORTE 2 — Baseline sano (0:30 – 1:15)

🖥️ **EN PANTALLA:** Cambiá a la pestaña #1 (dashboard de la app).

⚡ **ACCIÓN:** Refrescá la página. El dashboard debe mostrar:
- **SERVICE HEALTH: Healthy** (semáforo verde)
- **RESPONSE LATENCY: Fast**
- **ACTIVE FEATURE FLAGS: FAILURE MODE: OFF | DB TIMEOUT: OFF**

🗣️ **NARRACIÓN:**
> "Esta es nuestra aplicación — un API de checkout corriendo en Azure App Service en Sweden Central. Semáforo verde, respuestas sub-segundo, flags apagadas. Todo saludable."

⚡ **ACCIÓN:** Bajá lentamente hasta la sección **DEMO CONTROLS** para que se vean los botones. **No hagas click todavía.**

🗣️ **NARRACIÓN:**
> "Y acá abajo tenemos los controles de demostración — dos botones que simulan una configuración mala llegando a producción. Vamos a activar el primero."

🎬 **CORTE**

---

## 🎬 CORTE 3 — Introducir la falla (1:15 – 2:00)

🖥️ **EN PANTALLA:** Seguí en la pestaña #1, sección DEMO CONTROLS.

⚡ **ACCIÓN:** Mové el mouse despacio hacia el botón rojo **"Enable Failure Mode"**. Hacé click.

🗣️ **NARRACIÓN (mientras hacés click):**
> "Un click. Esto simula el tipo de cambio de configuración que un ingeniero apurado podría desplegar un viernes por la tarde. Un flag que hace que aproximadamente un tercio de las requests de producción fallen."

⚡ **ACCIÓN:** El dashboard va a actualizarse en unos segundos:
- **SERVICE HEALTH** cambia a rojo → **Degraded**
- **RESPONSE LATENCY** puede cambiar a **Slow** o **Degraded**
- **FAILURE MODE badge** cambia a rojo → **FAILURE MODE: ON**

Hacé pausa unos 3-5 segundos para que la audiencia procese el cambio visual.

🗣️ **NARRACIÓN:**
> "Y ahí lo tenemos. El semáforo se pone en rojo. El dashboard nos dice que *algo* está mal — pero no nos dice *qué*, ni *por qué*, ni *a quién* está afectando, ni *cómo* arreglarlo. Aquí es donde la mayoría de los equipos abren un call de incidente y empiezan a apagar incendios."

💡 **NOTA:** No abras Application Insights todavía. Todo el punto de la demo es que el agente hace la investigación. Aguantá las ganas.

🎬 **CORTE**

---

## 🎬 CORTE 4 — Prompt 1: Investigar (2:00 – 3:30)

🖥️ **EN PANTALLA:** Cambiá a la pestaña #2 (chat del SRE Agent).

⚡ **ACCIÓN:** Pegá el prompt (elegí uno):

**Inglés (respuestas más precisas):**
```
Investigate the spike in 500 errors in the last 10 minutes.
```

**Español (mejor UX Latam):**
```
Investiga el aumento de errores 500 en los últimos 10 minutos.
```

Enter. El agente tarda 30–90 segundos. No hables sobre el spinner — dejá que se vea trabajar.

🗣️ **NARRACIÓN (mientras piensa):**
> "Le estoy dando al agente una sola línea — la misma línea que un ingeniero de guardia agotado escribiría a las 2 de la mañana. Fíjense que no le digo qué herramientas usar, qué consultas correr, ni dónde buscar. El agente lo decide solo."

⚡ **ACCIÓN:** Cuando aparezca la respuesta, hacé scroll lento. Pausá en:
- El timeline exacto (`19:31 UTC → 19:34 UTC`)
- La métrica de 30/75 requests (40 % failure rate)
- La evidencia `SIM_FAILURE_001` y `active.flags=FAILURE_MODE`

🗣️ **NARRACIÓN:**
> "En menos de dos minutos, el agente ha: identificado el minuto exacto en que empezó el problema, cuantificado el impacto — 40 por ciento de tasa de falla, nombrado los tres endpoints afectados, citado las entradas de log exactas como evidencia, y — esto es importante — encontró un *segundo* bug, no relacionado, en el handler de orders que ni siquiera sabíamos que existía."

⚡ **ACCIÓN:** Click en el link a GitHub (`FailureModeMiddleware.cs#L27`) en la respuesta del agente. Se abre el repo en la línea exacta (pestaña #4).

🗣️ **NARRACIÓN (viendo el código):**
> "Cada afirmación del agente es trazable hasta una línea de código en su repo. Esto no es una alucinación — es evidencia forense."

⚡ **ACCIÓN:** Regresá a la pestaña #2 (agent chat).

🎬 **CORTE**

---

## 🎬 CORTE 5 — Prompt 2: Impacto en clientes (3:30 – 4:30)

⚡ **ACCIÓN:** Pegá:

**Inglés:**
```
What customers are impacted by the degradation?
```

**Español:**
```
¿Qué clientes están siendo afectados por la degradación?
```

🗣️ **NARRACIÓN (mientras piensa):**
> "La siguiente pregunta que sus ejecutivos van a hacer: ¿a quién le está pegando esto? Y aquí es donde uno se entera si puede confiar en el agente."

⚡ **ACCIÓN:** Resaltá la línea donde el agente dice que no puede identificar clientes.

🗣️ **NARRACIÓN:**
> "Miren esto. El agente se niega a adivinar. Nos dice exactamente qué campos de telemetría están vacíos — user ID, session ID, client IP — y sugiere cómo cerrar esa brecha de observabilidad para la próxima vez. Este es el comportamiento que uno quiere en una herramienta que el liderazgo va a confiar con incidentes reales. Es honesto sobre los límites de lo que los datos pueden probar."

🎬 **CORTE**

---

## 🎬 CORTE 6 — Prompt 3: Cambios recientes de código (4:30 – 5:30)

⚡ **ACCIÓN:** Pegá:

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

⚡ **ACCIÓN:** Cuando aparezca, hacé scroll a la conclusión: "No **recent deployed code change** correlates. What does correlate is a **configuration change**."

🗣️ **NARRACIÓN:**
> "Esta es una distinción que los SREs senior hacen y que la mayoría de las herramientas se equivocan. El agente inspeccionó el historial de deploys, mapeó el SHA del commit que está corriendo a su mensaje de commit real, y *descartó* un commit más nuevo en main porque no está desplegado. No está adivinando. Está razonando."

🎬 **CORTE**

---

## 🎬 CORTE 7 — Prompt 4: Causa raíz (5:30 – 6:15)

⚡ **ACCIÓN:** Pegá:

**Inglés:**
```
What is the most likely root cause?
```

**Español:**
```
¿Cuál es la causa raíz más probable?
```

⚡ **ACCIÓN:** Resaltá la primera oración decisiva.

🗣️ **NARRACIÓN:**
> "Una oración para la causa raíz. Tres piezas de evidencia. Separación limpia entre el problema primario y el bug secundario. Ese es el estándar que le exigimos a un incident commander. El agente lo cumplió."

🎬 **CORTE**

---

## 🎬 CORTE 8 — Prompt 5: Mitigación (6:15 – 7:15)

⚡ **ACCIÓN:** Pegá:

**Inglés:**
```
Recommend immediate mitigation and long-term remediation.
```

**Español:**
```
Recomienda mitigación inmediata y remediación de largo plazo.
```

⚡ **ACCIÓN:** Hacé scroll mostrando ambas secciones. Detente en la última línea: "If you want, I can patch the /orders bug now..."

🗣️ **NARRACIÓN:**
> "Dos niveles — qué hacer ahora, y qué hacer para que esto nunca vuelva a pasar. Fíjense en la lista de largo plazo: guardrails, TTL en el flag, alertas, tests de integración. Esto es lo que una organización de ingeniería madura pone en su tracker de acciones post-mortem. Y fíjense en la última línea — el agente está ofreciendo hacer el fix por sí mismo. Esta es la diferencia entre un asistente y un operador."

🎬 **CORTE**

---

## 🎬 CORTE 9 — Mitigar en vivo (7:15 – 8:00)

🖥️ **EN PANTALLA:** Cambiá a la pestaña #1 (dashboard de la app).

⚡ **ACCIÓN:** Bajá hasta DEMO CONTROLS. Mové el mouse despacio hacia el botón verde **"Disable Failure Mode"**. Click.

🗣️ **NARRACIÓN (mientras hacés click):**
> "Siguiendo la mitigación inmediata que recomendó el agente, desactivamos el flag. Un click."

⚡ **ACCIÓN:** Esperá que el dashboard se actualice:
- **SERVICE HEALTH** vuelve a verde → **Healthy**
- **RESPONSE LATENCY** vuelve a verde → **Fast**
- **FAILURE MODE badge** cambia a **FAILURE MODE: OFF**

🗣️ **NARRACIÓN:**
> "Servicio restaurado. Tiempo total del incidente al verde: menos de diez minutos, la mayor parte de los cuales fue el agente pensando, no humanos."

🎬 **CORTE**

---

## 🎬 CORTE 10 — Prompt 6: Post-mortem (8:00 – 10:30)

🖥️ **EN PANTALLA:** Cambiá a la pestaña #2 (SRE Agent).

⚡ **ACCIÓN:** Pegá:

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

⚡ **ACCIÓN:** Scroll lento de arriba a abajo, deteniéndote en cada sección: Executive Summary, Customer Impact, Timeline, Root Cause, Mitigation, What Went Well, What Went Poorly, Action Items.

🗣️ **NARRACIÓN (durante el scroll):**
> "Clasificación Sev 2. Resumen ejecutivo. Impacto en clientes — con una nota honesta sobre las brechas de telemetría. Timeline al segundo. Causa raíz con un link a la línea exacta de GitHub. Mitigación inmediata y de largo plazo. Qué salió bien, qué salió mal, lecciones aprendidas, action items. Este es un post-mortem de calidad producción escrito en menos de dos minutos, por una máquina que leyó su código, sus logs y sus runbooks."

⚡ **ACCIÓN:** Detené el scroll al llegar a "Action items". No hagas scroll más allá.

🎬 **CORTE**

---

## 🎬 CORTE 11 — Cierre (10:30 – 11:30)

🖥️ **EN PANTALLA:** Volvé a la vista Overview del SRE Agent (la del CORTE 1).

🗣️ **NARRACIÓN:**
> "Todo lo que vieron hoy corrió sobre una aplicación real de Azure en Sweden Central. El agente está conectado a Application Insights, Log Analytics, un grupo de recursos de Azure, un repositorio de GitHub, y ocho archivos de conocimiento. Todo el entorno cuesta menos de quince dólares al mes."
>
> "Para sus clientes, esto significa: incidentes resueltos más rápido, post-mortems que efectivamente se escriben, y un copiloto de SRE permanente que no duerme y que no se va de la empresa."
>
> "Ese es Azure SRE Agent. Hablemos de su entorno."

🎬 **CORTE** — fin de la grabación.

---

## Después de grabar

- [ ] Revisá el raw por titubeos, movimientos del cursor y pausas de carga del portal
- [ ] Cortá las pausas de "agent thinking" a ~5 segundos cada una
- [ ] Textos superpuestos / lower-thirds recomendados en:
  - CORTE 3 → "1 CLICK = FAILURE INJECTED IN PRODUCTION"
  - Prompt 1 → "40% failure rate"
  - Prompt 1 → click al link de GitHub
  - Prompt 3 → "Config change, not code change"
  - Prompt 6 → "Post-mortem written in < 2 minutes"
- [ ] Mantené el runtime total en 10 minutos o menos
- [ ] Tarjeta de título de 3 s al inicio + tarjeta de CTA de 3 s al final
- [ ] Exportá en 1080p60, H.264

## 🔒 Después de publicar (si es grabación pública)

Rotá el token porque ya lo pre-cargaste en el localStorage del navegador y podría haberse capturado accidentalmente:

```powershell
$newToken = [guid]::NewGuid().ToString()
az webapp config appsettings set -g rg-sredemo-swe -n sredemo-mim-app --settings "ADMIN_TOKEN=$newToken"
Write-Host "New ADMIN_TOKEN: $newToken"
```

Después, actualizá tu localStorage con el nuevo token (Save de nuevo desde el dashboard) para futuras demos.

---

## Plan B — si una toma sale mal

Igual que el otro guion. Podés regrabar cualquier CORTE por separado y splicear en edición. Si el agente da respuestas débiles varias tomas seguidas:

- Usá la captura verbatim en `docs/demo-backup-screenshots/prompt-N-*.md` como overlay
- Narrá sobre un frame estático usando la respuesta capturada
- Solo como último recurso — la investigación en vivo es el punto de la demo

---

## Diferencias clave con el guion PowerShell

Para tu referencia, si querés hacer híbrido:

| Elemento | Este guion (Dashboard) | Guion PowerShell |
|---|---|---|
| Introducir falla (CORTE 3) | Click botón rojo en navegador | `.\scripts\toggle-failure.ps1 -FailureMode $true` |
| Mitigar (CORTE 9) | Click botón verde en navegador | `.\scripts\toggle-failure.ps1 -FailureMode $false` |
| Pestañas de navegador | 4 (sin terminal) | 5 (incluye terminal) |
| Vibra | "Ejecutivo, cinemático" | "Técnico, práctico" |
| Riesgo de exponer token | Alto si no pre-cargás fuera de cámara | Nulo — token nunca se ve |
| Best for | CIO, VP, directores | SREs, DevOps, ingenieros |
