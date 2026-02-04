/// Status of a screenshot upload
enum UploadStatus {
  pending,
  uploading,
  completed,
  failed,
}

/// Represents a screenshot being attached to an issue
class ScreenshotAttachment {
  final String id;
  final String localPath;
  final String? uploadedUrl;
  final UploadStatus status;
  final double? uploadProgress;
  final String? error;

  const ScreenshotAttachment({
    required this.id,
    required this.localPath,
    this.uploadedUrl,
    this.status = UploadStatus.pending,
    this.uploadProgress,
    this.error,
  });

  bool get isUploaded => status == UploadStatus.completed && uploadedUrl != null;
  bool get canRetry => status == UploadStatus.failed;
  bool get isUploading => status == UploadStatus.uploading;
  bool get isPending => status == UploadStatus.pending;

  ScreenshotAttachment copyWith({
    String? id,
    String? localPath,
    String? uploadedUrl,
    UploadStatus? status,
    double? uploadProgress,
    String? error,
  }) {
    return ScreenshotAttachment(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      uploadedUrl: uploadedUrl ?? this.uploadedUrl,
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error ?? this.error,
    );
  }
}
