-- ============================================
-- Diagnostic Query: Find ALL triggers in database
-- Run this first to see what triggers exist
-- ============================================

-- Show ALL triggers in the database
SELECT
    trigger_name,
    event_object_schema,
    event_object_table,
    action_statement,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE event_object_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Show ALL functions that might be trigger functions
SELECT
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_type = 'FUNCTION'
ORDER BY routine_name;

-- Check if calendar_id column still exists (it shouldn't)
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND column_name LIKE '%calendar_id%'
ORDER BY table_name, column_name;
