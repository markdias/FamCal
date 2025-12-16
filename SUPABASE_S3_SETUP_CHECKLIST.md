# FamCal Supabase S3 Storage Setup Checklist

Complete these steps to enable S3 storage for event attachments.

## ✅ Phase 1: AWS Setup (Do This First)

### Step 1.1: Create S3 Bucket
- [ ] Go to [AWS S3 Console](https://s3.console.aws.amazon.com/)
- [ ] Create bucket named: `famcal-event-attachments`
- [ ] Region: `us-east-1` (or your preferred region)
- [ ] Keep "Block public access" enabled
- [ ] Note: **Bucket Name**: `famcal-event-attachments`
- [ ] Note: **Region**: `us-east-1`

### Step 1.2: Create IAM User with S3 Access
- [ ] Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
- [ ] Create new user: `famcal-supabase`
- [ ] Attach policy: `AmazonS3FullAccess` (or use custom policy)
- [ ] Create access key for programmatic access
- [ ] **Save these securely**:
  - [ ] Access Key ID: `AKIA...`
  - [ ] Secret Access Key: `...`

### Step 1.3: Document AWS Credentials
- [ ] S3_HOST = `famcal-event-attachments.s3-us-east-1.amazonaws.com`
- [ ] S3_REGION = `us-east-1`
- [ ] S3_ACCESS_KEY = `your_access_key_id`
- [ ] S3_SECRET_KEY = `your_secret_access_key`

---

## ✅ Phase 2: Local Development Setup

### Step 2.1: Create .env.local File
```bash
cd /Users/markdias/project/FamCal
cp supabase/.env.example supabase/.env.local
```

### Step 2.2: Edit supabase/.env.local
- [ ] Open `supabase/.env.local`
- [ ] Replace with your actual AWS credentials:
  ```bash
  S3_HOST=famcal-event-attachments.s3-us-east-1.amazonaws.com
  S3_REGION=us-east-1
  S3_ACCESS_KEY=your_actual_access_key_id
  S3_SECRET_KEY=your_actual_secret_access_key
  ```
- [ ] Save file
- [ ] Verify .gitignore includes `supabase/.env.local`

### Step 2.3: Update config.toml for S3
- [ ] Open `supabase/config.toml`
- [ ] Find the `[experimental]` section (around line 347)
- [ ] Update to enable S3:
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

### Step 2.4: Test Local Supabase with S3
```bash
cd /Users/markdias/project/FamCal

# Stop any running Supabase instance
supabase stop

# Start Supabase with S3 configuration
supabase start

# Check logs for OrioleDB initialization
# Should see messages about S3 connection
```

### Step 2.5: Verify Local Setup
- [ ] Supabase should start without errors
- [ ] Check logs for "OrioleDB" and S3 connection messages
- [ ] Go to http://localhost:54323 (Supabase Studio)
- [ ] Create test bucket and upload file
- [ ] Verify file appears in AWS S3 console

---

## ✅ Phase 3: Production Setup

### Step 3.1: Update Production Environment Variables
You need to set these in your production Supabase project environment:

**Via Supabase Dashboard:**
1. [ ] Go to [Supabase Dashboard](https://supabase.com/)
2. [ ] Select project `tzkspidmzlipujsnxpzc`
3. [ ] Go to **Settings** → **Environment**
4. [ ] Add these environment variables:
   - [ ] `S3_HOST` = `famcal-event-attachments.s3-us-east-1.amazonaws.com`
   - [ ] `S3_REGION` = `us-east-1`
   - [ ] `S3_ACCESS_KEY` = (your access key)
   - [ ] `S3_SECRET_KEY` = (your secret key)

### Step 3.2: Verify Database Migration
- [ ] Migrations are already created in:
  ```
  supabase/migrations/20251216120000_create_event_attachments.sql
  ```
- [ ] This migration includes:
  - [ ] `event_attachments` table
  - [ ] RLS policies
  - [ ] Storage bucket creation
  - [ ] Helper functions

### Step 3.3: Push Migrations to Production
```bash
cd /Users/markdias/project/FamCal

# Make sure environment variables are set
export S3_HOST=famcal-event-attachments.s3-us-east-1.amazonaws.com
export S3_REGION=us-east-1
export S3_ACCESS_KEY=your_access_key_id
export S3_SECRET_KEY=your_secret_access_key

# Push migrations to production
supabase db push --linked

# This will:
# - Create event_attachments table
# - Create RLS policies
# - Create storage bucket
# - Create helper functions
```

### Step 3.4: Verify Production Setup
- [ ] Go to [Supabase Dashboard](https://supabase.com/)
- [ ] Select project `tzkspidmzlipujsnxpzc`
- [ ] Go to **SQL Editor**
- [ ] Run: `SELECT * FROM public.event_attachments;` (should work, 0 rows)
- [ ] Go to **Storage**
- [ ] Verify `event-attachments` bucket exists
- [ ] Go to AWS S3 Console
- [ ] Verify bucket `famcal-event-attachments` exists and is empty

---

## ✅ Phase 4: Swift Code (No Changes Needed!)

Good news! The REST API endpoints are the same for both PostgreSQL and S3 storage.

- [ ] No Swift code changes required
- [ ] `SupabaseManager` methods work with S3 backend
- [ ] `SupabaseDataManager` works as designed
- [ ] All existing implementations are compatible

---

## ✅ Phase 5: Testing

### Step 5.1: Local Testing
```bash
# Upload a test file
# Verify it appears in S3 bucket

# Download the file
# Verify content is correct

# Delete the file
# Verify it's removed from S3

# Check quota calculation
# Should sum file_size from event_attachments table
```

### Step 5.2: Production Testing
- [ ] Upload test PDF from production app
- [ ] Verify file in S3 bucket
- [ ] Download test PDF from production app
- [ ] Verify file content
- [ ] Delete test PDF
- [ ] Verify removal from S3 and database

### Step 5.3: Monitor S3 Access
- [ ] Go to AWS S3 Console
- [ ] Check bucket access logs
- [ ] Verify proper family scoping (files in {family_id}/ folders)

---

## 🚀 Deployment Commands

### Quick Setup Script (Copy & Run)
```bash
#!/bin/bash
set -e

cd /Users/markdias/project/FamCal

echo "🔧 Setting up Supabase S3 Storage..."

# 1. Create .env.local
if [ ! -f supabase/.env.local ]; then
  cp supabase/.env.example supabase/.env.local
  echo "✅ Created supabase/.env.local"
  echo "   ⚠️  Edit with your AWS credentials!"
else
  echo "✅ supabase/.env.local already exists"
fi

# 2. Check config.toml
if grep -q "orioledb_version = \"\"" supabase/config.toml; then
  echo "⚠️  config.toml needs S3 configuration"
  echo "   See documentation/supabase/S3_STORAGE_SETUP.md"
else
  echo "✅ config.toml S3 configuration found"
fi

# 3. Verify migration exists
if [ -f supabase/migrations/20251216120000_create_event_attachments.sql ]; then
  echo "✅ Event attachments migration exists"
else
  echo "❌ Event attachments migration not found!"
  exit 1
fi

echo ""
echo "📋 Next Steps:"
echo "1. Edit supabase/.env.local with your AWS credentials"
echo "2. Run: supabase start"
echo "3. Test file upload/download"
echo "4. Push to production when ready: supabase db push --linked"
```

Save this as `scripts/setup-s3.sh` and run:
```bash
chmod +x scripts/setup-s3.sh
./scripts/setup-s3.sh
```

---

## 📚 Troubleshooting

| Issue | Solution |
|-------|----------|
| OrioleDB won't start | Check S3 credentials in .env.local |
| Files not in S3 | Verify IAM user has s3:PutObject permission |
| Can't download files | Verify IAM user has s3:GetObject permission |
| RLS errors | Ensure user is member of family_id |
| Quota calculation wrong | Run `SELECT public.get_attachment_storage_used(user_id)` |

---

## 📞 Support

For detailed S3 configuration help, see:
- `documentation/supabase/S3_STORAGE_SETUP.md` - Complete setup guide
- `documentation/features/EVENT_ATTACHMENTS_SETUP.md` - Feature setup
- `documentation/features/EVENT_ATTACHMENTS_QUICK_REFERENCE.md` - API reference

---

## ✅ Final Verification Checklist

- [ ] AWS S3 bucket created
- [ ] IAM user created with S3 credentials
- [ ] `.env.local` file populated with credentials
- [ ] `config.toml` updated with S3 configuration
- [ ] Local Supabase starts successfully
- [ ] Production environment variables set
- [ ] Migrations pushed to production
- [ ] Test file uploads work
- [ ] Test file downloads work
- [ ] Files visible in S3 console
- [ ] RLS policies working (family scoping)
- [ ] Quota calculation working

**Status**: Ready for development once all items checked! ✅
