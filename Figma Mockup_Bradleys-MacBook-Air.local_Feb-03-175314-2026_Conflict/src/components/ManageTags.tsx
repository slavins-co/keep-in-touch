import { useState } from 'react';
import { ChevronLeft, Plus, X } from 'lucide-react';
import { AppSettings } from '../types/settings';
import { Tag } from '../types/contact';
import { Contact } from '../types/contact';

interface ManageTagsProps {
  settings: AppSettings;
  onBack: () => void;
  onUpdateSettings: (settings: AppSettings) => void;
  contacts: Contact[];
  onUpdateContacts: (contacts: Contact[]) => void;
}

const TAG_COLORS = [
  '#0A84FF', // Blue
  '#FF3B30', // Red
  '#34C759', // Green
  '#FF9500', // Orange
  '#AF52DE', // Purple
  '#FF2D55', // Pink
  '#5AC8FA', // Light Blue
  '#FFCC00', // Yellow
  '#FF6482', // Coral
  '#30D158', // Mint
];

export function ManageTags({ settings, onBack, onUpdateSettings, contacts, onUpdateContacts }: ManageTagsProps) {
  const [showAddTag, setShowAddTag] = useState(false);
  const [newTagName, setNewTagName] = useState('');
  const [selectedColor, setSelectedColor] = useState(TAG_COLORS[0]);

  const handleAddTag = () => {
    if (!newTagName.trim()) return;

    const newTag: Tag = {
      id: `tag-${Date.now()}`,
      name: newTagName.trim(),
      color: selectedColor,
    };

    onUpdateSettings({
      ...settings,
      tags: [...settings.tags, newTag],
    });

    setNewTagName('');
    setSelectedColor(TAG_COLORS[0]);
    setShowAddTag(false);
  };

  const handleDeleteTag = (tagId: string) => {
    // Remove tag from settings
    onUpdateSettings({
      ...settings,
      tags: settings.tags.filter(t => t.id !== tagId),
    });

    // Remove tag from all contacts
    const updatedContacts = contacts.map(contact => ({
      ...contact,
      tags: contact.tags?.filter(t => t !== tagId),
    }));
    onUpdateContacts(updatedContacts);
  };

  const isDark = settings.theme === 'dark';
  const textPrimary = isDark ? 'text-white' : 'text-black';
  const textSecondary = isDark ? 'text-[#8E8E93]' : 'text-[#6B6B6B]';
  const bgPrimary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const bgSecondary = isDark ? 'bg-[#1C1C1E]' : 'bg-[#F2F2F7]';
  const bgTertiary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const borderColor = isDark ? 'border-[#1C1C1E]' : 'border-[#E5E5EA]';
  const btnActive = isDark ? 'active:bg-[#2C2C2E]' : 'active:bg-[#E5E5EA]';

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
        <h1 className={`text-[34px] ${textPrimary} tracking-tight`}>Manage Tags</h1>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-5 py-5">
        {settings.tags.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-center px-6">
            <div className="text-[48px] mb-3">🏷️</div>
            <p className={`text-[17px] ${textPrimary} mb-2`}>No tags yet</p>
            <p className={`text-[15px] ${textSecondary}`}>Create tags to organize your contacts</p>
          </div>
        ) : (
          <div className="space-y-2">
            {settings.tags.map((tag) => (
              <div
                key={tag.id}
                className={`${bgSecondary} rounded-[12px] px-4 py-3 flex items-center gap-3`}
              >
                <div 
                  className="w-6 h-6 rounded-full flex-shrink-0"
                  style={{ backgroundColor: tag.color }}
                />
                <span className={`flex-1 text-[17px] ${textPrimary}`}>{tag.name}</span>
                <button
                  onClick={() => handleDeleteTag(tag.id)}
                  className={`p-1 rounded-full ${btnActive} transition-colors`}
                >
                  <X className={`w-5 h-5 ${textSecondary}`} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Add Tag Button */}
      <div className={`p-5 border-t ${borderColor}`}>
        <button
          onClick={() => setShowAddTag(true)}
          className="w-full bg-[#0A84FF] text-white text-[17px] rounded-[12px] py-4 active:opacity-80 transition-opacity font-medium flex items-center justify-center gap-2"
        >
          <Plus className="w-5 h-5" />
          <span>Add Tag</span>
        </button>
      </div>

      {/* Add Tag Modal */}
      {showAddTag && (
        <div className="absolute inset-0 bg-black/60 flex items-end backdrop-blur-sm">
          <div className={`w-full ${bgSecondary} rounded-t-[20px] max-h-[80%] flex flex-col`}>
            <div className={`px-5 py-4 border-b ${borderColor} flex items-center justify-between`}>
              <button 
                onClick={() => {
                  setShowAddTag(false);
                  setNewTagName('');
                  setSelectedColor(TAG_COLORS[0]);
                }}
                className="text-[17px] text-[#0A84FF] active:opacity-50"
              >
                Cancel
              </button>
              <h3 className={`text-[17px] ${textPrimary} font-medium`}>Add Tag</h3>
              <button 
                onClick={handleAddTag}
                className="text-[17px] text-[#0A84FF] active:opacity-50 font-medium disabled:opacity-40"
                disabled={!newTagName.trim()}
              >
                Add
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-5 space-y-5">
              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  Tag Name
                </label>
                <input
                  type="text"
                  value={newTagName}
                  onChange={(e) => setNewTagName(e.target.value)}
                  placeholder="e.g. Colleague, Client, etc."
                  className={`w-full ${bgTertiary} ${borderColor} border rounded-[12px] px-4 py-3 text-[17px] ${textPrimary} placeholder:${textSecondary} focus:outline-none focus:ring-2 focus:ring-[#0A84FF]`}
                  autoFocus
                />
              </div>

              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  Color
                </label>
                <div className="grid grid-cols-5 gap-3">
                  {TAG_COLORS.map((color) => (
                    <button
                      key={color}
                      onClick={() => setSelectedColor(color)}
                      className="relative aspect-square rounded-full transition-transform active:scale-90"
                      style={{ backgroundColor: color }}
                    >
                      {selectedColor === color && (
                        <div className="absolute inset-0 flex items-center justify-center">
                          <div className="w-6 h-6 text-white text-[20px] leading-none">✓</div>
                        </div>
                      )}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
