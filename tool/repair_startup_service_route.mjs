import fs from 'node:fs';

function replaceExactly(source, oldText, newText, label) {
  const count = source.split(oldText).length - 1;
  if (count !== 1) {
    throw new Error(`Expected exactly one ${label} target, found ${count}. Stop instead of guessing.`);
  }
  return source.replace(oldText, newText);
}

function repairNavigationSurface() {
  const target = 'lib/flutter_flow/nav/nav.dart';
  let source = fs.readFileSync(target, 'utf8');

  if (source.includes('final child = page; // Web/native startup owns the loading surface.')) {
    console.log('Navigation startup surface is already canonical.');
    return;
  }

  const oldText = `          final child = appStateNotifier.loading
              ? Container(
                  color: Colors.transparent,
                  child: Image.asset(
                    'assets/images/pipe_buyer_logo.png',
                    fit: BoxFit.contain,
                  ),
                )
              : page;`;
  const newText = `          final child = page; // Web/native startup owns the loading surface.`;

  source = replaceExactly(source, oldText, newText, 'router loading surface');
  fs.writeFileSync(target, source, 'utf8');
  console.log('Removed duplicate router logo loading surface.');
}

function repairWebStartup() {
  const target = 'web/index.html';
  let source = fs.readFileSync(target, 'utf8');

  const markers = [
    'id="pipe-service-truck"',
    'id="pipe-pumpjack"',
    "window.setTimeout(removePipeStartup, 1400);",
    "const truck = document.getElementById('pipe-service-truck');",
  ];
  if (markers.every((marker) => source.includes(marker))) {
    console.log('Service-truck startup surface is already applied.');
    return;
  }

  const cssOld = `    .pipe-startup-track {
      width: min(360px, 68vw);
      height: 5px;
      margin-top: 13px;
      overflow: hidden;
      border-radius: 999px;
      background: #edf1f5;
    }

    #pipe-startup-progress {
      width: 4%;
      height: 100%;
      border-radius: inherit;
      background: var(--pipe-orange);
      transition: width 240ms ease-out;
    }
`;

  const cssNew = `    .pipe-service-route {
      width: min(430px, 78vw);
      margin-top: 34px;
      padding: 18px 34px 8px 14px;
      box-sizing: border-box;
    }

    .pipe-startup-track {
      position: relative;
      width: 100%;
      height: 6px;
      margin: 0;
      overflow: visible;
      border-radius: 999px;
      background: #edf1f5;
      box-shadow: inset 0 0 0 1px rgba(6, 29, 73, .04);
    }

    #pipe-startup-progress {
      width: 4%;
      height: 100%;
      border-radius: inherit;
      background: linear-gradient(90deg, var(--pipe-orange), #ff7a33);
      transition: width 240ms ease-out;
    }

    .pipe-service-truck {
      position: absolute;
      left: 7%;
      top: -35px;
      width: 72px;
      height: 38px;
      transform: translateX(-50%);
      transition: left 280ms ease-out;
      filter: drop-shadow(0 5px 5px rgba(6, 29, 73, .18));
      pointer-events: none;
    }

    .pipe-service-truck svg,
    .pipe-pumpjack svg {
      display: block;
      width: 100%;
      height: 100%;
    }

    .pipe-pumpjack {
      position: absolute;
      right: -29px;
      top: -52px;
      width: 64px;
      height: 54px;
      filter: drop-shadow(0 5px 5px rgba(6, 29, 73, .14));
      pointer-events: none;
    }

    .pipe-pumpjack-arm {
      transform-box: fill-box;
      transform-origin: 42% 62%;
      animation: pipe-pumpjack-rock 1.35s ease-in-out infinite alternate;
    }

    .pipe-service-endpoint {
      position: absolute;
      right: -2px;
      top: 50%;
      width: 10px;
      height: 10px;
      transform: translate(50%, -50%);
      border: 3px solid #ffffff;
      border-radius: 50%;
      background: var(--pipe-orange);
      box-shadow: 0 0 0 1px rgba(255, 90, 0, .22);
    }

    .pipe-pumpjack.serviced {
      filter: drop-shadow(0 5px 8px rgba(255, 90, 0, .25));
    }

    @keyframes pipe-pumpjack-rock {
      from { transform: rotate(-4deg); }
      to { transform: rotate(5deg); }
    }

    @media (prefers-reduced-motion: reduce) {
      .pipe-service-truck,
      #pipe-startup-progress {
        transition: none;
      }
      .pipe-pumpjack-arm {
        animation: none;
      }
    }
`;

  const jsOld = `    function updatePipeStartup(percent, status) {
      pipeStartupProgress = Math.max(pipeStartupProgress, Math.min(96, percent));
      const bar = document.getElementById('pipe-startup-progress');
      const label = document.getElementById('pipe-startup-status');
      if (bar) bar.style.width = \`${'${pipeStartupProgress}'}%\`;
      if (label && status) label.textContent = status;
    }
`;

  const jsNew = `    function updatePipeStartup(percent, status) {
      pipeStartupProgress = Math.max(pipeStartupProgress, Math.min(100, percent));
      const bar = document.getElementById('pipe-startup-progress');
      const label = document.getElementById('pipe-startup-status');
      const track = document.querySelector('.pipe-startup-track');
      const truck = document.getElementById('pipe-service-truck');
      const pumpjack = document.getElementById('pipe-pumpjack');
      if (bar) bar.style.width = \`${'${pipeStartupProgress}'}%\`;
      if (label && status) label.textContent = status;
      if (track) track.setAttribute('aria-valuenow', String(Math.round(pipeStartupProgress)));
      if (truck) {
        const travelPercent = 7 + (Math.min(100, pipeStartupProgress) / 100) * 78;
        truck.style.left = \`${'${travelPercent}'}%\`;
      }
      if (pumpjack) pumpjack.classList.toggle('serviced', pipeStartupProgress >= 92);
    }
`;

  const frameOld = `    window.addEventListener('flutter-first-frame', () => {
      updatePipeStartup(96, 'Opening Pipe Buyer');
      requestAnimationFrame(removePipeStartup);
    }, { once: true });`;

  const frameNew = `    window.addEventListener('flutter-first-frame', () => {
      updatePipeStartup(96, 'Opening secure Pipe Buyer access');
      window.setTimeout(() => updatePipeStartup(100, 'Pipe Buyer ready'), 450);
      // Keep the single HTML startup surface over Flutter long enough for the
      // initial Firebase Auth event and enforced auth route to settle underneath.
      window.setTimeout(removePipeStartup, 1400);
    }, { once: true });`;

  const htmlOld = `      <div class="pipe-startup-track" role="progressbar" aria-label="Application startup progress" aria-valuemin="0" aria-valuemax="100">
        <div id="pipe-startup-progress"></div>
      </div>`;

  const htmlNew = `      <div class="pipe-service-route" aria-hidden="true">
        <div class="pipe-startup-track" role="progressbar" aria-label="Application startup progress" aria-valuemin="0" aria-valuemax="100" aria-valuenow="4">
          <div id="pipe-startup-progress"></div>
          <div id="pipe-service-truck" class="pipe-service-truck">
            <svg viewBox="0 0 92 48" focusable="false" aria-hidden="true">
              <rect x="10" y="15" width="45" height="19" rx="3" fill="#061d49"/>
              <rect x="15" y="10" width="31" height="7" rx="2" fill="#64748b"/>
              <rect x="18" y="18" width="8" height="5" rx="1" fill="#ffffff" opacity=".88"/>
              <rect x="30" y="18" width="8" height="5" rx="1" fill="#ffffff" opacity=".88"/>
              <rect x="42" y="18" width="8" height="5" rx="1" fill="#ffffff" opacity=".88"/>
              <path d="M54 20h20l8 8v6H54z" fill="#ff5a00"/>
              <path d="M60 21h11l5 6H60z" fill="#dbeafe"/>
              <rect x="6" y="31" width="77" height="4" rx="2" fill="#061d49"/>
              <circle cx="23" cy="37" r="7" fill="#111827"/>
              <circle cx="23" cy="37" r="3" fill="#cbd5e1"/>
              <circle cx="68" cy="37" r="7" fill="#111827"/>
              <circle cx="68" cy="37" r="3" fill="#cbd5e1"/>
              <rect x="8" y="12" width="4" height="17" rx="2" fill="#ff5a00"/>
            </svg>
          </div>
          <div class="pipe-service-endpoint"></div>
          <div id="pipe-pumpjack" class="pipe-pumpjack">
            <svg viewBox="0 0 80 64" focusable="false" aria-hidden="true">
              <path d="M9 55h62" stroke="#061d49" stroke-width="4" stroke-linecap="round"/>
              <path d="M27 53 37 24 48 53" fill="none" stroke="#061d49" stroke-width="5" stroke-linejoin="round"/>
              <path d="M22 42h32" stroke="#64748b" stroke-width="4" stroke-linecap="round"/>
              <g class="pipe-pumpjack-arm">
                <path d="M35 25 65 13" stroke="#061d49" stroke-width="6" stroke-linecap="round"/>
                <path d="M59 12 71 18" stroke="#ff5a00" stroke-width="6" stroke-linecap="round"/>
              </g>
              <path d="M67 18v29" stroke="#ff5a00" stroke-width="3" stroke-linecap="round"/>
              <circle cx="40" cy="25" r="4" fill="#ff5a00"/>
            </svg>
          </div>
        </div>
      </div>`;

  source = replaceExactly(source, cssOld, cssNew, 'startup route CSS');
  source = replaceExactly(source, jsOld, jsNew, 'startup progress controller');
  source = replaceExactly(source, frameOld, frameNew, 'first-frame handoff');
  source = replaceExactly(source, htmlOld, htmlNew, 'startup route markup');

  for (const marker of markers) {
    if (!source.includes(marker)) {
      throw new Error(`Startup service-route marker missing after repair: ${marker}`);
    }
  }

  fs.writeFileSync(target, source, 'utf8');
  console.log('Applied single Pipe Buyer service-truck startup surface.');
}

repairNavigationSurface();
repairWebStartup();
