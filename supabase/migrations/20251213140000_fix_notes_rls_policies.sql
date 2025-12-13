-- Fix RLS policies on notes table - simplify to directly check family membership
-- The previous policies may have been too restrictive

-- Drop the existing complex policies
DROP POLICY IF EXISTS "Family members can view notes in their family" ON public.notes;
DROP POLICY IF EXISTS "Family members can insert notes in their family" ON public.notes;
DROP POLICY IF EXISTS "Family members can update notes in their family" ON public.notes;
DROP POLICY IF EXISTS "Family members can delete notes in their family" ON public.notes;

-- Disable RLS temporarily to allow admin operations
ALTER TABLE public.notes DISABLE ROW LEVEL SECURITY;

-- Re-enable RLS
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- Create simplified RLS policies that work with the family_id directly
-- SELECT policy: user must be part of the family
CREATE POLICY "notes_select_family"
  ON public.notes
  FOR SELECT
  USING (
    family_id IN (
      SELECT DISTINCT family_id FROM public.family_members
      WHERE linked_user_id = auth.uid()
    )
    OR
    family_id IN (
      SELECT id FROM public.families
      WHERE owner_user_id = auth.uid()
    )
  );

-- INSERT policy: user must be part of the family
CREATE POLICY "notes_insert_family"
  ON public.notes
  FOR INSERT
  WITH CHECK (
    family_id IN (
      SELECT DISTINCT family_id FROM public.family_members
      WHERE linked_user_id = auth.uid()
    )
    OR
    family_id IN (
      SELECT id FROM public.families
      WHERE owner_user_id = auth.uid()
    )
  );

-- UPDATE policy: user must be part of the family
CREATE POLICY "notes_update_family"
  ON public.notes
  FOR UPDATE
  USING (
    family_id IN (
      SELECT DISTINCT family_id FROM public.family_members
      WHERE linked_user_id = auth.uid()
    )
    OR
    family_id IN (
      SELECT id FROM public.families
      WHERE owner_user_id = auth.uid()
    )
  )
  WITH CHECK (
    family_id IN (
      SELECT DISTINCT family_id FROM public.family_members
      WHERE linked_user_id = auth.uid()
    )
    OR
    family_id IN (
      SELECT id FROM public.families
      WHERE owner_user_id = auth.uid()
    )
  );

-- DELETE policy: user must be part of the family
CREATE POLICY "notes_delete_family"
  ON public.notes
  FOR DELETE
  USING (
    family_id IN (
      SELECT DISTINCT family_id FROM public.family_members
      WHERE linked_user_id = auth.uid()
    )
    OR
    family_id IN (
      SELECT id FROM public.families
      WHERE owner_user_id = auth.uid()
    )
  );
