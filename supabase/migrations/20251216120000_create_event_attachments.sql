-- Create event_attachments table for managing file uploads associated with events
-- Attachments are scoped to families via the family_id foreign key

CREATE TABLE IF NOT EXISTS public.event_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    event_identifier TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    file_type TEXT,
    storage_path TEXT NOT NULL,
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    uploaded_by UUID REFERENCES auth.users,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_event_attachments_event ON public.event_attachments(event_identifier);
CREATE INDEX IF NOT EXISTS idx_event_attachments_user ON public.event_attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_event_attachments_family ON public.event_attachments(family_id);
CREATE INDEX IF NOT EXISTS idx_event_attachments_created_at ON public.event_attachments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.event_attachments ENABLE ROW LEVEL SECURITY;

-- Policy 1: Family members can view attachments for their family
CREATE POLICY "Family members can view family attachments"
  ON public.event_attachments
  FOR SELECT
  USING (
    family_id IN (
      SELECT family_id FROM public.profiles WHERE id = auth.uid()
    )
  );

-- Policy 2: Users can upload attachments to their family
CREATE POLICY "Users can upload attachments to family"
  ON public.event_attachments
  FOR INSERT
  WITH CHECK (
    user_id = auth.uid() AND
    family_id IN (
      SELECT family_id FROM public.profiles WHERE id = auth.uid()
    )
  );

-- Policy 3: Users can update their own attachments
CREATE POLICY "Users can update own attachments"
  ON public.event_attachments
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy 4: Users can delete their own attachments
CREATE POLICY "Users can delete own attachments"
  ON public.event_attachments
  FOR DELETE
  USING (user_id = auth.uid());

-- Create storage bucket for event attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('event-attachments', 'event-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Set up storage bucket RLS policies
-- Policy 1: Users can upload to their family's folder
CREATE POLICY "Users can upload to family folder" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'event-attachments' AND
    (storage.foldername(name))[1] IN (
      SELECT family_id::text FROM public.profiles WHERE id = auth.uid()
    )
  );

-- Policy 2: Users can read family attachments
CREATE POLICY "Users can read family attachments" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'event-attachments' AND
    (storage.foldername(name))[1] IN (
      SELECT family_id::text FROM public.profiles WHERE id = auth.uid()
    )
  );

-- Policy 3: Users can delete their own attachments
CREATE POLICY "Users can delete own attachments in storage" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'event-attachments' AND
    auth.uid()::text = (storage.foldername(name))[2]
  );

-- Create Postgres function for quota calculation
CREATE OR REPLACE FUNCTION public.get_attachment_storage_used(p_user_id UUID)
RETURNS BIGINT AS $$
  SELECT COALESCE(SUM(file_size), 0)::BIGINT
  FROM public.event_attachments
  WHERE user_id = p_user_id;
$$ LANGUAGE SQL STABLE;

-- Add auto-update trigger for updated_at column
CREATE OR REPLACE FUNCTION public.update_event_attachments_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_event_attachments_updated_at ON public.event_attachments;
CREATE TRIGGER update_event_attachments_updated_at
BEFORE UPDATE ON public.event_attachments
FOR EACH ROW
EXECUTE FUNCTION public.update_event_attachments_updated_at_column();

-- Add table comments for documentation
COMMENT ON TABLE public.event_attachments IS 'Event attachments storage metadata for FamCal. Files are stored in the event-attachments storage bucket.';
COMMENT ON COLUMN public.event_attachments.id IS 'Unique identifier for the attachment';
COMMENT ON COLUMN public.event_attachments.user_id IS 'User who uploaded the attachment';
COMMENT ON COLUMN public.event_attachments.family_id IS 'Family that owns this attachment';
COMMENT ON COLUMN public.event_attachments.event_identifier IS 'Identifier of the event this attachment is associated with';
COMMENT ON COLUMN public.event_attachments.file_name IS 'Original file name';
COMMENT ON COLUMN public.event_attachments.file_size IS 'File size in bytes';
COMMENT ON COLUMN public.event_attachments.file_type IS 'MIME type of the file';
COMMENT ON COLUMN public.event_attachments.storage_path IS 'Path to the file in the storage bucket';
COMMENT ON COLUMN public.event_attachments.uploaded_at IS 'When the file was uploaded';
COMMENT ON COLUMN public.event_attachments.uploaded_by IS 'User ID of the uploader (denormalized for reference)';
COMMENT ON COLUMN public.event_attachments.created_at IS 'When the record was created';
COMMENT ON COLUMN public.event_attachments.updated_at IS 'When the record was last modified (auto-updated)';
