import { useState } from 'react';
import { ChevronLeft, Plus, Trash2, Edit3 } from 'lucide-react';
import { AppSettings } from '../types/settings';
import { Contact, SLAGroup } from '../types/contact';

interface ManageGroupsProps {
  settings: AppSettings;
  onBack: () => void;
  onUpdateSettings: (settings: AppSettings) => void;
  contacts: Contact[];
  onUpdateContacts: (contacts: Contact[]) => void;
}

export function ManageGroups({ settings, onBack, onUpdateSettings, contacts, onUpdateContacts }: ManageGroupsProps) {
  const [editingGroup, setEditingGroup] = useState<SLAGroup | null>(null);
  const [groupName, setGroupName] = useState('');
  const [groupDays, setGroupDays] = useState('');
  const [groupWarningDays, setGroupWarningDays] = useState('');
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null);

  const isDark = settings.theme === 'dark';
  const textPrimary = isDark ? 'text-white' : 'text-black';
  const textSecondary = isDark ? 'text-[#8E8E93]' : 'text-[#6B6B6B]';
  const bgPrimary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const bgSecondary = isDark ? 'bg-[#1C1C1E]' : 'bg-[#F2F2F7]';
  const bgTertiary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const borderColor = isDark ? 'border-[#1C1C1E]' : 'border-[#E5E5EA]';
  const dividerColor = isDark ? 'divide-[#2C2C2E]' : 'divide-[#E5E5EA]';
  const btnActive = isDark ? 'active:bg-[#2C2C2E]' : 'active:bg-[#E5E5EA]';

  const handleStartEdit = (group: SLAGroup) => {
    setEditingGroup(group);
    setGroupName(group.name);
    setGroupDays(group.days.toString());
    setGroupWarningDays(group.warningDays.toString());
  };

  const handleStartAdd = () => {
    setEditingGroup({ id: '', name: '', days: 0, warningDays: 0 } as SLAGroup);
    setGroupName('');
    setGroupDays('');
    setGroupWarningDays('');
  };

  const handleSave = () => {
    if (!groupName || !groupDays || !groupWarningDays) return;

    const days = parseInt(groupDays);
    const warningDays = parseInt(groupWarningDays);

    if (days <= 0 || warningDays < 0 || warningDays >= days) return;

    if (editingGroup?.id) {
      // Edit existing group
      const updatedGroups = settings.groups.map(g =>
        g.id === editingGroup.id
          ? { ...g, name: groupName, days, warningDays }
          : g
      );
      onUpdateSettings({ ...settings, groups: updatedGroups });
    } else {
      // Add new group
      const newGroup: SLAGroup = {
        id: `group-${Date.now()}`,
        name: groupName,
        days,
        warningDays,
      };
      onUpdateSettings({ ...settings, groups: [...settings.groups, newGroup] });
    }

    setEditingGroup(null);
    setGroupName('');
    setGroupDays('');
    setGroupWarningDays('');
  };

  const handleDelete = (groupId: string) => {
    const group = settings.groups.find(g => g.id === groupId);
    if (group?.isDefault) return; // Can't delete default groups

    // Check if any contacts use this group
    const affectedContacts = contacts.filter(c => c.slaGroup === groupId);
    
    if (affectedContacts.length > 0) {
      setShowDeleteConfirm(groupId);
    } else {
      // Delete the group
      const updatedGroups = settings.groups.filter(g => g.id !== groupId);
      onUpdateSettings({ ...settings, groups: updatedGroups });
    }
  };

  const handleConfirmDelete = (groupId: string) => {
    // Find the first default group to reassign contacts to
    const defaultGroup = settings.groups.find(g => g.isDefault);
    if (!defaultGroup) return;

    // Reassign all contacts from deleted group to the default group
    const updatedContacts = contacts.map(c =>
      c.slaGroup === groupId ? { ...c, slaGroup: defaultGroup.id } : c
    );
    onUpdateContacts(updatedContacts);

    // Delete the group
    const updatedGroups = settings.groups.filter(g => g.id !== groupId);
    onUpdateSettings({ ...settings, groups: updatedGroups });
    setShowDeleteConfirm(null);
  };

  const getContactCount = (groupId: string) => {
    return contacts.filter(c => c.slaGroup === groupId).length;
  };

  return (
    <div className={`h-full flex flex-col ${bgPrimary}`}>
      {/* Header */}
      <div className={`px-4 pt-3 pb-4 border-b ${borderColor}`}>
        <button 
          onClick={onBack}
          className="flex items-center gap-1 text-[#0A84FF] text-[17px] active:opacity-50 mb-4"
        >
          <ChevronLeft className="w-5 h-5" />
          <span>Settings</span>
        </button>
        <div className="flex items-center justify-between">
          <h1 className={`text-[34px] ${textPrimary} tracking-tight`}>Manage Groups</h1>
          <button
            onClick={handleStartAdd}
            className="p-2 rounded-full bg-[#0A84FF] active:opacity-80"
          >
            <Plus className="w-6 h-6 text-white" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-5 py-5">
        <div className={`${bgSecondary} rounded-[12px] overflow-hidden ${dividerColor} divide-y`}>
          {settings.groups.map((group) => (
            <div key={group.id} className="px-4 py-3">
              <div className="flex items-start justify-between mb-2">
                <div className="flex-1">
                  <div className={`text-[17px] ${textPrimary} mb-1`}>
                    {group.name}
                    {group.isDefault && (
                      <span className={`ml-2 text-[13px] ${textSecondary}`}>(Default)</span>
                    )}
                  </div>
                  <div className={`text-[15px] ${textSecondary}`}>
                    Every {group.days} days • {getContactCount(group.id)} contact{getContactCount(group.id) !== 1 ? 's' : ''}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleStartEdit(group)}
                    className={`p-2 rounded-lg ${btnActive} transition-colors`}
                  >
                    <Edit3 className="w-4 h-4 text-[#0A84FF]" />
                  </button>
                  {!group.isDefault && (
                    <button
                      onClick={() => handleDelete(group.id)}
                      className={`p-2 rounded-lg ${btnActive} transition-colors`}
                    >
                      <Trash2 className="w-4 h-4 text-[#FF3B30]" />
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Edit/Add Modal */}
      {editingGroup && (
        <div className="absolute inset-0 bg-black/60 flex items-end backdrop-blur-sm">
          <div className={`w-full ${bgSecondary} rounded-t-[20px] max-h-[80%] flex flex-col`}>
            <div className={`px-5 py-4 border-b ${borderColor} flex items-center justify-between`}>
              <button 
                onClick={() => setEditingGroup(null)}
                className="text-[17px] text-[#0A84FF] active:opacity-50"
              >
                Cancel
              </button>
              <h3 className={`text-[17px] ${textPrimary} font-medium`}>
                {editingGroup.id ? 'Edit Group' : 'New Group'}
              </h3>
              <button 
                onClick={handleSave}
                className="text-[17px] text-[#0A84FF] active:opacity-50 font-medium"
                disabled={!groupName || !groupDays || !groupWarningDays}
              >
                Save
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-5 space-y-5">
              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  Group Name
                </label>
                <input
                  type="text"
                  value={groupName}
                  onChange={(e) => setGroupName(e.target.value)}
                  placeholder="e.g., Close Friends"
                  className={`w-full ${bgTertiary} ${borderColor} border rounded-[12px] px-4 py-3 text-[17px] ${textPrimary} placeholder:${textSecondary} focus:outline-none focus:ring-2 focus:ring-[#0A84FF]`}
                />
              </div>

              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  Check-in Interval (days)
                </label>
                <input
                  type="number"
                  value={groupDays}
                  onChange={(e) => setGroupDays(e.target.value)}
                  placeholder="e.g., 14"
                  min="1"
                  className={`w-full ${bgTertiary} ${borderColor} border rounded-[12px] px-4 py-3 text-[17px] ${textPrimary} placeholder:${textSecondary} focus:outline-none focus:ring-2 focus:ring-[#0A84FF]`}
                />
              </div>

              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  Warning Days Before Due
                </label>
                <input
                  type="number"
                  value={groupWarningDays}
                  onChange={(e) => setGroupWarningDays(e.target.value)}
                  placeholder="e.g., 3"
                  min="0"
                  className={`w-full ${bgTertiary} ${borderColor} border rounded-[12px] px-4 py-3 text-[17px] ${textPrimary} placeholder:${textSecondary} focus:outline-none focus:ring-2 focus:ring-[#0A84FF]`}
                />
                <p className={`text-[13px] ${textSecondary} mt-2 px-1`}>
                  Show "due soon" status this many days before the interval expires
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="absolute inset-0 bg-black/60 flex items-center justify-center backdrop-blur-sm p-5">
          <div className={`w-full max-w-[300px] ${bgSecondary} rounded-[14px] overflow-hidden`}>
            <div className="px-4 pt-5 pb-4 text-center">
              <h3 className={`text-[17px] ${textPrimary} font-medium mb-2`}>
                Delete Group?
              </h3>
              <p className={`text-[13px] ${textSecondary}`}>
                {getContactCount(showDeleteConfirm)} contact{getContactCount(showDeleteConfirm) !== 1 ? 's' : ''} will be moved to the default group.
              </p>
            </div>
            <div className={`border-t ${borderColor} ${dividerColor} divide-y`}>
              <button
                onClick={() => handleConfirmDelete(showDeleteConfirm)}
                className={`w-full py-3 text-[17px] text-[#FF3B30] ${btnActive} transition-colors`}
              >
                Delete
              </button>
              <button
                onClick={() => setShowDeleteConfirm(null)}
                className={`w-full py-3 text-[17px] text-[#0A84FF] ${btnActive} transition-colors font-medium`}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
