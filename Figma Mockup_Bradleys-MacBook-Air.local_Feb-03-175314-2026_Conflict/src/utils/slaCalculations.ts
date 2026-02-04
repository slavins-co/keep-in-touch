import { Contact, SLAStatus, SLAGroup } from '../types/contact';

export function getDaysSinceContact(lastContacted: Date, today: Date = new Date()): number {
  const diff = today.getTime() - lastContacted.getTime();
  return Math.floor(diff / (1000 * 60 * 60 * 24));
}

export function getSLAStatus(contact: Contact, groups: SLAGroup[], today: Date = new Date()): SLAStatus {
  if (contact.isPaused) return 'in-sla';
  
  const group = groups.find(g => g.id === contact.slaGroup);
  if (!group) return 'in-sla';
  
  const daysSince = getDaysSinceContact(contact.lastContacted, today);
  
  if (daysSince >= group.days) {
    return 'out-of-sla';
  } else if (daysSince >= group.days - group.warningDays) {
    return 'due-soon';
  }
  return 'in-sla';
}

export function getDaysOverdue(contact: Contact, groups: SLAGroup[], today: Date = new Date()): number {
  const group = groups.find(g => g.id === contact.slaGroup);
  if (!group) return 0;
  
  const daysSince = getDaysSinceContact(contact.lastContacted, today);
  return Math.max(0, daysSince - group.days);
}

export function getStatusColor(status: SLAStatus): string {
  switch (status) {
    case 'in-sla':
      return '#34C759'; // Green
    case 'due-soon':
      return '#FF9500'; // Orange
    case 'out-of-sla':
      return '#FF3B30'; // Red
  }
}

export function getStatusLabel(status: SLAStatus): string {
  switch (status) {
    case 'in-sla':
      return 'All good';
    case 'due-soon':
      return 'Check in soon';
    case 'out-of-sla':
      return 'Overdue catch-up';
  }
}

export function formatLastContact(lastContacted: Date, today: Date = new Date()): string {
  const days = getDaysSinceContact(lastContacted, today);
  
  if (days === 0) return 'Today';
  if (days === 1) return 'Yesterday';
  if (days < 7) return `${days}d ago`;
  if (days < 30) return `${Math.floor(days / 7)}w ago`;
  return `${Math.floor(days / 30)}mo ago`;
}
