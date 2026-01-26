import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class FeedbackScreen extends StatefulWidget {
  final String repo;
  final int issueNum;
  final String issueTitle;

  const FeedbackScreen({
    super.key,
    required this.repo,
    required this.issueNum,
    required this.issueTitle,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _feedbackController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ADD SCREENSHOT',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE6EDF3),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF00FF41)),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFE6EDF3),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF58A6FF)),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFE6EDF3),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _submitFeedback() async {
    final feedbackText = _feedbackController.text.trim();
    if (feedbackText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter feedback text'),
          backgroundColor: Color(0xFFDA3633),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? imageUrl;

      // Upload image if selected
      if (_selectedImage != null) {
        setState(() => _isUploadingImage = true);
        imageUrl = await _apiService.uploadImage(_selectedImage!);
        if (!mounted) return;
        setState(() => _isUploadingImage = false);
      }

      // Post feedback
      await _apiService.postFeedback(
        widget.repo,
        widget.issueNum,
        feedbackText,
        imageUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted! Revision job queued.'),
            backgroundColor: Color(0xFF238636),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.userMessage : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFDA3633),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'REQUEST CHANGES',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: const Color(0xFF00FF41),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Issue context header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(
                bottom: BorderSide(color: Color(0xFF30363D)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ISSUE #${widget.issueNum}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF8B949E),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.issueTitle,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6EDF3),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Feedback text input
                  const Text(
                    'DESCRIBE THE CHANGES NEEDED',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B949E),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: TextField(
                      controller: _feedbackController,
                      maxLines: 8,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: Color(0xFFE6EDF3),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Describe what needs to be changed...\n\nBe specific about:\n- What is wrong\n- What you expected\n- Where the issue appears',
                        hintStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF484F58),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Screenshot section
                  Row(
                    children: [
                      const Text(
                        'SCREENSHOT (OPTIONAL)',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B949E),
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedImage == null)
                        TextButton.icon(
                          onPressed: _showImageSourceDialog,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text('ADD'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF58A6FF),
                            textStyle: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Image preview
                  if (_selectedImage != null)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(11),
                            ),
                            child: Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFF30363D)),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.image,
                                  size: 16,
                                  color: Color(0xFF8B949E),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Screenshot attached',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: Color(0xFF8B949E),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _removeImage,
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Color(0xFFDA3633),
                                  ),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF30363D),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: Color(0xFF484F58),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add a screenshot to help explain the issue',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Color(0xFF484F58),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('ADD SCREENSHOT'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF58A6FF),
                              side: const BorderSide(color: Color(0xFF58A6FF)),
                              textStyle: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Submit button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(
                top: BorderSide(color: Color(0xFF30363D)),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isUploadingImage
                        ? 'UPLOADING IMAGE...'
                        : (_isSubmitting ? 'SUBMITTING...' : 'SUBMIT FEEDBACK'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDA3633),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
