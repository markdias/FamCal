# Supabase S3 Storage Configuration for Event Attachments

## Overview

This guide explains how to configure Supabase to use AWS S3 for storing event attachments. Supabase uses S3-compatible storage via OrioleDB as its storage backend.

## Prerequisites

You need:
1. AWS Account with S3 access
2. AWS Access Key ID and Secret Access Key
3. AWS S3 Bucket (or will create one)
4. Supabase CLI installed
5. Admin access to your Supabase project (tzkspidmzlipujsnxpzc)

## Step 1: Create AWS S3 Bucket and Credentials

### Option A: Using AWS Console

1. **Create S3 Bucket**:
   - Go to [AWS S3 Console](https://s3.console.aws.amazon.com/)
   - Click "Create bucket"
   - Bucket name: `famcal-event-attachments` (or your preferred name)
   - Region: Choose your region (e.g., `us-east-1`)
   - Block public access settings: **Keep blocked** (we'll use authenticated access)
   - Click "Create bucket"

2. **Create IAM User for S3 Access**:
   - Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
   - Click "Users" → "Create user"
   - Username: `famcal-supabase`
   - Uncheck "Provide user access to the AWS Management Console"
   - Click "Next"

3. **Attach S3 Permissions**:
   - Click "Attach policies directly"
   - Search for and select: `AmazonS3FullAccess` (or create custom policy below)
   - Click "Next" → "Create user"

4. **Create Access Keys**:
   - Click on the user you just created
   - Go to "Security credentials" tab
   - Click "Create access key"
   - Select "Application running outside AWS"
   - Accept and click "Next"
   - **Save these values**:
     - Access Key ID
     - Secret Access Key

### Custom IAM Policy (More Secure)

If you want to restrict to only the event-attachments bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::famcal-event-attachments",
        "arn:aws:s3:::famcal-event-attachments/*"
      ]
    }
  ]
}
```

## Step 2: Configure Local Development Environment

### Update `supabase/config.toml`

Uncomment and update the experimental S3 section:

```toml
[experimental]
# Configures Postgres storage engine to use OrioleDB (S3)
orioledb_version = "1.5.1"

# Configures S3 bucket URL, eg. <bucket_name>.s3-<region>.amazonaws.com
s3_host = "env(S3_HOST)"

# Configures S3 bucket region, eg. us-east-1
s3_region = "env(S3_REGION)"

# Configures AWS_ACCESS_KEY_ID for S3 bucket
s3_access_key = "env(S3_ACCESS_KEY)"

# Configures AWS_SECRET_ACCESS_KEY for S3 bucket
s3_secret_key = "env(S3_SECRET_KEY)"
```

### Create `supabase/.env.local`

Add your AWS credentials:

```bash
# AWS S3 Configuration
S3_HOST=famcal-event-attachments.s3-us-east-1.amazonaws.com
S3_REGION=us-east-1
S3_ACCESS_KEY=your_access_key_id_here
S3_SECRET_KEY=your_secret_access_key_here
```

**Important**: Add `.env.local` to `.gitignore` if not already there!

```bash
echo "supabase/.env.local" >> .gitignore
```

## Step 3: Configure Production Supabase Project

### Via Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/)
2. Select project `tzkspidmzlipujsnxpzc`
3. Go to **Settings** → **Infrastructure**
4. Look for storage configuration options (may be under "Storage" section)

### Via Supabase CLI

The CLI should automatically use S3 when you push migrations. However, for production configuration:

```bash
cd /Users/markdias/project/FamCal

# Set environment variables for your production project
export S3_HOST=famcal-event-attachments.s3-us-east-1.amazonaws.com
export S3_REGION=us-east-1
export S3_ACCESS_KEY=your_access_key_id_here
export S3_SECRET_KEY=your_secret_access_key_here

# Push your migrations (including S3 configuration)
supabase db push
```

## Step 4: Verify S3 Configuration

### Test Local Development

```bash
cd /Users/markdias/project/FamCal

# Start Supabase with S3
supabase start

# Check if OrioleDB is running with S3
# Look for "OrioleDB" in the logs
# Files should be stored in your S3 bucket
```

### Test Production

1. Go to [S3 Console](https://s3.console.aws.amazon.com/)
2. Navigate to `famcal-event-attachments` bucket
3. You should see uploaded files with the structure:
   ```
   {family_id}/{event_identifier}/{user_id}_{timestamp}_{filename}
   ```

## Step 5: Update Swift Code (SupabaseManager)

The REST API endpoints change slightly with S3. Here's what stays the same:

```swift
// These endpoints work with both PostgreSQL and S3 storage:

// Upload
func uploadAttachment(
    familyId: String,
    eventIdentifier: String,
    fileData: Data,
    fileName: String,
    fileType: String
) async throws -> String {
    let timestamp = Int(Date().timeIntervalSince1970)
    let storagePath = "\(familyId)/\(eventIdentifier)/\(userId)_\(timestamp)_\(fileName)"

    let url = supabaseURL.appendingPathComponent("storage/v1/object/event-attachments/\(storagePath)")
    // ... rest of implementation stays the same
}

// Download
func downloadAttachment(storagePath: String) async throws -> Data {
    let url = supabaseURL.appendingPathComponent("storage/v1/object/event-attachments/\(storagePath)")
    // ... rest of implementation stays the same
}

// Delete
func deleteAttachment(storagePath: String) async throws {
    let url = supabaseURL.appendingPathComponent("storage/v1/object/event-attachments/\(storagePath)")
    // ... rest of implementation stays the same
}
```

**Good news**: The REST API endpoints are the same! No Swift code changes needed.

## Storage Bucket Configuration

The `event-attachments` bucket should already be created by your migration, but with S3 backend it stores files in your AWS S3 bucket.

### RLS Policies (Already Set Up)

Your migration creates these policies:

```sql
-- Users can upload to their family folder
CREATE POLICY "Users can upload to family folder" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'event-attachments' AND
    (storage.foldername(name))[1] IN (
      SELECT family_id::text FROM profiles WHERE id = auth.uid()
    )
  );

-- Users can read family attachments
CREATE POLICY "Users can read family attachments" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'event-attachments' AND
    (storage.foldername(name))[1] IN (
      SELECT family_id::text FROM profiles WHERE id = auth.uid()
    )
  );

-- Users can delete own attachments
CREATE POLICY "Users can delete own attachments in storage" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'event-attachments' AND
    auth.uid()::text = (storage.foldername(name))[2]
  );
```

## Troubleshooting

### Issue: OrioleDB not starting

**Solution**: Check that S3 credentials are correct and bucket exists

### Issue: Files not appearing in S3

**Solution**:
- Verify IAM user has `s3:PutObject` permission
- Check S3_HOST format: `bucket.s3-region.amazonaws.com`
- Check S3_REGION format: `us-east-1` (with hyphen)

### Issue: Files can't be downloaded

**Solution**:
- Verify IAM user has `s3:GetObject` permission
- Check RLS policies are enabled on storage.objects
- Verify user is member of the family that uploaded the file

### Issue: Can't delete files

**Solution**:
- Verify IAM user has `s3:DeleteObject` permission
- Check RLS policy for DELETE allows the user

## Cost Considerations

With S3 storage:

### Pricing (as of 2024)
- **Storage**: $0.023 per GB/month (us-east-1)
- **PUT requests**: $0.005 per 1,000 requests
- **GET requests**: $0.0004 per 1,000 requests
- **DELETE requests**: $0.0004 per 1,000 requests

### Example Cost for FamCal

With 250MB per Pro user limit and 400 Pro users max:
- **Total storage**: 100GB
- **Monthly cost**: ~$2.30 (storage only)
- **Typical usage**: Very low request costs

Much cheaper than managing your own S3 infrastructure!

## Security Best Practices

1. **Use IAM Policies**: Don't use root AWS credentials
2. **Rotate Keys**: Regularly rotate access keys
3. **Use S3 Encryption**: Enable default encryption in bucket
4. **Enable Versioning**: For recovery from accidental deletions
5. **Enable MFA Delete**: For production critical files
6. **Monitor Access**: Use CloudTrail to track S3 access

## Monitoring and Backups

### CloudWatch Monitoring

Set up CloudWatch alarms for:
- Large files being uploaded (potential abuse)
- Unusual deletion patterns
- Failed authentication attempts

### S3 Backup Strategy

```bash
# Enable versioning on bucket
aws s3api put-bucket-versioning \
  --bucket famcal-event-attachments \
  --versioning-configuration Status=Enabled

# Enable object lock (optional, for compliance)
aws s3api put-object-lock-configuration \
  --bucket famcal-event-attachments \
  --object-lock-configuration '...'
```

## References

- [Supabase Storage Documentation](https://supabase.com/docs/guides/storage)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [OrioleDB Documentation](https://docs.orioledb.org/)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli/introduction)
