import { useState } from 'react';
import { ChevronLeft, Moon, Sun, Bell, Download, ChevronRight, Users, Tag } from 'lucide-react';
import { AppSettings, DayOfWeek } from '../types/settings';
import { Contact } from '../types/contact';
import { ManageGroups } from './ManageGroups';
import { ManageTags } from './ManageTags';

interface SettingsProps {
  settings: AppSettings;
  onBack: () => void;
  onUpdateSettings: (settings: AppSettings) => void;
  contacts: Contact[];
  onUpdateContacts: (contacts: Contact[]) => void;
}

const daysOfWeek: DayOfWeek[] = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

export function Settings({ settings, onBack, onUpdateSettings, contacts, onUpdateContacts }: SettingsProps) {
  const [showTimeSelector, setShowTimeSelector] = useState(false);
  const [showDaySelector, setShowDaySelector] = useState(false);
  const [showManageGroups, setShowManageGroups] = useState(false);
  const [showManageTags, setShowManageTags] = useState(false);

  const handleToggleTheme = () => {
    onUpdateSettings({
      ...settings,
      theme: settings.theme === 'dark' ? 'light' : 'dark',
    });
  };

  const handleToggleNotifications = () => {
    onUpdateSettings({
      ...settings,
      notifications: {
        ...settings.notifications,
        enabled: !settings.notifications.enabled,
      },
    });
  };

  const handleToggleWeeklyDigest = () => {
    onUpdateSettings({
      ...settings,
      notifications: {
        ...settings.notifications,
        weeklyDigestEnabled: !settings.notifications.weeklyDigestEnabled,
      },
    });
  };

  const handleSetTime = (time: string) => {
    onUpdateSettings({
      ...settings,
      notifications: {
        ...settings.notifications,
        dailyBreachTime: time,
      },
    });
    setShowTimeSelector(false);
  };

  const handleSetDay = (day: DayOfWeek) => {
    onUpdateSettings({
      ...settings,
      notifications: {
        ...settings.notifications,
        weeklyDigestDay: day,
      },
    });
    setShowDaySelector(false);
  };

  const handleExportData = () => {
    const dataStr = JSON.stringify(contacts, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `contacts-export-${new Date().toISOString().split('T')[0]}.json`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const isDark = settings.theme === 'dark';
  const textPrimary = isDark ? 'text-white' : 'text-black';
  const textSecondary = isDark ? 'text-[#8E8E93]' : 'text-[#6B6B6B]';
  const bgPrimary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const bgSecondary = isDark ? 'bg-[#1C1C1E]' : 'bg-[#F2F2F7]';
  const bgTertiary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const borderColor = isDark ? 'border-[#1C1C1E]' : 'border-[#E5E5EA]';
  const dividerColor = isDark ? 'divide-[#2C2C2E]' : 'divide-[#E5E5EA]';
  const btnActive = isDark ? 'active:bg-[#2C2C2E]' : 'active:bg-[#E5E5EA]';

  const timeOptions = [
    '06:00', '07:00', '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
    '20:00', '21:00', '22:00'
  ];

  if (showManageGroups) {
    return (
      <ManageGroups
        settings={settings}
        onBack={() => setShowManageGroups(false)}
        onUpdateSettings={onUpdateSettings}
        contacts={contacts}
        onUpdateContacts={onUpdateContacts}
      />
    );
  }

  if (showManageTags) {
    return (
      <ManageTags
        settings={settings}
        onBack={() => setShowManageTags(false)}
        onUpdateSettings={onUpdateSettings}
        contacts={contacts}
        onUpdateContacts={onUpdateContacts}
      />
    );
  }

  return (
    <div className={`h-full flex flex-col ${bgPrimary}`}>
      {/* Header */}
      <div className={`px-4 pt-3 pb-4 border-b ${borderColor}`}>
        <button 
          onClick={onBack}
          className="flex items-center gap-1 text-[#0A84FF] text-[17px] active:opacity-50 mb-4"
        >
          <ChevronLeft className="w-5 h-5" />
          <span>Back</span>
        </button>
        <h1 className={`text-[34px] ${textPrimary} tracking-tight`}>Settings</h1>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-5 py-5 space-y-6">
        {/* Appearance */}
        <div>
          <div className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 px-1`}>
            Appearance
          </div>
          <div className={`${bgSecondary} rounded-[12px] overflow-hidden`}>
            <button
              onClick={handleToggleTheme}
              className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
            >
              {settings.theme === 'dark' ? (
                <Moon className="w-5 h-5 text-[#0A84FF]" />
              ) : (
                <Sun className="w-5 h-5 text-[#FF9500]" />
              )}
              <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>
                {settings.theme === 'dark' ? 'Dark Mode' : 'Light Mode'}
              </span>
              <div
                className={`w-[51px] h-[31px] rounded-full p-[2px] transition-colors ${
                  settings.theme === 'dark' ? 'bg-[#34C759]' : 'bg-[#E5E5EA]'
                }`}
              >
                <div
                  className={`w-[27px] h-[27px] rounded-full bg-white transition-transform ${
                    settings.theme === 'dark' ? 'translate-x-[20px]' : 'translate-x-0'
                  }`}
                />
              </div>
            </button>
          </div>
        </div>

        {/* Groups */}
        <div>
          <div className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 px-1`}>
            Cadence Groups
          </div>
          <div className={`${bgSecondary} rounded-[12px] overflow-hidden`}>
            <button
              onClick={() => setShowManageGroups(true)}
              className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
            >
              <Users className="w-5 h-5 text-[#0A84FF]" />
              <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>
                Manage Groups
              </span>
              <div className="flex items-center gap-2">
                <span className={`text-[15px] ${textSecondary}`}>
                  {settings.groups.length}
                </span>
                <ChevronRight className={`w-5 h-5 ${textSecondary}`} />
              </div>
            </button>
          </div>
        </div>

        {/* Tags */}
        <div>
          <div className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 px-1`}>
            Tags
          </div>
          <div className={`${bgSecondary} rounded-[12px] overflow-hidden`}>
            <button
              onClick={() => setShowManageTags(true)}
              className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
            >
              <Tag className="w-5 h-5 text-[#0A84FF]" />
              <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>
                Manage Tags
              </span>
              <div className="flex items-center gap-2">
                <span className={`text-[15px] ${textSecondary}`}>
                  {settings.tags.length}
                </span>
                <ChevronRight className={`w-5 h-5 ${textSecondary}`} />
              </div>
            </button>
          </div>
        </div>

        {/* Notifications */}
        <div>
          <div className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 px-1`}>
            Notifications
          </div>
          <div className={`${bgSecondary} rounded-[12px] overflow-hidden ${dividerColor} divide-y`}>
            <button
              onClick={handleToggleNotifications}
              className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
            >
              <Bell className="w-5 h-5 text-[#FF9500]" />
              <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>
                Daily Breach Alerts
              </span>
              <div
                className={`w-[51px] h-[31px] rounded-full p-[2px] transition-colors ${
                  settings.notifications.enabled ? 'bg-[#34C759]' : 'bg-[#E5E5EA]'
                }`}
              >
                <div
                  className={`w-[27px] h-[27px] rounded-full bg-white transition-transform ${
                    settings.notifications.enabled ? 'translate-x-[20px]' : 'translate-x-0'
                  }`}
                />
              </div>
            </button>

            {settings.notifications.enabled && (
              <button
                onClick={() => setShowTimeSelector(true)}
                className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
              >
                <div className="w-5"></div>
                <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>
                  Alert Time
                </span>
                <div className="flex items-center gap-2">
                  <span className={`text-[17px] ${textSecondary}`}>
                    {settings.notifications.dailyBreachTime}
                  </span>
                  <ChevronRight className={`w-5 h-5 ${textSecondary}`} />
                </div>
              </button>
            )}

            <button
              onClick={handleToggleWeeklyDigest}
              className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
            >
              <Bell className="w-5 h-5 text-[#0A84FF]" />
              <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>
                Weekly Digest
              </span>
              <div
                className={`w-[51px] h-[31px] rounded-full p-[2px] transition-colors ${
                  settings.notifications.weeklyDigestEnabled ? 'bg-[#34C759]' : 'bg-[#E5E5EA]'
                }`}
              >
                <div
                  className={`w-[27px] h-[27px] rounded-full bg-white transition-transform ${
                    settings.notifications.weeklyDigestEnabled ? 'translate-x-[20px]' : 'translate-x-0'
                  }`}
                />
              </div>
            </button>

            {settings.notifications.weeklyDigestEnabled && (
              <button
                onClick={() => setShowDaySelector(true)}
                className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
              >
                <div className="w-5"></div>
                <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>
                  Digest Day
                </span>
                <div className="flex items-center gap-2">
                  <span className={`text-[17px] ${textSecondary}`}>
                    {settings.notifications.weeklyDigestDay}
                  </span>
                  <ChevronRight className={`w-5 h-5 ${textSecondary}`} />
                </div>
              </button>
            )}
          </div>
        </div>

        {/* Data */}
        <div>
          <div className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 px-1`}>
            Data
          </div>
          <div className={`${bgSecondary} rounded-[12px] overflow-hidden`}>
            <button
              onClick={handleExportData}
              className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
            >
              <Download className="w-5 h-5 text-[#0A84FF]" />
              <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>
                Export Contacts
              </span>
              <ChevronRight className={`w-5 h-5 ${textSecondary}`} />
            </button>
          </div>
        </div>

        {/* About */}
        <div className={`text-center ${textSecondary} text-[13px] pb-6`}>
          <p>Stay in Touch v1.0</p>
          <p className="mt-1">Privacy-first personal CRM</p>
        </div>
      </div>

      {/* Time Selector Modal */}
      {showTimeSelector && (
        <div className="absolute inset-0 bg-black/60 flex items-end backdrop-blur-sm">
          <div className={`w-full ${bgSecondary} rounded-t-[20px] max-h-[70%] flex flex-col`}>
            <div className={`px-5 py-4 border-b ${borderColor} flex items-center justify-between`}>
              <button 
                onClick={() => setShowTimeSelector(false)}
                className="text-[17px] text-[#0A84FF] active:opacity-50"
              >
                Cancel
              </button>
              <h3 className={`text-[17px] ${textPrimary} font-medium`}>Alert Time</h3>
              <div className="w-[60px]"></div>
            </div>

            <div className="flex-1 overflow-y-auto p-5">
              <div className={`${bgTertiary} rounded-[12px] overflow-hidden ${dividerColor} divide-y`}>
                {timeOptions.map((time) => (
                  <button
                    key={time}
                    onClick={() => handleSetTime(time)}
                    className={`w-full px-4 py-3 flex items-center justify-between ${btnActive} transition-colors`}
                  >
                    <span className={`text-[17px] ${textPrimary}`}>{time}</span>
                    {settings.notifications.dailyBreachTime === time && (
                      <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                    )}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Day Selector Modal */}
      {showDaySelector && (
        <div className="absolute inset-0 bg-black/60 flex items-end backdrop-blur-sm">
          <div className={`w-full ${bgSecondary} rounded-t-[20px] max-h-[70%] flex flex-col`}>
            <div className={`px-5 py-4 border-b ${borderColor} flex items-center justify-between`}>
              <button 
                onClick={() => setShowDaySelector(false)}
                className="text-[17px] text-[#0A84FF] active:opacity-50"
              >
                Cancel
              </button>
              <h3 className={`text-[17px] ${textPrimary} font-medium`}>Digest Day</h3>
              <div className="w-[60px]"></div>
            </div>

            <div className="flex-1 overflow-y-auto p-5">
              <div className={`${bgTertiary} rounded-[12px] overflow-hidden ${dividerColor} divide-y`}>
                {daysOfWeek.map((day) => (
                  <button
                    key={day}
                    onClick={() => handleSetDay(day)}
                    className={`w-full px-4 py-3 flex items-center justify-between ${btnActive} transition-colors`}
                  >
                    <span className={`text-[17px] ${textPrimary}`}>{day}</span>
                    {settings.notifications.weeklyDigestDay === day && (
                      <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                    )}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}