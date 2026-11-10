const endpoints = ['/products', '/orders', '/checkout'];
const context = 'workspace Log Analytics sredemo-mim-law, grupo rg-sredemo-swe, suscripcion 8e6e91bf-61fa-4262-b049-3f28f5aee367, workspace ID 2e737e8a-b75f-49e1-86e4-e3f8a67ca2eb';
const storageKey = 'sre-demo-runs-v1';

async function fetchTimed(url, options = {}, fetchImpl = fetch) {
  const controller = new AbortController();
  const abort = () => controller.abort();
  if (options.signal?.aborted) controller.abort();
  options.signal?.addEventListener('abort', abort, { once: true });
  const timer = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetchImpl(url, { ...options, signal: controller.signal, cache: 'no-store' });
    const text = await response.text();
    return { status: response.status, text };
  } finally {
    clearTimeout(timer);
    options.signal?.removeEventListener('abort', abort);
  }
}

export async function runTraffic({ signal, fetchImpl = fetch, onProgress = () => {} } = {}) {
  const run = {
    runId: crypto.randomUUID(),
    startUtc: new Date().toISOString(),
    endUtc: null,
    results: []
  };
  let next = 0;
  await Promise.all(Array.from({ length: 6 }, async () => {
    while (next < 60 && !signal?.aborted) {
      const index = next++;
      const endpoint = endpoints[index % endpoints.length];
      const start = performance.now();
      try {
        const options = endpoint === '/products'
          ? { signal }
          : { signal, method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{"productId":1,"quantity":1}' };
        const response = await fetchTimed(`${endpoint}?demoRun=${run.runId}`, options, fetchImpl);
        run.results.push({ endpoint, status: response.status, durationMs: performance.now() - start });
      } catch (error) {
        run.results.push({ endpoint, status: 0, durationMs: performance.now() - start, error: error.message });
      }
      onProgress(run.results.length);
    }
  }));
  run.endUtc = new Date().toISOString();
  return run;
}

function hasRunShape(run) {
  return run && /^[0-9a-f-]{36}$/i.test(run.runId)
    && Number.isFinite(Date.parse(run.startUtc)) && Number.isFinite(Date.parse(run.endUtc))
    && Date.parse(run.endUtc) >= Date.parse(run.startUtc)
    && Array.isArray(run.results) && run.results.length <= 60
    && run.results.every(row => row && endpoints.includes(row.endpoint)
      && Number.isInteger(row.status) && row.status >= 0 && row.status <= 599
      && Number.isFinite(row.durationMs) && row.durationMs >= 0);
}

export function isValidRun(run, recovery = false) {
  if (!hasRunShape(run) || run.results.length !== 60) return false;
  return endpoints.every(endpoint => run.results.filter(result => result.endpoint === endpoint).length === 20)
    && run.results.every(result => recovery ? result.status === 200 : [200, 500].includes(result.status))
    && (recovery || run.results.some(result => result.status === 500));
}

function interval(run) {
  return `${new Date(Date.parse(run.startUtc) - 10000).toISOString()} a ${new Date(Date.parse(run.endUtc) + 10000).toISOString()}`;
}

export function buildPrompts(incident, recovery) {
  const incidentReady = isValidRun(incident);
  const recoveryReady = isValidRun(recovery, true);
  const source = `Consulta el ${context}. Usa AppRequests, AppExceptions y AppTraces en el ambito del workspace, no esas tablas en el ambito del recurso Application Insights. No listes app settings, no solicites credenciales ni permisos adicionales. Solo lectura; no hagas cambios ni remediaciones. Responde en espanol.`;
  return {
    investigate: incidentReady
      ? `Investiga los HTTP 500 de sredemo-mim-app. ${source} Intervalo fijo UTC: ${interval(incident)}. El trafico de prueba lleva demoRun=${incident.runId} en la URL; filtra AppRequests por ese identificador y correlaciona excepciones y trazas por OperationId. Calcula tasa de errores y latencia por endpoint y del conjunto de esas solicitudes de negocio, con denominadores explicitos. Identifica excepciones y evidencia de activacion del flag en las trazas del intervalo, sin exigir que la llamada administrativa lleve demoRun. Si no hay datos aun, informa el retraso de ingesta; si una consulta falla, muestra el error concreto. No inventes clientes afectados.`
      : '',
    cause: incidentReady
      ? `Correlaciona los hallazgos de demoRun=${incident.runId} con el repositorio conectado y la documentacion indexada. Localiza FailureModeMiddleware y FeatureFlagService y explica que activa SIM_FAILURE_001, las rutas afectadas, la probabilidad de error y las demoras programadas. Cita el repositorio, revision, ruta y lineas realmente consultados. Distingue hechos de hipotesis y no atribuyas el incidente a un despliegue sin evidencia. Propone una mitigacion, pero no la ejecutes. Si no puedes leer el codigo, declara la limitacion. ${source}`
      : '',
    recovery: incidentReady && recoveryReady
      ? `El operador ha desactivado ambas fallas. Verifica la recuperacion de sredemo-mim-app. ${source} Prueba posterior: intervalo UTC ${interval(recovery)}, demoRun=${recovery.runId} en la URL. Compara los errores y latencias de sus solicitudes con el incidente: ${interval(incident)}, demoRun=${incident.runId}. Filtra cada muestra por su demoRun y correlaciona AppTraces por OperationId. Busca tambien la traza de desactivacion del flag en el intervalo de recuperacion; la llamada administrativa no lleva demoRun. Si la ingesta no muestra todas las solicitudes, no des por confirmada la prueba completa. Distingue una muestra de recuperacion de observacion sostenida.`
      : '',
    report: incidentReady && recoveryReady
      ? `Genera un informe post-incidente breve de las pruebas demoRun=${incident.runId} y demoRun=${recovery.runId}: resumen ejecutivo, impacto observado, linea de tiempo UTC, causa raiz con evidencias, mitigacion aplicada por el operador, validacion de recuperacion y acciones preventivas propuestas. Usa los resultados que realmente consultaste en este chat; si falta verificar algo, marcalo como pendiente. Aclara que fue una simulacion con trafico de prueba, sin evidencia de clientes reales afectados. Distingue acciones realizadas de recomendaciones y una muestra de 60 solicitudes de observacion sostenida. No inventes despliegues ni calcules MTTR sin justificar inicio y fin. ${source}`
      : ''
  };
}

export function describeRun(run) {
  if (!run) return 'Sin prueba.';
  const failures = run.results.filter(result => result.status === 500).length;
  const errors = run.results.filter(result => ![200, 500].includes(result.status));
  const lines = [
    `HTTP 500: ${failures}/${run.results.length} | Otros errores: ${errors.length}`,
    ...endpoints.map(endpoint => {
      const rows = run.results.filter(result => result.endpoint === endpoint);
      const ok = rows.filter(result => result.status === 200).length;
      return `${endpoint}: ${ok}/${rows.length} HTTP 200`;
    }),
    `UTC: ${run.startUtc} a ${run.endUtc}`,
    `demoRun=${run.runId}`,
    'Medicion del navegador; pendiente de correlacion en Log Analytics.'
  ];
  if (errors.length) lines.push(`Primer error: ${errors[0].error || `HTTP ${errors[0].status}`}`);
  return lines.join('\n');
}

async function initialize() {
  const element = id => document.getElementById(id);
  let adminToken = '';
  let busy = false;
  let recovering = false;
  let activeOperation = Promise.resolve();
  let trafficController;
  let incident = null;
  let recovery = null;

  function notice(message) {
    element('notice').hidden = !message;
    element('notice').textContent = message;
  }

  function render() {
    element('incident').disabled = !adminToken || busy || recovering;
    element('recover').disabled = !adminToken || recovering;
    element('stop').disabled = !adminToken || recovering;
    element('save-token').disabled = busy || recovering;
    element('incident-result').textContent = describeRun(incident);
    element('recovery-result').textContent = describeRun(recovery);
    const prompts = buildPrompts(incident, recovery);
    for (const [name, text] of Object.entries(prompts)) {
      const id = `prompt-${name}`;
      element(id).value = text || 'Completa primero la prueba correspondiente sin errores inesperados.';
      document.querySelector(`[data-copy="${id}"]`).disabled = !text;
    }
  }

  function persist() {
    try {
      sessionStorage.setItem(storageKey, JSON.stringify({ incident, recovery }));
    } catch (error) {
      notice(`No se pudo conservar la prueba en esta pestana: ${error.message}. No recargues antes de copiar los mensajes.`);
    }
  }

  async function jsonRequest(url, options) {
    const response = await fetchTimed(url, options);
    if (response.status !== 200) {
      throw new Error(response.status === 401 ? 'Token invalido. Pega y guarda el token correcto.' : `${url}: HTTP ${response.status}`);
    }
    return JSON.parse(response.text);
  }

  async function health() {
    try {
      const data = await jsonRequest('/health');
      if (typeof data.flags?.failureMode !== 'boolean' || typeof data.flags?.dbTimeout !== 'boolean' || data.status !== 'healthy') {
        throw new Error('Respuesta /health inesperada.');
      }
      const active = data.flags.failureMode || data.flags.dbTimeout;
      element('health').className = `status ${active ? 'danger' : 'success'}`;
      element('health').textContent = `FAILURE MODE: ${data.flags.failureMode ? 'ON' : 'OFF'} | DB TIMEOUT: ${data.flags.dbTimeout ? 'ON' : 'OFF'} | API: ${data.version}\n${active ? 'Falla activa: recupera antes de terminar.' : 'Flags apagadas; usa la prueba de negocio para verificar las compras.'}`;
      return data;
    } catch (error) {
      element('health').className = 'status danger';
      element('health').textContent = `Estado desconocido: ${error.message}. No asumas que las fallas estan apagadas.`;
      throw error;
    }
  }

  async function toggle(flag, enabled) {
    await jsonRequest(`/admin/${flag}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Admin-Token': adminToken },
      body: JSON.stringify({ enabled })
    });
  }

  async function traffic() {
    trafficController = new AbortController();
    return runTraffic({
      signal: trafficController.signal,
      onProgress: count => { element('activity').textContent = `Generando trafico acotado: ${count}/60 solicitudes. No cierres esta pestana.`; }
    });
  }

  function runAction(action) {
    busy = true;
    notice('');
    render();
    activeOperation = (async () => {
      try {
        await action();
      } catch (error) {
        element('activity').className = 'status danger';
        element('activity').textContent = `Operacion no completada: ${error.message}\nSi la falla quedo activa, usa "Apagar ambas fallas sin prueba".`;
      } finally {
        busy = false;
        trafficController = null;
        persist();
        render();
      }
    })();
    return activeOperation;
  }

  element('token-form').addEventListener('submit', event => {
    event.preventDefault();
    adminToken = element('token').value.trim();
    element('token').value = '';
    element('token-status').textContent = adminToken ? 'Token cargado en memoria. Nunca se incluye en mensajes ni resultados.' : 'Token vacio; vuelve a pegarlo.';
    element('activity').textContent = 'Listo. Activa la falla solo cuando estes preparado para investigar.';
    render();
  });

  element('incident').addEventListener('click', () => {
    runAction(async () => {
      incident = null;
      recovery = null;
      persist();
      render();
      const before = await health();
      if (before.flags.dbTimeout) throw new Error('DB TIMEOUT esta activo. Recupera primero para no mezclar escenarios.');
      const startUtc = new Date().toISOString();
      await toggle('failure-mode', true);
      const active = await health();
      if (!active.flags.failureMode || active.flags.dbTimeout) throw new Error('Las flags no coinciden con el escenario del incidente.');
      const run = await traffic();
      // Include the administrative toggle in the query window.
      run.startUtc = startUtc;
      incident = run;
      const after = await health();
      if (!after.flags.failureMode || after.flags.dbTimeout) {
        incident = null;
        throw new Error('Las flags cambiaron durante la prueba. No se usara esta muestra para investigar.');
      }
      if (!isValidRun(incident)) throw new Error('Prueba incompleta, sin HTTP 500 o con errores inesperados. Revisa los resultados antes de repetir.');
      element('activity').className = 'status success';
      element('activity').textContent = 'Incidente generado. Copia A al chat nuevo del agente; despues usa B. La falla sigue activa hasta que recuperes.';
    });
  });

  async function recover(withTraffic) {
    if (recovering) return;
    recovering = true;
    render();
    if (busy) {
      trafficController?.abort();
      await activeOperation;
    }
    await runAction(async () => {
      recovery = null;
      render();
      const startUtc = new Date().toISOString();
      const errors = [];
      for (const flag of ['failure-mode', 'db-timeout']) {
        try { await toggle(flag, false); }
        catch (error) { errors.push(error.message); }
      }
      const data = await health();
      if (errors.length || data.flags.failureMode || data.flags.dbTimeout) {
        throw new Error(`No se confirmo la desactivacion de ambas fallas. ${errors.join(' ')}`);
      }
      if (withTraffic) {
        const run = await traffic();
        run.startUtc = startUtc;
        recovery = run;
        const after = await health();
        if (after.flags.failureMode || after.flags.dbTimeout) {
          recovery = null;
          throw new Error('Una falla se reactivo durante la prueba de recuperacion.');
        }
        if (!isValidRun(recovery, true)) throw new Error('Recuperacion NO verificada: se requieren 60/60 respuestas HTTP 200. Revisa los errores.');
      }
      element('activity').className = 'status success';
      element('activity').textContent = withTraffic
        ? 'Recuperacion verificada por el navegador: 60/60 HTTP 200. Copia C y despues D para verificar telemetria y generar el informe.'
        : 'Ambas fallas apagadas y verificadas en /health. No se ejecuto una prueba de compras.';
    });
    recovering = false;
    render();
  }

  element('recover').addEventListener('click', () => recover(true));
  element('stop').addEventListener('click', () => recover(false));
  for (const button of document.querySelectorAll('[data-copy]')) {
    button.addEventListener('click', async () => {
      const textarea = element(button.dataset.copy);
      try {
        await navigator.clipboard.writeText(textarea.value);
        element('copy-status').textContent = 'Mensaje copiado. Pegalo en el mismo chat del SRE Agent.';
      } catch (error) {
        textarea.closest('details').open = true;
        textarea.focus();
        textarea.select();
        element('copy-status').textContent = `No se pudo copiar automaticamente (${error.message}). El texto esta seleccionado: usa Ctrl+C.`;
      }
    });
  }
  window.addEventListener('beforeunload', event => {
    if (busy || (incident && !recovery)) {
      event.preventDefault();
      event.returnValue = '';
    }
  });

  try {
    const saved = JSON.parse(sessionStorage.getItem(storageKey) || 'null');
    if (saved) {
      if ((saved.incident && !hasRunShape(saved.incident)) || (saved.recovery && !hasRunShape(saved.recovery))) {
        throw new Error('Formato de resultados no reconocido.');
      }
      incident = saved.incident;
      recovery = saved.recovery;
      notice('Se restauraron resultados anteriores de esta pestana. Para una demo nueva, pulsa el boton 1. El token NO se conserva al recargar.');
    }
  } catch (error) {
    notice(`No se pudieron restaurar los resultados: ${error.message}. Genera una prueba nueva.`);
  }
  render();
  const refresh = async () => {
    try { await health(); }
    catch (error) { console.error('Demo health check failed:', error.message); }
    setTimeout(refresh, 15000);
  };
  await refresh();
}

if (typeof document !== 'undefined') initialize();
