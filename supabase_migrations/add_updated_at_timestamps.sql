-- Migration: Add updated_at timestamps to tables for incremental sync
-- Tables: shared_calendars, family_member_calendars, families
-- Created: 2025-12-05

-- ============================================
-- 1. Add updated_at column to shared_calendars
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
-- 2. Add updated_at column to family_member_calendars
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
-- 3. Add updated_at column to families
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
-- Verification Queries (run after migration)
-- ============================================

-- Check that all rows have updated_at
-- SELECT COUNT(*) FROM shared_calendars WHERE updated_at IS NULL;
-- SELECT COUNT(*) FROM family_member_calendars WHERE updated_at IS NULL;
-- SELECT COUNT(*) FROM families WHERE updated_at IS NULL;

-- Check trigger functions exist
-- SELECT trigger_name, event_object_table FROM information_schema.triggers
-- WHERE trigger_name LIKE 'set_updated_at%';
