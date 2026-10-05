import { createContext, useContext } from 'react';

export type CreateKind = 'task' | 'shoot' | 'content' | 'user';

export interface MobileChromeValue {
  /** Thanh tìm kiếm + bộ lọc đang thu gọn vì người dùng lướt xuống. */
  toolbarHidden: boolean;
}

export const MobileChromeContext = createContext<MobileChromeValue>({ toolbarHidden: false });

export function useMobileChrome() {
  return useContext(MobileChromeContext);
}
