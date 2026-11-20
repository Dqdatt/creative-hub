import { supabase } from '../lib/supabase';
import { getPwaState } from './pwa';

export type PushStatus = 'unsupported' | 'needs-install' | 'denied' | 'off' | 'on';

const VAPID_PUBLIC_KEY = 'BEq_526p9jlh9n8L3pRzKPoOZBpsqnUNGPLTuNTq1ZHR9Cz5f2pD7nxbXLFYUSPPcCDsTWIh1D9OWqwJX-TZKDM';

function supportsPush() {
  return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
}

function decodeBase64Url(value: string) {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
  return Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
}

async function registerSubscription(sub: PushSubscription) {
  const keys = sub.toJSON().keys;
  if (!supabase || !sub.endpoint || !keys?.p256dh || !keys.auth) {
    throw new Error('Thiếu thông tin đăng ký thông báo đẩy.');
  }
  const { error } = await supabase.rpc('register_web_push_subscription', {
    p_endpoint: sub.endpoint,
    p_p256dh: keys.p256dh,
    p_auth: keys.auth,
    p_user_agent: navigator.userAgent.slice(0, 300),
  });
  if (error) throw error;
}

export async function getPushStatus(): Promise<PushStatus> {
  const { isStandalone, platform } = getPwaState();
  if (!isStandalone && (platform === 'ios-safari' || platform === 'ios-other')) return 'needs-install';
  if (!supabase || !supportsPush()) return 'unsupported';
  const registration = await navigator.serviceWorker.getRegistration();
  if (!registration) return 'unsupported';
  if (Notification.permission === 'denied') return 'denied';
  if (Notification.permission === 'granted' && await registration.pushManager.getSubscription()) return 'on';
  return 'off';
}

export async function enablePush(): Promise<PushStatus> {
  if (!supabase || !supportsPush()) return 'unsupported';
  const permission = await Notification.requestPermission();
  if (permission === 'denied') return 'denied';
  if (permission !== 'granted') return 'off';

  const registration = await navigator.serviceWorker.getRegistration();
  if (!registration) return 'unsupported';
  const sub = await registration.pushManager.getSubscription() ?? await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: decodeBase64Url(VAPID_PUBLIC_KEY),
  });
  try {
    await registerSubscription(sub);
  } catch {
    await sub.unsubscribe().catch((error) => console.warn('Không thể hủy đăng ký thông báo đẩy.', error));
    throw new Error('Không thể bật thông báo đẩy.');
  }
  return 'on';
}

export async function disablePush(): Promise<void> {
  if (!supabase) throw new Error('Không thể kết nối để tắt thông báo đẩy.');
  if (!supportsPush()) return;
  const registration = await navigator.serviceWorker.getRegistration();
  const sub = await registration?.pushManager.getSubscription();
  if (!sub) return;

  try {
    const { error } = await supabase.rpc('delete_web_push_subscription', { p_endpoint: sub.endpoint });
    if (error) throw error;
  } finally {
    await sub.unsubscribe();
  }
}

export async function syncPushSubscription(): Promise<void> {
  if (!supportsPush() || Notification.permission !== 'granted') return;
  try {
    const registration = await navigator.serviceWorker.getRegistration();
    const sub = await registration?.pushManager.getSubscription();
    if (sub) await registerSubscription(sub);
  } catch (error) {
    console.warn('Không thể đồng bộ đăng ký thông báo đẩy.', error);
  }
}
