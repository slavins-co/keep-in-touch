import { useState } from 'react';
import { Contact, TouchMethod, SLAGroup, TouchLog, Tag } from '../types/contact';
import { ChevronLeft, MessageCircle, Phone, Mail, Calendar, Pause, Play, ChevronDown, ChevronUp, Plus, X, Pencil, Trash2 } from 'lucide-react';
import { getSLAStatus, getDaysOverdue, getStatusColor, getStatusLabel, formatLastContact, getDaysSinceContact } from '../utils/slaCalculations';
import { Theme } from '../types/settings';

interface ContactDetailProps {
  contact: Contact;
  onBack: () => void;
  onUpdate: (contact: Contact) => void;
  theme: Theme;
  groups: SLAGroup[];
  tags: Tag[];
}

const touchMethods: TouchMethod[] = ['Text', 'Call', 'IRL', 'Email', 'Other'];

export function ContactDetail({ contact, onBack, onUpdate, theme, groups, tags }: ContactDetailProps) {
  const [showLogTouch, setShowLogTouch] = useState(false);
  const [selectedMethod, setSelectedMethod] = useState<TouchMethod>('Text');
  const [notes, setNotes] = useState('');
  const [showChangeGroup, setShowChangeGroup] = useState(false);
  const [showFullHistory, setShowFullHistory] = useState(false);
  const [showManageTags, setShowManageTags] = useState(false);
  const [editingLog, setEditingLog] = useState<TouchLog | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState<string | null>(null);

  const status = getSLAStatus(contact, groups);
  const daysOverdue = getDaysOverdue(contact, groups);
  const daysSince = getDaysSinceContact(contact.lastContacted);
  const slaConfig = groups.find(g => g.id === contact.slaGroup);

  const handleQuickLog = () => {
    const newLog: TouchLog = {
      id: `log-${Date.now()}`,
      date: new Date(),
      method: selectedMethod,
      notes: notes || undefined,
    };

    const updatedContact: Contact = {
      ...contact,
      lastContacted: new Date(),
      lastTouchMethod: selectedMethod,
      notes: notes || undefined,
      history: [newLog, ...contact.history],
    };
    onUpdate(updatedContact);
    setShowLogTouch(false);
    setNotes('');
  };

  const handleEditLog = (log: TouchLog) => {
    setEditingLog(log);
    setSelectedMethod(log.method);
    setNotes(log.notes || '');
  };

  const handleSaveEdit = () => {
    if (!editingLog) return;

    const updatedHistory = contact.history.map(log =>
      log.id === editingLog.id
        ? { ...log, method: selectedMethod, notes: notes || undefined }
        : log
    );

    // Update lastContacted and lastTouchMethod if we're editing the most recent entry
    const isLatestEntry = contact.history[0]?.id === editingLog.id;
    const updatedContact: Contact = {
      ...contact,
      history: updatedHistory,
      ...(isLatestEntry && {
        lastTouchMethod: selectedMethod,
        notes: notes || undefined,
      }),
    };

    onUpdate(updatedContact);
    setEditingLog(null);
    setNotes('');
  };

  const handleDeleteLog = (logId: string) => {
    const updatedHistory = contact.history.filter(log => log.id !== logId);

    // If we're deleting the most recent entry, update lastContacted and lastTouchMethod
    const isLatestEntry = contact.history[0]?.id === logId;
    const newLatestEntry = updatedHistory[0];

    const updatedContact: Contact = {
      ...contact,
      history: updatedHistory,
      ...(isLatestEntry && newLatestEntry && {
        lastContacted: newLatestEntry.date,
        lastTouchMethod: newLatestEntry.method,
        notes: newLatestEntry.notes,
      }),
    };

    onUpdate(updatedContact);
    setShowDeleteConfirm(null);
  };

  const handleTogglePause = () => {
    onUpdate({ ...contact, isPaused: !contact.isPaused });
  };

  const handleChangeGroup = (newGroupId: string) => {
    onUpdate({ ...contact, slaGroup: newGroupId });
    setShowChangeGroup(false);
  };

  const handleAddTag = (tagId: string) => {
    const currentTags = contact.tags || [];
    if (!currentTags.includes(tagId)) {
      onUpdate({ ...contact, tags: [...currentTags, tagId] });
    }
  };

  const handleRemoveTag = (tagId: string) => {
    const currentTags = contact.tags || [];
    onUpdate({ ...contact, tags: currentTags.filter(t => t !== tagId) });
  };

  // Calculate days remaining until due
  const daysRemaining = slaConfig ? slaConfig.days - daysSince : 0;

  const contactTags = contact.tags?.map(tagId => tags.find(t => t.id === tagId)).filter(Boolean) as Tag[];
  const availableTags = tags.filter(tag => !contact.tags?.includes(tag.id));

  const isDark = theme === 'dark';
  const textPrimary = isDark ? 'text-white' : 'text-black';
  const textSecondary = isDark ? 'text-[#8E8E93]' : 'text-[#6B6B6B]';
  const bgPrimary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const bgSecondary = isDark ? 'bg-[#1C1C1E]' : 'bg-[#F2F2F7]';
  const bgTertiary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const borderColor = isDark ? 'border-[#1C1C1E]' : 'border-[#E5E5EA]';
  const dividerColor = isDark ? 'divide-[#2C2C2E]' : 'divide-[#E5E5EA]';
  const btnActive = isDark ? 'active:bg-[#2C2C2E]' : 'active:bg-[#E5E5EA]';

  return (
    <div className={`h-full flex flex-col ${bgPrimary}`}>
      {/* Header */}
      <div className={`px-4 pt-3 pb-4 border-b ${borderColor}`}>
        <button 
          onClick={onBack}
          className={`flex items-center gap-1 text-[#0A84FF] text-[17px] active:opacity-50 mb-4`}
        >
          <ChevronLeft className="w-5 h-5" />
          <span>Back</span>
        </button>

        {/* Avatar & Name */}
        <div className="flex items-center gap-4 mb-4">
          <div 
            className="w-[72px] h-[72px] rounded-full flex items-center justify-center flex-shrink-0"
            style={{ backgroundColor: contact.color }}
          >
            <span className="text-white text-[28px]">{contact.initials}</span>
          </div>
          <div className="flex-1 min-w-0">
            <h2 className={`text-[28px] ${textPrimary} tracking-tight truncate mb-1`}>{contact.name}</h2>
            <div className="flex items-center gap-2">
              <div 
                className="w-2 h-2 rounded-full"
                style={{ backgroundColor: getStatusColor(status) }}
              />
              <span className={`text-[15px] ${textSecondary}`}>{getStatusLabel(status)}</span>
              {daysOverdue > 0 && (
                <span className="text-[15px] text-[#FF3B30] font-medium">+{daysOverdue}d</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto px-5 py-5 space-y-4">
        {/* SLA Status Card */}
        {slaConfig && (
          <div className={`${bgSecondary} rounded-[12px] p-4`}>
            <div className="flex items-center justify-between mb-3">
              <span className={`text-[13px] ${textSecondary} uppercase tracking-wide`}>Cadence</span>
              <button
                onClick={() => setShowChangeGroup(true)}
                className="text-[15px] text-[#0A84FF] active:opacity-50"
              >
                Change
              </button>
            </div>
            <div className={`text-[24px] ${textPrimary} mb-2`}>{slaConfig.name}</div>
            <div className={`text-[15px] ${textSecondary}`}>
              Connect every {slaConfig.days} days
              {!contact.isPaused && daysRemaining > 0 && (
                <span> • {daysRemaining}d remaining</span>
              )}
            </div>
          </div>
        )}

        {/* Tags Card */}
        <div className={`${bgSecondary} rounded-[12px] p-4`}>
          <div className="flex items-center justify-between mb-3">
            <span className={`text-[13px] ${textSecondary} uppercase tracking-wide`}>Tags</span>
            <button
              onClick={() => setShowManageTags(true)}
              className="text-[15px] text-[#0A84FF] active:opacity-50"
            >
              Manage
            </button>
          </div>
          {contactTags && contactTags.length > 0 ? (
            <div className="flex flex-wrap gap-2">
              {contactTags.map(tag => (
                <button
                  key={tag.id}
                  onClick={() => handleRemoveTag(tag.id)}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[15px] text-white active:opacity-70 transition-opacity"
                  style={{ backgroundColor: tag.color }}
                >
                  <span>{tag.name}</span>
                  <X className="w-3.5 h-3.5" />
                </button>
              ))}
            </div>
          ) : (
            <div className={`text-[15px] ${textSecondary}`}>
              No tags yet
            </div>
          )}
        </div>

        {/* Contact History */}
        <div className={`${bgSecondary} rounded-[12px] p-4`}>
          <div className="flex items-center justify-between mb-3">
            <span className={`text-[13px] ${textSecondary} uppercase tracking-wide`}>
              Contact History
            </span>
            {contact.history.length > 1 && (
              <button
                onClick={() => setShowFullHistory(!showFullHistory)}
                className="flex items-center gap-1 text-[15px] text-[#0A84FF] active:opacity-50"
              >
                {showFullHistory ? (
                  <>
                    <span>Show Less</span>
                    <ChevronUp className="w-4 h-4" />
                  </>
                ) : (
                  <>
                    <span>See All ({contact.history.length})</span>
                    <ChevronDown className="w-4 h-4" />
                  </>
                )}
              </button>
            )}
          </div>

          {/* History Items */}
          <div className="space-y-3">
            {(showFullHistory ? contact.history : contact.history.slice(0, 1)).map((log, index) => (
              <div key={log.id} className={index > 0 ? 'pt-3 border-t ' + borderColor : ''}>
                <div className="flex items-start gap-3">
                  <Calendar className="w-5 h-5 text-[#0A84FF] mt-0.5 flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <div className={`text-[17px] ${textPrimary} mb-1`}>
                      {formatLastContact(log.date)}
                      <span className={textSecondary}> via {log.method}</span>
                    </div>
                    <div className={`text-[15px] ${textSecondary}`}>
                      {log.date.toLocaleDateString('en-US', { 
                        weekday: 'long', 
                        month: 'short', 
                        day: 'numeric',
                        year: 'numeric'
                      })}
                    </div>
                    {log.notes && (
                      <div className={`text-[15px] ${textSecondary} ${bgTertiary} rounded-[8px] p-3 mt-2`}>
                        "{log.notes}"
                      </div>
                    )}
                  </div>
                  <div className="flex items-center gap-2 flex-shrink-0">
                    <button
                      onClick={() => handleEditLog(log)}
                      className="text-[#0A84FF] active:opacity-50 transition-opacity p-1"
                      aria-label="Edit"
                    >
                      <Pencil className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => setShowDeleteConfirm(log.id)}
                      className="text-[#FF3B30] active:opacity-50 transition-opacity p-1"
                      aria-label="Delete"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Quick Actions */}
        {(contact.phone || contact.email) && (
          <div className={`${bgSecondary} rounded-[12px] overflow-hidden`}>
            <div className="px-4 pt-4 pb-2">
              <div className={`text-[13px] ${textSecondary} uppercase tracking-wide`}>
                Quick Actions
              </div>
            </div>
            <div className={`${dividerColor} divide-y`}>
              {contact.phone && (
                <>
                  <button className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}>
                    <MessageCircle className="w-5 h-5 text-[#0A84FF]" />
                    <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>Message</span>
                    <span className={`text-[15px] ${textSecondary}`}>{contact.phone}</span>
                  </button>
                  <button className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}>
                    <Phone className="w-5 h-5 text-[#34C759]" />
                    <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>Call</span>
                    <span className={`text-[15px] ${textSecondary}`}>{contact.phone}</span>
                  </button>
                </>
              )}
              {contact.email && (
                <button className={`w-full px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}>
                  <Mail className="w-5 h-5 text-[#0A84FF]" />
                  <span className={`flex-1 text-left text-[17px] ${textPrimary}`}>Email</span>
                  <span className={`text-[15px] ${textSecondary} truncate`}>{contact.email}</span>
                </button>
              )}
            </div>
          </div>
        )}

        {/* Pause/Resume */}
        <button
          onClick={handleTogglePause}
          className={`w-full ${bgSecondary} rounded-[12px] px-4 py-3 flex items-center gap-3 ${btnActive} transition-colors`}
        >
          {contact.isPaused ? (
            <>
              <Play className="w-5 h-5 text-[#34C759]" />
              <span className={`text-[17px] ${textPrimary}`}>Resume Tracking</span>
            </>
          ) : (
            <>
              <Pause className="w-5 h-5 text-[#FF9500]" />
              <span className={`text-[17px] ${textPrimary}`}>Pause Tracking</span>
            </>
          )}
        </button>
      </div>

      {/* Fixed Log Touch Button */}
      <div className={`p-5 border-t ${borderColor}`}>
        <button
          onClick={() => setShowLogTouch(true)}
          className="w-full bg-[#0A84FF] text-white text-[17px] rounded-[12px] py-4 active:opacity-80 transition-opacity font-medium"
        >
          Log Touch
        </button>
      </div>

      {/* Log Touch Modal */}
      {showLogTouch && (
        <div className="absolute inset-0 bg-black/60 flex items-end backdrop-blur-sm">
          <div className={`w-full ${bgSecondary} rounded-t-[20px] max-h-[80%] flex flex-col`}>
            <div className={`px-5 py-4 border-b ${borderColor} flex items-center justify-between`}>
              <button 
                onClick={() => setShowLogTouch(false)}
                className="text-[17px] text-[#0A84FF] active:opacity-50"
              >
                Cancel
              </button>
              <h3 className={`text-[17px] ${textPrimary} font-medium`}>Log Touch</h3>
              <button 
                onClick={handleQuickLog}
                className="text-[17px] text-[#0A84FF] active:opacity-50 font-medium"
              >
                Done
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-5 space-y-5">
              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  How did you connect?
                </label>
                <div className={`${bgTertiary} rounded-[12px] overflow-hidden ${dividerColor} divide-y`}>
                  {touchMethods.map((method) => (
                    <button
                      key={method}
                      onClick={() => setSelectedMethod(method)}
                      className={`w-full px-4 py-3 flex items-center justify-between ${btnActive} transition-colors`}
                    >
                      <span className={`text-[17px] ${textPrimary}`}>{method}</span>
                      {selectedMethod === method && (
                        <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                      )}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  Notes (Optional)
                </label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="What did you talk about?"
                  className={`w-full ${bgTertiary} ${borderColor} border rounded-[12px] px-4 py-3 text-[17px] ${textPrimary} placeholder:${textSecondary} min-h-[100px] resize-none focus:outline-none focus:ring-2 focus:ring-[#0A84FF]`}
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Edit Log Modal */}
      {editingLog && (
        <div className="absolute inset-0 bg-black/60 flex items-end backdrop-blur-sm">
          <div className={`w-full ${bgSecondary} rounded-t-[20px] max-h-[80%] flex flex-col`}>
            <div className={`px-5 py-4 border-b ${borderColor} flex items-center justify-between`}>
              <button 
                onClick={() => {
                  setEditingLog(null);
                  setNotes('');
                }}
                className="text-[17px] text-[#0A84FF] active:opacity-50"
              >
                Cancel
              </button>
              <h3 className={`text-[17px] ${textPrimary} font-medium`}>Edit Touch</h3>
              <button 
                onClick={handleSaveEdit}
                className="text-[17px] text-[#0A84FF] active:opacity-50 font-medium"
              >
                Save
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-5 space-y-5">
              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  Date
                </label>
                <div className={`${bgTertiary} rounded-[12px] px-4 py-3`}>
                  <div className={`text-[17px] ${textPrimary}`}>
                    {editingLog.date.toLocaleDateString('en-US', { 
                      weekday: 'long', 
                      month: 'short', 
                      day: 'numeric',
                      year: 'numeric'
                    })}
                  </div>
                  <div className={`text-[13px] ${textSecondary} mt-1`}>
                    Date cannot be changed
                  </div>
                </div>
              </div>

              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  How did you connect?
                </label>
                <div className={`${bgTertiary} rounded-[12px] overflow-hidden ${dividerColor} divide-y`}>
                  {touchMethods.map((method) => (
                    <button
                      key={method}
                      onClick={() => setSelectedMethod(method)}
                      className={`w-full px-4 py-3 flex items-center justify-between ${btnActive} transition-colors`}
                    >
                      <span className={`text-[17px] ${textPrimary}`}>{method}</span>
                      {selectedMethod === method && (
                        <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                      )}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  Notes (Optional)
                </label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="What did you talk about?"
                  className={`w-full ${bgTertiary} ${borderColor} border rounded-[12px] px-4 py-3 text-[17px] ${textPrimary} placeholder:${textSecondary} min-h-[100px] resize-none focus:outline-none focus:ring-2 focus:ring-[#0A84FF]`}
                />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation Modal */}
      {showDeleteConfirm && (
        <div className="absolute inset-0 bg-black/60 flex items-center justify-center backdrop-blur-sm px-5">
          <div className={`w-full max-w-[270px] ${bgSecondary} rounded-[14px] overflow-hidden`}>
            <div className="px-4 py-5 text-center">
              <h3 className={`text-[17px] ${textPrimary} font-medium mb-2`}>
                Delete Touch Entry?
              </h3>
              <p className={`text-[13px] ${textSecondary}`}>
                This action cannot be undone.
              </p>
            </div>
            <div className={`border-t ${borderColor}`}>
              <button
                onClick={() => handleDeleteLog(showDeleteConfirm)}
                className={`w-full py-3 text-[17px] text-[#FF3B30] font-medium active:opacity-50 transition-opacity border-b ${borderColor}`}
              >
                Delete
              </button>
              <button
                onClick={() => setShowDeleteConfirm(null)}
                className={`w-full py-3 text-[17px] text-[#0A84FF] active:opacity-50 transition-opacity`}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Change Group Modal */}
      {showChangeGroup && (
        <div className="absolute inset-0 bg-black/60 flex items-end backdrop-blur-sm">
          <div className={`w-full ${bgSecondary} rounded-t-[20px] max-h-[70%] flex flex-col`}>
            <div className={`px-5 py-4 border-b ${borderColor} flex items-center justify-between`}>
              <button 
                onClick={() => setShowChangeGroup(false)}
                className="text-[17px] text-[#0A84FF] active:opacity-50"
              >
                Cancel
              </button>
              <h3 className={`text-[17px] ${textPrimary} font-medium`}>Change Cadence</h3>
              <div className="w-[60px]"></div>
            </div>

            <div className="flex-1 overflow-y-auto p-5">
              <div className={`${bgTertiary} rounded-[12px] overflow-hidden ${dividerColor} divide-y`}>
                {groups.map((group) => (
                  <button
                    key={group.id}
                    onClick={() => handleChangeGroup(group.id)}
                    className={`w-full px-4 py-4 flex items-start justify-between ${btnActive} transition-colors`}
                  >
                    <div className="text-left">
                      <div className={`text-[17px] ${textPrimary} mb-1`}>{group.name}</div>
                      <div className={`text-[15px] ${textSecondary}`}>
                        Every {group.days} days
                      </div>
                    </div>
                    {contact.slaGroup === group.id && (
                      <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                    )}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Manage Tags Modal */}
      {showManageTags && (
        <div className="absolute inset-0 bg-black/60 flex items-end backdrop-blur-sm">
          <div className={`w-full ${bgSecondary} rounded-t-[20px] max-h-[80%] flex flex-col`}>
            <div className={`px-5 py-4 border-b ${borderColor} flex items-center justify-between`}>
              <button 
                onClick={() => setShowManageTags(false)}
                className="text-[17px] text-[#0A84FF] active:opacity-50"
              >
                Cancel
              </button>
              <h3 className={`text-[17px] ${textPrimary} font-medium`}>Manage Tags</h3>
              <div className="w-[60px]"></div>
            </div>

            <div className="flex-1 overflow-y-auto p-5 space-y-4">
              {contactTags && contactTags.length > 0 && (
                <div>
                  <span className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>Current Tags</span>
                  <div className="flex flex-wrap gap-2">
                    {contactTags.map(tag => (
                      <button
                        key={tag.id}
                        onClick={() => handleRemoveTag(tag.id)}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[15px] text-white active:opacity-70 transition-opacity"
                        style={{ backgroundColor: tag.color }}
                      >
                        <span>{tag.name}</span>
                        <X className="w-3.5 h-3.5" />
                      </button>
                    ))}
                  </div>
                </div>
              )}

              <div>
                <span className={`text-[13px] ${textSecondary} uppercase tracking-wide mb-3 block`}>
                  {availableTags && availableTags.length > 0 ? 'Add Tags' : 'No More Tags Available'}
                </span>
                {availableTags && availableTags.length > 0 ? (
                  <div className="flex flex-wrap gap-2">
                    {availableTags.map(tag => (
                      <button
                        key={tag.id}
                        onClick={() => {
                          handleAddTag(tag.id);
                        }}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[15px] text-white active:opacity-70 transition-opacity"
                        style={{ backgroundColor: tag.color }}
                      >
                        <span>{tag.name}</span>
                        <Plus className="w-3.5 h-3.5" />
                      </button>
                    ))}
                  </div>
                ) : (
                  <div className={`text-[15px] ${textSecondary}`}>
                    All tags have been added
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}