# Event Attachments Quick Reference

## Quick Start

The event attachments feature is fully configured and ready to deploy.

### What Was Created
- Database table `event_attachments`
- 4 performance indexes
- 4 RLS policies on the table
- 1 private storage bucket
- 3 storage bucket RLS policies
- 2 PostgreSQL functions
- 1 auto-update trigger

### Deploy Now
```bash
cd /Users/markdias/project/FamCal
supabase db push
```

Or use Supabase Dashboard:
1. SQL Editor → New Query
2. Paste contents of: `supabase/migrations/20251216120000_create_event_attachments.sql`
3. Run

## Table Schema Quick Reference

```sql
CREATE TABLE event_attachments (
    id UUID PRIMARY KEY,                  -- gen_random_uuid()
    user_id UUID NOT NULL,                -- Who has it
    family_id UUID NOT NULL,              -- Which family
    event_identifier TEXT NOT NULL,       -- Which event
    file_name TEXT NOT NULL,              -- Original filename
    file_size INTEGER NOT NULL,           -- Bytes
    file_type TEXT,                       -- MIME type
    storage_path TEXT NOT NULL,           -- Path in bucket
    uploaded_at TIMESTAMPTZ,              -- Upload time
    uploaded_by UUID,                     -- Uploader (audit)
    created_at TIMESTAMPTZ,               -- Record created
    updated_at TIMESTAMPTZ                -- Auto-updated
);
```

## Query Examples

### Get attachments for an event
```sql
SELECT * FROM event_attachments
WHERE event_identifier = 'event-abc-123'
ORDER BY created_at DESC;
```

### Get user's storage usage
```sql
SELECT get_attachment_storage_used('user-id-here'::uuid);
```

### Get family's attachments
```sql
SELECT * FROM event_attachments
WHERE family_id = 'family-id-here'::uuid
ORDER BY created_at DESC;
```

### Get user's attachments in a family
```sql
SELECT * FROM event_attachments
WHERE user_id = 'user-id-here'::uuid
AND family_id = 'family-id-here'::uuid
ORDER BY created_at DESC;
```

## RLS Policies Summary

| Policy Name | Type | Condition | Result |
|---|---|---|---|
| View family attachments | SELECT | is_family_member(family_id) | Family members see all attachments |
| Upload to family | INSERT | user_id = auth.uid() AND is_family_member() | Users upload as themselves |
| Update own | UPDATE | user_id = auth.uid() | Users update only their own |
| Delete own | DELETE | user_id = auth.uid() | Users delete only their own |

## Storage RLS Policies Summary

| Policy Name | Type | Condition | Result |
|---|---|---|---|
| Upload to family folder | INSERT | Bucket is event-attachments + family_id in path | Users upload to their family folder |
| Read family attachments | SELECT | Bucket is event-attachments + family_id in path | Family can read files |
| Delete own attachments | DELETE | Bucket is event-attachments + user_id in path | Users delete their files |

## Function Reference

### get_attachment_storage_used(user_id)
```sql
SELECT get_attachment_storage_used('550e8400-e29b-41d4-a716-446655440000'::uuid);
-- Returns: 1024000 (bytes)
```

### is_family_member(family_id)
- Used by RLS policies automatically
- Checks if auth.uid() is owner or linked member

## Indexes for Performance

| Index | Column | Purpose |
|---|---|---|
| idx_event_attachments_event | event_identifier | Find attachments by event |
| idx_event_attachments_user | user_id | Find user's attachments |
| idx_event_attachments_family | family_id | Find family's attachments |
| idx_event_attachments_created_at | created_at DESC | Sort by date efficiently |

## Common Operations

### Insert attachment (automatically RLS filtered)
```sql
INSERT INTO event_attachments (
    user_id, family_id, event_identifier, file_name,
    file_size, file_type, storage_path, uploaded_by
) VALUES (
    'current-user-id'::uuid,
    'current-family-id'::uuid,
    'event-123',
    'document.pdf',
    2048,
    'application/pdf',
    'event-attachments/family-id/user-id/document.pdf',
    'current-user-id'::uuid
);
```

### Update attachment metadata (only own)
```sql
UPDATE event_attachments
SET file_name = 'new-name.pdf', updated_at = NOW()
WHERE id = 'attachment-id'::uuid
AND user_id = auth.uid();
```

### Delete attachment (only own)
```sql
DELETE FROM event_attachments
WHERE id = 'attachment-id'::uuid
AND user_id = auth.uid();
```

## Storage Paths Pattern

Format: `{family_id}/{user_id}/{timestamp}-{original_filename}`

Example: `f47ac10b-58cc-4372-a567-0e02b2c3d479/a6521411-cf27-4921-b9d0-3f50b9eeb6fc/1702750800-vacation-plans.pdf`

Benefits:
- Easy RLS filtering (split path at /)
- User identification from path
- No filename collisions (timestamp prefix)
- Organized by family then user

## Migration Safety

Migration is idempotent - safe to run multiple times:
- All CREATE statements use IF NOT EXISTS
- Trigger uses DROP IF EXISTS before CREATE
- Bucket insert uses ON CONFLICT DO NOTHING

## Verification Commands

```bash
# After deployment, verify everything:
psql $SUPABASE_CONNECTION_STRING << EOF
-- Check table
\dt public.event_attachments

-- Check indexes
\di+ idx_event_attachments*

-- Check RLS policies
SELECT tablename, policyname FROM pg_policies
WHERE tablename = 'event_attachments';

-- Check storage bucket
SELECT * FROM storage.buckets WHERE id = 'event-attachments';

-- Check functions
\df public.get_attachment_storage_used
\df public.is_family_member
EOF
```

## Next Steps for Development

1. Create Swift model: `EventAttachment`
2. Add to SupabaseDataManager:
   - `uploadAttachment()`
   - `getAttachments()`
   - `deleteAttachment()`
3. Add storage methods:
   - `uploadFile()`
   - `downloadFile()`
   - `deleteFile()`
4. Create UI views:
   - Attachment picker
   - Attachment list
   - Attachment preview
5. Integrate with event details view

## Documentation Files

- **Setup Guide**: `/documentation/features/EVENT_ATTACHMENTS_SETUP.md`
- **Migration**: `/supabase/migrations/20251216120000_create_event_attachments.sql`
- **This File**: `/documentation/features/EVENT_ATTACHMENTS_QUICK_REFERENCE.md`

## Support Notes

- All data is family-scoped for security
- Users can only access their own attachments for management
- Cascading deletes ensure data consistency
- Updated_at is automatically maintained
- Storage quota can be enforced using `get_attachment_storage_used()`
