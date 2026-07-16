import { useCallback, useEffect, useRef, useState } from 'react';
import { PRODUCT_UPDATE } from '../config/productUpdates';

export const WHATS_NEW_RELEASE_KEY = PRODUCT_UPDATE.key;

const WHATS_NEW_STORAGE_PREFIX = 'creativehub_whats_new';
const SEEN_VALUE = 'seen';

export function getWhatsNewStorageKey(profileId: string) {
  return `${WHATS_NEW_STORAGE_PREFIX}_${WHATS_NEW_RELEASE_KEY}_${profileId}`;
}

function readSeenMarker(storageKey: string) {
  try {
    return window.localStorage.getItem(storageKey) === SEEN_VALUE;
  } catch {
    return false;
  }
}

function writeSeenMarker(storageKey: string) {
  try {
    window.localStorage.setItem(storageKey, SEEN_VALUE);
  } catch {
    // The modal should still close if browser storage is unavailable.
  }
}

export function useWhatsNewOnboarding(profileId: string | null | undefined) {
  const [isOpen, setIsOpen] = useState(false);
  const evaluatedProfileIdRef = useRef<string | null>(null);
  const storageKey = profileId ? getWhatsNewStorageKey(profileId) : null;

  useEffect(() => {
    if (!profileId || !storageKey) {
      evaluatedProfileIdRef.current = null;
      setIsOpen(false);
      return;
    }

    if (evaluatedProfileIdRef.current === profileId) return;
    evaluatedProfileIdRef.current = profileId;

    if (!readSeenMarker(storageKey)) {
      setIsOpen(true);
    }
  }, [profileId, storageKey]);

  const close = useCallback(() => {
    if (storageKey) writeSeenMarker(storageKey);
    setIsOpen(false);
  }, [storageKey]);

  const openManually = useCallback(() => {
    if (!profileId) return;
    setIsOpen(true);
  }, [profileId]);

  return {
    isOpen,
    close,
    openManually,
    storageKey,
  };
}
