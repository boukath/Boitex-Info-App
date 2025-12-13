// lib/screens/announce/channel_chat_page.dart
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:async'; // Added for Timer

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'package:boitex_info_app/models/channel_model.dart';
import 'package:boitex_info_app/models/message_model.dart';
import 'package:boitex_info_app/services/announce_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';
import 'package:boitex_info_app/widgets/voice_message_bubble.dart'; // ✅ ADDED
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show Uint8List, HapticFeedback;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Platform;

// ✅ NEW IMPORTS FOR VOICE
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class ChannelChatPage extends StatefulWidget {
  final ChannelModel channel;
  const ChannelChatPage({super.key, required this.channel});
  @override
  State createState() => _ChannelChatPageState();
}

class _ChannelChatPageState extends State<ChannelChatPage> with SingleTickerProviderStateMixin {
  final AnnounceService _announceService = AnnounceService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isUploading = false;

  final FocusNode _messageInputFocusNode = FocusNode();

  // ✅ State for Editing
  MessageModel? _editingMessage;

  // 🚀 State for Replying
  MessageModel? _replyToMessage;

  // 🎤 State for Voice Recording
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isTextEmpty = true; // Tracks if we should show Mic or Send button

  // ⏱️ Timer & Animation for Recording
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  late AnimationController _recordingAnimationController; // For pulsing dot

  // State for mention suggestions
  bool _showMentionSuggestions = false;
  List<String> _mentionSuggestions = [];
  int _mentionTriggerIndex = -1;

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  /// Fetches B2 upload credentials from your Cloud Function.
  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response =
      await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Failed to get B2 credentials: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return null;
    }
  }

  /// Uploads file bytes to B2.
  Future<String?> _uploadBytesToB2(
      Uint8List fileBytes, String fileName, Map<String, dynamic> b2Creds) async {
    try {
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      String? mimeType;
      final fNameLower = fileName.toLowerCase();
      if (fNameLower.endsWith('.jpg') || fNameLower.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fNameLower.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fNameLower.endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (fNameLower.endsWith('.pdf')) {
        mimeType = 'application/pdf';
      } else if (fNameLower.endsWith('.mp4')) {
        mimeType = 'video/mp4';
      } else if (fNameLower.endsWith('.mov')) {
        mimeType = 'video/quicktime';
      } else if (fNameLower.endsWith('.m4a') || fNameLower.endsWith('.aac')) {
        mimeType = 'audio/mp4'; // ✅ Mime for voice notes
      } else {
        mimeType = 'b2/x-auto';
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName),
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final encodedPath = (body['fileName'] as String)
            .split('/')
            .map(Uri.encodeComponent)
            .join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      } else {
        debugPrint('Failed to upload to B2: ${resp.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading file to B2: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _audioRecorder = AudioRecorder(); // 🎤 Init Recorder

    // Init pulsing animation
    _recordingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageInputFocusNode.dispose();
    _audioRecorder.dispose(); // 🎤 Dispose Recorder
    _recordTimer?.cancel();
    _recordingAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // 🎤 Update text state to toggle Mic/Send button
    setState(() {
      _isTextEmpty = _messageController.text.trim().isEmpty;
    });

    // If editing, don't show suggestions
    if (_editingMessage != null) {
      setState(() => _showMentionSuggestions = false);
      return;
    }

    final text = _messageController.text;
    final selection = _messageController.selection;

    if (selection.start == -1) {
      if (_showMentionSuggestions) setState(() => _showMentionSuggestions = false);
      return;
    }
    final textBeforeCursor = text.substring(0, selection.start);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex == -1) {
      if (_showMentionSuggestions) setState(() => _showMentionSuggestions = false);
      return;
    }
    final query = textBeforeCursor.substring(atIndex + 1);

    if (query.contains(' ')) {
      if (_showMentionSuggestions) setState(() => _showMentionSuggestions = false);
      return;
    }

    setState(() {
      _mentionTriggerIndex = atIndex;
    });
    _fetchMentionSuggestions(query);
  }

  Future<void> _fetchMentionSuggestions(String query) async {
    final suggestions = await _announceService.searchUserDisplayNames(query);
    if (!mounted) return;
    setState(() {
      _mentionSuggestions = suggestions;
      _showMentionSuggestions = suggestions.isNotEmpty;
    });
  }

  void _onMentionSuggestionTapped(String displayName) {
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.start;
    final textBefore = text.substring(0, _mentionTriggerIndex);
    final textAfter = text.substring(cursorPosition);
    final newText = '$textBefore@$displayName $textAfter';
    _messageController.text = newText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _mentionTriggerIndex + displayName.length + 2),
    );
    setState(() {
      _showMentionSuggestions = false;
      _mentionSuggestions.clear();
    });
  }

  // ✅ UPDATED: Send Text with Reply Context
  void _sendNewTextMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _announceService.sendTextMessage(
        widget.channel.id,
        _messageController.text.trim(),
        replyTo: _replyToMessage,
      );
      _messageController.clear();
      setState(() {
        _showMentionSuggestions = false;
        _replyToMessage = null;
      });
    }
  }

  // ⏱️ TIMER LOGIC
  void _startTimer() {
    _recordDuration = Duration.zero;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration = Duration(seconds: timer.tick);
      });
    });
  }

  void _stopTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  String _formatRecordingDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // 🎤 START RECORDING
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String filePath = path.join(appDir.path, 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a');

        const config = RecordConfig(encoder: AudioEncoder.aacLc); // High quality, low size

        await _audioRecorder.start(config, path: filePath);
        _startTimer(); // Start the visual timer

        setState(() {
          _isRecording = true;
        });
        HapticFeedback.mediumImpact();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission micro refusée')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  // 🎤 STOP & SEND RECORDING
  Future<void> _stopAndSendRecording() async {
    _stopTimer();
    try {
      final String? path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        final File file = File(path);
        // Safety check: Don't send if < 1 second (accidental tap)
        if (_recordDuration.inSeconds < 1) {
          await file.delete();
          return;
        }

        final Uint8List fileBytes = await file.readAsBytes();
        final int fileSize = fileBytes.length;

        // 1. Get B2 Creds
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) throw Exception('No B2 credentials.');

        // 2. Upload
        final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final String? downloadUrl = await _uploadBytesToB2(fileBytes, fileName, b2Credentials);

        if (downloadUrl == null) throw Exception('Upload failed.');

        // 3. Save to Firestore as "voice" message
        await _announceService.saveFileMessageWithUrl(
          channelId: widget.channel.id,
          fileUrl: downloadUrl,
          fileName: fileName,
          messageType: 'voice', // ✅ New Message Type
          fileSize: fileSize,
          replyTo: _replyToMessage,
        );

        // Cleanup temp file
        try {
          await file.delete();
        } catch (_) {}

        setState(() {
          _replyToMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Error stopping/sending recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur envoi vocal: $e')));
      }
    }
  }

  // ❌ CANCEL RECORDING
  Future<void> _cancelRecording() async {
    _stopTimer();
    try {
      final String? path = await _audioRecorder.stop();
      if (path != null) {
        final File file = File(path);
        await file.delete(); // Delete local file
      }
    } catch (e) {
      debugPrint("Error cancelling recording: $e");
    }

    setState(() {
      _isRecording = false;
    });
    HapticFeedback.heavyImpact(); // Strong vibration for cancel
  }

  void _sendEditMessage() {
    if (_editingMessage == null) return;

    final newText = _messageController.text.trim();
    if (newText.isNotEmpty && newText != _editingMessage!.text) {
      _announceService.updateMessage(
        widget.channel.id,
        _editingMessage!.id,
        newText,
      );
    }
    _cancelEditing();
  }

  void _startEditing(MessageModel message) {
    setState(() {
      _editingMessage = message;
      _replyToMessage = null;
      _messageController.text = message.text ?? '';
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
      _showMentionSuggestions = false;
    });
    _messageInputFocusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
    });
    _messageController.clear();
    _messageInputFocusNode.unfocus();
  }

  void _startReplying(MessageModel message) {
    setState(() {
      _replyToMessage = message;
      _editingMessage = null;
    });
    _messageInputFocusNode.requestFocus();
  }

  void _cancelReplying() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _deleteMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le message?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              _announceService.deleteMessage(widget.channel.id, message.id);
              Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(MessageModel message) {
    if (message.senderId != _currentUserId) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (message.messageType == 'text')
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Modifier le message'),
                  onTap: () {
                    Navigator.pop(context);
                    _startEditing(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Supprimer le message', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'pdf', 'mp4', 'mov', 'avi', 'mkv',
          'doc', 'docx', 'xls', 'xlsx', 'zip', 'rar',
        ],
        withData: kIsWeb,
      );

      if (result != null && result.files.single != null) {
        setState(() {
          _isUploading = true;
        });

        final PlatformFile platformFile = result.files.first;
        Uint8List? fileBytes;
        if (kIsWeb) {
          fileBytes = platformFile.bytes;
        } else if (platformFile.path != null) {
          fileBytes = await File(platformFile.path!).readAsBytes();
        }

        if (fileBytes == null) throw Exception("Cannot read file bytes.");

        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) throw Exception('No B2 credentials.');

        final String? downloadUrl =
        await _uploadBytesToB2(fileBytes, platformFile.name, b2Credentials);

        if (downloadUrl == null) throw Exception('Upload failed.');

        String messageType = 'file';
        final extension = platformFile.extension?.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
          messageType = 'image';
        } else if (extension == 'pdf') {
          messageType = 'pdf';
        } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
          messageType = 'video';
        }

        await _announceService.saveFileMessageWithUrl(
          channelId: widget.channel.id,
          fileUrl: downloadUrl,
          fileName: platformFile.name,
          messageType: messageType,
          fileSize: platformFile.size,
          replyTo: _replyToMessage,
        );

        setState(() {
          _replyToMessage = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future _launchFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $url')),
        );
      }
    }
  }

  Future _openPdf(String url, String title) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (!mounted) return;
      Navigator.pop(context);
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerPage(pdfBytes: bytes, title: title),
          ),
        );
      } else {
        throw Exception('Failed to load PDF: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = _editingMessage != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editing...' : widget.channel.name),
        leading: isEditing
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelEditing,
        )
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, const Color(0xFFE3F0FF), Colors.white],
            stops: const [0.0, 0.7, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _announceService.getMessages(widget.channel.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No messages yet."));
                  }
                  final messages = snapshot.data!;

                  bool isAtBottom = true;
                  if (_scrollController.hasClients) {
                    isAtBottom = _scrollController.position.atEdge &&
                        _scrollController.position.pixels ==
                            _scrollController.position.maxScrollExtent;
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (isAtBottom) _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == _currentUserId;

                      if (!isMe && !message.readBy.contains(_currentUserId)) {
                        _announceService.markMessageAsRead(widget.channel.id, message.id);
                      }

                      final bool isEditingThisMessage = _editingMessage?.id == message.id;

                      return Dismissible(
                        key: Key(message.id),
                        direction: DismissDirection.startToEnd,
                        confirmDismiss: (direction) async {
                          _startReplying(message);
                          HapticFeedback.lightImpact();
                          return false;
                        },
                        background: Container(
                          color: Colors.transparent,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.reply, color: Colors.blueGrey),
                        ),
                        child: _buildMessageBubble(message, isMe, isEditingThisMessage),
                      );
                    },
                  );
                },
              ),
            ),
            if (_isUploading)
              const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
            _buildSuggestionList(),

            if (_replyToMessage != null) _buildReplyPreview(),

            // ✅ SWITCH BETWEEN INPUT AND RECORDING UI
            _isRecording ? _buildRecordingUI() : _buildMessageInput(isEditing),
          ],
        ),
      ),
    );
  }

  // 🚀 NEW: The Recording UI (Slide to Cancel)
  Widget _buildRecordingUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // 1. Pulsing Red Dot
          FadeTransition(
            opacity: _recordingAnimationController,
            child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 8),

          // 2. Timer
          Text(
            _formatRecordingDuration(_recordDuration),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: "FiraCode"),
          ),

          // 3. Slide to Cancel (Dismissible Area)
          Expanded(
            child: Dismissible(
              key: const Key('cancel_recording'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                _cancelRecording();
                return false;
              },
              child: Center(
                child: Text(
                  '< Glisser pour annuler',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
          ),

          // 4. Send Button
          GestureDetector(
            onTap: _stopAndSendRecording,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF3380FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Replying to ${_replyToMessage?.senderName ?? 'Unknown'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  _replyToMessage?.text ??
                      (_replyToMessage?.fileName != null ? "📎 ${_replyToMessage!.fileName}" : "Media"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelReplying,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionList() {
    if (!_showMentionSuggestions) return const SizedBox.shrink();
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: ListView.builder(
        itemCount: _mentionSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _mentionSuggestions[index];
          return ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.blueAccent),
            title: Text(suggestion, style: const TextStyle(fontWeight: FontWeight.bold)),
            dense: true,
            onTap: () => _onMentionSuggestionTapped(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildMessageInput(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isEditing ? Colors.blue[50] : Colors.white.withOpacity(0.90),
        borderRadius: _showMentionSuggestions ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent),
              onPressed: _cancelEditing,
            )
          else
            IconButton(
              icon: const Icon(Icons.attach_file, color: Color(0xFF6AA3FF)),
              onPressed: _isUploading ? null : _pickAndUploadFile,
            ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageInputFocusNode,
              decoration: InputDecoration(
                hintText: isEditing ? 'Modification...' : (_replyToMessage != null ? 'Type your reply...' : 'Type a message...'),
                hintStyle: const TextStyle(color: Color(0xFFB4C7DF)),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: const TextStyle(color: Colors.black87),
              onSubmitted: (_) => isEditing ? _sendEditMessage() : _sendNewTextMessage(),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 5,
            ),
          ),

          // 🎤 MIC BUTTON (Replaces Send when text is empty)
          if (!isEditing)
            GestureDetector(
              // Simple Tap Logic: Tap to Start -> Icon Changes -> Tap to Stop
              onTap: _isTextEmpty
                  ? (_isRecording ? _stopAndSendRecording : _startRecording)
                  : _sendNewTextMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : const Color(0xFF3380FF),
                ),
                child: Icon(
                  _isTextEmpty
                      ? (_isRecording ? Icons.stop : Icons.mic)
                      : Icons.send,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check_rounded, color: Color(0xFF3380FF)),
              onPressed: _isUploading ? null : _sendEditMessage,
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe, bool isEditingThisMessage) {
    final borderRadius = BorderRadius.circular(24.0);
    final bubbleColor = isEditingThisMessage
        ? Colors.blue[100]
        : (isMe ? const Color(0xFFEDF4FF) : const Color(0xFFF8FBFF));
    final bubbleBorder = Border.all(
      color: isMe ? const Color(0xFFB4D0FF).withOpacity(0.43) : const Color(0xFFBFCDEB).withOpacity(0.45),
      width: 1.2,
    );
    final textColor = isMe ? const Color(0xFF174485) : const Color(0xFF335075);

    return GestureDetector(
      onLongPress: () {
        if (isMe) _showMessageOptions(message);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: isMe ? 20 : 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6AA3FF), Color(0xFFB9DFFD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [BoxShadow(color: Colors.lightBlueAccent.withOpacity(0.22), blurRadius: 8, spreadRadius: 1)],
                  ),
                  child: Text(
                    message.senderName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Colors.white, letterSpacing: 0.18),
                  ),
                ),
              ),
            Stack(
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (kIsWeb ? 0.54 : 0.80)),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                    border: bubbleBorder,
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(isMe ? 0.09 : 0.08), blurRadius: 22, spreadRadius: 2, offset: const Offset(0, 10))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyToMessageId != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.white.withOpacity(0.5) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(left: BorderSide(color: isMe ? Colors.blue.shade300 : Colors.grey, width: 3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.replyToSenderName ?? 'Unknown',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isMe ? Colors.blue.shade800 : Colors.grey.shade800),
                                ),
                                Text(
                                  message.replyToText ?? 'Attachment',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: isMe ? Colors.blue.shade900.withOpacity(0.7) : Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),

                        _buildMessageContent(message, textColor),
                        SizedBox(height: message.reactions.isNotEmpty ? 8 : 2),
                        _buildReactionsDisplay(message, isMe),

                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (message.isEdited)
                                Text('(modifié) ', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                              Text(
                                DateFormat('HH:mm').format(message.timestamp.toDate()),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF8BA2BA), fontFamily: "FiraCode", letterSpacing: 1),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                    Icons.done_all,
                                    size: 16,
                                    color: message.readBy.length > 1 ? Colors.blue : Colors.grey[400]
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsDisplay(MessageModel message, bool isMe) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: message.reactions.entries.map((entry) {
          final String emoji = entry.key;
          final List userIds = entry.value;
          final bool iReacted = userIds.contains(_currentUserId);
          if (userIds.isEmpty) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => _announceService.toggleReaction(widget.channel.id, message.id, emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: iReacted ? const Color(0xFF6AA3FF).withOpacity(0.10) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: iReacted ? Border.all(color: const Color(0xFF6AA3FF).withOpacity(0.18), width: 1.1) : null,
              ),
              child: Text('$emoji ${userIds.length}', style: TextStyle(fontSize: 12, color: isMe ? const Color(0xFF24509E) : const Color(0xFF2F406D))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, Color textColor) {
    final bool amIMentioned = message.mentionedUserIds.contains(_currentUserId);
    // Is this message sent by me? Needed for bubble color logic
    final bool isMe = message.senderId == _currentUserId;

    if (message.fileUrl == null && message.messageType != 'text') {
      return Text('Error: File not found', style: TextStyle(color: Colors.red.withOpacity(0.8)));
    }
    switch (message.messageType) {
      case 'text':
        return _buildTextWithMentions(message.text ?? '', textColor, amIMentioned);
    // 🎤 NEW CASE: Voice Message
      case 'voice':
        return VoiceMessageBubble(
          audioUrl: message.fileUrl!,
          isMe: isMe,
        );
      case 'image':
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ImageGalleryPage(imageUrls: [message.fileUrl!], initialIndex: 0)));
          },
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                message.fileUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      case 'pdf':
        return GestureDetector(
          onTap: () => _openPdf(message.fileUrl!, message.fileName ?? 'PDF'),
          child: _buildFileBubble(message.fileName ?? 'File.pdf', Icons.picture_as_pdf_rounded, Colors.red.shade700),
        );
      case 'video':
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerPage(videoUrl: message.fileUrl!))),
          child: _buildFileBubble(message.fileName ?? 'Video.mp4', Icons.videocam_rounded, Colors.blue.shade700),
        );
      case 'apk':
        return GestureDetector(
          onTap: () => _launchFile(message.fileUrl!),
          child: _buildApkBubble(message),
        );
      default:
        return GestureDetector(
          onTap: () => _launchFile(message.fileUrl!),
          child: _buildFileBubble(message.fileName ?? 'File', Icons.insert_drive_file_rounded, Colors.grey.shade700),
        );
    }
  }

  Widget _buildFileBubble(String fileName, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFE8F2FF), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
              style: const TextStyle(color: Color(0xFF27416A), fontWeight: FontWeight.w500, fontSize: 13, fontFamily: "FiraCode"),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApkBubble(MessageModel message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFE8F2FF), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF3380FF), shape: BoxShape.circle),
            child: const Icon(Icons.android, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.fileName ?? 'application.apk', style: const TextStyle(color: Color(0xFF174485), fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 2),
                if (message.fileSize != null)
                  Text(_formatBytes(message.fileSize!), style: const TextStyle(color: Color(0xFF27416A), fontWeight: FontWeight.w500, fontSize: 12, fontFamily: "FiraCode")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextWithMentions(String text, Color defaultColor, bool amIMentioned) {
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final List<TextSpan> textSpans = [];
    final TextStyle defaultStyle = TextStyle(color: defaultColor, fontSize: 15, fontFamily: "Inter", fontWeight: FontWeight.w500, height: 1.33);
    final TextStyle mentionStyle = defaultStyle.copyWith(color: Colors.blue.shade700, fontWeight: FontWeight.bold);
    final TextStyle selfMentionStyle = mentionStyle.copyWith(backgroundColor: Colors.blue.withOpacity(0.15));

    int lastMatchEnd = 0;
    for (final Match match in mentionRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        textSpans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: defaultStyle));
      }
      textSpans.add(TextSpan(text: match.group(0)!, style: amIMentioned ? selfMentionStyle : mentionStyle));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      textSpans.add(TextSpan(text: text.substring(lastMatchEnd), style: defaultStyle));
    }
    return RichText(text: TextSpan(children: textSpans));
  }
}