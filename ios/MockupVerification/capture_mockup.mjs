import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';

const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const debugPort = 9333;
const outputDir = new URL('.', import.meta.url);
const targetUrl = 'http://127.0.0.1:5173/ios-prototype';

function requestJson(url) {
  return fetch(url).then((response) => {
    if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);
    return response.json();
  });
}

async function waitForVersion() {
  const endpoint = `http://127.0.0.1:${debugPort}/json/list`;
  for (let attempt = 0; attempt < 80; attempt += 1) {
    try {
      const pages = await requestJson(endpoint);
      const page = pages.find((item) => item.type === 'page');
      if (page?.webSocketDebuggerUrl) return page.webSocketDebuggerUrl;
    } catch {
      // Chrome is still starting.
    }
    await delay(100);
  }
  throw new Error('Chrome remote debugging endpoint was not ready.');
}

function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let nextId = 1;
  const pending = new Map();

  ws.addEventListener('message', (event) => {
    const payload = JSON.parse(event.data);
    if (!payload.id) return;
    const callbacks = pending.get(payload.id);
    if (!callbacks) return;
    pending.delete(payload.id);
    if (payload.error) callbacks.reject(new Error(payload.error.message));
    else callbacks.resolve(payload.result ?? {});
  });

  const opened = new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve, { once: true });
    ws.addEventListener('error', reject, { once: true });
  });

  return {
    opened,
    send(method, params = {}) {
      const id = nextId;
      nextId += 1;
      const promise = new Promise((resolve, reject) => {
        pending.set(id, { resolve, reject });
      });
      ws.send(JSON.stringify({ id, method, params }));
      return promise;
    },
    close() {
      ws.close();
    },
  };
}

async function main() {
  await mkdir(outputDir, { recursive: true });

  const chrome = spawn(chromePath, [
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    `--remote-debugging-port=${debugPort}`,
    '--window-size=393,852',
    '--user-data-dir=/tmp/creativehub-ios-mockup-chrome',
    targetUrl,
  ], { stdio: ['ignore', 'ignore', 'pipe'] });

  chrome.stderr.on('data', () => {});

  const wsUrl = await waitForVersion();
  const cdp = connect(wsUrl);
  await cdp.opened;
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width: 393,
    height: 852,
    deviceScaleFactor: 1,
    mobile: false,
  });
  await delay(900);

  async function clickBySelector(selector) {
    await cdp.send('Runtime.evaluate', {
      expression: `document.querySelector(${JSON.stringify(selector)})?.click()`,
      awaitPromise: true,
    });
    await delay(550);
  }

  async function clickByText(text) {
    await cdp.send('Runtime.evaluate', {
      expression: `
        Array.from(document.querySelectorAll('button, a'))
          .find((element) => element.textContent?.includes(${JSON.stringify(text)}))
          ?.click()
      `,
      awaitPromise: true,
    });
    await delay(650);
  }

  async function capture(name) {
    const result = await cdp.send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: false,
    });
    await writeFile(new URL(`${name}.png`, outputDir), Buffer.from(result.data, 'base64'));
  }

  await capture('dashboard');
  await clickBySelector('[aria-label="Video"]');
  await capture('tasks');
  await clickBySelector('[aria-label="Lịch quay"]');
  await capture('calendar');
  await clickBySelector('[aria-label="Cá nhân"]');
  await capture('profile');
  await clickBySelector('[aria-label="Tạo mới"]');
  await capture('quick-create-task');
  await clickBySelector('[aria-label="Close"]');
  await clickByText('Đăng xuất');
  await capture('login');

  cdp.close();
  chrome.kill('SIGTERM');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
