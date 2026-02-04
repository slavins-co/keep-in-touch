import { SLAGroup, Tag } from './contact';

export type Theme = 'light' | 'dark';

export type DayOfWeek = 'Monday' | 'Tuesday' | 'Wednesday' | 'Thursday' | 'Friday' | 'Saturday' | 'Sunday';

export interface AppSettings {
  theme: Theme;
  notifications: {
    enabled: boolean;
    dailyBreachTime: string; // Format: "18:00"
    weeklyDigestEnabled: boolean;
    weeklyDigestDay: DayOfWeek;
  };
  groups: SLAGroup[];
  tags: Tag[];
}

export const DEFAULT_GROUPS: SLAGroup[] = [
  { id: 'weekly', name: 'Weekly', days: 7, warningDays: 2, isDefault: true },
  { id: 'bi-weekly', name: 'Bi-Weekly', days: 14, warningDays: 3, isDefault: true },
  { id: 'monthly', name: 'Monthly', days: 30, warningDays: 5, isDefault: true },
  { id: 'quarterly', name: 'Quarterly', days: 90, warningDays: 10, isDefault: true },
];

export const DEFAULT_TAGS: Tag[] = [
  { id: 'work', name: 'Work', color: '#0A84FF' },
  { id: 'family', name: 'Family', color: '#FF3B30' },
  { id: 'friend', name: 'Friend', color: '#34C759' },
  { id: 'mentor', name: 'Mentor', color: '#FF9500' },
];

export const DEFAULT_SETTINGS: AppSettings = {
  theme: 'dark',
  notifications: {
    enabled: true,
    dailyBreachTime: '18:00',
    weeklyDigestEnabled: true,
    weeklyDigestDay: 'Friday',
  },
  groups: DEFAULT_GROUPS,
  tags: DEFAULT_TAGS,
};