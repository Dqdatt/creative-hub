import { useEffect } from 'react';

let activeLocks = 0;
let previousBodyOverflow = '';
let previousHtmlOverflow = '';

function lockDocumentScroll() {
  if (activeLocks === 0) {
    previousBodyOverflow = document.body.style.overflow;
    previousHtmlOverflow = document.documentElement.style.overflow;
    document.body.style.overflow = 'hidden';
    document.documentElement.style.overflow = 'hidden';
  }

  activeLocks += 1;
}

function unlockDocumentScroll() {
  activeLocks = Math.max(0, activeLocks - 1);

  if (activeLocks === 0) {
    document.body.style.overflow = previousBodyOverflow;
    document.documentElement.style.overflow = previousHtmlOverflow;
  }
}

export function useDocumentScrollLock(isLocked: boolean) {
  useEffect(() => {
    if (!isLocked) return undefined;

    lockDocumentScroll();
    return unlockDocumentScroll;
  }, [isLocked]);
}
