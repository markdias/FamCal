#!/bin/bash

# Comprehensive Supabase Authentication Diagnostics
# This script tests your Supabase setup to identify why login is failing

SUPABASE_URL="https://tzkspidmzlipujsnxpzc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6a3NwaWRtemxpcHVqc254cHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4OTI2MTYsImV4cCI6MjA3OTQ2ODYxNn0.QMKZYMrESCOCT0KCHAKhPU995_mIB1F3l4Y4uq8s1uM"

echo "=================================================="
echo "SUPABASE AUTHENTICATION DIAGNOSTICS"
echo "=================================================="
echo ""
echo "Project URL: $SUPABASE_URL"
echo ""

# Test 1: Check if Supabase is accessible
echo "TEST 1: Check if Supabase is accessible"
echo "---"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$SUPABASE_URL/auth/v1/health")
if [ "$RESPONSE" = "200" ]; then
    echo "✅ Supabase is accessible (HTTP $RESPONSE)"
else
    echo "❌ Supabase unreachable (HTTP $RESPONSE)"
    echo "This means Supabase servers are down or URL is wrong"
    exit 1
fi
echo ""

# Test 2: Check auth provider configuration
echo "TEST 2: List auth providers"
echo "---"
curl -s -X GET "$SUPABASE_URL/auth/v1/metadata" \
  -H "apikey: $ANON_KEY" | jq '.' 2>/dev/null || echo "(Could not parse response - this is OK)"
echo ""

# Test 3: Test email/password auth endpoint
echo "TEST 3: Test email/password auth (with test@example.com)"
echo "---"
RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "Content-Type: application/json" \
  -H "apikey: $ANON_KEY" \
  -d '{"email":"test@example.com","password":"Test123456"}')

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"

# Parse the error
if echo "$RESPONSE" | grep -q "invalid_credentials"; then
    echo ""
    echo "❌ INVALID LOGIN CREDENTIALS"
    echo "This means:"
    echo "  - User doesn't exist with that email/password"
    echo "  - Or password is wrong"
    echo "  → Action: Create test@example.com user in Supabase dashboard"
elif echo "$RESPONSE" | grep -q "Email not confirmed"; then
    echo ""
    echo "❌ EMAIL NOT CONFIRMED"
    echo "This means:"
    echo "  - User exists but email isn't verified"
    echo "  → Action: Toggle 'Email Confirmed' in Supabase Users list"
elif echo "$RESPONSE" | grep -q "unsupported_grant_type"; then
    echo ""
    echo "❌ UNSUPPORTED GRANT TYPE"
    echo "This means:"
    echo "  - Endpoint format is wrong"
    echo "  - grant_type needs to be in URL query string"
    echo "  → Action: Check endpoint format"
elif echo "$RESPONSE" | grep -q "access_token"; then
    echo ""
    echo "✅ LOGIN SUCCESSFUL!"
    echo "This means:"
    echo "  - Auth endpoint is working"
    echo "  - User credentials are correct"
    echo "  - The issue is in the app code, not Supabase"
elif echo "$RESPONSE" | grep -q "error_code"; then
    ERROR_CODE=$(echo "$RESPONSE" | jq -r '.error_code' 2>/dev/null)
    echo ""
    echo "❌ ERROR: $ERROR_CODE"
    echo "Full response: $RESPONSE"
else
    echo ""
    echo "⚠️  Could not parse response"
    echo "Full response: $RESPONSE"
fi

echo ""
echo "=================================================="
echo "DIAGNOSTICS COMPLETE"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. If error is 'invalid_credentials' → Create user in Supabase"
echo "2. If error is 'Email not confirmed' → Confirm email in Supabase"
echo "3. If login successful → Issue is in app code"
echo "4. If other error → Check error code and Supabase settings"
