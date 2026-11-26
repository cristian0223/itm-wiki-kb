// Genera automaticamente las capturas de evidencia con Playwright (Chromium).
//
//   node evidencias.mjs texto  <titulo> <subtitulo> <archivo.txt> <salida.png>
//   node evidencias.mjs wiki   <url_wiki> <salida.png>
//   node evidencias.mjs grafana <url_grafana> <salida.png>
//   node evidencias.mjs alertas <url_alertmanager> <url_mailpit> <salida.png>
import { chromium } from 'playwright';
import fs from 'node:fs';

const [, , mode, ...args] = process.argv;
const commit = (process.env.GITHUB_SHA || 'local').slice(0, 7);
const runUrl = process.env.GITHUB_RUN_ID
  ? `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`
  : 'ejecucion local';
const stamp = new Date().toLocaleString('es-CO', { timeZone: 'America/Bogota' });

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function footer() {
  return `<div class="foot">Generada automaticamente · ${esc(stamp)} (hora de Colombia) · commit ${esc(commit)} · ${esc(runUrl)}</div>`;
}

const baseCss = `
  body{margin:0;background:#f3f4f6;font-family:"Segoe UI",Arial,sans-serif;padding:28px;color:#1f2937}
  h1{font-size:20px;margin:0 0 4px} p.sub{margin:0 0 16px;color:#4b5563;font-size:14px}
  .foot{margin-top:14px;color:#6b7280;font-size:12px}
`;

function terminalHtml(title, subtitle, text) {
  const lines = text.replace(/\r/g, '').split('\n');
  const clipped = lines.length > 160 ? [...lines.slice(0, 150), `... (${lines.length - 150} lineas mas en el log del pipeline)`] : lines;
  const body = clipped
    .map((l) => {
      const e = esc(l);
      if (l.startsWith('$ ')) return `<span class="cmd">${e}</span>`;
      if (/OK|SUPERADA|Success|complete!|up\b|healthy/i.test(l)) return `<span class="ok">${e}</span>`;
      if (/ERROR|firing/i.test(l)) return `<span class="warn">${e}</span>`;
      return e;
    })
    .join('\n');
  return `<!doctype html><html><head><meta charset="utf-8"><style>${baseCss}
    .win{background:#1e1e1e;border-radius:10px;box-shadow:0 6px 20px rgba(0,0,0,.25);overflow:hidden}
    .bar{background:#2d2d2d;color:#cfcfcf;padding:10px 16px;font-size:13px}
    .dot{display:inline-block;width:12px;height:12px;border-radius:50%;margin-right:6px;vertical-align:middle}
    pre{margin:0;padding:18px 22px;color:#d4d4d4;font:13px/1.5 Consolas,"DejaVu Sans Mono",monospace;white-space:pre-wrap;word-break:break-word}
    .cmd{color:#4fc1ff;font-weight:bold}.ok{color:#89d185}.warn{color:#f48771}
  </style></head><body><h1>${esc(title)}</h1><p class="sub">${esc(subtitle)}</p>
  <div class="win"><div class="bar"><span class="dot" style="background:#ff5f56"></span><span class="dot" style="background:#ffbd2e"></span><span class="dot" style="background:#27c93f"></span> bash — itm-wiki-kb</div>
  <pre>${body}</pre></div>${footer()}</body></html>`;
}

async function withPage(viewport, fn) {
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport, locale: 'es-CO' });
    return await fn(page);
  } finally {
    await browser.close();
  }
}

async function texto([title, subtitle, file, out]) {
  const text = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : `(no se encontro ${file})`;
  await withPage({ width: 1280, height: 720 }, async (page) => {
    await page.setContent(terminalHtml(title, subtitle, text), { waitUntil: 'load' });
    await page.screenshot({ path: out, fullPage: true });
  });
}

async function wiki([base, out]) {
  await withPage({ width: 1440, height: 900 }, async (page) => {
    await page.goto(`${base}/login`, { waitUntil: 'networkidle' });
    await page.fill('input[name="email"]', 'admin@admin.com');
    await page.fill('input[name="password"]', 'password');
    await Promise.all([
      page.waitForLoadState('networkidle'),
      page.locator('form[action$="/login"] button').first().click(),
    ]);
    await page.waitForTimeout(1500);

    let target = `${base}/books`;
    try {
      await page.goto(`${base}/create-book`, { waitUntil: 'networkidle' });
      await page.fill('input[name="name"]', 'Guias de despliegue');
      await Promise.all([
        page.waitForURL(/\/books\/[^/]+$/, { timeout: 20000 }),
        page.locator('form[action$="/books"] button').last().click(),
      ]);
      const bookUrl = page.url();
      target = bookUrl;

      await page.goto(`${bookUrl}/create-page`, { waitUntil: 'networkidle' });
      await page.fill('input[name="name"]', 'Como desplegar la wiki con Terraform');
      const editor = page.frameLocator('.tox-edit-area iframe').locator('body');
      await editor.click({ timeout: 10000 });
      await editor.pressSequentially(
        'Guia del equipo: terraform init, terraform plan y terraform apply levantan BookStack, MariaDB, Redis, Prometheus, Grafana y Alertmanager. terraform destroy deja todo limpio.',
        { delay: 5 },
      );
      await Promise.all([
        page.waitForURL(/\/page\/[^/]+$/, { timeout: 20000 }),
        page.locator('#save-button, button[type="submit"]:has-text("Guardar")').first().click(),
      ]);
      target = page.url();
    } catch (err) {
      console.log(`Aviso: no se pudo crear todo el contenido de ejemplo (${err.message.split('\n')[0]})`);
    }

    await page.goto(target, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1000);
    await page.screenshot({ path: out });
  });
}

async function grafana([base, out]) {
  await withPage({ width: 1600, height: 1000 }, async (page) => {
    await page.goto(`${base}/d/itm-wiki?orgId=1&from=now-15m&to=now&kiosk`, { waitUntil: 'networkidle' });
    await page.waitForTimeout(8000);
    await page.screenshot({ path: out, fullPage: true });
  });
}

async function alertas([am, mail, out]) {
  const amShot = out.replace(/\.png$/, '-alertmanager.png');
  const mailShot = out.replace(/\.png$/, '-correo.png');
  await withPage({ width: 1280, height: 800 }, async (page) => {
    await page.goto(`${am}/#/alerts`, { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);
    await page.screenshot({ path: amShot });

    let view = `${mail}/`;
    try {
      const res = await page.request.get(`${mail}/api/v1/messages`);
      const data = await res.json();
      const first = (data.messages || [])[0];
      if (first && first.ID) view = `${mail}/view/${first.ID}`;
    } catch (err) {
      console.log(`Aviso: no se pudo leer la API de Mailpit (${err.message})`);
    }
    await page.goto(view, { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);
    await page.screenshot({ path: mailShot });
  });

  const img = (p) => `data:image/png;base64,${fs.readFileSync(p).toString('base64')}`;
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>${baseCss}
    .grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}
    .card{background:#fff;border-radius:10px;box-shadow:0 4px 14px rgba(0,0,0,.12);padding:12px}
    .card h2{font-size:15px;margin:2px 0 10px} .card img{width:100%;border:1px solid #e5e7eb;border-radius:6px}
  </style></head><body>
  <h1>Alerta disparada y correo recibido</h1>
  <p class="sub">Prueba controlada: se detuvo Redis, Prometheus disparo la alerta y Alertmanager envio el correo al buzon de Mailpit.</p>
  <div class="grid">
    <div class="card"><h2>Alertmanager: alertas activas</h2><img src="${img(amShot)}"></div>
    <div class="card"><h2>Correo de alerta recibido</h2><img src="${img(mailShot)}"></div>
  </div>${footer()}</body></html>`;
  await withPage({ width: 1700, height: 900 }, async (page) => {
    await page.setContent(html, { waitUntil: 'load' });
    await page.screenshot({ path: out, fullPage: true });
  });
}

const modes = { texto, wiki, grafana, alertas };
if (!modes[mode]) {
  console.error(`Modo desconocido: ${mode}. Use: ${Object.keys(modes).join(', ')}`);
  process.exit(2);
}
await modes[mode](args);
console.log(`Evidencia generada: ${args[args.length - 1]}`);
