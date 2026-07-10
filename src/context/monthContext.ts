import { createContext, useContext } from 'react';

export interface MonthContextValue {
  selectedMonth: string;
  setSelectedMonth: (monthValue: string) => void;
  goToPreviousMonth: () => void;
  goToNextMonth: () => void;
  goToCurrentMonth: () => void;
}

export const MonthContext = createContext<MonthContextValue>({
  selectedMonth: '',
  setSelectedMonth: () => {},
  goToPreviousMonth: () => {},
  goToNextMonth: () => {},
  goToCurrentMonth: () => {},
});

export function useMonth() {
  return useContext(MonthContext);
}
