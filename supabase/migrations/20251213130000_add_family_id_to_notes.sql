-- Add family_id column to notes table for better family scoping and RLS
-- Backfill family_id from family_members table via member_identifier foreign key

-- Add family_id column
ALTER TABLE public.notes ADD COLUMN family_id UUID REFERENCES public.families(id) ON DELETE CASCADE;

-- Backfill family_id from family_members table
UPDATE public.notes n
SET family_id = fm.family_id
FROM public.family_members fm
WHERE n.member_identifier = fm.id
  AND n.family_id IS NULL;

-- Make family_id NOT NULL after backfill
ALTER TABLE public.notes ALTER COLUMN family_id SET NOT NULL;

-- Drop old RLS policies
DROP POLICY IF EXISTS "Family members can view notes for family members" ON public.notes;
DROP POLICY IF EXISTS "Family members can insert notes for family members" ON public.notes;
DROP POLICY IF EXISTS "Family members can update notes for family members" ON public.notes;
DROP POLICY IF EXISTS "Family members can delete notes for family members" ON public.notes;

-- Create new simplified RLS policies using family_id directly
CREATE POLICY "Family members can view notes in their family"
  ON public.notes
  FOR SELECT
  USING (
    is_family_member(family_id)
  );

CREATE POLICY "Family members can insert notes in their family"
  ON public.notes
  FOR INSERT
  WITH CHECK (
    is_family_member(family_id)
  );

CREATE POLICY "Family members can update notes in their family"
  ON public.notes
  FOR UPDATE
  USING (is_family_member(family_id))
  WITH CHECK (is_family_member(family_id));

CREATE POLICY "Family members can delete notes in their family"
  ON public.notes
  FOR DELETE
  USING (is_family_member(family_id));

-- Create index on family_id for efficient queries
CREATE INDEX IF NOT EXISTS idx_notes_family_id ON public.notes(family_id);

-- Update table comment
COMMENT ON COLUMN public.notes.family_id IS 'References the family this note belongs to (denormalized from member_identifier for RLS efficiency)';
