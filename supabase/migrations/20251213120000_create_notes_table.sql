-- Create notes table for member-specific notes with soft delete support
-- Notes are scoped to families via the member_id foreign key

CREATE TABLE IF NOT EXISTS public.notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_identifier UUID NOT NULL REFERENCES public.family_members(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  created_by TEXT
);

-- Enable Row Level Security
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- Create RLS policy: Family members can view notes for members in their family
CREATE POLICY "Family members can view notes for family members"
  ON public.notes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = notes.member_identifier
        AND EXISTS (
          SELECT 1 FROM public.families f
          WHERE f.id = fm.family_id
            AND (
              f.owner_user_id = auth.uid()
              OR EXISTS (
                SELECT 1 FROM public.family_members fm2
                WHERE fm2.family_id = f.id
                  AND fm2.linked_user_id = auth.uid()
              )
            )
        )
    )
  );

-- Create RLS policy: Family members can insert notes for members in their family
CREATE POLICY "Family members can insert notes for family members"
  ON public.notes
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = notes.member_identifier
        AND EXISTS (
          SELECT 1 FROM public.families f
          WHERE f.id = fm.family_id
            AND (
              f.owner_user_id = auth.uid()
              OR EXISTS (
                SELECT 1 FROM public.family_members fm2
                WHERE fm2.family_id = f.id
                  AND fm2.linked_user_id = auth.uid()
              )
            )
        )
    )
  );

-- Create RLS policy: Family members can update notes for members in their family
CREATE POLICY "Family members can update notes for family members"
  ON public.notes
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = notes.member_identifier
        AND EXISTS (
          SELECT 1 FROM public.families f
          WHERE f.id = fm.family_id
            AND (
              f.owner_user_id = auth.uid()
              OR EXISTS (
                SELECT 1 FROM public.family_members fm2
                WHERE fm2.family_id = f.id
                  AND fm2.linked_user_id = auth.uid()
              )
            )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = notes.member_identifier
        AND EXISTS (
          SELECT 1 FROM public.families f
          WHERE f.id = fm.family_id
            AND (
              f.owner_user_id = auth.uid()
              OR EXISTS (
                SELECT 1 FROM public.family_members fm2
                WHERE fm2.family_id = f.id
                  AND fm2.linked_user_id = auth.uid()
              )
            )
        )
    )
  );

-- Create RLS policy: Family members can delete (soft delete) notes for members in their family
CREATE POLICY "Family members can delete notes for family members"
  ON public.notes
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = notes.member_identifier
        AND EXISTS (
          SELECT 1 FROM public.families f
          WHERE f.id = fm.family_id
            AND (
              f.owner_user_id = auth.uid()
              OR EXISTS (
                SELECT 1 FROM public.family_members fm2
                WHERE fm2.family_id = f.id
                  AND fm2.linked_user_id = auth.uid()
              )
            )
        )
    )
  );

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notes_member_identifier ON public.notes(member_identifier);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON public.notes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_modified_at ON public.notes(modified_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON public.notes(deleted_at);

-- Add auto-update trigger for modified_at column
CREATE OR REPLACE FUNCTION public.update_notes_modified_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.modified_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_notes_modified_at ON public.notes;
CREATE TRIGGER update_notes_modified_at
BEFORE UPDATE ON public.notes
FOR EACH ROW
EXECUTE FUNCTION public.update_notes_modified_at_column();

-- Add table comment for documentation
COMMENT ON TABLE public.notes IS 'Member-specific notes for FamCal. Supports soft deletes via deleted_at column.';
COMMENT ON COLUMN public.notes.id IS 'Unique identifier for the note';
COMMENT ON COLUMN public.notes.member_identifier IS 'References the family member this note is for';
COMMENT ON COLUMN public.notes.content IS 'The note text content';
COMMENT ON COLUMN public.notes.created_at IS 'When the note was created';
COMMENT ON COLUMN public.notes.modified_at IS 'When the note was last modified (auto-updated)';
COMMENT ON COLUMN public.notes.deleted_at IS 'When the note was soft-deleted (NULL if active)';
COMMENT ON COLUMN public.notes.created_by IS 'User identifier who created the note';
