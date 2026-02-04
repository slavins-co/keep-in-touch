import { useState } from 'react';
import { ContactList } from './components/ContactList';
import { ContactDetail } from './components/ContactDetail';
import { Settings } from './components/Settings';
import { Contact } from './types/contact';
import { AppSettings, DEFAULT_SETTINGS } from './types/settings';

// Mock contact data with history
const initialContacts: Contact[] = [
  {
    id: '1',
    name: 'Sarah Chen',
    initials: 'SC',
    color: '#FF6B6B',
    slaGroup: 'weekly',
    lastContacted: new Date('2026-01-18T14:30:00'),
    lastTouchMethod: 'Call',
    notes: 'Discussed project updates',
    phone: '+1 (555) 123-4567',
    email: 'sarah@example.com',
    tags: ['work', 'friend'],
    history: [
      {
        id: 'h1-3',
        date: new Date('2026-01-18T14:30:00'),
        method: 'Call',
        notes: 'Discussed project updates',
      },
      {
        id: 'h1-2',
        date: new Date('2026-01-11T10:00:00'),
        method: 'Text',
        notes: 'Quick check-in about weekend plans',
      },
      {
        id: 'h1-1',
        date: new Date('2026-01-04T16:45:00'),
        method: 'IRL',
        notes: 'Coffee at the new cafe downtown',
      },
    ],
  },
  {
    id: '2',
    name: 'Mike Rodriguez',
    initials: 'MR',
    color: '#4ECDC4',
    slaGroup: 'weekly',
    lastContacted: new Date('2026-01-10T10:00:00'),
    lastTouchMethod: 'IRL',
    notes: 'Coffee at Blue Bottle',
    phone: '+1 (555) 234-5678',
    tags: ['work'],
    history: [
      {
        id: 'h2-2',
        date: new Date('2026-01-10T10:00:00'),
        method: 'IRL',
        notes: 'Coffee at Blue Bottle',
      },
      {
        id: 'h2-1',
        date: new Date('2026-01-03T14:00:00'),
        method: 'Call',
      },
    ],
  },
  {
    id: '3',
    name: 'Emily Watson',
    initials: 'EW',
    color: '#95E1D3',
    slaGroup: 'bi-weekly',
    lastContacted: new Date('2026-01-15T16:45:00'),
    lastTouchMethod: 'Text',
    email: 'emily@example.com',
    tags: ['friend'],
    history: [
      {
        id: 'h3-1',
        date: new Date('2026-01-15T16:45:00'),
        method: 'Text',
      },
    ],
  },
  {
    id: '4',
    name: 'James Park',
    initials: 'JP',
    color: '#F38181',
    slaGroup: 'bi-weekly',
    lastContacted: new Date('2026-01-01T12:00:00'),
    lastTouchMethod: 'Email',
    notes: 'Sent holiday greetings',
    email: 'james@example.com',
    history: [
      {
        id: 'h4-2',
        date: new Date('2026-01-01T12:00:00'),
        method: 'Email',
        notes: 'Sent holiday greetings',
      },
      {
        id: 'h4-1',
        date: new Date('2025-12-20T09:00:00'),
        method: 'Call',
        notes: 'Year-end catch-up',
      },
    ],
  },
  {
    id: '5',
    name: 'Lisa Anderson',
    initials: 'LA',
    color: '#AA96DA',
    slaGroup: 'monthly',
    lastContacted: new Date('2025-12-25T18:30:00'),
    lastTouchMethod: 'Call',
    phone: '+1 (555) 345-6789',
    tags: ['family'],
    history: [
      {
        id: 'h5-1',
        date: new Date('2025-12-25T18:30:00'),
        method: 'Call',
      },
    ],
  },
  {
    id: '6',
    name: 'David Kim',
    initials: 'DK',
    color: '#FCBAD3',
    slaGroup: 'monthly',
    lastContacted: new Date('2026-01-05T09:15:00'),
    lastTouchMethod: 'Text',
    phone: '+1 (555) 456-7890',
    history: [
      {
        id: 'h6-1',
        date: new Date('2026-01-05T09:15:00'),
        method: 'Text',
      },
    ],
  },
  {
    id: '7',
    name: 'Rachel Green',
    initials: 'RG',
    color: '#FFD93D',
    slaGroup: 'quarterly',
    lastContacted: new Date('2025-11-15T14:00:00'),
    lastTouchMethod: 'IRL',
    notes: 'Dinner catch-up',
    email: 'rachel@example.com',
    history: [
      {
        id: 'h7-1',
        date: new Date('2025-11-15T14:00:00'),
        method: 'IRL',
        notes: 'Dinner catch-up',
      },
    ],
  },
  {
    id: '8',
    name: 'Tom Wilson',
    initials: 'TW',
    color: '#6BCB77',
    slaGroup: 'quarterly',
    lastContacted: new Date('2025-12-01T11:30:00'),
    lastTouchMethod: 'Email',
    email: 'tom@example.com',
    history: [
      {
        id: 'h8-1',
        date: new Date('2025-12-01T11:30:00'),
        method: 'Email',
      },
    ],
  },
];

type View = 'list' | 'detail' | 'settings';

export default function App() {
  const [contacts, setContacts] = useState<Contact[]>(initialContacts);
  const [selectedContact, setSelectedContact] = useState<Contact | null>(null);
  const [selectedGroup, setSelectedGroup] = useState<string | 'All'>('All');
  const [currentView, setCurrentView] = useState<View>('list');
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);

  const handleUpdateContact = (updatedContact: Contact) => {
    setContacts(contacts.map(c => c.id === updatedContact.id ? updatedContact : c));
    setSelectedContact(updatedContact);
  };

  const handleBack = () => {
    setCurrentView('list');
    setSelectedContact(null);
  };

  const handleOpenSettings = () => {
    setCurrentView('settings');
  };

  const handleSelectContact = (contact: Contact) => {
    setSelectedContact(contact);
    setCurrentView('detail');
  };

  const handleUpdateSettings = (newSettings: AppSettings) => {
    setSettings(newSettings);
  };

  const bgColor = settings.theme === 'dark' ? '#000000' : '#FFFFFF';
  const statusBarColor = settings.theme === 'dark' ? 'white' : 'black';

  return (
    <div className="h-screen bg-[#F2F2F7] flex items-center justify-center">
      {/* iPhone Frame */}
      <div className="relative w-[390px] h-[844px] bg-black rounded-[60px] shadow-2xl overflow-hidden">
        {/* Screen */}
        <div className="absolute inset-[12px] rounded-[48px] overflow-hidden" style={{ backgroundColor: bgColor }}>
          {/* Status Bar */}
          <div className="h-[44px] px-6 flex items-center justify-between relative z-10" style={{ backgroundColor: bgColor }}>
            <div className="text-[15px]" style={{ color: statusBarColor }}>9:41</div>
            <div className="flex items-center gap-1">
              <svg width="17" height="12" viewBox="0 0 17 12" fill="none">
                <path d="M0 2C0 0.895431 0.895431 0 2 0H4C5.10457 0 6 0.895431 6 2V10C6 11.1046 5.10457 12 4 12H2C0.895431 12 0 11.1046 0 10V2Z" fill={statusBarColor}/>
                <path d="M7 3C7 1.89543 7.89543 1 9 1H11C12.1046 1 13 1.89543 13 3V9C13 10.1046 12.1046 11 11 11H9C7.89543 11 7 10.1046 7 9V3Z" fill={statusBarColor}/>
                <path d="M14 4C14 2.89543 14.8954 2 16 2H16C16.5523 2 17 2.44772 17 3V9C17 9.55228 16.5523 10 16 10C14.8954 10 14 9.10457 14 8V4Z" fill={statusBarColor} fillOpacity="0.4"/>
              </svg>
              <svg width="17" height="12" viewBox="0 0 17 12" fill="none">
                <path fillRule="evenodd" clipRule="evenodd" d="M2.5 3C1.39543 3 0.5 3.89543 0.5 5V7C0.5 8.10457 1.39543 9 2.5 9H13.5C14.6046 9 15.5 8.10457 15.5 7V5C15.5 3.89543 14.6046 3 13.5 3H2.5ZM16.5 5.5C16.5 5.22386 16.7239 5 17 5C17.5523 5 18 5.44772 18 6C18 6.55228 17.5523 7 17 7C16.7239 7 16.5 6.77614 16.5 6.5V5.5Z" fill={statusBarColor}/>
              </svg>
            </div>
          </div>

          {/* App Content */}
          <div className="h-[calc(100%-44px)] overflow-hidden" style={{ backgroundColor: bgColor }}>
            {currentView === 'settings' ? (
              <Settings 
                settings={settings}
                onBack={handleBack}
                onUpdateSettings={handleUpdateSettings}
                contacts={contacts}
                onUpdateContacts={setContacts}
              />
            ) : currentView === 'detail' && selectedContact ? (
              <ContactDetail 
                contact={selectedContact} 
                onBack={handleBack}
                onUpdate={handleUpdateContact}
                theme={settings.theme}
                groups={settings.groups}
                tags={settings.tags}
              />
            ) : (
              <ContactList 
                contacts={contacts}
                selectedGroup={selectedGroup}
                onSelectGroup={setSelectedGroup}
                onSelectContact={handleSelectContact}
                onOpenSettings={handleOpenSettings}
                theme={settings.theme}
                groups={settings.groups}
                tags={settings.tags}
              />
            )}
          </div>
        </div>

        {/* Dynamic Island */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[126px] h-[37px] bg-black rounded-full"></div>
      </div>
    </div>
  );
}