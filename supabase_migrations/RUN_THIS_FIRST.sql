-- ============================================
-- FamCal Database Migration - Phase 2
-- Run this file to apply all migrations in the correct order
-- ============================================

\echo '🔧 Starting FamCal database migration...'

-- Step 1: Drop old triggers that reference removed calendar_id column
\echo '📋 Step 1/2: Dropping old calendar_id triggers...'
\i drop_old_calendar_id_triggers.sql

-- Step 2: Add updated_at timestamps for incremental sync
\echo '📋 Step 2/2: Adding updated_at timestamps...'
\i add_updated_at_timestamps.sql

\echo '✅ Migration complete! Your database is now up to date.'
\echo ''
\echo 'Next steps:'
\echo '1. Verify the migration by checking that updated_at columns exist'
\echo '2. Rebuild and run the iOS app'
\echo '3. Test the initial family setup flow'
