export function getCurrentMonthValue(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

export function monthValueToDate(monthValue: string) {
  const [yearText, monthText] = monthValue.split('-');
  const year = Number(yearText);
  const month = Number(monthText);

  if (!Number.isFinite(year) || !Number.isFinite(month)) {
    return new Date();
  }

  return new Date(year, month - 1, 1);
}

export function shiftMonthValue(monthValue: string, delta: number) {
  const date = monthValueToDate(monthValue);
  date.setMonth(date.getMonth() + delta);
  return getCurrentMonthValue(date);
}

export function getMonthRange(monthValue: string) {
  const date = monthValueToDate(monthValue);
  const year = date.getFullYear();
  const month = date.getMonth();
  const start = new Date(year, month, 1);
  const end = new Date(year, month + 1, 0);

  return {
    startDate: `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}-01`,
    endDate: `${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, '0')}-${String(end.getDate()).padStart(2, '0')}`,
  };
}

export function formatVietnameseMonth(value: string | Date) {
  const date = typeof value === 'string' ? monthValueToDate(value) : value;
  return `Tháng ${date.getMonth() + 1}, ${date.getFullYear()}`;
}

export function isDisplayDateInMonth(value: string | undefined, monthValue: string) {
  if (!value) return false;

  const cleanValue = value.trim();
  if (!cleanValue || cleanValue === '#') return false;
  if (/^\d{4}-\d{2}/.test(cleanValue)) return cleanValue.startsWith(monthValue);

  const [, selectedMonthText] = monthValue.split('-');
  const selectedMonth = Number(selectedMonthText);
  const compactDateMatch = cleanValue.match(/\b\d{1,2}\/(\d{1,2})(?:\/(\d{2,4}))?\b/);

  if (!compactDateMatch) return false;
  return Number(compactDateMatch[1]) === selectedMonth;
}
