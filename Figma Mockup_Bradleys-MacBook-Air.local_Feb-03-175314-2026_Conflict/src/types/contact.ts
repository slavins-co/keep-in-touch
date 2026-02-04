export type TouchMethod = 'Text' | 'Call' | 'IRL' | 'Email' | 'Other';

export type SLAStatus = 'in-sla' | 'due-soon' | 'out-of-sla';

export interface Tag {
  id: string;
  name: string;
  color: string;
}

export interface TouchLog {
  id: string;
  date: Date;
  method: TouchMethod;
  notes?: string;
}

export interface Contact {
  id: string;
  name: string;
  initials: string;
  color: string;
  slaGroup: string; // Changed to string to support custom groups
  lastContacted: Date;
  lastTouchMethod?: TouchMethod;
  notes?: string;
  isPaused?: boolean;
  tags?: string[]; // Array of tag IDs
  // Full history log
  history: TouchLog[];
  // Optional contact methods for quick actions
  phone?: string;
  email?: string;
}

export interface SLAGroup {
  id: string;
  name: string;
  days: number;
  warningDays: number; // Days before breach to show "due soon"
  isDefault?: boolean; // Can't be deleted if true
}