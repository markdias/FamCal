-- Enable hard delete for notes table
-- This migration removes the soft delete infrastructure and allows actual row deletion

-- Drop the trigger that auto-updates modified_at
DROP TRIGGER IF EXISTS update_notes_modified_at ON public.notes;
DROP FUNCTION IF EXISTS public.update_notes_modified_at_column();

-- Drop the deleted_at index since we're removing the column
DROP INDEX IF EXISTS idx_notes_deleted_at;

-- Remove the deleted_at column (soft delete is no longer supported)
ALTER TABLE public.notes DROP COLUMN IF EXISTS deleted_at;

-- Recreate the modified_at trigger without the soft-delete logic
CREATE OR REPLACE FUNCTION public.update_notes_modified_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.modified_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_notes_modified_at
BEFORE UPDATE ON public.notes
FOR EACH ROW
EXECUTE FUNCTION public.update_notes_modified_at_column();
