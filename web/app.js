/**
 * Aspect: Railway Vital Interlocking & ETCS Level 2 Visualization Engine.
 * Standards: EN 50128 SIL 4 / ERA ETCS Subset-026.
 */

(() => {
  'use strict';

  // WebSocket Configuration
  const WS_URL = 'ws://' + (window.location.hostname || 'localhost') + ':9003';
  let socket = null;
  let reconnectTimer = null;

  // DOM Elements
  const connDot = document.getElementById('conn-dot');
  const connLabel = document.getElementById('conn-label');
  const metricTime = document.getElementById('metric-time');
  const metricSteps = document.getElementById('metric-steps');

  // SVG Layers
  const svgTracks = document.getElementById('svg-track-paths');
  const svgSwitches = document.getElementById('svg-switches');
  const svgSignals = document.getElementById('svg-signals');
  const svgTrains = document.getElementById('svg-trains');

  // DMI Elements
  const gaugeNeedle = document.getElementById('gauge-speed-needle');
  const gaugeSpeedText = document.getElementById('gauge-speed-text');
  const gaugePermArc = document.getElementById('gauge-permitted-arc');
  const gaugeWarnArc = document.getElementById('gauge-warning-arc');
  const gaugeEbiArc = document.getElementById('gauge-ebi-arc');
  const dmiVPerm = document.getElementById('dmi-v-perm');
  const dmiVWarn = document.getElementById('dmi-v-warn');
  const dmiVEbi = document.getElementById('dmi-v-ebi');
  const dmiTargetDist = document.getElementById('dmi-target-dist');
  const barThrottle = document.getElementById('bar-throttle');
  const barBrake = document.getElementById('bar-brake');
  const textThrottle = document.getElementById('text-throttle');
  const textBrake = document.getElementById('text-brake');

  // Diagnostics & Routes
  const routeTableBody = document.getElementById('route-table-body');
  const cardChanA = document.getElementById('card-chan-a');
  const cardChanB = document.getElementById('card-chan-b');
  const cardChanC = document.getElementById('card-chan-c');
  const vitalVoter = document.getElementById('vital-voter-state');
  const vitalInvariant = document.getElementById('vital-invariant-state');
  const vitalDivergences = document.getElementById('vital-divergences');
  const eventLog = document.getElementById('event-log');

  // Geographic Layout Coordinates
  const TRACK_SECTIONS = [
    { id: 1, name: 'S01', x1: 50, y1: 100, x2: 350, y2: 100 },
    { id: 2, name: 'S02', x1: 350, y1: 100, x2: 750, y2: 100 },
    { id: 3, name: 'S03', x1: 750, y1: 100, x2: 1150, y2: 100 },
    { id: 4, name: 'S04', x1: 350, y1: 100, x2: 500, y2: 170 },
    { id: 5, name: 'S05', x1: 500, y1: 170, x2: 900, y2: 170 },
    { id: 6, name: 'S06', x1: 900, y1: 170, x2: 1050, y2: 100 }
  ];

  const SIGNALS = [
    { id: 1, x: 320, y: 70, name: 'SIG-01' },
    { id: 2, x: 720, y: 70, name: 'SIG-02' },
    { id: 3, x: 1120, y: 70, name: 'SIG-03' },
    { id: 4, x: 880, y: 140, name: 'SIG-04' }
  ];

  // Helper: Format Time in MM:SS.mmm
  function formatSimTime(ms) {
    const totalSec = Math.floor(ms / 1000);
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    const millis = ms % 1000;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}.${String(millis).padStart(3, '0')}`;
  }

  // Speedometer Gauge Math (220-degree arc from 160 deg to 380 deg)
  const START_ANGLE = 160;
  const END_ANGLE = 380;
  const MAX_GAUGE_SPEED = 240.0;
  const GAUGE_RADIUS = 90;
  const GAUGE_CX = 120;
  const GAUGE_CY = 120;

  function speedToAngle(speed) {
    const clamped = Math.max(0, Math.min(speed, MAX_GAUGE_SPEED));
    const ratio = clamped / MAX_GAUGE_SPEED;
    return START_ANGLE + ratio * (END_ANGLE - START_ANGLE);
  }

  function polarToCartesian(cx, cy, r, angleInDegrees) {
    const angleInRadians = (angleInDegrees - 90) * Math.PI / 180.0;
    return {
      x: cx + (r * Math.cos(angleInRadians)),
      y: cy + (r * Math.sin(angleInRadians))
    };
  }

  function describeArc(cx, cy, r, startAngle, endAngle) {
    const start = polarToCartesian(cx, cy, r, endAngle);
    const end = polarToCartesian(cx, cy, r, startAngle);
    const largeArcFlag = endAngle - startAngle <= 180 ? '0' : '1';
    return [
      'M', start.x, start.y,
      'A', r, r, 0, largeArcFlag, 0, end.x, end.y
    ].join(' ');
  }

  function updateDMI(train) {
    if (!train) return;

    const currentSpeed = train.speed_kph || 0.0;
    const vPerm = train.permitted_kph || 160.0;
    const vWarn = train.warning_kph || 165.0;
    const vEbi = train.ebi_kph || 175.0;

    // Digital readout
    gaugeSpeedText.textContent = currentSpeed.toFixed(1);
    dmiVPerm.textContent = `${vPerm.toFixed(1)} km/h`;
    dmiVWarn.textContent = `${vWarn.toFixed(1)} km/h`;
    dmiVEbi.textContent = `${vEbi.toFixed(1)} km/h`;

    // Speed needle
    const needleAngle = speedToAngle(currentSpeed);
    const pCenter = { x: GAUGE_CX, y: GAUGE_CY };
    const pTip = polarToCartesian(GAUGE_CX, GAUGE_CY, GAUGE_RADIUS - 10, needleAngle);
    gaugeNeedle.setAttribute('d', `M ${pCenter.x} ${pCenter.y} L ${pTip.x} ${pTip.y}`);

    // Color based on supervision state
    if (currentSpeed > vEbi) {
      gaugeNeedle.style.stroke = 'var(--color-red)';
      gaugeSpeedText.style.fill = 'var(--color-red)';
    } else if (currentSpeed > vWarn) {
      gaugeNeedle.style.stroke = 'var(--color-yellow)';
      gaugeSpeedText.style.fill = 'var(--color-yellow)';
    } else {
      gaugeNeedle.style.stroke = '#ffffff';
      gaugeSpeedText.style.fill = '#ffffff';
    }

    // Arc hooks
    const permAngle = speedToAngle(vPerm);
    const warnAngle = speedToAngle(vWarn);
    const ebiAngle = speedToAngle(vEbi);

    gaugePermArc.setAttribute('d', describeArc(GAUGE_CX, GAUGE_CY, GAUGE_RADIUS, START_ANGLE, permAngle));
    gaugeWarnArc.setAttribute('d', describeArc(GAUGE_CX, GAUGE_CY, GAUGE_RADIUS, permAngle, warnAngle));
    gaugeEbiArc.setAttribute('d', describeArc(GAUGE_CX, GAUGE_CY, GAUGE_RADIUS, warnAngle, ebiAngle));

    // Effort bars
    const throttlePct = Math.max(0, Math.min(train.throttle_pct || 0, 100));
    const brakePct = Math.max(0, Math.min(train.brake_pct || 0, 100));

    barThrottle.style.width = `${throttlePct}%`;
    textThrottle.textContent = `${throttlePct.toFixed(0)}%`;
    barBrake.style.width = `${brakePct}%`;
    textBrake.textContent = `${brakePct.toFixed(0)}%`;
  }

  // Renders the SVG Track Elements
  function renderTracks(sections, switches) {
    let html = '';

    TRACK_SECTIONS.forEach(def => {
      const live = sections ? sections.find(s => s.id === def.id) : null;
      let stateClass = 'state-clear';
      if (live) {
        if (live.occupied) {
          stateClass = 'state-occupied';
        } else if (live.locked) {
          stateClass = 'state-locked';
        }
      }

      html += `<path class="track-rail ${stateClass}" d="M ${def.x1} ${def.y1} L ${def.x2} ${def.y2}" id="sec-${def.id}" />`;
      // Section tag
      const midX = (def.x1 + def.x2) / 2;
      const midY = (def.y1 + def.y2) / 2 - 12;
      html += `<text x="${midX}" y="${midY}" class="switch-indicator" text-anchor="middle">${def.name}</text>`;
    });

    svgTracks.innerHTML = html;

    // Render Switches
    let swHtml = '';
    if (switches) {
      switches.forEach(sw => {
        const isRev = sw.position === 'REVERSE';
        const swColor = isRev ? 'var(--color-yellow)' : 'var(--color-cyan)';
        const posText = isRev ? 'REV' : 'NORM';
        const posX = sw.id === 1 ? 350 : 750;
        const posY = 100;

        swHtml += `<circle cx="${posX}" cy="${posY}" r="6" fill="${swColor}" />`;
        swHtml += `<text x="${posX}" y="${posY + 25}" class="switch-indicator" text-anchor="middle" fill="${swColor}">SW-${sw.id}: ${posText}</text>`;
      });
    }
    svgSwitches.innerHTML = swHtml;
  }

  function renderSignals(signals) {
    let html = '';
    SIGNALS.forEach(def => {
      const live = signals ? signals.find(s => s.id === def.id) : null;
      const aspect = live ? live.aspect : 'STOP';

      let redClass = 'lamp-off';
      let yellowClass = 'lamp-off';
      let greenClass = 'lamp-off';

      if (aspect === 'STOP') {
        redClass = 'lamp-red';
      } else if (aspect === 'CAUTION' || aspect === 'PRELIMINARY_CAUTION') {
        yellowClass = 'lamp-yellow';
      } else if (aspect === 'CLEAR') {
        greenClass = 'lamp-green';
      }

      html += `
        <g transform="translate(${def.x}, ${def.y})">
          <rect class="signal-housing" x="-8" y="-28" width="16" height="34" rx="4" />
          <circle class="signal-lamp ${greenClass}" cx="0" cy="-20" r="3.5" />
          <circle class="signal-lamp ${yellowClass}" cx="0" cy="-11" r="3.5" />
          <circle class="signal-lamp ${redClass}" cx="0" cy="-2" r="3.5" />
          <text x="0" y="16" class="switch-indicator" text-anchor="middle">${def.name}</text>
        </g>
      `;
    });
    svgSignals.innerHTML = html;
  }

  function renderTrains(trains) {
    let html = '';
    if (!trains) return;

    trains.forEach(t => {
      // Linear mapping of train chainage km to track pixels
      const km = t.chainage_km || 0.0;
      // Section 1: 0.0 to 0.8 km -> x: 50 to 350
      // Section 2: 0.8 to 1.4 km -> x: 350 to 750
      // Section 3: 1.4 to 2.6 km -> x: 750 to 1150
      let px = 50 + (km * 400);
      let py = 100;

      if (t.section === 4 || t.section === 5) {
        py = 170;
        px = 500 + (km * 350);
      }

      px = Math.max(50, Math.min(px, 1140));

      html += `
        <g class="train-consist" transform="translate(${px}, ${py})">
          <rect class="train-body" x="-35" y="-10" width="70" height="20" />
          <circle class="train-headlight" cx="33" cy="0" r="3" />
          <text class="train-label" x="0" y="4">TR-${t.id || 1}</text>
        </g>
      `;
    });
    svgTrains.innerHTML = html;
  }

  function renderRoutes(routes) {
    if (!routes) return;
    let html = '';
    routes.forEach(r => {
      const stateClass = r.state === 'INTERLOCKED' || r.state === 'CLEARED' ? 'badge-interlocked' :
                         r.state === 'REQUESTED' ? 'badge-requested' :
                         r.state === 'CANCELLED' ? 'badge-cancelled' : 'badge-unset';

      html += `
        <tr>
          <td><strong>R-${r.id}</strong></td>
          <td><span class="route-badge ${stateClass}">${r.state}</span></td>
          <td>SIG-${r.entry_sig || 1}</td>
          <td>SIG-${r.exit_sig || 2}</td>
          <td>TR-01</td>
        </tr>
      `;
    });
    routeTableBody.innerHTML = html;
  }

  function renderDiagnostics(voter) {
    if (!voter) return;

    if (voter.is_degraded) {
      vitalVoter.textContent = 'DEGRADED 2oo2';
      vitalVoter.className = 'vital-value danger';
      cardChanC.className = 'channel-card faulted';
      cardChanC.querySelector('.card-status').textContent = 'ISOLATED';
    } else {
      vitalVoter.textContent = 'UNANIMOUS 3oo3';
      vitalVoter.className = 'vital-value success';
      cardChanC.className = 'channel-card healthy';
      cardChanC.querySelector('.card-status').textContent = 'NOMINAL';
    }

    vitalDivergences.textContent = voter.divergences || 0;
    vitalInvariant.textContent = voter.last_passed ? 'PASS (5/5)' : 'FAIL TRIPPED';
    vitalInvariant.className = voter.last_passed ? 'vital-value success' : 'vital-value danger';
  }

  function logEvent(msg) {
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.textContent = msg;
    eventLog.appendChild(entry);
    eventLog.scrollTop = eventLog.scrollHeight;
  }

  // Telemetry Snapshot Ingestion Handler
  function handleSnapshot(snap) {
    metricTime.textContent = formatSimTime(snap.timestamp_ms || 0);
    metricSteps.textContent = snap.step_number || 0;

    renderTracks(snap.sections, snap.switches);
    renderSignals(snap.signals);
    renderTrains(snap.trains);
    renderRoutes(snap.routes);
    renderDiagnostics(snap.voter);

    if (snap.trains && snap.trains.length > 0) {
      updateDMI(snap.trains[0]);
    }
  }

  // WebSocket Connection Lifecycle
  function connectWebSocket() {
    connLabel.textContent = 'CONNECTING...';
    socket = new WebSocket(WS_URL);

    socket.onopen = () => {
      connDot.className = 'status-dot connected';
      connLabel.textContent = 'WS CONNECTED';
      logEvent(`[${formatSimTime(0)}] Connected to Aspect telemetry bridge.`);
    };

    socket.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.type === 'telemetry_snapshot') {
          handleSnapshot(data);
        }
      } catch (err) {
        console.error('Failed to parse telemetry JSON:', err);
      }
    };

    socket.onclose = () => {
      connDot.className = 'status-dot disconnected';
      connLabel.textContent = 'DISCONNECTED';
      logEvent(`[${formatSimTime(0)}] Disconnected. Retrying in 2 seconds...`);
      clearTimeout(reconnectTimer);
      reconnectTimer = setTimeout(connectWebSocket, 2000);
    };

    socket.onerror = () => {
      socket.close();
    };
  }

  // Initial Boot
  renderTracks([], []);
  renderSignals([]);
  connectWebSocket();

})();
