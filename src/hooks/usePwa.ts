import { useSyncExternalStore } from 'react';
import { getPwaState, subscribePwa } from '../pwa/pwa';

export function usePwa() {
  return useSyncExternalStore(subscribePwa, getPwaState, getPwaState);
}
