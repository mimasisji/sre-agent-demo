# Demo del jueves 12 de noviembre de 2026 - solo navegador

Este es el guion vigente. Sustituye los guiones anteriores basados en el chat del
Azure Portal, prompts relativos como "ultimos 10 minutos" y trafico desde PowerShell.

## Dos pestanas para presentar

1. [Consola del presentador](https://sredemo-mim-app.azurewebsites.net/demo.html).
2. [Azure SRE Agent](https://sre.azure.com/agents/subscriptions/8e6e91bf-61fa-4262-b049-3f28f5aee367/resourceGroups/rg-sredemo-swe/providers/Microsoft.App/agents/sredemo-sre-agent).

Abre tambien el chat del ensayo del 10 de noviembre como respaldo, sin sustituirlo
por respuestas inventadas. La consola incluye el guion corto y genera los cuatro
mensajes para copiar. No necesita instalar nada ni mantener este equipo encendido.
La aplicacion y el agente deben permanecer desplegados en Azure.

El [dashboard para mostrar al cliente](https://sredemo-mim-app.azurewebsites.net/)
no contiene un enlace a la consola del presentador. Abre la consola solo mediante
su enlace directo y mantenla fuera de la vista del cliente cuando muestres el dashboard.
Los mensajes A y B se generan al completar la prueba del boton 1; C y D se generan
al completar la prueba del boton 2. No requieren que alguien los coloque manualmente.

## Notas de narracion en la consola

La consola incluye notas junto a la apertura, el incidente, la mitigacion, cada
mensaje A-D, el cierre y el plan B. Cada nota indica que mostrar, un texto para
decir en voz alta y cuando avanzar. Son apoyo del presentador: no se copian al
chat y no se agregan al dashboard del cliente. Mantener la consola fuera de la
pantalla compartida; mostrar al cliente el dashboard y el chat.

Los textos no precargan conclusiones ni cifras del ensayo. Leer solo los resultados
que el agente confirme en la ejecucion actual. Los botones, los mensajes para
copiar y el orden del recorrido no cambian.

## Preparacion antes de compartir pantalla (10-15 minutos)

1. Entra en `sre.azure.com` con el tenant que tiene acceso a la suscripcion de la
   demo. El agente ya no se opera desde Azure Portal.
2. Abre un chat nuevo. No borres el chat del ensayo.
3. En **Build + setup**, comprueba:
   - **Extensions > Connectors**: Application Insights y Log Analytics, Connected.
   - **Context > Code access**: repositorio conectado.
   - **Context > Knowledge sources**: ocho documentos, Indexed.
   - **Context > Managed resources**: `rg-sredemo-swe`, Sweden Central.
4. Carga el ADMIN_TOKEN en la consola del presentador, antes de compartir:
   - Si no tienes el token disponible, abre el App Service `sredemo-mim-app` en
     Azure Portal, **Settings > Environment variables > App settings**.
   - Revela y copia solo `ADMIN_TOKEN`; no lo pegues en el chat ni lo grabes.
   - Pegalo en el campo password de la consola y pulsa **Guardar token**.
   - El valor se borra del campo y queda solo en memoria de esa pestana.
   - Recargar o cerrar exige volver a cargar el token. NO se almacena en
     localStorage, sessionStorage, URLs ni mensajes.
5. Si alguna flag aparece ON, pulsa **Apagar ambas fallas sin prueba** y verifica
   ambas OFF. No uses DB TIMEOUT en este recorrido.
6. Desactiva notificaciones. Comprueba zoom y legibilidad. Evita DevTools y la
   pantalla de configuracion de Azure mientras compartes.

Los toggles de navegador cambian el estado en memoria de la API. Los App Settings
persistentes deben permanecer `ENABLE_FAILURE_MODE=false` y `ENABLE_DB_TIMEOUT=false`.
No se requiere desplegar ni reiniciar la app durante la presentacion.

## Recorrido (objetivo 10-15 minutos, sujeto a tiempos del agente e ingesta)

### 1. Apertura

> "El agente tiene acceso a telemetria, codigo y documentacion. Hoy investigaremos
> una falla controlada, no un incidente de clientes reales."

Muestra ambas flags OFF. Explica que `/health` no comprueba el checkout.

### 2. Activar y producir evidencia

Pulsa **1. Activar falla y generar 60 solicitudes** una sola vez. La consola
activa FailureMode y ejecuta 20 solicitudes a cada ruta: `/products`, `/orders`,
`/checkout`, con un maximo de seis solicitudes simultaneas. Muestra los resultados
del navegador, separados de la futura verificacion en Log Analytics.

El 30 % es una probabilidad programada, no una tasa garantizada para cada muestra.
Las respuestas fallidas tardan 3-8 segundos. Se esperan HTTP 200 y HTTP 500;
timeouts, 403, 429 y otros errores se marcan como inesperados y bloquean los
mensajes de una prueba valida. Si no se observa ningun 500, revisa antes de repetir.

Cada muestra lleva un `demoRun` aleatorio en la URL. La consola genera intervalos
UTC fijos que incluyen el toggle y la prueba: no hace falta escribir fechas.

### 3. Investigar

Copia **A. Investigar** al chat nuevo del agente. Espera la respuesta.

El mensaje apunta directamente al workspace correcto y a `AppRequests`,
`AppExceptions`, `AppTraces`. Evita el error de consultar las tablas workspace
en el ambito del componente Application Insights. No requiere listar app settings
ni ampliar permisos.

> "El agente cuantifica el impacto y vincula las solicitudes fallidas con sus
> excepciones. Cada conclusion debe tener evidencia."

Espera 2-5 minutos si aun no se ingieren los datos. No cambies a ventanas relativas
ni anuncies conteos antes de consultarlos. Las solicitudes `/health` no forman
parte del denominador de las muestras de negocio filtradas por `demoRun`.

### 4. Correlacionar causa y codigo

Copia **B. Correlacionar causa** al mismo chat.

> "Ahora contrasta lo observado con el codigo y los runbooks. No suponemos que
> hubo un despliegue: buscamos evidencia del cambio que realmente ocurrio."

Muestra las citas del middleware y la traza de activacion.
No afirmes que hay clientes afectados ni una regresion de despliegue sin evidencia.
La documentacion indexada describe patrones; no demuestra que sus incidentes
historicos hayan ocurrido en la ventana actual.

### 5. Mitigar y probar

Vuelve a la consola y pulsa **2. Recuperar y probar 60 solicitudes**.
Apaga ambas flags y ejecuta otras 20 solicitudes por endpoint.

> "Un operador aplica la mitigacion. El agente no ha realizado cambios."

La consola exige **60/60 HTTP 200** para habilitar el mensaje de recuperacion.
Una prueba fallida no se presenta como exito. Las compras de prueba son datos
sinteticos, no clientes reales.

### 6. Verificar y cerrar

Copia **C. Verificar recuperacion** y espera la confirmacion en telemetria.
Despues copia **D. Informe post-incidente**.

> "El agente correlaciono telemetria, codigo y documentacion. Un operador aplico
> la mitigacion y el agente verifico la recuperacion con evidencia."

La muestra de 60 solicitudes NO es observacion sostenida. No anuncies MTTR,
porcentajes, severidades, costos ni ahorros que la evidencia no justifique.

## Plan B

| Problema | Accion |
|---|---|
| Solicitud de Grant permissions | Cancelar. Reusar el mensaje A con el workspace; no ampliar permisos para salvar el guion. |
| Telemetria incompleta | Esperar ingesta y pedir reconsulta del mismo intervalo y demoRun. |
| GitHub no responde | Declarar que falta correlacionar el codigo. Mostrar evidencia del ensayo, claramente identificada. |
| Token invalido | Volver a cargarlo antes de compartir pantalla; no mostrarlo ni enviarlo al agente. |
| Se cerro/recargo la consola | Volver a cargar el token. Los resultados sin secretos se conservan solo en la misma pestana con sessionStorage; comprobar siempre las flags actuales. |
| Hay que detener la prueba | Pulsar **Apagar ambas fallas sin prueba**. Cancela el trafico pendiente y verifica ambas flags OFF. No equivale a verificar compras. |
| Agente lento/no disponible | Recuperar primero. Mostrar el chat del ensayo del 10 de noviembre y aclarar que no es una investigacion nueva. |
| App devuelve 403/no responde | No iniciar. Revisar acceso publico, estado de App Service y cuota F1 antes de la sesion. |

Cerrar la pagina NO desactiva la falla. El aviso del navegador es solo una ayuda,
no una garantia. Al terminar comprueba flags OFF y conserva el chat con la evidencia.
No hagas teardown antes de la demo: eliminaria la telemetria.

La consola tambien incluye un resumen expandible del ensayo como respaldo sin
depender del chat. Esta identificado expresamente como evidencia anterior, no en vivo.

## Evidencia del ensayo del 10 de noviembre

- Incidente: 60 solicitudes de negocio, 12 HTTP 500 (20 %).
- Recuperacion: 60 solicitudes, 0 HTTP 500.
- Latencia media del conjunto: 1.333,0 a 143,2 ms.
- Causa correlacionada: activacion de FailureMode; SIM_FAILURE_001.
- El agente verifico los datos en el workspace y consulto el codigo y los documentos.
- No se identificaron clientes reales afectados ni un despliegue causante.

Estos numeros son SOLO del ensayo; no estan precargados como resultados de una
presentacion nueva. La consola mide una muestra nueva en cada ejecucion.

## Validacion de la consola desplegada (10 de noviembre)

Probada contra la app real desde el navegador, sin PowerShell para operar los botones:

| Muestra | Intervalo UTC | Solicitudes | HTTP 500 |
|---|---|---|---|
| Incidente | 17:23:38-17:24:00 | 60 | 15 |
| Recuperacion | 17:24:00-17:24:05 | 60 | 0 |

Log Analytics confirmo ambos conteos, con `ItemCount=1` en estas muestras.
Identificadores: incidente `d0015ca8-f4a8-4bf5-8dec-e4e420b10e51`;
recuperacion `66baed06-909b-454f-bcf4-b75d3fc54e14`.
La API conservo la revision `8514344`. El despliegue agrego solo archivos estaticos;
no cambio la API, RBAC ni habilito credenciales basicas de publicacion.
Las dos flags quedaron OFF. Estos resultados tampoco deben presentarse como una
prueba nueva el jueves.

## Mantenimiento y validacion

- La consola es estatica: [demo.html](../src/SreAgentDemo.Api/wwwroot/demo.html)
  y [demo.mjs](../src/SreAgentDemo.Api/wwwroot/demo.mjs). No cambia la API ni RBAC.
- Las pruebas de trafico y mensajes se ejecutan sin dependencias nuevas:
  `node --test src\SreAgentDemo.Tests\demo.test.mjs`.
- El repositorio configurado en el agente durante el ensayo fue
  `mimasisji/sre-agent-demo`; contiene la revision de API `8514344`.
  El checkout de trabajo usa `mimasis_microsoft/sre-agent-demo`.
  No cambiar la conexion durante la demo sin validar antes el codigo.
- El plan F1 tiene cuota diaria y no dispone de Always On. Evita pruebas de carga
  continuas; cada boton ejecuta un lote acotado y no deja generadores locales.
