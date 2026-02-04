# Architecture: Screenshot Attachment for Issue Creation

## Overview

Add the ability to attach screenshots when creating issues from the Ops Deck mobile app. Screenshots will be uploaded to the server via the existing `/images/upload` endpoint and embedded as markdown images in the issue body before creation.

## Approach

The implementation leverages the existing `ApiService.uploadImage()` method which uploads images to the server. The server handles storage (via GitHub Gist) and returns a URL. We add a new `ScreenshotPicker` widget to the `CreateIssueScreen` that allows users to:

1. Select images from gallery or take photos
2. Upload them asynchronously with progress indication
3. Remove images before submission
4. Have them automatically embedded in the issue body on creation

## Data Models

### ScreenshotAttachment

```dart
/// Represents a screenshot being attached to an issue
class ScreenshotAttachment {
  final String localPath;      // Local file path
  final String? uploadedUrl;   // URL after successful upload
  final UploadStatus status;   // pending, uploading, completed, failed
  final double? uploadProgress; // 0.0 - 1.0
  final String? error;         // Error message if failed

  bool get isUploaded => status == UploadStatus.completed && uploadedUrl != null;
  bool get canRetry => status == UploadStatus.failed;
}

enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
}
```

### Updated IssueProvider State

```dart
class IssueProvider with ChangeNotifier {
  // ... existing fields ...

  List<ScreenshotAttachment> _screenshots = [];

  List<ScreenshotAttachment> get screenshots => _screenshots;
  bool get hasScreenshots => _screenshots.isNotEmpty;
  bool get allScreenshotsUploaded =>
      _screenshots.every((s) => s.isUploaded);
  int get uploadingCount =>
      _screenshots.where((s) => s.status == UploadStatus.uploading).length;
}
```

## Component Structure

```
lib/
├── models/
│   └── screenshot_attachment.dart   # NEW: ScreenshotAttachment model
├── providers/
│   └── job_provider.dart            # MODIFY: Add screenshot state to IssueProvider
├── screens/
│   └── create_issue_screen.dart     # MODIFY: Add screenshot section
└── widgets/
    └── screenshot_picker.dart       # NEW: Reusable screenshot picker widget
```

## API Integration

### Existing Endpoint (No Server Changes Required)

The server already supports image upload via:

```
POST /images/upload
Content-Type: multipart/form-data

Body:
- image: File (PNG, JPG, GIF)

Response (200):
{
  "url": "https://gist.githubusercontent.com/..."
}

Error Responses:
- 400: Invalid file type
- 413: File too large
- 500: Upload failed
```

### Issue Body Modification

When creating an issue, screenshots are appended to the body as markdown:

```markdown
[User's original description]

---
### Screenshots

![Screenshot 1](https://gist.githubusercontent.com/...)
![Screenshot 2](https://gist.githubusercontent.com/...)
```

## User Flows

### Adding Screenshots

1. User taps "Add" button in screenshot section
2. Bottom sheet appears with options: Camera, Gallery, Clipboard
3. User selects source and picks image
4. Image appears in grid with upload progress indicator
5. Upload completes, checkmark shown
6. User can tap X to remove

### Creating Issue with Screenshots

1. User fills out title and description
2. User adds 1-5 screenshots
3. All screenshots upload in parallel
4. User taps "Create & Queue"
5. If any uploads pending, show loading state
6. System appends screenshot markdown to body
7. Issue created with embedded images

### Error Handling

- **Upload failure**: Show error badge on thumbnail, allow retry
- **Network error during create**: Uploaded images are safe (URLs are valid)
- **Max limit reached**: Disable add button, show hint

## Implementation Phases

### Phase 1: Core Screenshot Model & Provider (1-2 files)

- Create `ScreenshotAttachment` model
- Add screenshot state to `IssueProvider`
- Add methods: `addScreenshot`, `removeScreenshot`, `uploadScreenshot`, `clearScreenshots`
- Modify `createIssue` to append screenshot markdown to body

### Phase 2: Screenshot Picker Widget (1 file)

- Create `ScreenshotPicker` widget with grid display
- Implement image source selection bottom sheet
- Add upload progress visualization
- Handle remove and retry actions

### Phase 3: UI Integration (1 file)

- Add `ScreenshotPicker` to `CreateIssueScreen`
- Update info text to mention screenshots
- Add validation for pending uploads
- Clear screenshots on successful creation

## Security Considerations

- **File validation**: Only allow image file types (PNG, JPG, GIF)
- **Size limit**: Enforce 10MB max per image (client-side)
- **Count limit**: Maximum 5 screenshots per issue
- **No sensitive data**: Images uploaded to public Gist - warn users if needed

## Dependencies

### Flutter Packages Required

```yaml
dependencies:
  image_picker: ^1.0.0  # For camera and gallery access
```

The `image_picker` package is the standard Flutter solution for accessing device camera and photo gallery.

## Testing Strategy

### Unit Tests

- `ScreenshotAttachment` model state transitions
- `IssueProvider` screenshot management methods
- Markdown generation for issue body

### Widget Tests

- `ScreenshotPicker` renders correctly with various states
- Add/remove interactions work correctly
- Upload progress displays correctly

### Integration Tests

- End-to-end flow: pick image → upload → create issue
- Error recovery: failed upload → retry → success
- Multiple images uploaded in parallel

## TDD Template

`user-interface` - This feature is primarily a UI enhancement with straightforward data flow.
