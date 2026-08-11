import { useState, useCallback } from 'react';

export type IOSTab = 'dashboard' | 'tasks' | 'calendar' | 'content_plan' | 'users' | 'profile' | 'login';
export type PrototypeStateMode = 'default' | 'loading' | 'empty' | 'error';
export type IOSSheetType = 
  | null 
  | 'task_detail' 
  | 'task_create' 
  | 'shoot_detail' 
  | 'shoot_create' 
  | 'content_plan_detail' 
  | 'user_detail' 
  | 'profile_edit' 
  | 'password_edit'
  | 'more_menu';

export function useIOSState() {
  const [currentTab, setCurrentTab] = useState<IOSTab>('dashboard');
  const [prototypeMode, setPrototypeMode] = useState<PrototypeStateMode>('default');
  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => document.documentElement.classList.contains('dark'));
  const [viewScale, setViewScale] = useState<'normal' | 'fit'>('normal');
  
  const [activeSheet, setActiveSheet] = useState<IOSSheetType>(null);
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(1);
  const [selectedShootId, setSelectedShootId] = useState<string | null>('s1');
  const [selectedContentPlanId, setSelectedContentPlanId] = useState<string | null>(null);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedTaskFilter, setSelectedTaskFilter] = useState<string>('all');
  const [selectedMonth, setSelectedMonth] = useState<string>('2026-07');

  const toggleDarkMode = useCallback(() => {
    setIsDarkMode((prev) => {
      const next = !prev;
      if (next) {
        document.documentElement.classList.add('dark');
      } else {
        document.documentElement.classList.remove('dark');
      }
      return next;
    });
  }, []);

  const openSheet = useCallback((sheet: IOSSheetType, id?: number | string) => {
    if (typeof id === 'number') {
      setSelectedTaskId(id);
    } else if (typeof id === 'string') {
      if (sheet === 'shoot_detail') setSelectedShootId(id);
      else if (sheet === 'content_plan_detail') setSelectedContentPlanId(id);
      else if (sheet === 'user_detail') setSelectedUserId(id);
    }
    setActiveSheet(sheet);
  }, []);

  const closeSheet = useCallback(() => {
    setActiveSheet(null);
  }, []);

  return {
    currentTab,
    setCurrentTab,
    prototypeMode,
    setPrototypeMode,
    isDarkMode,
    toggleDarkMode,
    viewScale,
    setViewScale,
    activeSheet,
    openSheet,
    closeSheet,
    selectedTaskId,
    selectedShootId,
    selectedContentPlanId,
    selectedUserId,
    searchQuery,
    setSearchQuery,
    selectedTaskFilter,
    setSelectedTaskFilter,
    selectedMonth,
    setSelectedMonth,
  };
}

export type IOSStateReturn = ReturnType<typeof useIOSState>;
