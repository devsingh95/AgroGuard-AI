const state = {
  backendOrigin: localStorage.getItem('agroguard.backendOrigin') || '',
  sensorTimer: null,
};

const $ = (selector) => document.querySelector(selector);

const els = {
  backendUrl: $('#backendUrl'),
  backendStatus: $('#backendStatus'),
  saveBackend: $('#saveBackend'),
  resetBackend: $('#resetBackend'),
  cropForm: $('#cropForm'),
  cropResult: $('#cropResult'),
  diseaseForm: $('#diseaseForm'),
  diseaseImage: $('#diseaseImage'),
  cropType: $('#cropType'),
  diseaseResult: $('#diseaseResult'),
  sensorGrid: $('#sensorGrid'),
  sensorAlert: $('#sensorAlert'),
  refreshSensors: $('#refreshSensors'),
  sensorMeta: $('#sensorMeta'),
};

function apiBase() {
  if (state.backendOrigin) return state.backendOrigin.replace(/\/$/, '');
  return window.location.origin;
}

function hasBackend() {
  return Boolean(state.backendOrigin);
}

function setStatus(message, kind = 'info') {
  els.backendStatus.textContent = message;
  els.backendStatus.className = `status ${kind}`;
}

function pretty(value) {
  if (value === null || value === undefined) return 'n/a';
  if (typeof value === 'number') return Number.isInteger(value) ? `${value}` : value.toFixed(2);
  if (typeof value === 'object') return JSON.stringify(value, null, 2);
  return String(value);
}

async function request(path, options = {}) {
  const url = `${apiBase()}${path}`;
  return fetch(url, {
    headers: { 'Accept': 'application/json', ...(options.headers || {}) },
    ...options,
  });
}

async function predictCrop(event) {
  event.preventDefault();
  const form = new FormData(els.cropForm);
  const payload = Object.fromEntries(form.entries());
  Object.keys(payload).forEach((key) => (payload[key] = Number(payload[key])));

  if (!hasBackend()) {
    els.cropResult.textContent = 'Demo mode\nCrop: Rice\nConfidence: 0.92\n\nSet a backend URL to run a live prediction.';
    return;
  }

  els.cropResult.textContent = 'Predicting crop...';
  try {
    const response = await request('/api/predict_crop', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await response.json();
    els.cropResult.textContent = response.ok
      ? `Crop: ${data.crop ?? data.prediction ?? 'Unknown'}\nConfidence: ${pretty(data.confidence ?? data.probability)}\n\nRaw response:\n${pretty(data)}`
      : `Request failed (${response.status})\n\n${pretty(data)}`;
  } catch (error) {
    els.cropResult.textContent = `Offline/demo mode\n${error.message}`;
  }
}

async function detectDisease(event) {
  event.preventDefault();
  const image = els.diseaseImage.files?.[0];
  if (!image) return;

  if (!hasBackend()) {
    els.diseaseResult.textContent = 'Demo mode\nDisease: Tomato late blight\nConfidence: 0.95\n\nSymptoms: Water-soaked spots on leaves\nTreatment: Apply copper fungicide\nPrevention: Avoid overhead watering';
    return;
  }

  const body = new FormData();
  body.append('image', image);
  if (els.cropType.value.trim()) body.append('crop_type', els.cropType.value.trim());

  els.diseaseResult.textContent = 'Analyzing image...';
  try {
    const response = await request('/api/predict_disease', { method: 'POST', body });
    const data = await response.json();
    els.diseaseResult.textContent = response.ok
      ? `Disease: ${data.disease ?? data.prediction ?? 'Unknown'}\nConfidence: ${pretty(data.confidence ?? data.probability)}\n\nSymptoms: ${pretty(data.symptoms)}\nTreatment: ${pretty(data.treatment)}\nPrevention: ${pretty(data.prevention)}\n\nRaw response:\n${pretty(data)}`
      : `Request failed (${response.status})\n\n${pretty(data)}`;
  } catch (error) {
    els.diseaseResult.textContent = `Offline/demo mode\n${error.message}`;
  }
}

function getSeverity(value, key) {
  const number = Number(value);
  if (Number.isNaN(number)) return 'warn';
  if (key.includes('humidity') && (number < 30 || number > 80)) return 'bad';
  if (key.includes('temperature') && (number < 15 || number > 35)) return 'warn';
  if (key.includes('ph') && (number < 6 || number > 8)) return 'bad';
  return 'ok';
}

function renderSensors(data) {
  const current = data?.current_data || data || {};
  const keys = ['nitrogen', 'phosphorus', 'potassium', 'temperature', 'humidity', 'ph', 'rainfall', 'soil_moisture', 'light_intensity'];
  els.sensorGrid.innerHTML = keys.map((key) => {
    const value = current[key];
    const severity = getSeverity(value, key);
    return `<div class="metric"><label>${key.replace(/_/g, ' ')}</label><strong class="${severity}">${pretty(value)}</strong></div>`;
  }).join('');

  const alerts = data?.alerts || [];
  if (alerts.length) {
    els.sensorAlert.className = 'alert';
    els.sensorAlert.textContent = alerts.map((alert) => `${alert.metric ?? 'alert'}: ${alert.message ?? pretty(alert.value)}`).join('\n');
  } else {
    els.sensorAlert.className = 'alert empty';
    els.sensorAlert.textContent = 'No active alerts.';
  }
}

async function loadSensors() {
  if (!hasBackend()) {
    renderSensors({
      current_data: {
        nitrogen: 48.2,
        phosphorus: 31.8,
        potassium: 40.5,
        temperature: 26.1,
        humidity: 66.4,
        ph: 6.9,
        rainfall: 192.3,
        soil_moisture: 63.5,
        light_intensity: 5250,
      },
      alerts: [],
    });
    els.sensorMeta.textContent = 'Demo mode: set a backend URL for live sensor data.';
    return;
  }

  els.sensorMeta.textContent = 'Fetching live sensor data...';
  try {
    const response = await request('/api/sensor_data');
    const data = await response.json();
    renderSensors(data);
    els.sensorMeta.textContent = response.ok ? `Updated ${new Date().toLocaleTimeString()}` : `Sensor API returned ${response.status}`;
  } catch (error) {
    renderSensors({
      current_data: {
        nitrogen: 48.2,
        phosphorus: 31.8,
        potassium: 40.5,
        temperature: 26.1,
        humidity: 66.4,
        ph: 6.9,
        rainfall: 192.3,
        soil_moisture: 63.5,
        light_intensity: 5250,
      },
      alerts: [{ metric: 'demo', message: `Demo mode: ${error.message}` }],
    });
    els.sensorMeta.textContent = 'Demo data shown because the API is unavailable.';
  }
}

function bindBackendControls() {
  els.backendUrl.value = state.backendOrigin;
  setStatus(state.backendOrigin ? `Using ${state.backendOrigin}` : 'Demo mode enabled. Set a backend URL for live API calls.');

  els.saveBackend.addEventListener('click', () => {
    const value = els.backendUrl.value.trim().replace(/\/$/, '');
    state.backendOrigin = value;
    if (value) {
      localStorage.setItem('agroguard.backendOrigin', value);
      setStatus(`Backend saved: ${value}`, 'ok');
    } else {
      localStorage.removeItem('agroguard.backendOrigin');
      setStatus('Demo mode enabled. Set a backend URL for live API calls.', 'info');
    }
    loadSensors();
  });

  els.resetBackend.addEventListener('click', () => {
    state.backendOrigin = '';
    localStorage.removeItem('agroguard.backendOrigin');
    els.backendUrl.value = '';
    setStatus('Demo mode enabled. Set a backend URL for live API calls.', 'info');
    loadSensors();
  });
}

function boot() {
  bindBackendControls();
  els.cropForm.addEventListener('submit', predictCrop);
  els.diseaseForm.addEventListener('submit', detectDisease);
  els.refreshSensors.addEventListener('click', loadSensors);
  loadSensors();
  state.sensorTimer = window.setInterval(loadSensors, 8000);
}

boot();