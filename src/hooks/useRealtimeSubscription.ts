import { useEffect, useRef } from 'react';
import { supabase } from '../lib/supabase';

export type RealtimeTable = 'video_tasks' | 'shoots' | 'shoot_editors' | 'content_plan';

interface UseRealtimeSubscriptionOptions {
  tables: RealtimeTable[];
  onChange: () => void | Promise<void>;
  enabled?: boolean;
  debounceMs?: number;
  channelName?: string;
}

export function useRealtimeSubscription({
  tables,
  onChange,
  enabled = true,
  debounceMs = 350,
  channelName,
}: UseRealtimeSubscriptionOptions) {
  const tablesKey = tables.join('|');
  const onChangeRef = useRef(onChange);

  useEffect(() => {
    onChangeRef.current = onChange;
  }, [onChange]);

  useEffect(() => {
    if (!enabled || !supabase || !tablesKey) return;

    const client = supabase;
    const subscribedTables = tablesKey.split('|').filter(Boolean) as RealtimeTable[];
    const resolvedChannelName = channelName ?? `public-db-${tablesKey.replace(/\|/g, '-')}`;
    let isMounted = true;
    let timeoutId: ReturnType<typeof setTimeout> | null = null;

    const scheduleRefetch = () => {
      if (!isMounted) return;

      if (timeoutId) {
        clearTimeout(timeoutId);
      }

      timeoutId = setTimeout(() => {
        if (!isMounted) return;
        void onChangeRef.current();
      }, debounceMs);
    };

    const channel = client.channel(resolvedChannelName);

    subscribedTables.forEach((table) => {
      channel.on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table,
        },
        scheduleRefetch
      );
    });

    channel.subscribe();

    return () => {
      isMounted = false;

      if (timeoutId) {
        clearTimeout(timeoutId);
      }

      void client.removeChannel(channel);
    };
  }, [channelName, debounceMs, enabled, tablesKey]);
}
