# Security Review - Pre-Push Check

Review all staged/changed files for sensitive data before pushing to the public repository.

## Instructions

You are a security reviewer. Before any code is pushed to the public repository, you MUST check for sensitive data leaks.

### Step 1: Get Changed Files

Run these commands to see what will be committed/pushed:

```bash
# Get list of staged files
git diff --cached --name-only

# Get list of changed files not yet staged
git diff --name-only

# Get commits not yet pushed (if any)
git log --oneline @{u}..HEAD 2>/dev/null || echo "No upstream set"
```

### Step 2: Scan for Sensitive Patterns

For EACH changed file, check for these patterns:

#### Critical - BLOCK COMMIT if found:
- **API Keys/Tokens**: `GEMINI_API_KEY=`, `api_key`, `apiKey`, `secret_key`, `access_token`, `bearer`
- **Firebase Credentials**: `google-services.json`, `GoogleService-Info.plist` (actual files, not references)
- **Service Account Data**: `"private_key"`, `"client_email"`, `firebase-adminsdk`, `-----BEGIN PRIVATE KEY-----`
- **Credentials**: `password=`, `passwd`, `credentials`, `auth_token`
- **Personal Paths**: `/Users/leew/`, `/Users/[username]/` (any personal home directory)
- **Private URLs**: Internal URLs, staging servers, private repo URLs
- **Environment Variables with Values**: `export.*=.*[actual value]` (not placeholders)
- **Hardcoded Server URLs**: Real IP addresses with ports (not localhost)

#### High Risk - Warn and Confirm:
- **Email Addresses**: Real email addresses (not example@example.com)
- **IP Addresses**: Hardcoded IPs (not localhost/127.0.0.1)
- **Phone Numbers**: Any phone number patterns
- **Database Connection Strings**: mongodb://, postgres://, mysql:// with credentials
- **Firebase Project IDs**: Real project IDs in code (not config files)

#### Check These Files Should NOT Be Staged:
- `google-services.json` (real Firebase config)
- `GoogleService-Info.plist` (real Firebase config)
- `.env` (real one, not .example)
- `*.db`, `*.db-shm`, `*.db-wal` (SQLite databases)
- `*.jks` (Java keystores)
- `key.properties` (Android signing)
- Any file with real credentials

### Step 3: Content Review

For each file, use grep to scan:

```bash
# Check staged files for secrets
git diff --cached -U0 | grep -iE "(api.?key|secret|password|token|private.?key|bearer|credential)"

# Check for personal paths
git diff --cached | grep -E "/Users/[a-zA-Z]+"

# Check for private keys
git diff --cached | grep -E "BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY"

# Check for hardcoded emails (not example ones)
git diff --cached | grep -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" | grep -v "example\|noreply\|test"

# Check for Firebase credentials
git diff --cached | grep -iE "(firebase|project_id|client_id|api_key)"

# Check for hardcoded IPs with ports (potential server URLs)
git diff --cached | grep -E "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]+"
```

### Step 4: Report Findings

Create a report with:

```
## Security Review Results

### Files Reviewed
- [list of files checked]

### Critical Issues (MUST FIX)
- [ ] Issue description and file:line

### Warnings (Review Required)
- [ ] Warning description and file:line

### Checks Passed
- [x] No Firebase config files staged
- [x] No .env files staged
- [x] No API keys found in diff
- [x] No personal paths found
- [x] No private keys found
- [x] No hardcoded credentials

### Recommendation
[ ] SAFE TO PUSH - No sensitive data found
[ ] BLOCK - Critical issues must be resolved first
[ ] REVIEW NEEDED - Warnings require manual verification
```

### Step 5: Known Safe Patterns

These are OK and should NOT trigger warnings:
- `.example` files (google-services.json.example, .env.example)
- Placeholder values: `your-api-key-here`, `YOUR_PROJECT_ID`, `your-server-url`
- Documentation references to file names
- Test fixtures with fake data
- `Co-Authored-By: Claude` email (noreply@anthropic.com)
- Gitignored file references in .gitignore itself
- Example URLs like `http://192.168.1.x:5001` in docs

### Step 6: Take Action

If any CRITICAL issues found:
1. List the exact files and line numbers
2. Explain what needs to be removed/changed
3. Suggest how to fix (use .example files, environment variables, etc.)
4. DO NOT approve the push

If only WARNINGS found:
1. List each warning with context
2. Ask user to confirm each is intentional
3. Proceed only after explicit confirmation

If CLEAN:
1. Confirm "Security review passed - safe to push"
2. Summarize what was checked
