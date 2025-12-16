# S3 Storage Configuration Summary

## What's Been Set Up

✅ **Supabase Database Migration**
- Location: `supabase/migrations/20251216120000_create_event_attachments.sql`
- Creates: `event_attachments` table with RLS policies
- Bucket: `event-attachments` (private)
- Status: Ready to deploy

✅ **Documentation**
- `documentation/supabase/S3_STORAGE_SETUP.md` - Complete setup guide
- `SUPABASE_S3_SETUP_CHECKLIST.md` - Step-by-step checklist
- `supabase/.env.example` - Environment template

## What You Need To Do

You need to provide AWS credentials. Here's what we need:

### Option 1: Create New AWS S3 Bucket (Recommended)

If you don't have AWS S3 set up yet:

1. **Create AWS Account** (if needed)
   - Go to [AWS Console](https://aws.amazon.com/)

2. **Create S3 Bucket**
   - Bucket name: `famcal-event-attachments`
   - Region: `us-east-1` (or your choice)
   - Keep "Block public access" enabled

3. **Create IAM User**
   - Username: `famcal-supabase`
   - Attach policy: `AmazonS3FullAccess`
   - Create access key

4. **Get Credentials**
   - Access Key ID: `AKIA...`
   - Secret Access Key: `...`

### Option 2: Use Existing AWS Account

If you already have S3 set up:

1. Get your S3 bucket name
2. Get your AWS region (e.g., `us-east-1`)
3. Create IAM user with S3 access (or use existing)
4. Get access key and secret key

## Configuration Process

Once you have AWS credentials:

### 1. Create Local Environment File
```bash
cd /Users/markdias/project/FamCal
cp supabase/.env.example supabase/.env.local
```

### 2. Add Your Credentials to `supabase/.env.local`
```bash
S3_HOST=famcal-event-attachments.s3-us-east-1.amazonaws.com
S3_REGION=us-east-1
S3_ACCESS_KEY=your_access_key_id
S3_SECRET_KEY=your_secret_access_key
```

### 3. Update `supabase/config.toml`
Find the `[experimental]` section and uncomment/update S3 config:
```toml
[experimental]
orioledb_version = "1.5.1"
s3_host = "env(S3_HOST)"
s3_region = "env(S3_REGION)"
s3_access_key = "env(S3_ACCESS_KEY)"
s3_secret_key = "env(S3_SECRET_KEY)"
```

### 4. Test Locally
```bash
cd /Users/markdias/project/FamCal
supabase start
```

### 5. Deploy to Production
```bash
supabase db push --linked
```

## Key Points

✅ **No Swift Code Changes** - REST API endpoints work the same with S3

✅ **Automatic RLS Policies** - Family scoping is built-in to migration

✅ **File Structure** - Files stored as: `{family_id}/{event_identifier}/{user_id}_{timestamp}_{filename}`

✅ **Quota Tracking** - Function `get_attachment_storage_used()` calculates storage per user

✅ **Production Ready** - All security policies and indexes included

## AWS Credentials Needed

Please provide these values:

```
S3_HOST = ___________________________________
S3_REGION = ___________________________________
S3_ACCESS_KEY = ___________________________________
S3_SECRET_KEY = ___________________________________
```

Once you provide these, I can:
1. ✅ Create your `.env.local` file
2. ✅ Update `config.toml` with correct values
3. ✅ Test the configuration
4. ✅ Deploy to production

## Estimated Setup Time

- AWS setup: 10-15 minutes
- Supabase configuration: 5 minutes
- Testing: 5-10 minutes
- **Total: ~30 minutes**

## Next Steps

1. **Create AWS account** (if needed)
2. **Create S3 bucket** with name `famcal-event-attachments`
3. **Create IAM user** `famcal-supabase` with S3 access
4. **Share AWS credentials** with me
5. **I'll complete the Supabase setup**

Once AWS is ready, I can finish the configuration automatically!

---

**Ready?** Let me know your AWS credentials and I'll complete the setup!
