import { useCallback, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { MonthContext } from './monthContext';
import { getCurrentMonthValue, shiftMonthValue } from '../utils/month';

function normalizeMonthValue(monthValue: string) {
  return /^\d{4}-\d{2}$/.test(monthValue) ? monthValue : getCurrentMonthValue();
}

export function MonthProvider({ children }: { children: ReactNode }) {
  const [selectedMonth, setSelectedMonthState] = useState(() => getCurrentMonthValue());

  const setSelectedMonth = useCallback((monthValue: string) => {
    setSelectedMonthState(normalizeMonthValue(monthValue));
  }, []);

  const goToPreviousMonth = useCallback(() => {
    setSelectedMonthState((current) => shiftMonthValue(current, -1));
  }, []);

  const goToNextMonth = useCallback(() => {
    setSelectedMonthState((current) => shiftMonthValue(current, 1));
  }, []);

  const goToCurrentMonth = useCallback(() => {
    setSelectedMonthState(getCurrentMonthValue());
  }, []);

  const value = useMemo(() => ({
    selectedMonth,
    setSelectedMonth,
    goToPreviousMonth,
    goToNextMonth,
    goToCurrentMonth,
  }), [goToCurrentMonth, goToNextMonth, goToPreviousMonth, selectedMonth, setSelectedMonth]);

  return (
    <MonthContext.Provider value={value}>
      {children}
    </MonthContext.Provider>
  );
}
