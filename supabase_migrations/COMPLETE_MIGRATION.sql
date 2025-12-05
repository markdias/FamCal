-- ============================================
-- FamCal Complete Database Migration
-- Copy and paste this entire file into Supabase SQL Editor
-- This fixes the "calendar_id" error and adds updated_at timestamps
-- ============================================

-- ============================================
-- PART 1: Drop old triggers referencing calendar_id
-- ============================================

-- Drop any triggers on shared_calendars
DROP TRIGGER IF EXISTS set_calendar_id_shared_calendars ON shared_calendars;
DROP TRIGGER IF EXISTS update_calendar_id_shared_calendars ON shared_calendars;
DROP TRIGGER IF EXISTS sync_calendar_id_shared_calendars ON shared_calendars;

-- Drop any triggers on family_member_calendars
DROP TRIGGER IF EXISTS set_calendar_id_family_member_calendars ON family_member_calendars;
DROP TRIGGER IF EXISTS update_calendar_id_family_member_calendars ON family_member_calendars;
DROP TRIGGER IF EXISTS sync_calendar_id_family_member_calendars ON family_member_calendars;

-- Drop any triggers on personal_calendars
DROP TRIGGER IF EXISTS set_calendar_id_personal_calendars ON personal_calendars;
DROP TRIGGER IF EXISTS update_calendar_id_personal_calendars ON personal_calendars;
DROP TRIGGER IF EXISTS sync_calendar_id_personal_calendars ON personal_calendars;

-- Drop old functions that might reference calendar_id
DROP FUNCTION IF EXISTS update_shared_calendars_calendar_id();
DROP FUNCTION IF EXISTS update_family_member_calendars_calendar_id();
DROP FUNCTION IF EXISTS update_personal_calendars_calendar_id();
DROP FUNCTION IF EXISTS set_calendar_id();
DROP FUNCTION IF EXISTS sync_calendar_id();

-- ============================================
-- PART 2: Add updated_at column to shared_calendars
-- ============================================

ALTER TABLE shared_calendars
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill existing rows with current timestamp
UPDATE shared_calendars
SET updated_at = NOW()
WHERE updated_at IS NULL;

-- Make updated_at NOT NULL after backfill
ALTER TABLE shared_calendars
ALTER COLUMN updated_at SET NOT NULL;

-- Create trigger to auto-update timestamp on row changes
CREATE OR REPLACE FUNCTION update_shared_calendars_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at_shared_calendars ON shared_calendars;
CREATE TRIGGER set_updated_at_shared_calendars
    BEFORE INSERT OR UPDATE ON shared_calendars
    FOR EACH ROW
    EXECUTE FUNCTION update_shared_calendars_updated_at();

-- ============================================
-- PART 3: Add updated_at column to family_member_calendars
-- ============================================

ALTER TABLE family_member_calendars
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill existing rows
UPDATE family_member_calendars
SET updated_at = NOW()
WHERE updated_at IS NULL;

-- Make updated_at NOT NULL after backfill
ALTER TABLE family_member_calendars
ALTER COLUMN updated_at SET NOT NULL;

-- Create trigger to auto-update timestamp
CREATE OR REPLACE FUNCTION update_family_member_calendars_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at_family_member_calendars ON family_member_calendars;
CREATE TRIGGER set_updated_at_family_member_calendars
    BEFORE INSERT OR UPDATE ON family_member_calendars
    FOR EACH ROW
    EXECUTE FUNCTION update_family_member_calendars_updated_at();

-- ============================================
-- PART 4: Add updated_at column to families
-- ============================================

ALTER TABLE families
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill existing rows
UPDATE families
SET updated_at = NOW()
WHERE updated_at IS NULL;

-- Make updated_at NOT NULL after backfill
ALTER TABLE families
ALTER COLUMN updated_at SET NOT NULL;

-- Create trigger to auto-update timestamp
CREATE OR REPLACE FUNCTION update_families_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at_families ON families;
CREATE TRIGGER set_updated_at_families
    BEFORE INSERT OR UPDATE ON families
    FOR EACH ROW
    EXECUTE FUNCTION update_families_updated_at();

-- ============================================
-- Verification Queries
-- ============================================

-- Check that all rows have updated_at
SELECT 'shared_calendars' as table_name, COUNT(*) as rows_with_null_updated_at FROM shared_calendars WHERE updated_at IS NULL
UNION ALL
SELECT 'family_member_calendars', COUNT(*) FROM family_member_calendars WHERE updated_at IS NULL
UNION ALL
SELECT 'families', COUNT(*) FROM families WHERE updated_at IS NULL;

-- Check trigger functions exist
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE 'set_updated_at%'
ORDER BY event_object_table;

-- Migration complete!
SELECT '✅ Migration complete! All tables now have updated_at timestamps and old calendar_id triggers removed.' as status;
