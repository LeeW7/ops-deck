#!/bin/bash
# Pre-commit security check for ops-deck (Flutter)
# Install: cp scripts/pre-commit-security-check.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Running security check..."

BLOCKED=0
WARNED=0

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    echo -e "${GREEN}No files staged for commit${NC}"
    exit 0
fi

# Check for files that should never be committed (Firebase, env, etc.)
FORBIDDEN_FILES="google-services.json GoogleService-Info.plist .env key.properties"
for file in $FORBIDDEN_FILES; do
    if echo "$STAGED_FILES" | grep -q "${file}$"; then
        echo -e "${RED}BLOCKED: $file should not be committed${NC}"
        BLOCKED=1
    fi
done

# Check for database files
if echo "$STAGED_FILES" | grep -qE '\.db$|\.db-shm$|\.db-wal$'; then
    echo -e "${RED}BLOCKED: Database files should not be committed${NC}"
    BLOCKED=1
fi

# Check for keystore files
if echo "$STAGED_FILES" | grep -qE '\.jks$|\.keystore$'; then
    echo -e "${RED}BLOCKED: Keystore files should not be committed${NC}"
    BLOCKED=1
fi

# Check staged content for secrets (only added lines, excluding docs, examples, and this script)
STAGED_CONTENT=$(git diff --cached -- ':(exclude)*.example' ':(exclude)*.md' ':(exclude)README*' ':(exclude)scripts/pre-commit*' ':(exclude).claude/commands/*' | grep -E '^\+' || true)

if [ -n "$STAGED_CONTENT" ]; then
    # Check for real API key assignments (not placeholders or references)
    if echo "$STAGED_CONTENT" | grep -qiE "(GEMINI_API_KEY|FIREBASE_API_KEY|API_KEY)\s*[=:]\s*['\"][a-zA-Z0-9_-]{20,}['\"]"; then
        echo -e "${RED}BLOCKED: Hardcoded API key value found${NC}"
        BLOCKED=1
    fi

    # Check for private keys (the actual key content, not pattern descriptions)
    if echo "$STAGED_CONTENT" | grep -q 'BEGIN RSA PRIVATE KEY' || \
       echo "$STAGED_CONTENT" | grep -q 'BEGIN EC PRIVATE KEY' || \
       echo "$STAGED_CONTENT" | grep -q 'BEGIN OPENSSH PRIVATE KEY' || \
       echo "$STAGED_CONTENT" | grep -qE 'BEGIN PRIVATE KEY-----\\n[A-Za-z0-9+/=]'; then
        echo -e "${RED}BLOCKED: Private key found in staged changes${NC}"
        BLOCKED=1
    fi

    # Check for firebase service account credentials (actual JSON with private_key field)
    if echo "$STAGED_CONTENT" | grep -qE '"private_key_id":\s*"[a-f0-9]{40}"'; then
        echo -e "${RED}BLOCKED: Firebase service account credentials found${NC}"
        BLOCKED=1
    fi

    # Check for hardcoded passwords (not placeholders)
    if echo "$STAGED_CONTENT" | grep -qiE 'password\s*[=:]\s*['\''"][^'\''"${\}]{8,}['\''"]'; then
        echo -e "${YELLOW}WARNING: Possible hardcoded password${NC}"
        WARNED=1
    fi
fi

# Check for personal paths in Dart source files only
DART_CHANGES=$(git diff --cached -- '*.dart' | grep -E '^\+' || true)
if [ -n "$DART_CHANGES" ]; then
    # Check for hardcoded personal paths (not in comments)
    if echo "$DART_CHANGES" | grep -v '//' | grep -qE '"/Users/[a-zA-Z]+/[^"]*"'; then
        echo -e "${YELLOW}WARNING: Hardcoded personal path found in Dart code${NC}"
        echo "Check: git diff --cached -- '*.dart' | grep -E '/Users/'"
        WARNED=1
    fi

    # Check for hardcoded IP:port combinations (potential server URLs)
    if echo "$DART_CHANGES" | grep -v '//' | grep -v 'example' | grep -qE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]+'; then
        echo -e "${YELLOW}WARNING: Hardcoded IP:port found - verify it's not a real server${NC}"
        WARNED=1
    fi
fi

# Check for real email addresses in code (not common safe ones)
if [ -n "$STAGED_CONTENT" ]; then
    EMAILS=$(echo "$STAGED_CONTENT" | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | grep -vE 'example\.com|noreply|test|anthropic\.com|localhost|placeholder|gserviceaccount\.com' | sort -u || true)
    if [ -n "$EMAILS" ]; then
        echo -e "${YELLOW}WARNING: Email address(es) found: $EMAILS${NC}"
        WARNED=1
    fi
fi

# Final result
echo ""
if [ $BLOCKED -eq 1 ]; then
    echo -e "${RED}=== COMMIT BLOCKED ===${NC}"
    echo "Sensitive data detected. Please remove before committing."
    echo "To bypass (NOT RECOMMENDED): git commit --no-verify"
    exit 1
elif [ $WARNED -eq 1 ]; then
    echo -e "${YELLOW}=== WARNINGS FOUND ===${NC}"
    echo "Review the warnings above. Continuing with commit..."
    echo "For thorough review, run: claude /security-review"
fi

echo -e "${GREEN}Security check passed${NC}"
exit 0
