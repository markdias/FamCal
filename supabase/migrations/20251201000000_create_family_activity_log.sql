-- Create family_activity_log table for tracking family actions
-- Used for notifications and activity feeds
-- Safe to run multiple times

-- Create activity_type enum if not exists
CREATE TYPE public.activity_type AS ENUM (
    'member_added',
    'member_edited',
    'member_deleted',
    'member_linked',
    'driver_created',
    'driver_updated',
    'driver_deleted',
    'address_added',
    'address_updated',
    'address_deleted',
    'calendar_shared',
    'calendar_removed'
);

-- Create subject_type enum if not exists
CREATE TYPE public.subject_type AS ENUM (
    'family_member',
    'driver',
    'address',
    'shared_calendar'
);

-- Create family_activity_log table
CREATE TABLE IF NOT EXISTS public.family_activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    action_by_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_by_member_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL,
    action_type public.activity_type NOT NULL,
    action_subject_id TEXT NOT NULL,
    action_subject_type public.subject_type NOT NULL,
    subject_name TEXT NOT NULL,
    action_details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create indices for efficient querying
CREATE INDEX IF NOT EXISTS idx_family_activity_log_family_id_created_at
    ON public.family_activity_log(family_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_family_activity_log_action_by_user_id
    ON public.family_activity_log(action_by_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_family_activity_log_action_type
    ON public.family_activity_log(action_type);

CREATE INDEX IF NOT EXISTS idx_family_activity_log_subject_id
    ON public.family_activity_log(action_subject_id);

-- Enable RLS
ALTER TABLE public.family_activity_log ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view activity logs for families they're part of
DROP POLICY IF EXISTS "Users can view family activity logs" ON public.family_activity_log;
CREATE POLICY "Users can view family activity logs"
    ON public.family_activity_log
    FOR SELECT
    USING (
        family_id IN (
            SELECT family_id FROM public.families
            WHERE owner_user_id = auth.uid()
        )
        OR
        family_id IN (
            SELECT DISTINCT fm.family_id FROM public.family_members fm
            WHERE fm.linked_user_id = auth.uid()
        )
    );

-- RLS Policy: System can insert (via triggers, using security definer)
DROP POLICY IF EXISTS "System can insert family activity logs" ON public.family_activity_log;
CREATE POLICY "System can insert family activity logs"
    ON public.family_activity_log
    FOR INSERT
    WITH CHECK (true); -- Controlled via trigger with SECURITY DEFINER

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_family_activity_log_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS family_activity_log_updated_at_trigger ON public.family_activity_log;
CREATE TRIGGER family_activity_log_updated_at_trigger
    BEFORE UPDATE ON public.family_activity_log
    FOR EACH ROW
    EXECUTE FUNCTION public.update_family_activity_log_updated_at();

-- Comment on table
COMMENT ON TABLE public.family_activity_log IS 'Audit trail of family actions for notifications and activity feeds';
COMMENT ON COLUMN public.family_activity_log.action_type IS 'Type of action performed (member_added, driver_created, etc.)';
COMMENT ON COLUMN public.family_activity_log.action_details IS 'JSONB object with additional context (oldValue, newValue, changedFields, etc.)';
