import { useOutletContext } from 'react-router-dom';
import type { useNotifications } from '../../hooks/useNotifications';

export interface AppOutletContext {
  notifications: ReturnType<typeof useNotifications>;
  openInstall: () => void;
}

export function useAppOutlet() {
  return useOutletContext<AppOutletContext>();
}
