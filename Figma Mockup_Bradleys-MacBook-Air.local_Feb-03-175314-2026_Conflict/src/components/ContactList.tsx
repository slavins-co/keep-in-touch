import { Contact, SLAGroup, Tag } from '../types/contact';
import { ChevronRight, Settings, Search, ChevronDown, ChevronUp } from 'lucide-react';
import { getSLAStatus, getDaysOverdue, getStatusColor, formatLastContact } from '../utils/slaCalculations';
import { Theme } from '../types/settings';
import { useState } from 'react';

interface ContactListProps {
  contacts: Contact[];
  selectedGroup: string | 'All';
  onSelectGroup: (group: string | 'All') => void;
  onSelectContact: (contact: Contact) => void;
  onOpenSettings: () => void;
  theme: Theme;
  groups: SLAGroup[];
  tags: Tag[];
}

type SortBy = 'status' | 'name';

export function ContactList({ contacts, selectedGroup, onSelectGroup, onSelectContact, onOpenSettings, theme, groups, tags }: ContactListProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [sortBy, setSortBy] = useState<SortBy>('status');
  const [collapsedSections, setCollapsedSections] = useState<Set<string>>(new Set());
  const [showGroupDropdown, setShowGroupDropdown] = useState(false);
  const [showSortDropdown, setShowSortDropdown] = useState(false);
  const [selectedTag, setSelectedTag] = useState<string | 'All'>('All');
  const [showTagDropdown, setShowTagDropdown] = useState(false);

  const groupOptions: (string | 'All')[] = ['All', ...groups.map(g => g.id)];
  const tagOptions: (string | 'All')[] = ['All', ...tags.map(t => t.id)];
  
  // Filter contacts based on selected group, tag, exclude paused, and apply search
  const filteredContacts = contacts.filter(c => {
    if (c.isPaused) return false;
    if (selectedGroup !== 'All' && c.slaGroup !== selectedGroup) return false;
    if (selectedTag !== 'All' && (!c.tags || !c.tags.includes(selectedTag))) return false;
    if (searchQuery && !c.name.toLowerCase().includes(searchQuery.toLowerCase())) return false;
    return true;
  });

  // Group contacts by status
  const groupedByStatus = filteredContacts.reduce((acc, contact) => {
    const status = getSLAStatus(contact, groups);
    if (!acc[status]) acc[status] = [];
    acc[status].push(contact);
    return acc;
  }, {} as Record<string, Contact[]>);

  // Sort contacts within each group
  const sortContacts = (contactsList: Contact[]) => {
    if (sortBy === 'name') {
      return [...contactsList].sort((a, b) => a.name.localeCompare(b.name));
    }
    // Sort by days overdue (descending)
    return [...contactsList].sort((a, b) => {
      const daysA = getDaysOverdue(a, groups);
      const daysB = getDaysOverdue(b, groups);
      return daysB - daysA;
    });
  };

  const overdueContacts = sortContacts(groupedByStatus['out-of-sla'] || []);
  const dueSoonContacts = sortContacts(groupedByStatus['due-soon'] || []);
  const allGoodContacts = sortContacts(groupedByStatus['in-sla'] || []);

  const toggleSection = (section: string) => {
    const newCollapsed = new Set(collapsedSections);
    if (newCollapsed.has(section)) {
      newCollapsed.delete(section);
    } else {
      newCollapsed.add(section);
    }
    setCollapsedSections(newCollapsed);
  };

  const isDark = theme === 'dark';
  const textPrimary = isDark ? 'text-white' : 'text-black';
  const textSecondary = isDark ? 'text-[#8E8E93]' : 'text-[#6B6B6B]';
  const bgPrimary = isDark ? 'bg-[#000000]' : 'bg-[#FFFFFF]';
  const bgSecondary = isDark ? 'bg-[#1C1C1E]' : 'bg-[#F2F2F7]';
  const borderColor = isDark ? 'border-[#1C1C1E]' : 'border-[#E5E5EA]';
  const btnActive = isDark ? 'active:bg-[#2C2C2E]' : 'active:bg-[#E5E5EA]';
  const inputBg = isDark ? 'bg-[#1C1C1E]' : 'bg-[#F2F2F7]';
  const dividerColor = isDark ? 'divide-[#2C2C2E]' : 'divide-[#E5E5EA]';

  const getGroupName = (groupId: string | 'All') => {
    if (groupId === 'All') return 'All';
    return groups.find(g => g.id === groupId)?.name || groupId;
  };

  const handleSelectGroup = (groupId: string | 'All') => {
    onSelectGroup(groupId);
    setShowGroupDropdown(false);
  };

  const handleSelectSort = (sort: SortBy) => {
    setSortBy(sort);
    setShowSortDropdown(false);
  };

  const handleSelectTag = (tagId: string | 'All') => {
    setSelectedTag(tagId);
    setShowTagDropdown(false);
  };

  const renderContactCard = (contact: Contact) => {
    const status = getSLAStatus(contact, groups);
    const daysOverdue = getDaysOverdue(contact, groups);
    const groupName = getGroupName(contact.slaGroup);
    const contactTags = contact.tags?.map(tagId => tags.find(t => t.id === tagId)).filter(Boolean) as Tag[];
    
    return (
      <button
        key={contact.id}
        onClick={() => onSelectContact(contact)}
        className={`w-full ${bgSecondary} rounded-[12px] p-3 flex items-start gap-3 ${btnActive} transition-colors`}
      >
        {/* Avatar */}
        <div 
          className="w-[44px] h-[44px] rounded-full flex items-center justify-center flex-shrink-0"
          style={{ backgroundColor: contact.color }}
        >
          <span className="text-white text-[15px]">{contact.initials}</span>
        </div>

        {/* Info */}
        <div className="flex-1 min-w-0 pt-0.5">
          {/* Name */}
          <div className={`text-[17px] ${textPrimary} truncate mb-1`}>
            {contact.name}
          </div>
          {/* Metadata - Group, Time, Method */}
          <div className={`text-[13px] ${textSecondary} truncate`}>
            {groupName} • {formatLastContact(contact.lastContacted)}
            {contact.lastTouchMethod && ` • ${contact.lastTouchMethod}`}
          </div>
          {/* Tags */}
          {contactTags && contactTags.length > 0 && (
            <div className="flex flex-wrap gap-1.5 mt-1.5">
              {contactTags.map(tag => (
                <span
                  key={tag.id}
                  className="inline-flex items-center px-2 py-0.5 rounded-full text-[11px] text-white"
                  style={{ backgroundColor: tag.color }}
                >
                  {tag.name}
                </span>
              ))}
            </div>
          )}
        </div>

        {/* Status Indicators - Right Side */}
        <div className="flex items-center gap-2 flex-shrink-0 pt-0.5">
          {daysOverdue > 0 && (
            <span className="text-[13px] text-[#FF3B30] font-medium">
              +{daysOverdue}d
            </span>
          )}
          <div 
            className="w-[10px] h-[10px] rounded-full"
            style={{ backgroundColor: getStatusColor(status) }}
          />
          <ChevronRight className={`w-5 h-5 ${isDark ? 'text-[#3A3A3C]' : 'text-[#C6C6C8]'}`} />
        </div>
      </button>
    );
  };

  const renderSection = (title: string, count: number, contacts: Contact[], color: string, sectionKey: string) => {
    if (count === 0) return null;
    const isCollapsed = collapsedSections.has(sectionKey);
    
    return (
      <div className="mb-4">
        <button
          onClick={() => toggleSection(sectionKey)}
          className={`w-full flex items-center justify-between px-1 py-2 ${btnActive} rounded-lg transition-colors`}
        >
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: color }}></div>
            <span className={`text-[15px] ${textPrimary} font-medium`}>{title}</span>
            <span className={`text-[15px] ${textSecondary}`}>({count})</span>
          </div>
          {isCollapsed ? (
            <ChevronDown className={`w-5 h-5 ${textSecondary}`} />
          ) : (
            <ChevronUp className={`w-5 h-5 ${textSecondary}`} />
          )}
        </button>
        {!isCollapsed && (
          <div className="space-y-2 mt-2">
            {contacts.map(renderContactCard)}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="h-full flex flex-col">
      {/* Header */}
      <div className="px-5 pt-4 pb-3">
        <div className="flex items-start justify-between mb-1">
          <h1 className={`text-[34px] ${textPrimary} tracking-tight`}>Stay in Touch</h1>
          <button
            onClick={onOpenSettings}
            className={`p-2 rounded-full ${btnActive} transition-colors`}
          >
            <Settings className={`w-6 h-6 ${textSecondary}`} />
          </button>
        </div>
        <div className="flex items-center gap-3 text-[13px]">
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-[#FF3B30]"></div>
            <span className={textSecondary}>{overdueContacts.length} overdue</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-[#FF9500]"></div>
            <span className={textSecondary}>{dueSoonContacts.length} due soon</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-[#34C759]"></div>
            <span className={textSecondary}>{allGoodContacts.length} all good</span>
          </div>
        </div>
      </div>

      {/* Group Filter & Sort Control */}
      <div className="px-5 pb-3">
        <div className="flex items-center gap-3">
          {/* Group Dropdown */}
          <div className="relative flex-1">
            <button
              onClick={() => {
                setShowGroupDropdown(!showGroupDropdown);
                setShowSortDropdown(false);
                setShowTagDropdown(false);
              }}
              className={`w-full px-4 py-2 rounded-[10px] text-[15px] flex items-center justify-between ${bgSecondary} ${btnActive} transition-colors`}
            >
              <span className={textPrimary}>{getGroupName(selectedGroup)}</span>
              <ChevronDown className={`w-4 h-4 ${textSecondary}`} />
            </button>
            {showGroupDropdown && (
              <div className={`absolute top-full left-0 right-0 mt-2 ${bgSecondary} rounded-[12px] overflow-hidden shadow-lg z-10 ${dividerColor} divide-y`}>
                {groupOptions.map(groupId => (
                  <button
                    key={groupId}
                    onClick={() => handleSelectGroup(groupId)}
                    className={`px-4 py-3 w-full text-left ${btnActive} transition-colors flex items-center justify-between`}
                  >
                    <span className={`text-[15px] ${textPrimary}`}>{getGroupName(groupId)}</span>
                    {selectedGroup === groupId && (
                      <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Sort Dropdown */}
          <div className="relative flex-1">
            <button
              onClick={() => {
                setShowSortDropdown(!showSortDropdown);
                setShowGroupDropdown(false);
                setShowTagDropdown(false);
              }}
              className={`w-full px-4 py-2 rounded-[10px] text-[15px] flex items-center justify-between ${bgSecondary} ${btnActive} transition-colors`}
            >
              <span className={textPrimary}>{sortBy === 'status' ? 'Status' : 'Name'}</span>
              <ChevronDown className={`w-4 h-4 ${textSecondary}`} />
            </button>
            {showSortDropdown && (
              <div className={`absolute top-full left-0 right-0 mt-2 ${bgSecondary} rounded-[12px] overflow-hidden shadow-lg z-10 ${dividerColor} divide-y`}>
                <button
                  onClick={() => handleSelectSort('status')}
                  className={`px-4 py-3 w-full text-left ${btnActive} transition-colors flex items-center justify-between`}
                >
                  <span className={`text-[15px] ${textPrimary}`}>Status</span>
                  {sortBy === 'status' && (
                    <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                  )}
                </button>
                <button
                  onClick={() => handleSelectSort('name')}
                  className={`px-4 py-3 w-full text-left ${btnActive} transition-colors flex items-center justify-between`}
                >
                  <span className={`text-[15px] ${textPrimary}`}>Name</span>
                  {sortBy === 'name' && (
                    <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                  )}
                </button>
              </div>
            )}
          </div>

          {/* Tag Dropdown */}
          <div className="relative flex-1">
            <button
              onClick={() => {
                setShowTagDropdown(!showTagDropdown);
                setShowGroupDropdown(false);
                setShowSortDropdown(false);
              }}
              className={`w-full px-4 py-2 rounded-[10px] text-[15px] flex items-center justify-between ${bgSecondary} ${btnActive} transition-colors`}
            >
              <span className={textPrimary}>{selectedTag === 'All' ? 'All Tags' : tags.find(t => t.id === selectedTag)?.name || selectedTag}</span>
              <ChevronDown className={`w-4 h-4 ${textSecondary}`} />
            </button>
            {showTagDropdown && (
              <div className={`absolute top-full left-0 right-0 mt-2 ${bgSecondary} rounded-[12px] overflow-hidden shadow-lg z-10 ${dividerColor} divide-y`}>
                {tagOptions.map(tagId => (
                  <button
                    key={tagId}
                    onClick={() => handleSelectTag(tagId)}
                    className={`px-4 py-3 w-full text-left ${btnActive} transition-colors flex items-center justify-between`}
                  >
                    <span className={`text-[15px] ${textPrimary}`}>{tagId === 'All' ? 'All Tags' : tags.find(t => t.id === tagId)?.name || tagId}</span>
                    {selectedTag === tagId && (
                      <div className="w-5 h-5 text-[#0A84FF] text-[20px] leading-none">✓</div>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Contact List - Grouped by Status */}
      <div className="flex-1 overflow-y-auto px-5 pb-24">
        {filteredContacts.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-center px-6">
            <div className="text-[48px] mb-3">
              {searchQuery ? '🔍' : '👋'}
            </div>
            <p className={`text-[17px] ${textPrimary} mb-2`}>
              {searchQuery ? 'No contacts found' : 'No contacts yet'}
            </p>
            <p className={`text-[15px] ${textSecondary}`}>
              {searchQuery ? 'Try a different search' : 'Add people you want to stay in touch with'}
            </p>
          </div>
        ) : (
          <div>
            {renderSection('Overdue', overdueContacts.length, overdueContacts, '#FF3B30', 'overdue')}
            {renderSection('Due Soon', dueSoonContacts.length, dueSoonContacts, '#FF9500', 'due-soon')}
            {renderSection('All Good', allGoodContacts.length, allGoodContacts, '#34C759', 'all-good')}
          </div>
        )}
      </div>

      {/* Search Bar - Fixed at Bottom */}
      <div className={`px-5 py-3 border-t ${borderColor} ${bgPrimary}`}>
        <div className={`flex items-center gap-3 ${inputBg} rounded-[10px] px-4 py-3`}>
          <Search className={`w-5 h-5 ${textSecondary} flex-shrink-0`} />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search contacts..."
            className={`flex-1 bg-transparent ${textPrimary} placeholder:${textSecondary} text-[17px] focus:outline-none`}
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className={`${textSecondary} text-[15px] active:opacity-50`}
            >
              Clear
            </button>
          )}
        </div>
      </div>
    </div>
  );
}