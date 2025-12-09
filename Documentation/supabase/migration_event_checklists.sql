-- Migration: Add Event Checklists Feature
-- Description: Adds checklist functionality to events with support for shared checklist items
-- Date: 2025-12-09
-- Author: Claude Code

-- ============================================================================
-- TABLE: event_checklists
-- Description: Stores checklists associated with calendar events
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.event_checklists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_identifier TEXT NOT NULL,
    event_group_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    deletion_reason TEXT,

    CONSTRAINT event_checklists_event_identifier_check CHECK (char_length(event_identifier) > 0)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_event_checklists_event_id
    ON public.event_checklists(event_identifier)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_event_checklists_group_id
    ON public.event_checklists(event_group_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_event_checklists_created_at
    ON public.event_checklists(created_at DESC);

-- Add comment for documentation
COMMENT ON TABLE public.event_checklists IS 'Stores checklists for calendar events. Each event can have one checklist with multiple items.';
COMMENT ON COLUMN public.event_checklists.event_identifier IS 'EventKit event identifier from iOS calendar';
COMMENT ON COLUMN public.event_checklists.event_group_id IS 'Groups checklists across recurring event occurrences';
COMMENT ON COLUMN public.event_checklists.deleted_at IS 'Soft delete timestamp - null means active';

-- ============================================================================
-- TABLE: checklist_items
-- Description: Stores individual items within a checklist
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.checklist_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    checklist_id UUID NOT NULL REFERENCES public.event_checklists(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    due_date TIMESTAMPTZ,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    completed_by UUID,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    notification_id TEXT,

    CONSTRAINT checklist_items_title_check CHECK (char_length(title) > 0),
    CONSTRAINT checklist_items_sort_order_check CHECK (sort_order >= 0),
    CONSTRAINT checklist_items_completed_logic CHECK (
        (completed = FALSE AND completed_at IS NULL AND completed_by IS NULL) OR
        (completed = TRUE)
    )
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_checklist_items_checklist
    ON public.checklist_items(checklist_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_checklist_items_sort_order
    ON public.checklist_items(checklist_id, sort_order)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_checklist_items_due_date
    ON public.checklist_items(due_date)
    WHERE deleted_at IS NULL AND completed = FALSE;

-- Add comment for documentation
COMMENT ON TABLE public.checklist_items IS 'Individual items within an event checklist';
COMMENT ON COLUMN public.checklist_items.title IS 'Item description or title';
COMMENT ON COLUMN public.checklist_items.due_date IS 'Optional due date for the item (can be different from event date)';
COMMENT ON COLUMN public.checklist_items.completed_by IS 'UUID of family member who checked off the item';
COMMENT ON COLUMN public.checklist_items.sort_order IS 'Display order within the checklist (0-based)';
COMMENT ON COLUMN public.checklist_items.notification_id IS 'Comma-separated list of iOS notification IDs';

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on both tables
ALTER TABLE public.event_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICY: event_checklists - SELECT
-- Description: Users can view checklists for events they have access to
-- ============================================================================

CREATE POLICY "Users can view checklists for their family events"
    ON public.event_checklists
    FOR SELECT
    USING (
        -- User is authenticated
        auth.uid() IS NOT NULL
        AND
        -- Checklist is not deleted
        deleted_at IS NULL
        AND
        -- User belongs to a family (through family_members table)
        EXISTS (
            SELECT 1
            FROM public.family_members fm
            WHERE fm.user_id::uuid = auth.uid()
        )
    );

-- ============================================================================
-- RLS POLICY: event_checklists - INSERT
-- Description: Users can create checklists for events
-- ============================================================================

CREATE POLICY "Users can create checklists"
    ON public.event_checklists
    FOR INSERT
    WITH CHECK (
        -- User is authenticated
        auth.uid() IS NOT NULL
        AND
        -- User belongs to a family
        EXISTS (
            SELECT 1
            FROM public.family_members fm
            WHERE fm.user_id::uuid = auth.uid()
        )
    );

-- ============================================================================
-- RLS POLICY: event_checklists - UPDATE
-- Description: Users can update checklists for their family events
-- ============================================================================

CREATE POLICY "Users can update checklists for their family events"
    ON public.event_checklists
    FOR UPDATE
    USING (
        -- User is authenticated
        auth.uid() IS NOT NULL
        AND
        -- User belongs to a family
        EXISTS (
            SELECT 1
            FROM public.family_members fm
            WHERE fm.user_id::uuid = auth.uid()
        )
    )
    WITH CHECK (
        -- Same condition as USING
        auth.uid() IS NOT NULL
        AND
        EXISTS (
            SELECT 1
            FROM public.family_members fm
            WHERE fm.user_id::uuid = auth.uid()
        )
    );

-- ============================================================================
-- RLS POLICY: event_checklists - DELETE
-- Description: Users can soft delete checklists (sets deleted_at timestamp)
-- Note: Actual DELETE operations should be rare - use soft delete instead
-- ============================================================================

CREATE POLICY "Users can delete checklists for their family events"
    ON public.event_checklists
    FOR DELETE
    USING (
        -- User is authenticated
        auth.uid() IS NOT NULL
        AND
        -- User belongs to a family
        EXISTS (
            SELECT 1
            FROM public.family_members fm
            WHERE fm.user_id::uuid = auth.uid()
        )
    );

-- ============================================================================
-- RLS POLICY: checklist_items - SELECT
-- Description: Users can view items for checklists they have access to
-- ============================================================================

CREATE POLICY "Users can view checklist items for their family events"
    ON public.checklist_items
    FOR SELECT
    USING (
        -- User is authenticated
        auth.uid() IS NOT NULL
        AND
        -- Item is not deleted
        deleted_at IS NULL
        AND
        -- User has access to the parent checklist
        EXISTS (
            SELECT 1
            FROM public.event_checklists ec
            JOIN public.family_members fm ON fm.user_id::uuid = auth.uid()
            WHERE ec.id = checklist_id
            AND ec.deleted_at IS NULL
        )
    );

-- ============================================================================
-- RLS POLICY: checklist_items - INSERT
-- Description: Users can create items in checklists they have access to
-- ============================================================================

CREATE POLICY "Users can create checklist items"
    ON public.checklist_items
    FOR INSERT
    WITH CHECK (
        -- User is authenticated
        auth.uid() IS NOT NULL
        AND
        -- User has access to the parent checklist
        EXISTS (
            SELECT 1
            FROM public.event_checklists ec
            JOIN public.family_members fm ON fm.user_id::uuid = auth.uid()
            WHERE ec.id = checklist_id
            AND ec.deleted_at IS NULL
        )
    );

-- ============================================================================
-- RLS POLICY: checklist_items - UPDATE
-- Description: Users can update items in checklists they have access to
-- ============================================================================

CREATE POLICY "Users can update checklist items"
    ON public.checklist_items
    FOR UPDATE
    USING (
        -- User is authenticated
        auth.uid() IS NOT NULL
        AND
        -- User has access to the parent checklist
        EXISTS (
            SELECT 1
            FROM public.event_checklists ec
            JOIN public.family_members fm ON fm.user_id::uuid = auth.uid()
            WHERE ec.id = checklist_id
            AND ec.deleted_at IS NULL
        )
    )
    WITH CHECK (
        -- Same condition as USING
        auth.uid() IS NOT NULL
        AND
        EXISTS (
            SELECT 1
            FROM public.event_checklists ec
            JOIN public.family_members fm ON fm.user_id::uuid = auth.uid()
            WHERE ec.id = checklist_id
            AND ec.deleted_at IS NULL
        )
    );

-- ============================================================================
-- RLS POLICY: checklist_items - DELETE
-- Description: Users can soft delete items (sets deleted_at timestamp)
-- ============================================================================

CREATE POLICY "Users can delete checklist items"
    ON public.checklist_items
    FOR DELETE
    USING (
        -- User is authenticated
        auth.uid() IS NOT NULL
        AND
        -- User has access to the parent checklist
        EXISTS (
            SELECT 1
            FROM public.event_checklists ec
            JOIN public.family_members fm ON fm.user_id::uuid = auth.uid()
            WHERE ec.id = checklist_id
        )
    );

-- ============================================================================
-- FUNCTIONS: Auto-update modified_at timestamp
-- ============================================================================

-- Function to automatically update modified_at timestamp
CREATE OR REPLACE FUNCTION public.update_modified_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for event_checklists
DROP TRIGGER IF EXISTS update_event_checklists_modified_at ON public.event_checklists;
CREATE TRIGGER update_event_checklists_modified_at
    BEFORE UPDATE ON public.event_checklists
    FOR EACH ROW
    EXECUTE FUNCTION public.update_modified_at_column();

-- Trigger for checklist_items
DROP TRIGGER IF EXISTS update_checklist_items_modified_at ON public.checklist_items;
CREATE TRIGGER update_checklist_items_modified_at
    BEFORE UPDATE ON public.checklist_items
    FOR EACH ROW
    EXECUTE FUNCTION public.update_modified_at_column();

-- ============================================================================
-- GRANTS: Allow authenticated users to access tables
-- ============================================================================

-- Grant basic permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.event_checklists TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.checklist_items TO authenticated;

-- Grant usage on sequences (for id generation)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- VERIFICATION QUERIES (Run these to verify the migration)
-- ============================================================================

-- Verify tables were created
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('event_checklists', 'checklist_items');

-- Verify RLS is enabled
-- SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('event_checklists', 'checklist_items');

-- Verify policies were created
-- SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public' AND tablename IN ('event_checklists', 'checklist_items');

-- Verify indexes were created
-- SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('event_checklists', 'checklist_items');

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
