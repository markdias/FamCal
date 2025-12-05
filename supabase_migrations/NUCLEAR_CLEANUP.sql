-- ============================================
-- Nuclear Cleanup: Drop ALL triggers and functions
-- Use this if the previous migration didn't work
-- ============================================

-- WARNING: This drops ALL triggers on calendar-related tables
-- This is safe because we'll recreate the correct ones afterward

-- ============================================
-- Drop ALL triggers on shared_calendars
-- ============================================
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'shared_calendars'
        AND event_object_schema = 'public'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON shared_calendars', trigger_record.trigger_name);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.trigger_name;
    END LOOP;
END $$;

-- ============================================
-- Drop ALL triggers on family_member_calendars
-- ============================================
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'family_member_calendars'
        AND event_object_schema = 'public'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON family_member_calendars', trigger_record.trigger_name);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.trigger_name;
    END LOOP;
END $$;

-- ============================================
-- Drop ALL triggers on personal_calendars
-- ============================================
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'personal_calendars'
        AND event_object_schema = 'public'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON personal_calendars', trigger_record.trigger_name);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.trigger_name;
    END LOOP;
END $$;

-- ============================================
-- Drop ALL triggers on families
-- ============================================
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN
        SELECT trigger_name
        FROM information_schema.triggers
        WHERE event_object_table = 'families'
        AND event_object_schema = 'public'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON families', trigger_record.trigger_name);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.trigger_name;
    END LOOP;
END $$;

-- ============================================
-- Drop ALL functions that might be trigger functions
-- ============================================
DROP FUNCTION IF EXISTS update_shared_calendars_calendar_id() CASCADE;
DROP FUNCTION IF EXISTS update_family_member_calendars_calendar_id() CASCADE;
DROP FUNCTION IF EXISTS update_personal_calendars_calendar_id() CASCADE;
DROP FUNCTION IF EXISTS set_calendar_id() CASCADE;
DROP FUNCTION IF EXISTS sync_calendar_id() CASCADE;
DROP FUNCTION IF EXISTS handle_updated_at() CASCADE;
DROP FUNCTION IF EXISTS set_updated_at() CASCADE;

-- Drop any function that contains "calendar_id" in its name
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN
        SELECT routine_name, routine_schema
        FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_type = 'FUNCTION'
        AND routine_name LIKE '%calendar_id%'
    LOOP
        EXECUTE format('DROP FUNCTION IF EXISTS %I.%I() CASCADE', func_record.routine_schema, func_record.routine_name);
        RAISE NOTICE 'Dropped function: %', func_record.routine_name;
    END LOOP;
END $$;

-- ============================================
-- Now add the correct updated_at triggers
-- ============================================

-- Function for shared_calendars
CREATE OR REPLACE FUNCTION update_shared_calendars_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_shared_calendars
    BEFORE INSERT OR UPDATE ON shared_calendars
    FOR EACH ROW
    EXECUTE FUNCTION update_shared_calendars_updated_at();

-- Function for family_member_calendars
CREATE OR REPLACE FUNCTION update_family_member_calendars_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_family_member_calendars
    BEFORE INSERT OR UPDATE ON family_member_calendars
    FOR EACH ROW
    EXECUTE FUNCTION update_family_member_calendars_updated_at();

-- Function for families
CREATE OR REPLACE FUNCTION update_families_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_families
    BEFORE INSERT OR UPDATE ON families
    FOR EACH ROW
    EXECUTE FUNCTION update_families_updated_at();

-- ============================================
-- Verification
-- ============================================

-- Show remaining triggers (should only be updated_at triggers)
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE event_object_schema = 'public'
AND event_object_table IN ('shared_calendars', 'family_member_calendars', 'personal_calendars', 'families')
ORDER BY event_object_table, trigger_name;

SELECT '✅ Nuclear cleanup complete! All old triggers dropped, new updated_at triggers created.' as status;
