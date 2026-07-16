export function normalizeHttpUrl(value: string) {
  const cleanValue = value.trim();

  if (!cleanValue || cleanValue === '#') {
    throw new Error('Link chưa đúng định dạng URL. Vui lòng dùng link bắt đầu bằng http:// hoặc https://.');
  }

  try {
    const url = new URL(cleanValue);
    if (url.protocol === 'http:' || url.protocol === 'https:') {
      return cleanValue;
    }
  } catch {
    // Fall through to the shared user-facing validation error below.
  }

  throw new Error('Link chưa đúng định dạng URL. Vui lòng dùng link bắt đầu bằng http:// hoặc https://.');
}

export function normalizeOptionalHttpUrl(value: string) {
  const cleanValue = value.trim();
  if (!cleanValue || cleanValue === '#') return null;
  return normalizeHttpUrl(cleanValue);
}

export function isSafeHttpUrl(value: string) {
  try {
    normalizeHttpUrl(value);
    return true;
  } catch {
    return false;
  }
}
