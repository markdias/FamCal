#!/bin/bash

# Test login credentials with Supabase
# This tests if your email/password combination works with Supabase

SUPABASE_URL="https://tzkspidmzlipujsnxpzc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6a3NwaWRtemxpcHVqc254cHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4OTI2MTYsImV4cCI6MjA3OTQ2ODYxNn0.QMKZYMrESCOCT0KCHAKhPU995_mIB1F3l4Y4uq8s1uM"

# Prompt for email and password
read -p "Enter email: " EMAIL
read -sp "Enter password: " PASSWORD
echo ""

echo "=================================================="
echo "Testing login credentials..."
echo "=================================================="
echo ""
echo "Email: $EMAIL"
echo "URL: $SUPABASE_URL/auth/v1/token?grant_type=password"
echo ""

# Make the request
RESPONSE=$(curl -s -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "Content-Type: application/json" \
  -H "apikey: $ANON_KEY" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"

echo ""
echo "=================================================="
echo "Analysis:"
echo "=================================================="

# Check for success
if echo "$RESPONSE" | grep -q "access_token"; then
    echo "✅ LOGIN SUCCESSFUL!"
    echo ""
    echo "This means:"
    echo "  - Email is correct"
    echo "  - Password is correct"
    echo "  - User account exists and is confirmed"
    echo "  - You should be able to log in to the app"
    echo ""
    echo "Access token:"
    echo "$RESPONSE" | jq '.access_token' 2>/dev/null | head -c 50
    echo "..."

elif echo "$RESPONSE" | grep -q "invalid_credentials"; then
    echo "❌ INVALID CREDENTIALS"
    echo ""
    echo "This means one of:"
    echo "  1. Email is wrong (typo or different casing)"
    echo "  2. Password is wrong"
    echo "  3. User doesn't exist"
    echo "  4. User was deleted"
    echo ""
    echo "Solutions:"
    echo "  - Double-check email spelling (case-sensitive)"
    echo "  - Double-check password"
    echo "  - Create a new user account"

elif echo "$RESPONSE" | grep -q "Email not confirmed"; then
    echo "❌ EMAIL NOT CONFIRMED"
    echo ""
    echo "This means:"
    echo "  - User exists but email wasn't verified"
    echo "  - User cannot log in until email is confirmed"
    echo ""
    echo "Solutions:"
    echo "  1. Check email for confirmation link (might be in spam)"
    echo "  2. Delete the user and create a new one with 'Confirm email' ON"
    echo "  3. In Supabase dashboard: Click user → Turn ON 'Email confirmed'"

elif echo "$RESPONSE" | grep -q "error"; then
    ERROR_CODE=$(echo "$RESPONSE" | jq -r '.error_code // .error' 2>/dev/null)
    echo "❌ ERROR: $ERROR_CODE"
    echo ""
    echo "Full response:"
    echo "$RESPONSE"

else
    echo "⚠️ UNKNOWN RESPONSE"
    echo ""
    echo "Could not parse response. Full output:"
    echo "$RESPONSE"
fi

echo ""
