import { useState, useEffect, useCallback } from 'react';
import { FamilyMember, Family } from '@/types';
import supabaseDataService from '@/services/supabase/SupabaseDataService';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { STORAGE_KEYS } from '@/utils/storageKeys';

export function useFamilyData() {
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [family, setFamily] = useState<Family | null>(null);
  const [members, setMembers] = useState<FamilyMember[]>([]);
  const [currentMemberId, setCurrentMemberId] = useState<string | null>(null);

  // Load family data
  const loadFamily = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const familyId = await AsyncStorage.getItem(STORAGE_KEYS.FAMILY_ID);
      
      if (familyId) {
        const { data: familyData } = await supabaseDataService.getFamily(familyId);
        if (familyData) {
          setFamily(familyData as unknown as Family);
        }

        const { data: membersData } = await supabaseDataService.getFamilyMembers(familyId);
        if (membersData) {
          setMembers(membersData as unknown as FamilyMember[]);
        }
      }
    } catch (err) {
      setError(err as Error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Load family on mount
  useEffect(() => {
    loadFamily();
  }, [loadFamily]);

  // Get family members
  const getMembers = useCallback(async (familyId?: string): Promise<FamilyMember[]> => {
    try {
      const { data } = await supabaseDataService.getFamilyMembers(familyId);
      return (data as unknown as FamilyMember[]) || [];
    } catch (err) {
      setError(err as Error);
      return [];
    }
  }, []);

  // Get member by ID
  const getMember = useCallback(async (memberId: string): Promise<FamilyMember | null> => {
    try {
      const { data } = await supabaseDataService.getFamilyMember(memberId);
      return (data as unknown as FamilyMember) || null;
    } catch (err) {
      setError(err as Error);
      return null;
    }
  }, []);

  // Create family
  const createFamily = useCallback(async (name: string): Promise<Family | null> => {
    try {
      const { data } = await supabaseDataService.createFamily(name);
      if (data) {
        await AsyncStorage.setItem(STORAGE_KEYS.FAMILY_ID, data.id);
        setFamily(data as unknown as Family);
        return data as unknown as Family;
      }
      return null;
    } catch (err) {
      setError(err as Error);
      return null;
    }
  }, []);

  // Create family member
  const createMember = useCallback(async (
    member: Omit<FamilyMember, 'id' | 'createdAt' | 'updatedAt'>
  ): Promise<FamilyMember | null> => {
    try {
      const { data } = await supabaseDataService.createFamilyMember(member as any);
      if (data) {
        const newMember = data as unknown as FamilyMember;
        setMembers(prev => [...prev, newMember]);
        return newMember;
      }
      return null;
    } catch (err) {
      setError(err as Error);
      return null;
    }
  }, []);

  // Update family member
  const updateMember = useCallback(async (
    memberId: string,
    updates: Partial<FamilyMember>
  ): Promise<FamilyMember | null> => {
    try {
      const { data } = await supabaseDataService.updateFamilyMember(memberId, updates as any);
      if (data) {
        const updatedMember = data as unknown as FamilyMember;
        setMembers(prev => prev.map(m => m.id === memberId ? updatedMember : m));
        return updatedMember;
      }
      return null;
    } catch (err) {
      setError(err as Error);
      return null;
    }
  }, []);

  // Delete family member
  const deleteMember = useCallback(async (memberId: string): Promise<boolean> => {
    try {
      const { error } = await supabaseDataService.deleteFamilyMember(memberId);
      if (!error) {
        setMembers(prev => prev.filter(m => m.id !== memberId));
        return true;
      }
      return false;
    } catch (err) {
      setError(err as Error);
      return false;
    }
  }, []);

  // Set current member
  const setCurrentMember = useCallback(async (memberId: string) => {
    setCurrentMemberId(memberId);
    await AsyncStorage.setItem(STORAGE_KEYS.SELECTED_MEMBER_ID, memberId);
  }, []);

  // Get current member
  const getCurrentMember = useCallback((): FamilyMember | null => {
    if (!currentMemberId) return null;
    return members.find(m => m.id === currentMemberId) || null;
  }, [currentMemberId, members]);

  return {
    isLoading,
    error,
    family,
    members,
    currentMemberId,
    getCurrentMember,
    loadFamily,
    getMembers,
    getMember,
    createFamily,
    createMember,
    updateMember,
    deleteMember,
    setCurrentMember,
  };
}
