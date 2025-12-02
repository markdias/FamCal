#!/bin/bash

# Test Supabase Authentication Endpoints
# Run this to verify your Supabase authentication is working

SUPABASE_URL="https://tzkspidmzlipujsnxpzc.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6a3NwaWRtemxpcHVqc254cHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4OTI2MTYsImV4cCI6MjA3OTQ2ODYxNn0.QMKZYMrESCOCT0KCHAKhPU995_mIB1F3l4Y4uq8s1uM"

TEST_EMAIL="test@example.com"
TEST_PASSWORD="test123456"

echo "=========================================="
echo "Supabase Authentication Test"
echo "=========================================="
echo ""
echo "URL: $SUPABASE_URL"
echo "Testing with email: $TEST_EMAIL"
echo ""

# Test 1: Signup
echo "TEST 1: Signup (POST /auth/v1/signup)"
echo "---"
curl -s -X POST "$SUPABASE_URL/auth/v1/signup" \
  -H "Content-Type: application/json" \
  -H "apikey: $ANON_KEY" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}" | jq '.' 2>/dev/null || echo "(Could not parse response)"
echo ""

# Test 2: Login with form-encoded (CORRECT)
echo "TEST 2: Login with Form-Encoded (POST /auth/v1/token) - CORRECT METHOD"
echo "---"
curl -s -X POST "$SUPABASE_URL/auth/v1/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "apikey: $ANON_KEY" \
  -d "grant_type=password&email=$TEST_EMAIL&password=$TEST_PASSWORD" | jq '.' 2>/dev/null || echo "(Could not parse response)"
echo ""

# Test 3: Login with JSON (WRONG - for comparison)
echo "TEST 3: Login with JSON (POST /auth/v1/token) - WRONG METHOD (for comparison)"
echo "---"
curl -s -X POST "$SUPABASE_URL/auth/v1/token" \
  -H "Content-Type: application/json" \
  -H "apikey: $ANON_KEY" \
  -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"grant_type\":\"password\"}" | jq '.' 2>/dev/null || echo "(Could not parse response)"
echo ""

echo "=========================================="
echo "Expected Results:"
echo "TEST 1: 200 or 201 - user created or already exists"
echo "TEST 2: 200 - access_token returned (this should work now!)"
echo "TEST 3: 400 - invalid request (wrong content-type)"
echo "=========================================="
