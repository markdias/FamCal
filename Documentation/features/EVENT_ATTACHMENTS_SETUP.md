# Event Attachments Feature Setup

## Overview

This document describes the setup and implementation of the Event Attachments feature for FamCal. This feature allows users to upload and manage file attachments associated with calendar events.

## Database Migration

### Migration File
- **Location**: `/supabase/migrations/20251216120000_create_event_attachments.sql`
- **Status**: Created and ready to be deployed

### What Was Created

#### 1. Event Attachments Table
**Table**: `public.event_attachments`

```sql
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
```

**Columns Description**:
- `id`: Unique identifier for each attachment (UUID)
- `user_id`: The user who has access to this attachment (foreign key to auth.users)
- `family_id`: The family that owns this attachment (foreign key to families)
- `event_identifier`: Text identifier linking the attachment to an event
- `file_name`: Original name of the uploaded file
- `file_size`: Size of the file in bytes
- `file_type`: MIME type of the file (e.g., "application/pdf")
- `storage_path`: Path to the file in the storage bucket
- `uploaded_at`: Timestamp when the file was uploaded
- `uploaded_by`: User ID of the uploader (denormalized reference)
- `created_at`: Timestamp when the record was created
- `updated_at`: Timestamp when the record was last modified (auto-updated via trigger)

#### 2. Database Indexes
Four indexes were created for performance optimization:

```sql
CREATE INDEX IF NOT EXISTS idx_event_attachments_event ON public.event_attachments(event_identifier);
CREATE INDEX IF NOT EXISTS idx_event_attachments_user ON public.event_attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_event_attachments_family ON public.event_attachments(family_id);
CREATE INDEX IF NOT EXISTS idx_event_attachments_created_at ON public.event_attachments(created_at DESC);
```

**Purpose**:
- `idx_event_attachments_event`: Fast lookup of attachments by event
- `idx_event_attachments_user`: Fast lookup of user's attachments
- `idx_event_attachments_family`: Fast lookup of family's attachments
- `idx_event_attachments_created_at`: Efficient sorting by upload date

#### 3. Row Level Security (RLS) Policies
RLS is enabled on the `event_attachments` table with the following policies:

**Policy 1: View Permissions**
```
Name: "Family members can view family attachments"
Type: SELECT
Condition: User is a member of the family that owns the attachment
```

**Policy 2: Upload Permissions**
```
Name: "Users can upload attachments to family"
Type: INSERT
Conditions:
  - user_id matches current authenticated user
  - User is a member of the family
```

**Policy 3: Update Permissions**
```
Name: "Users can update own attachments"
Type: UPDATE
Condition: user_id matches current authenticated user
```

**Policy 4: Delete Permissions**
```
Name: "Users can delete own attachments"
Type: DELETE
Condition: user_id matches current authenticated user
```

#### 4. Storage Bucket
**Bucket**: `event-attachments`

Configuration:
- **Public**: No (private bucket)
- **Size Limit**: Configure in Supabase dashboard if needed
- **Path Pattern**: `{family_id}/{user_id}/{file_path}`

#### 5. Storage Bucket RLS Policies

**Policy 1: Upload**
```
Name: "Users can upload to family folder"
Type: INSERT
Condition: File path starts with user's family_id and user is authenticated
```

**Policy 2: Read**
```
Name: "Users can read family attachments"
Type: SELECT
Condition: File path starts with user's family_id and user is authenticated
```

**Policy 3: Delete**
```
Name: "Users can delete own attachments in storage"
Type: DELETE
Condition: File path contains user's ID and user is authenticated
```

#### 6. PostgreSQL Functions

**Function 1: Storage Usage Calculator**
```sql
CREATE OR REPLACE FUNCTION public.get_attachment_storage_used(p_user_id UUID)
RETURNS BIGINT AS $$
  SELECT COALESCE(SUM(file_size), 0)::BIGINT
  FROM public.event_attachments
  WHERE user_id = p_user_id;
$$ LANGUAGE SQL STABLE;
```

**Purpose**: Calculates total storage used by a specific user across all attachments.

**Function 2: Family Member Checker**
```sql
CREATE OR REPLACE FUNCTION public.is_family_member(family_id uuid)
RETURNS BOOLEAN LANGUAGE SQL STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT EXISTS(
    SELECT 1
    FROM public.families f
    LEFT JOIN public.family_members fm ON fm.family_id = f.id
    WHERE f.id = family_id
      AND (f.owner_user_id = auth.uid() OR fm.linked_user_id = auth.uid())
  );
$$;
```

**Purpose**: Helper function used by RLS policies to check if the current user is a member of a family.

**Function 3: Updated At Trigger Function**
```sql
CREATE OR REPLACE FUNCTION public.update_event_attachments_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Purpose**: Automatically updates the `updated_at` column whenever a record is modified.

## Architecture Decisions

### Family Scoping
- All attachments are scoped to families to ensure data isolation
- Users can only see/manage attachments from families they belong to
- This prevents data leakage between different family groups

### User Tracking
- Both `user_id` and `uploaded_by` are stored to track ownership and history
- `user_id` is used for RLS policies (who has access)
- `uploaded_by` provides audit trail

### File Metadata
- File size is stored in the database for quota management
- File type (MIME type) is stored for filtering and validation
- Storage path tracks the exact location in the bucket

### Storage Organization
Path structure: `{family_id}/{user_id}/{timestamp}-{original_filename}`

This ensures:
1. Easy scoping by family in storage policies
2. Easy identification of uploader in storage policies
3. Prevention of name collisions

## Deployment Steps

To deploy this migration to your Supabase project:

### Using Supabase CLI (Local Development)
```bash
cd /Users/markdias/project/FamCal
supabase db push
```

### Using Supabase Dashboard (Production)
1. Open your Supabase project dashboard
2. Navigate to SQL Editor
3. Click "New Query"
4. Copy the entire contents of `supabase/migrations/20251216120000_create_event_attachments.sql`
5. Click "Run"
6. Verify the results

### Verification
After deployment, verify the setup by running the verification queries:

```sql
-- Check table exists
SELECT EXISTS(SELECT 1 FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = 'event_attachments') AS table_exists;

-- Check indexes
SELECT indexname FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'event_attachments'
ORDER BY indexname;

-- Check RLS enabled
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'event_attachments';

-- Check RLS policies
SELECT policyname, cmd FROM pg_policies
WHERE tablename = 'event_attachments' ORDER BY policyname;

-- Check storage bucket
SELECT id, name, public FROM storage.buckets WHERE id = 'event-attachments';

-- Check functions
SELECT EXISTS(SELECT 1 FROM information_schema.routines
  WHERE routine_schema = 'public' AND routine_name = 'get_attachment_storage_used') AS function_exists;
```

## Swift Implementation (Next Steps)

To use this feature in the iOS app, you'll need to:

1. **Create Models**
   - `EventAttachment` struct matching the table schema
   - `AttachmentUploadRequest` for upload operations

2. **Update SupabaseDataManager**
   - Add methods for CRUD operations on attachments
   - Implement file upload/download to storage

3. **Update CalendarManager**
   - Link attachment management to event operations
   - Handle attachment lifecycle

4. **Create UI Components**
   - Attachment picker/upload view
   - Attachment list/display in event details
   - Attachment preview functionality

## Security Considerations

### RLS Protection
- All attachments are protected by RLS policies
- Users can only view/modify attachments from their families
- Family scope is enforced at the database level

### Storage Security
- Storage bucket is private (not publicly accessible)
- RLS policies control read/write/delete access
- Path-based security ensures family isolation

### Quota Management
- `get_attachment_storage_used()` function enables quota enforcement
- Implement storage limits in the app layer
- Monitor storage usage per user/family

## Maintenance

### Monitoring
Monitor the following in Supabase dashboard:
- Table size and growth
- Index usage
- RLS policy performance
- Storage bucket usage

### Cleanup
Consider implementing:
- Soft delete support (add `deleted_at` column)
- Cleanup job for expired/unused attachments
- Storage quota enforcement

### Future Enhancements
- Virus scanning integration
- File type restrictions
- Compression for certain file types
- CDN integration for large files
- Sharing policies for external users

## References

- Related Migration: `supabase/migrations/20251216120000_create_event_attachments.sql`
- Supabase Storage Docs: https://supabase.com/docs/guides/storage
- PostgreSQL RLS Docs: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
