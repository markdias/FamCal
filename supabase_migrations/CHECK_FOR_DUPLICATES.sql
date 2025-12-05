-- ============================================
-- Check for Duplicate Data in Supabase
-- Run this to see if you have duplicate family members
-- ============================================

-- Check for duplicate family members (same name in same family)
SELECT
    family_id,
    name,
    COUNT(*) as duplicate_count,
    array_agg(id) as member_ids
FROM family_members
GROUP BY family_id, name
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Check total family members per family
SELECT
    family_id,
    COUNT(*) as total_members,
    array_agg(name) as member_names
FROM family_members
GROUP BY family_id
ORDER BY total_members DESC;

-- Check if any members have NULL or empty names
SELECT id, family_id, name, linked_user_id
FROM family_members
WHERE name IS NULL OR name = '' OR TRIM(name) = ''
ORDER BY family_id;

-- Check for duplicate shared calendars
SELECT
    family_id,
    calendar_name,
    COUNT(*) as duplicate_count,
    array_agg(id) as calendar_ids
FROM shared_calendars
GROUP BY family_id, calendar_name
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
