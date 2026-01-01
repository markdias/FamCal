import CryptoJS from 'crypto-js';
import { format, parseISO } from 'date-fns';
import supabaseDataService from './supabase/SupabaseDataService';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from '@/utils/storageKeys';
import { Checklist, ChecklistItem } from '@/types';
import { NOTIFICATION_CONSTANTS } from '@/utils/constants';

type ChecklistChangeCallback = (checklists: Checklist[]) => void;

// Generate event identifier hash for checklist association
export function generateEventIdentifierHash(title: string, date: string): string {
  const input = `${title.trim().toLowerCase()}-${date}`;
  return CryptoJS.SHA256(input).toString(CryptoJS.enc.Hex);
}

// Generate legacy event identifier (for backward compatibility)
function generateLegacyEventIdentifier(title: string, date: string): string {
  return `${title.toLowerCase().replace(/\s+/g, '_')}_${date}`;
}

class ChecklistManager {
  private checklists: Map<string, Checklist> = new Map();
  private listeners: Set<ChecklistChangeCallback> = new Set();
  private isInitialized = false;

  // Initialize checklist manager
  async initialize(): Promise<void> {
    await this.loadChecklists();
    this.isInitialized = true;
  }

  // Load checklists from Supabase
  private async loadChecklists(): Promise<void> {
    try {
      // Load from local cache first
      const cachedData = await AsyncStorage.getItem(STORAGE_KEYS.CACHED_ADDRESSES);
      if (cachedData) {
        const checklists = JSON.parse(cachedData);
        checklists.forEach((checklist: Checklist) => {
          this.checklists.set(checklist.id, checklist);
        });
      }

      // Sync with Supabase (background)
      this.syncFromSupabase();
    } catch (error) {
      console.error('Failed to load checklists:', error);
    }
  }

  // Sync checklists from Supabase
  private async syncFromSupabase(): Promise<void> {
    try {
      // This would fetch checklists from Supabase
      // For now, we'll work with local state
      const familyId = await AsyncStorage.getItem(STORAGE_KEYS.FAMILY_ID);
      if (!familyId) return;

      // TODO: Fetch from Supabase
      // const { data } = await supabaseDataService.getChecklists();
    } catch (error) {
      console.error('Failed to sync checklists from Supabase:', error);
    }
  }

  // Get or create checklist for an event
  async getOrCreateChecklist(
    eventId: string,
    eventTitle: string,
    eventDate: string
  ): Promise<Checklist> {
    // Try to find existing checklist
    const existingChecklist = await this.findChecklistByEventId(eventId);
    if (existingChecklist) {
      return existingChecklist;
    }

    // Create new checklist
    const newChecklist = await this.createChecklist(eventId, eventTitle, eventDate);
    return newChecklist;
  }

  // Find checklist by event identifier
  async findChecklistByEventId(eventId: string): Promise<Checklist | null> {
    // Try multiple identifier formats for backward compatibility
    const dateStr = format(new Date(), 'yyyy-MM-dd');
    const primaryHash = generateEventIdentifierHash(eventTitle, dateStr);
    const legacyId = generateLegacyEventIdentifier(eventTitle, dateStr);

    for (const checklist of this.checklists.values()) {
      if (checklist.eventIdentifier === eventId ||
          checklist.eventIdentifier === primaryHash ||
          checklist.eventIdentifier === legacyId) {
        return checklist;
      }
    }

    return null;
  }

  // Create a new checklist
  async createChecklist(
    eventId: string,
    title: string,
    eventDate: string
  ): Promise<Checklist> {
    const dateStr = format(parseISO(eventDate), 'yyyy-MM-dd');
    const eventIdentifier = generateEventIdentifierHash(title, dateStr);

    const checklist: Checklist = {
      id: `checklist_${Date.now()}_${Math.random().toString(36).substring(7)}`,
      eventIdentifier: eventId || eventIdentifier,
      title: title,
      isCompleted: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      items: [],
    };

    // Save locally
    this.checklists.set(checklist.id, checklist);
    await this.saveChecklists();
    await this.syncToSupabase(checklist);

    // Notify listeners
    this.notifyListeners();

    return checklist;
  }

  // Add item to checklist
  async addItem(
    checklistId: string,
    text: string,
    sortOrder: number = 0
  ): Promise<ChecklistItem | null> {
    const checklist = this.checklists.get(checklistId);
    if (!checklist) {
      console.error('Checklist not found:', checklistId);
      return null;
    }

    const item: ChecklistItem = {
      id: `item_${Date.now()}_${Math.random().toString(36).substring(7)}`,
      checklistId,
      text,
      isChecked: false,
      sortOrder,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    checklist.items = checklist.items || [];
    checklist.items.push(item);
    checklist.updatedAt = new Date().toISOString();

    // Update local state
    this.checklists.set(checklistId, checklist);
    await this.saveChecklists();
    await this.syncToSupabase(checklist);

    // Notify listeners
    this.notifyListeners();

    return item;
  }

  // Toggle checklist item
  async toggleItem(checklistId: string, itemId: string): Promise<boolean> {
    const checklist = this.checklists.get(checklistId);
    if (!checklist || !checklist.items) {
      return false;
    }

    let updated = false;
    checklist.items = checklist.items.map(item => {
      if (item.id === itemId) {
        updated = true;
        return { ...item, isChecked: !item.isChecked, updatedAt: new Date().toISOString() };
      }
      return item;
    });

    if (updated) {
      // Check if all items are completed
      const allCompleted = checklist.items.every(item => item.isChecked);
      checklist.isCompleted = allCompleted;
      checklist.updatedAt = new Date().toISOString();

      // Update local state
      this.checklists.set(checklistId, checklist);
      await this.saveChecklists();
      await this.syncToSupabase(checklist);

      // Notify listeners
      this.notifyListeners();
    }

    return updated;
  }

  // Update checklist item
  async updateItem(
    checklistId: string,
    itemId: string,
    updates: Partial<ChecklistItem>
  ): Promise<boolean> {
    const checklist = this.checklists.get(checklistId);
    if (!checklist || !checklist.items) {
      return false;
    }

    let updated = false;
    checklist.items = checklist.items.map(item => {
      if (item.id === itemId) {
        updated = true;
        return { ...item, ...updates, updatedAt: new Date().toISOString() };
      }
      return item;
    });

    if (updated) {
      checklist.updatedAt = new Date().toISOString();

      this.checklists.set(checklistId, checklist);
      await this.saveChecklists();
      await this.syncToSupabase(checklist);

      this.notifyListeners();
    }

    return updated;
  }

  // Delete checklist item
  async deleteItem(checklistId: string, itemId: string): Promise<boolean> {
    const checklist = this.checklists.get(checklistId);
    if (!checklist || !checklist.items) {
      return false;
    }

    const originalCount = checklist.items.length;
    checklist.items = checklist.items.filter(item => item.id !== itemId);

    if (checklist.items.length !== originalCount) {
      checklist.updatedAt = new Date().toISOString();

      this.checklists.set(checklistId, checklist);
      await this.saveChecklists();
      await this.syncToSupabase(checklist);

      this.notifyListeners();
      return true;
    }

    return false;
  }

  // Delete entire checklist
  async deleteChecklist(checklistId: string): Promise<boolean> {
    if (this.checklists.has(checklistId)) {
      this.checklists.delete(checklistId);
      await this.saveChecklists();
      // TODO: Delete from Supabase
      this.notifyListeners();
      return true;
    }
    return false;
  }

  // Get all checklists
  getAllChecklists(): Checklist[] {
    return Array.from(this.checklists.values());
  }

  // Get checklists for a specific event
  getChecklistsForEvent(eventId: string): Checklist[] {
    return Array.from(this.checklists.values()).filter(
      checklist => checklist.eventIdentifier === eventId
    );
  }

  // Get incomplete checklists
  getIncompleteChecklists(): Checklist[] {
    return Array.from(this.checklists.values()).filter(
      checklist => !checklist.isCompleted
    );
  }

  // Reorder checklist items
  async reorderItems(
    checklistId: string,
    itemIds: string[]
  ): Promise<boolean> {
    const checklist = this.checklists.get(checklistId);
    if (!checklist || !checklist.items) {
      return false;
    }

    const itemMap = new Map(checklist.items.map(item => [item.id, item]));
    checklist.items = itemIds
      .map(id => itemMap.get(id))
      .filter((item): item is ChecklistItem => item !== undefined)
      .map((item, index) => ({ ...item, sortOrder: index }));

    checklist.updatedAt = new Date().toISOString();

    this.checklists.set(checklistId, checklist);
    await this.saveChecklists();
    await this.syncToSupabase(checklist);

    this.notifyListeners();
    return true;
  }

  // Subscribe to checklist changes
  subscribe(callback: ChecklistChangeCallback): () => void {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }

  // Notify all listeners
  private notifyListeners(): void {
    const checklists = this.getAllChecklists();
    this.listeners.forEach(callback => {
      try {
        callback(checklists);
      } catch (error) {
        console.error('Checklist listener error:', error);
      }
    });
  }

  // Save checklists to local storage
  private async saveChecklists(): Promise<void> {
    try {
      const checklists = Array.from(this.checklists.values());
      await AsyncStorage.setItem(STORAGE_KEYS.CACHED_ADDRESSES, JSON.stringify(checklists));
    } catch (error) {
      console.error('Failed to save checklists:', error);
    }
  }

  // Sync checklist to Supabase
  private async syncToSupabase(checklist: Checklist): Promise<void> {
    try {
      const familyId = await AsyncStorage.getItem(STORAGE_KEYS.FAMILY_ID);
      if (!familyId) return;

      // TODO: Implement Supabase sync
      // await supabaseDataService.upsertChecklist({
      //   ...checklist,
      //   family_id: familyId,
      // });
    } catch (error) {
      console.error('Failed to sync checklist to Supabase:', error);
    }
  }

  // Handle event deletion - mark checklist as deleted
  async handleEventDeletion(eventId: string): Promise<void> {
    const checklists = this.getChecklistsForEvent(eventId);
    
    for (const checklist of checklists) {
      // Soft delete - mark as completed and archive
      checklist.isCompleted = true;
      checklist.updatedAt = new Date().toISOString();
      this.checklists.set(checklist.id, checklist);
    }

    await this.saveChecklists();
    this.notifyListeners();
  }

  // Check if service is initialized
  isReady(): boolean {
    return this.isInitialized;
  }
}

export const checklistManager = new ChecklistManager();
export default checklistManager;
