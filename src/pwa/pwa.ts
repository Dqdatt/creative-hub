// Trạng thái cài đặt PWA dùng chung cho toàn app.
// Sự kiện beforeinstallprompt có thể bắn ra trước khi React mount, nên phải bắt
// ngay khi file này được import trong main.tsx rồi giữ lại cho hook dùng sau.

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed'; platform: string }>;
}

export type InstallPlatform = 'prompt' | 'ios-safari' | 'ios-other' | 'unsupported';

export interface PwaState {
  /** Đang chạy như app đã cài (màn hình chính / cửa sổ riêng). */
  isStandalone: boolean;
  /** Vừa cài xong trong phiên này (appinstalled). */
  justInstalled: boolean;
  /** Cách cài phù hợp với trình duyệt hiện tại. */
  platform: InstallPlatform;
  isOnline: boolean;
}

const DISMISS_KEY = 'ch-install-dismissed-at';
const DISMISS_DAYS = 7;

let deferredPrompt: BeforeInstallPromptEvent | null = null;
const listeners = new Set<() => void>();

function detectStandalone() {
  if (typeof window === 'undefined') return false;
  const nav = window.navigator as Navigator & { standalone?: boolean };
  return window.matchMedia('(display-mode: standalone)').matches || nav.standalone === true;
}

function detectIosPlatform(): InstallPlatform | null {
  const ua = window.navigator.userAgent;
  const isIos = /iPad|iPhone|iPod/.test(ua) || (ua.includes('Macintosh') && navigator.maxTouchPoints > 1);
  if (!isIos) return null;
  // Trên iOS chỉ Safari mới có "Thêm vào MH chính" cho PWA đầy đủ.
  const isOtherBrowser = /CriOS|FxiOS|EdgiOS|OPiOS|GSA\//.test(ua);
  return isOtherBrowser ? 'ios-other' : 'ios-safari';
}

let state: PwaState = {
  isStandalone: typeof window !== 'undefined' ? detectStandalone() : false,
  justInstalled: false,
  platform: 'unsupported',
  isOnline: typeof navigator !== 'undefined' ? navigator.onLine : true,
};

function setState(patch: Partial<PwaState>) {
  state = { ...state, ...patch };
  listeners.forEach((listener) => listener());
}

function resolvePlatform(): InstallPlatform {
  if (deferredPrompt) return 'prompt';
  return detectIosPlatform() ?? 'unsupported';
}

export function getPwaState() {
  return state;
}

export function subscribePwa(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/** Mở hộp thoại cài đặt của trình duyệt (Android / Chrome / Edge). */
export async function promptInstall(): Promise<'accepted' | 'dismissed' | 'unavailable'> {
  const event = deferredPrompt;
  if (!event) return 'unavailable';
  deferredPrompt = null;
  await event.prompt();
  const choice = await event.userChoice;
  setState({ platform: resolvePlatform() });
  return choice.outcome;
}

export function wasInstallDismissedRecently() {
  try {
    const raw = window.localStorage.getItem(DISMISS_KEY);
    if (!raw) return false;
    const at = Number(raw);
    return Number.isFinite(at) && Date.now() - at < DISMISS_DAYS * 86_400_000;
  } catch {
    return false;
  }
}

export function rememberInstallDismissed() {
  try {
    window.localStorage.setItem(DISMISS_KEY, String(Date.now()));
  } catch {
    // Không lưu được thì lần sau gợi ý lại, không ảnh hưởng gì khác.
  }
}

export function initPwa() {
  if (typeof window === 'undefined') return;

  state = { ...state, platform: resolvePlatform() };

  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    deferredPrompt = event as BeforeInstallPromptEvent;
    setState({ platform: 'prompt' });
  });

  window.addEventListener('appinstalled', () => {
    deferredPrompt = null;
    setState({ justInstalled: true, platform: resolvePlatform() });
  });

  window.matchMedia('(display-mode: standalone)').addEventListener('change', () => {
    setState({ isStandalone: detectStandalone() });
  });

  window.addEventListener('online', () => setState({ isOnline: true }));
  window.addEventListener('offline', () => setState({ isOnline: false }));

  document.documentElement.toggleAttribute('data-standalone', state.isStandalone);

  // Chỉ đăng ký service worker ở bản build; khi dev, Vite cần nạp file trực tiếp.
  if ('serviceWorker' in navigator && import.meta.env.PROD) {
    window.addEventListener('load', () => {
      void navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch(() => {
        // Không đăng ký được thì app vẫn chạy bình thường như web.
      });
    });
  }
}
