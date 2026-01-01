import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'react-native-keychain';
import { STORAGE_KEYS, SECURE_STORAGE_KEYS, StorageKey } from '@/utils/storageKeys';

interface StorageValue {
  value: string;
  timestamp: number;
}

type StorageChangeCallback = (key: string, value: string | null) => void;

class StorageService {
  private listeners: Map<string, Set<StorageChangeCallback>> = new Map();
  private isInitialized = false;

  // Initialize storage service
  async initialize(): Promise<void> {
    this.isInitialized = true;
    console.log('Storage service initialized');
  }

  // ============ AsyncStorage Operations (Non-sensitive data) ============

  // Set a value
  async set(key: StorageKey, value: string): Promise<void> {
    try {
      await AsyncStorage.setItem(STORAGE_KEYS[key], value);
      this.notifyListeners(key, value);
    } catch (error) {
      console.error(`Failed to set ${key}:`, error);
      throw error;
    }
  }

  // Set an object (JSON)
  async setObject(key: StorageKey, value: Record<string, unknown>): Promise<void> {
    try {
      const jsonValue = JSON.stringify(value);
      await AsyncStorage.setItem(STORAGE_KEYS[key], jsonValue);
      this.notifyListeners(key, jsonValue);
    } catch (error) {
      console.error(`Failed to set object ${key}:`, error);
      throw error;
    }
  }

  // Get a value
  async get(key: StorageKey): Promise<string | null> {
    try {
      return await AsyncStorage.getItem(STORAGE_KEYS[key]);
    } catch (error) {
      console.error(`Failed to get ${key}:`, error);
      return null;
    }
  }

  // Get an object (JSON)
  async getObject<T>(key: StorageKey): Promise<T | null> {
    try {
      const jsonValue = await AsyncStorage.getItem(STORAGE_KEYS[key]);
      if (jsonValue) {
        return JSON.parse(jsonValue) as T;
      }
      return null;
    } catch (error) {
      console.error(`Failed to get object ${key}:`, error);
      return null;
    }
  }

  // Get a value with default
  async getOrDefault(key: StorageKey, defaultValue: string): Promise<string> {
    const value = await this.get(key);
    return value ?? defaultValue;
  }

  // Remove a value
  async remove(key: StorageKey): Promise<void> {
    try {
      await AsyncStorage.removeItem(STORAGE_KEYS[key]);
      this.notifyListeners(key, null);
    } catch (error) {
      console.error(`Failed to remove ${key}:`, error);
      throw error;
    }
  }

  // Check if key exists
  async has(key: StorageKey): Promise<boolean> {
    try {
      const value = await AsyncStorage.getItem(STORAGE_KEYS[key]);
      return value !== null;
    } catch (error) {
      console.error(`Failed to check ${key}:`, error);
      return false;
    }
  }

  // Clear all values
  async clearAll(): Promise<void> {
    try {
      const keys = Object.keys(STORAGE_KEYS);
      await AsyncStorage.multiRemove(keys);
      
      // Notify all listeners
      keys.forEach(key => {
        this.notifyListeners(key as StorageKey, null);
      });
    } catch (error) {
      console.error('Failed to clear all storage:', error);
      throw error;
    }
  }

  // Clear only non-sensitive data
  async clearNonSensitive(): Promise<void> {
    try {
      const sensitiveKeys = [
        'AUTH_TOKEN',
        'AUTH_REFRESH_TOKEN',
        'USER_ID',
        'USER_EMAIL',
        'PRO_ENABLED',
        'PRO_EXPIRES_AT',
      ];

      const keysToRemove = Object.keys(STORAGE_KEYS).filter(
        key => !sensitiveKeys.includes(key)
      );

      await AsyncStorage.multiRemove(keysToRemove);
    } catch (error) {
      console.error('Failed to clear non-sensitive data:', error);
      throw error;
    }
  }

  // Multi-get
  async multiGet(keys: StorageKey[]): Promise<Array<[StorageKey, string | null]>> {
    try {
      const stringKeys = keys.map(key => STORAGE_KEYS[key]);
      const results = await AsyncStorage.multiGet(stringKeys);
      
      return results.map(([storageKey, value]) => {
        const key = Object.keys(STORAGE_KEYS).find(
          k => STORAGE_KEYS[p as StorageKey] === storageKey
        ) as StorageKey;
        return [key, value];
      });
    } catch (error) {
      console.error('Failed to multiGet:', error);
      return keys.map(key => [key, null]);
    }
  }

  // Multi-set
  async multiSet(values: Array<[StorageKey, string]>): Promise<void> {
    try {
      const entries = values.map(([key, value]) => [STORAGE_KEYS[key], value]);
      await AsyncStorage.multiSet(entries);
      
      values.forEach(([key, value]) => {
        this.notifyListeners(key, value);
      });
    } catch (error) {
      console.error('Failed to multiSet:', error);
      throw error;
    }
  }

  // ============ SecureStore Operations (Sensitive data) ============

  // Set secure value
  async setSecure(key: string, value: string): Promise<void> {
    try {
      await SecureStore.setItemAsync(key, value, {
        accessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
      });
    } catch (error) {
      console.error(`Failed to set secure ${key}:`, error);
      throw error;
    }
  }

  // Get secure value
  async getSecure(key: string): Promise<string | null> {
    try {
      return await SecureStore.getItemAsync(key);
    } catch (error) {
      console.error(`Failed to get secure ${key}:`, error);
      return null;
    }
  }

  // Remove secure value
  async removeSecure(key: string): Promise<void> {
    try {
      await SecureStore.deleteItemAsync(key);
    } catch (error) {
      console.error(`Failed to remove secure ${key}:`, error);
      throw error;
    }
  }

  // Clear all secure values
  async clearSecureAll(): Promise<void> {
    try {
      await SecureStore.deleteItemAsync(SECURE_STORAGE_KEYS.AUTH_TOKEN);
      await SecureStore.deleteItemAsync(SECURE_STORAGE_KEYS.AUTH_REFRESH_TOKEN);
      await SecureStore.deleteItemAsync(SECURE_STORAGE_KEYS.ENCRYPTED_USER_DATA);
    } catch (error) {
      console.error('Failed to clear secure storage:', error);
      throw error;
    }
  }

  // ============ Subscriptions ============

  // Subscribe to storage changes
  subscribe(key: StorageKey, callback: StorageChangeCallback): () => void {
    if (!this.listeners.has(key)) {
      this.listeners.set(key, new Set());
    }
    this.listeners.get(key)!.add(callback);
    
    return () => {
      this.listeners.get(key)?.delete(callback);
    };
  }

  // Notify listeners
  private notifyListeners(key: StorageKey, value: string | null): void {
    const listeners = this.listeners.get(key);
    if (listeners) {
      listeners.forEach(callback => {
        try {
          callback(key, value);
        } catch (error) {
          console.error(`Storage listener error for ${key}:`, error);
        }
      });
    }
  }

  // ============ Migration Helpers ============

  // Migrate data from old key to new key
  async migrateKey(oldKey: string, newKey: StorageKey): Promise<boolean> {
    try {
      const oldValue = await AsyncStorage.getItem(oldKey);
      if (oldValue) {
        await this.set(newKey, oldValue);
        await AsyncStorage.removeItem(oldKey);
        return true;
      }
      return false;
    } catch (error) {
      console.error(`Failed to migrate key ${oldKey}:`, error);
      return false;
    }
  }

  // Check schema version and run migrations
  async checkAndRunMigrations(currentVersion: number): Promise<void> {
    const storedVersionStr = await AsyncStorage.getItem(STORAGE_KEYS.SCHEMA_VERSION);
    const storedVersion = parseInt(storedVersionStr || '0', 10);

    if (storedVersion < currentVersion) {
      console.log(`Running storage migrations from ${storedVersion} to ${currentVersion}`);
      
      // Run migrations based on version
      if (storedVersion < 1) {
        await this.runMigrationV1();
      }
      if (storedVersion < 2) {
        await this.runMigrationV2();
      }

      // Update version
      await AsyncStorage.setItem(STORAGE_KEYS.SCHEMA_VERSION, String(currentVersion));
    }
  }

  // Migration V1
  private async runMigrationV1(): Promise<void> {
    // Example migration: rename keys
    await this.migrateKey('com.famcal.theme', 'THEME_PREFERENCE');
    await this.migrateKey('com.famcal.userId', 'USER_ID');
    console.log('Migration V1 completed');
  }

  // Migration V2
  private async runMigrationV2(): Promise<void> {
    // Example migration: restructure data
    console.log('Migration V2 completed');
  }

  // ============ Helpers ============

  // Check if service is initialized
  isReady(): boolean {
    return this.isInitialized;
  }

  // Get storage usage info
  async getStorageInfo(): Promise<{ used: number; available: number }> {
    try {
      const keys = await AsyncStorage.getAllKeys();
      const data = await AsyncStorage.multiGet(keys);
      
      let used = 0;
      data.forEach(([, value]) => {
        if (value) {
          used += new Blob([value]).size;
        }
      });

      return {
        used,
        available: Number.MAX_SAFE_INTEGER - used, // Approximate
      };
    } catch (error) {
      console.error('Failed to get storage info:', error);
      return { used: 0, available: 0 };
    }
  }
}

export const storageService = new StorageService();
export default storageService;
