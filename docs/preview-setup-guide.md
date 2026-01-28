# Preview Validation System - Project Setup Guide

## Overview

The Preview Validation System automatically runs tests and deploys preview builds when implementations complete. This guide covers setup for different project types.

### Architecture

```
Implementation Completes
        │
        ▼
┌───────────────────┐     ┌──────────────────┐
│ GitHub Actions    │────▶│ Run Tests        │
│ Workflow Trigger  │     │ Report to Server │
└───────────────────┘     └────────┬─────────┘
                                   │
                          ┌────────▼─────────┐
                          │ Tests Pass?      │
                          └────────┬─────────┘
                                   │ Yes
                          ┌────────▼─────────┐
                          │ Deploy Preview   │
                          │ (Firebase/Vercel)│
                          └────────┬─────────┘
                                   │
                          ┌────────▼─────────┐
                          │ Report URL to    │
                          │ claude-ops       │
                          └────────┬─────────┘
                                   │
                          ┌────────▼─────────┐
                          │ WebSocket Event  │
                          │ to ops-deck      │
                          └──────────────────┘
```

### Server API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/issues/:owner/:repo/:num/preview` | GET | Get validation state (preview + test results) |
| `/issues/:owner/:repo/:num/preview` | POST | Trigger preview deployment |
| `/issues/:owner/:repo/:num/tests` | GET | Get test results |
| `/api/preview-callback` | POST | CI callback for preview status |
| `/api/test-callback` | POST | CI callback for test results |

---

## Table of Contents

1. [Project Configuration File](#1-project-configuration-file)
2. [GitHub Actions Workflows](#2-github-actions-workflows)
3. [Required Secrets](#3-required-secrets)
4. [Platform-Specific Setup](#4-platform-specific-setup)
5. [Testing the Setup](#5-testing-the-setup)
6. [Troubleshooting](#6-troubleshooting)
7. [Quick Start Checklist](#quick-start-checklist)

---

## 1. Project Configuration File

Create `.claude/project.yaml` in your repository root:

### Flutter Projects

```yaml
project:
  type: flutter

preview:
  enabled: true
  auto_deploy: true  # Deploy after implement job completes
  platform: firebase

  firebase:
    app_id: "1:123456789:android:abcdef"  # From Firebase console
    groups:
      - testers
      - preview

tests:
  required: true
  command: "flutter test --coverage"
  coverage_threshold: 70  # Optional: minimum coverage %
```

### Web Projects (Next.js, React, Vue)

```yaml
project:
  type: web

preview:
  enabled: true
  auto_deploy: true
  platform: vercel

  vercel:
    project_id: "prj_xxxxxxxxxxxxx"  # From Vercel dashboard
    team_id: "team_xxxxxxxxxxxxx"    # Optional: for team projects

tests:
  required: true
  command: "npm test -- --coverage"
  coverage_threshold: 80
```

### Backend Projects

```yaml
project:
  type: backend

preview:
  enabled: true
  auto_deploy: true
  platform: docker  # or: railway, fly

tests:
  required: true
  command: "pytest --cov=src"
  coverage_threshold: 75
```

### Library Projects (No Preview, Tests Only)

```yaml
project:
  type: library

preview:
  enabled: false

tests:
  required: true
  command: "npm test"
```

---

## 2. GitHub Actions Workflows

Add these workflow files to `.github/workflows/`:

### Main Preview Workflow

**`.github/workflows/preview.yml`**

```yaml
name: Preview Deployment

on:
  repository_dispatch:
    types: [preview-deploy]
  workflow_dispatch:
    inputs:
      issue_num:
        description: 'Issue number'
        required: true
      branch:
        description: 'Branch to deploy'
        required: true

env:
  CALLBACK_URL: ${{ secrets.CALLBACK_URL }}
  CALLBACK_SECRET: ${{ secrets.PREVIEW_CALLBACK_SECRET }}

jobs:
  detect-and-test:
    runs-on: ubuntu-latest
    outputs:
      project_type: ${{ steps.detect.outputs.type }}
      tests_passed: ${{ steps.test.outputs.passed }}

    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.client_payload.branch || inputs.branch }}

      - name: Detect project type
        id: detect
        run: |
          if [ -f "pubspec.yaml" ]; then
            echo "type=flutter" >> $GITHUB_OUTPUT
          elif [ -f "package.json" ]; then
            echo "type=web" >> $GITHUB_OUTPUT
          elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
            echo "type=backend" >> $GITHUB_OUTPUT
          else
            echo "type=unknown" >> $GITHUB_OUTPUT
          fi

      - name: Setup Flutter
        if: steps.detect.outputs.type == 'flutter'
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          cache: true

      - name: Setup Node.js
        if: steps.detect.outputs.type == 'web'
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Setup Python
        if: steps.detect.outputs.type == 'backend'
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          case "${{ steps.detect.outputs.type }}" in
            flutter) flutter pub get ;;
            web) npm ci ;;
            backend) pip install -r requirements.txt ;;
          esac

      - name: Run tests
        id: test
        run: |
          set +e
          case "${{ steps.detect.outputs.type }}" in
            flutter)
              flutter test --coverage --machine > test-results.json 2>&1
              ;;
            web)
              npm test -- --coverage --json --outputFile=test-results.json 2>&1
              ;;
            backend)
              pytest --cov=src --cov-report=json --json-report 2>&1
              ;;
          esac
          TEST_EXIT=$?

          if [ $TEST_EXIT -eq 0 ]; then
            echo "passed=true" >> $GITHUB_OUTPUT
          else
            echo "passed=false" >> $GITHUB_OUTPUT
          fi

      - name: Parse and report test results
        if: always()
        run: |
          # Parse test results and send to claude-ops
          ISSUE_NUM="${{ github.event.client_payload.issue_num || inputs.issue_num }}"

          curl -X POST "$CALLBACK_URL/api/test-callback" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $CALLBACK_SECRET" \
            -d @- << EOF
          {
            "repo": "${{ github.repository }}",
            "issue_num": $ISSUE_NUM,
            "commit_sha": "${{ github.sha }}",
            "test_suite": "Unit Tests",
            "passed": $(cat test-results.json | jq '.numPassedTests // .passed // 0'),
            "failed": $(cat test-results.json | jq '.numFailedTests // .failed // 0'),
            "skipped": $(cat test-results.json | jq '.numPendingTests // .skipped // 0'),
            "duration": $(cat test-results.json | jq '.duration // 0'),
            "coverage_percent": "$(cat coverage/lcov.info 2>/dev/null | grep -m1 'LF:' | sed 's/LF://' || echo '')",
            "run_url": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
          }
          EOF

  deploy-preview:
    needs: detect-and-test
    if: needs.detect-and-test.outputs.tests_passed == 'true'
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.client_payload.branch || inputs.branch }}

      - name: Deploy Flutter Preview
        if: needs.detect-and-test.outputs.project_type == 'flutter'
        uses: ./.github/workflows/preview-firebase.yml
        with:
          issue_num: ${{ github.event.client_payload.issue_num || inputs.issue_num }}

      - name: Deploy Web Preview
        if: needs.detect-and-test.outputs.project_type == 'web'
        uses: ./.github/workflows/preview-vercel.yml
        with:
          issue_num: ${{ github.event.client_payload.issue_num || inputs.issue_num }}

  report-failure:
    needs: detect-and-test
    if: needs.detect-and-test.outputs.tests_passed == 'false'
    runs-on: ubuntu-latest

    steps:
      - name: Report preview blocked
        run: |
          ISSUE_NUM="${{ github.event.client_payload.issue_num || inputs.issue_num }}"

          curl -X POST "$CALLBACK_URL/api/preview-callback" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $CALLBACK_SECRET" \
            -d @- << EOF
          {
            "type": "preview_status",
            "repo": "${{ github.repository }}",
            "issue_num": $ISSUE_NUM,
            "status": "failed",
            "error_message": "Tests failed - preview deployment blocked",
            "commit_sha": "${{ github.sha }}"
          }
          EOF
```

### Flutter/Firebase Preview

**`.github/workflows/preview-firebase.yml`**

```yaml
name: Firebase Preview

on:
  workflow_call:
    inputs:
      issue_num:
        required: true
        type: string

env:
  CALLBACK_URL: ${{ secrets.CALLBACK_URL }}
  CALLBACK_SECRET: ${{ secrets.PREVIEW_CALLBACK_SECRET }}

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          cache: true

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Decode google-services.json
        run: echo "${{ secrets.GOOGLE_SERVICES_JSON }}" | base64 -d > android/app/google-services.json

      - name: Build release APK
        run: |
          flutter pub get
          flutter build apk --release

      - name: Upload to Firebase App Distribution
        id: firebase
        uses: wzieba/Firebase-Distribution-Github-Action@v1
        with:
          appId: ${{ secrets.FIREBASE_APP_ID }}
          serviceCredentialsFileContent: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          groups: testers,preview
          file: build/app/outputs/flutter-apk/app-release.apk
          releaseNotes: |
            Preview build for Issue #${{ inputs.issue_num }}
            Commit: ${{ github.sha }}

      - name: Report preview ready
        run: |
          curl -X POST "$CALLBACK_URL/api/preview-callback" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $CALLBACK_SECRET" \
            -d @- << EOF
          {
            "type": "preview_status",
            "repo": "${{ github.repository }}",
            "issue_num": ${{ inputs.issue_num }},
            "status": "ready",
            "project_type": "flutter",
            "download_url": "${{ steps.firebase.outputs.downloadUrl }}",
            "build_id": "${{ github.run_id }}",
            "commit_sha": "${{ github.sha }}",
            "expires_at": $(date -d '+7 days' +%s)
          }
          EOF
```

### Web/Vercel Preview

**`.github/workflows/preview-vercel.yml`**

```yaml
name: Vercel Preview

on:
  workflow_call:
    inputs:
      issue_num:
        required: true
        type: string

env:
  VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
  VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
  CALLBACK_URL: ${{ secrets.CALLBACK_URL }}
  CALLBACK_SECRET: ${{ secrets.PREVIEW_CALLBACK_SECRET }}

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install Vercel CLI
        run: npm install -g vercel@latest

      - name: Pull Vercel Environment
        run: vercel pull --yes --environment=preview --token=${{ secrets.VERCEL_TOKEN }}

      - name: Build Project
        run: vercel build --token=${{ secrets.VERCEL_TOKEN }}

      - name: Deploy to Vercel
        id: deploy
        run: |
          URL=$(vercel deploy --prebuilt --token=${{ secrets.VERCEL_TOKEN }})
          echo "preview_url=$URL" >> $GITHUB_OUTPUT

      - name: Report preview ready
        run: |
          curl -X POST "$CALLBACK_URL/api/preview-callback" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $CALLBACK_SECRET" \
            -d @- << EOF
          {
            "type": "preview_status",
            "repo": "${{ github.repository }}",
            "issue_num": ${{ inputs.issue_num }},
            "status": "ready",
            "project_type": "web",
            "preview_url": "${{ steps.deploy.outputs.preview_url }}",
            "build_id": "${{ github.run_id }}",
            "commit_sha": "${{ github.sha }}"
          }
          EOF
```

---

## 3. Required Secrets

### Server Environment Variables (claude-ops)

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | For repository_dispatch API calls to trigger workflows |
| `PREVIEW_CALLBACK_SECRET` | Shared secret for callback authentication |
| `CALLBACK_URL` | Server URL for CI to call back (e.g., `https://claude-ops.example.com`) |

### Repository Secrets (GitHub Actions)

Configure these secrets in your repository (Settings > Secrets > Actions):

### All Projects

| Secret | Description |
|--------|-------------|
| `CALLBACK_URL` | Your claude-ops server URL (e.g., `https://claude-ops.example.com`) |
| `PREVIEW_CALLBACK_SECRET` | Shared secret for callback authentication (must match `PREVIEW_CALLBACK_SECRET` on server) |

### Flutter Projects (Firebase)

| Secret | Description |
|--------|-------------|
| `FIREBASE_APP_ID` | Firebase App ID (from Project Settings > General) |
| `FIREBASE_SERVICE_ACCOUNT` | Service account JSON (base64 encoded) |
| `GOOGLE_SERVICES_JSON` | google-services.json content (base64 encoded) |

**To get Firebase service account:**

1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Base64 encode: `base64 -i service-account.json | tr -d '\n'`

### Web Projects (Vercel)

| Secret | Description |
|--------|-------------|
| `VERCEL_TOKEN` | Vercel API token (from Account Settings > Tokens) |
| `VERCEL_ORG_ID` | Organization ID (from Project Settings > General) |
| `VERCEL_PROJECT_ID` | Project ID (from Project Settings > General) |

---

## 4. Platform-Specific Setup

### Firebase App Distribution

1. **Enable App Distribution** in Firebase Console

2. **Create tester groups:**
   - Go to App Distribution > Testers & Groups
   - Create groups: `testers`, `preview`
   - Add team members' emails

3. **Configure Android signing** (for release builds):

   ```bash
   # Generate keystore
   keytool -genkey -v -keystore upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```

   Add to `android/key.properties`:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

### Vercel

1. **Link project** (run locally once):

   ```bash
   vercel link
   ```

2. **Note your IDs** from `.vercel/project.json`:

   ```json
   {
     "orgId": "team_xxxxx",
     "projectId": "prj_xxxxx"
   }
   ```

3. **Configure environment variables** in Vercel dashboard for preview deployments

---

## 5. Testing the Setup

### Manual Trigger

You can test the workflow manually:

**Via GitHub CLI:**

```bash
gh workflow run preview.yml \
  -f issue_num=123 \
  -f branch=feature/my-branch
```

**Via API:**

```bash
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/OWNER/REPO/dispatches \
  -d '{"event_type":"preview-deploy","client_payload":{"issue_num":123,"branch":"feature/my-branch"}}'
```

### Verify in ops-deck

1. Open the issue in ops-deck
2. Go to the **PREVIEW** tab
3. You should see:
   - Test results (pass/fail counts, coverage)
   - Preview URL or download link when ready

---

## 6. Troubleshooting

### Tests not reporting

- Check workflow logs in GitHub Actions
- Verify `CALLBACK_URL` secret is set correctly
- Check claude-ops server logs for incoming requests

### Preview not deploying

- Ensure tests pass first (preview blocked if tests fail)
- Check Firebase/Vercel credentials are valid
- Verify callback token matches server configuration

### Preview URL not appearing in ops-deck

- Check WebSocket connection in ops-deck
- Verify callback was received (check server logs)
- Try refreshing the PREVIEW tab

---

## Quick Start Checklist

- [ ] Create `.claude/project.yaml` with project type and preview settings
- [ ] Add `.github/workflows/preview.yml`
- [ ] Add platform-specific workflow (`preview-firebase.yml` or `preview-vercel.yml`)
- [ ] Configure repository secrets
- [ ] Set up Firebase App Distribution or Vercel project
- [ ] Test with manual workflow trigger
- [ ] Verify results appear in ops-deck PREVIEW tab
