// lib/screens/announce/channel_chat_page.dart
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:boitex_info_app/widgets/voice_message_bubble.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show Uint8List, HapticFeedback;
import 'package:flutter/foundation.dart' show kIsWeb, Platform;

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:any_link_preview/any_link_preview.dart'; // 🌟 PRO FEATURE 3

class ChannelChatPage extends StatefulWidget {
  final ChannelModel channel;
  const ChannelChatPage({super.key, required this.channel});
  @override
  State<ChannelChatPage> createState() => _ChannelChatPageState();
}

class _ChannelChatPageState extends State<ChannelChatPage>
    with TickerProviderStateMixin {
  final AnnounceService _announceService = AnnounceService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isUploading = false;

  final FocusNode _messageInputFocusNode = FocusNode();

  MessageModel? _editingMessage;
  MessageModel? _replyToMessage;

  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isTextEmpty = true;

  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  late AnimationController _recordingAnimationController;
  late AnimationController _bgAnimationController;

  bool _showMentionSuggestions = false;
  List<String> _mentionSuggestions = [];
  int _mentionTriggerIndex = -1;

  // Typing Indicator State
  Timer? _typingTimer;

  // 🌟 FIX: Cached stream to prevent UI jitter
  late Stream<List<MessageModel>> _messagesStream;

  // 🌟 NEW: Key map for scrolling to replies
  final Map<String, GlobalKey> _messageKeys = {};

  // 🌟 NEW: Highlighted message state
  String? _highlightedMessageId;

  // 🌟 PRO FEATURE 2: Scroll to Bottom FAB State
  bool _showScrollToBottom = false;

  // 🌟 PRO FEATURE 4: Sticky Date Tracker
  DateTime? _currentlyVisibleDate;

  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  @override
  void initState() {
    super.initState();
    // 🌟 FIX: Initialize the stream once here!
    _messagesStream = _announceService.getMessages(widget.channel.id);

    _messageController.addListener(_onTextChanged);
    _audioRecorder = AudioRecorder();

    _recordingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // 🌟 PRO FEATURE 2: Listen to scroll changes
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _setTypingStatus(false);
    _typingTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageInputFocusNode.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    _recordingAnimationController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  // 🌟 PRO FEATURE 2 & 4: Scroll Logic
  void _onScroll() {
    // Scroll to bottom FAB logic
    if (_scrollController.offset > 300 && !_showScrollToBottom) {
      setState(() => _showScrollToBottom = true);
    } else if (_scrollController.offset <= 300 && _showScrollToBottom) {
      setState(() => _showScrollToBottom = false);
    }

    // Note for Pro Feature 4 (Sticky Dates):
    // A true sticky header usually requires a package like `sliver_tools` or `grouped_list`.
    // For this implementation, we will keep the floating pill at the top that updates based on the top-most visible item.
  }

  void _setTypingStatus(bool isTyping) {
    if (_currentUserId.isEmpty) return;
    _firestore
        .collection('channels')
        .doc(widget.channel.id)
        .collection('typing')
        .doc(_currentUserId)
        .set({
      'isTyping': isTyping,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFFF2D55), const Color(0xFF5856D6), const Color(0xFFFF9500),
      const Color(0xFF34C759), const Color(0xFF007AFF), const Color(0xFFAF52DE),
      const Color(0xFFFFCC00), const Color(0xFF32ADE6)
    ];
    return colors[name.hashCode % colors.length];
  }

  String _getInitials(String name) {
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return "?";
    if (parts.length == 1) return parts.first.substring(0, min(2, parts.first.length)).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return "Aujourd'hui";
    if (messageDate == yesterday) return "Hier";
    return DateFormat('dd MMM yyyy', 'fr').format(date);
  }

  Future<Map<String, dynamic>?> _getB2UploadCredentials() async {
    try {
      final response = await http.get(Uri.parse(_getB2UploadUrlCloudFunctionUrl));
      if (response.statusCode == 200) return json.decode(response.body) as Map<String, dynamic>;
      return null;
    } catch (e) { return null; }
  }

  Future<String?> _uploadBytesToB2(Uint8List fileBytes, String fileName, Map<String, dynamic> b2Creds) async {
    try {
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);
      String? mimeType;
      final fNameLower = fileName.toLowerCase();

      if (fNameLower.endsWith('.jpg') || fNameLower.endsWith('.jpeg')) mimeType = 'image/jpeg';
      else if (fNameLower.endsWith('.png')) mimeType = 'image/png';
      else if (fNameLower.endsWith('.pdf')) mimeType = 'application/pdf';
      else if (fNameLower.endsWith('.mp4')) mimeType = 'video/mp4';
      else if (fNameLower.endsWith('.m4a') || fNameLower.endsWith('.aac')) mimeType = 'audio/mp4';
      else mimeType = 'b2/x-auto';

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
        final encodedPath = (body['fileName'] as String).split('/').map(Uri.encodeComponent).join('/');
        return (b2Creds['downloadUrlPrefix'] as String) + encodedPath;
      }
      return null;
    } catch (e) { return null; }
  }

  // 🌟 FIX: Optimized text changed listener
  void _onTextChanged() {
    final isNowEmpty = _messageController.text.trim().isEmpty;

    // Only rebuild the UI if the emptiness state actually changes (Mic <-> Send arrow)
    if (_isTextEmpty != isNowEmpty) {
      setState(() => _isTextEmpty = isNowEmpty);
    }

    // Typing Indicator Trigger (Debounced, doesn't cause UI rebuild)
    if (!isNowEmpty) {
      _setTypingStatus(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () => _setTypingStatus(false));
    }

    if (_editingMessage != null) {
      if (_showMentionSuggestions) setState(() => _showMentionSuggestions = false);
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
    if (atIndex == -1 || textBeforeCursor.substring(atIndex + 1).contains(' ')) {
      if (_showMentionSuggestions) setState(() => _showMentionSuggestions = false);
      return;
    }
    setState(() => _mentionTriggerIndex = atIndex);
    _fetchMentionSuggestions(textBeforeCursor.substring(atIndex + 1));
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
    _messageController.text = '$textBefore@$displayName $textAfter';
    _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _mentionTriggerIndex + displayName.length + 2));
    setState(() { _showMentionSuggestions = false; _mentionSuggestions.clear(); });
  }

  void _sendNewTextMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _announceService.sendTextMessage(widget.channel.id, _messageController.text.trim(), replyTo: _replyToMessage);
      _messageController.clear();
      _setTypingStatus(false);
      setState(() { _showMentionSuggestions = false; _replyToMessage = null; });
      HapticFeedback.lightImpact();

      // 🌟 PRO FEATURE 2: Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  void _startTimer() {
    _recordDuration = Duration.zero;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordDuration = Duration(seconds: timer.tick));
    });
  }

  void _stopTimer() { _recordTimer?.cancel(); _recordTimer = null; }

  String _formatRecordingDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String filePath = path.join(appDir.path, 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a');
        const config = RecordConfig(encoder: AudioEncoder.aacLc);
        await _audioRecorder.start(config, path: filePath);
        _startTimer();
        _setTypingStatus(true);
        setState(() => _isRecording = true);
        HapticFeedback.mediumImpact();
      }
    } catch (e) { debugPrint('Error starting recording: $e'); }
  }

  Future<void> _stopAndSendRecording() async {
    _stopTimer();
    _setTypingStatus(false);
    try {
      final String? path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        final File file = File(path);
        if (_recordDuration.inSeconds < 1) { await file.delete(); return; }
        final Uint8List fileBytes = await file.readAsBytes();
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) throw Exception('No B2 credentials.');
        final String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final String? downloadUrl = await _uploadBytesToB2(fileBytes, fileName, b2Credentials);
        if (downloadUrl == null) throw Exception('Upload failed.');

        await _announceService.saveFileMessageWithUrl(
          channelId: widget.channel.id, fileUrl: downloadUrl, fileName: fileName,
          messageType: 'voice', fileSize: fileBytes.length, replyTo: _replyToMessage,
        );
        try { await file.delete(); } catch (_) {}
        setState(() => _replyToMessage = null);
        HapticFeedback.lightImpact();
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  Future<void> _cancelRecording() async {
    _stopTimer();
    _setTypingStatus(false);
    try {
      final String? path = await _audioRecorder.stop();
      if (path != null) await File(path).delete();
    } catch (e) { debugPrint("Cancel error: $e"); }
    setState(() => _isRecording = false);
    HapticFeedback.heavyImpact();
  }

  void _sendEditMessage() {
    if (_editingMessage == null) return;
    final newText = _messageController.text.trim();
    if (newText.isNotEmpty && newText != _editingMessage!.text) {
      _announceService.updateMessage(widget.channel.id, _editingMessage!.id, newText);
    }
    _cancelEditing();
  }

  void _startEditing(MessageModel message) {
    setState(() {
      _editingMessage = message; _replyToMessage = null;
      _messageController.text = message.text ?? '';
      _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
      _showMentionSuggestions = false;
    });
    _messageInputFocusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() => _editingMessage = null);
    _messageController.clear();
    _messageInputFocusNode.unfocus();
  }

  void _startReplying(MessageModel message) {
    setState(() { _replyToMessage = message; _editingMessage = null; });
    _messageInputFocusNode.requestFocus();
  }

  void _cancelReplying() => setState(() => _replyToMessage = null);

  void _deleteMessage(MessageModel message) => _announceService.deleteMessage(widget.channel.id, message.id);

  void _pinMessage(MessageModel message) {
    _firestore.collection('channels').doc(widget.channel.id).update({
      'pinnedMessageId': message.id,
      'pinnedMessageText': message.text ?? 'Fichier/Média',
      'pinnedMessageSender': message.senderName,
    });
  }

  void _unpinMessage() {
    _firestore.collection('channels').doc(widget.channel.id).update({
      'pinnedMessageId': FieldValue.delete(),
      'pinnedMessageText': FieldValue.delete(),
      'pinnedMessageSender': FieldValue.delete(),
    });
  }

  // 🌟 NEW: Function to scroll to original message
  void _scrollToMessage(String targetMessageId) {
    final targetKey = _messageKeys[targetMessageId];
    if (targetKey != null && targetKey.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );

      setState(() => _highlightedMessageId = targetMessageId);

      // Remove highlight after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            if (_highlightedMessageId == targetMessageId) {
              _highlightedMessageId = null;
            }
          });
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message original non trouvé (peut-être trop ancien).')),
      );
    }
  }


  // ==========================================
  // FILE HANDLING & LAUNCHING METHODS
  // ==========================================

  void _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf', 'mp4', 'mov', 'doc', 'zip'],
        withData: kIsWeb,
      );

      if (result != null && result.files.single != null) {
        setState(() => _isUploading = true);
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

        final String? downloadUrl = await _uploadBytesToB2(fileBytes, platformFile.name, b2Credentials);
        if (downloadUrl == null) throw Exception('Upload failed.');

        String messageType = 'file';
        final extension = platformFile.extension?.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) messageType = 'image';
        else if (extension == 'pdf') messageType = 'pdf';
        else if (['mp4', 'mov', 'avi'].contains(extension)) messageType = 'video';

        await _announceService.saveFileMessageWithUrl(
          channelId: widget.channel.id,
          fileUrl: downloadUrl,
          fileName: platformFile.name,
          messageType: messageType,
          fileSize: platformFile.size,
          replyTo: _replyToMessage,
        );
        setState(() => _replyToMessage = null);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future _launchFile(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  Future _openPdf(String url, String title) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      if (response.statusCode == 200) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerPage(pdfBytes: response.bodyBytes, title: title)));
      } else {
        throw Exception('Failed to load PDF');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showReadReceipts(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Column(
                children: [
                  Container(margin: const EdgeInsets.only(top: 12, bottom: 16), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
                  const Text("Détails de lecture", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: message.readBy.isEmpty
                        ? Center(child: Text("Personne n'a encore lu ce message.", style: TextStyle(color: Colors.white.withOpacity(0.5))))
                        : ListView.builder(
                      itemCount: message.readBy.length,
                      itemBuilder: (context, index) {
                        final uid = message.readBy[index];
                        return FutureBuilder<DocumentSnapshot>(
                          future: _firestore.collection('users').doc(uid).get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const ListTile(title: Text("Chargement...", style: TextStyle(color: Colors.white54)));
                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            final name = data?['displayName'] ?? 'Utilisateur inconnu';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getAvatarColor(name),
                                child: Text(_getInitials(name), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.done_all_rounded, color: Colors.blueAccent, size: 20),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMessageOptions(MessageModel message) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withOpacity(0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),

                  ListTile(
                    leading: const Icon(Icons.push_pin_rounded, color: Colors.orangeAccent),
                    title: const Text('Épingler le message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    onTap: () { Navigator.pop(context); _pinMessage(message); },
                  ),

                  if (message.senderId == _currentUserId)
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
                      title: const Text('Détails de lecture', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      onTap: () { Navigator.pop(context); _showReadReceipts(message); },
                    ),

                  if (message.senderId == _currentUserId && message.messageType == 'text')
                    ListTile(
                      leading: const Icon(Icons.edit_rounded, color: Colors.white),
                      title: const Text('Modifier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      onTap: () { Navigator.pop(context); _startEditing(message); },
                    ),
                  if (message.senderId == _currentUserId)
                    ListTile(
                      leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                      title: const Text('Supprimer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                      onTap: () { Navigator.pop(context); _deleteMessage(message); },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = _editingMessage != null;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(top: -100 + sin(_bgAnimationController.value * 2 * pi) * 50, left: -100 + cos(_bgAnimationController.value * 2 * pi) * 50, child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2C1065).withOpacity(0.6)))),
                  Positioned(bottom: -100 + cos(_bgAnimationController.value * 2 * pi) * 100, right: -50 + sin(_bgAnimationController.value * 2 * pi) * 100, child: Container(width: 500, height: 500, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0F3A5C).withOpacity(0.5)))),
                  BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.black.withOpacity(0.5))),
                ],
              );
            },
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  _buildGlassAppBar(isEditing),
                  _buildPinnedMessageHeader(),

                  Expanded(
                    child: StreamBuilder<List<MessageModel>>(
                      // 🌟 FIX: Use the cached stream here
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("Say hello!", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18)));

                        final messages = snapshot.data!.reversed.toList();

                        String? oldestUnreadId;
                        try {
                          oldestUnreadId = messages.lastWhere((m) => m.senderId != _currentUserId && !m.readBy.contains(_currentUserId)).id;
                        } catch (_) {}

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe = message.senderId == _currentUserId;

                            if (!isMe && !message.readBy.contains(_currentUserId)) {
                              _announceService.markMessageAsRead(widget.channel.id, message.id);
                            }

                            // 🌟 NEW: Ensure a GlobalKey exists for this message
                            final messageKey = _messageKeys.putIfAbsent(message.id, () => GlobalKey());

                            bool showDateSeparator = false;
                            if (index == messages.length - 1) { showDateSeparator = true; }
                            else {
                              final olderMessage = messages[index + 1];
                              final currentMsgDate = message.timestamp.toDate();
                              final olderMsgDate = olderMessage.timestamp.toDate();
                              if (currentMsgDate.day != olderMsgDate.day || currentMsgDate.month != olderMsgDate.month || currentMsgDate.year != olderMsgDate.year) showDateSeparator = true;
                            }

                            bool isFirstInGroup = true, isLastInGroup = true;
                            if (index < messages.length - 1) {
                              if (messages[index + 1].senderId == message.senderId && !showDateSeparator) isFirstInGroup = false;
                            }
                            if (index > 0) {
                              final newerMessage = messages[index - 1];
                              final currentMsgDate = message.timestamp.toDate();
                              final newerMsgDate = newerMessage.timestamp.toDate();
                              bool newerHasSeparator = (currentMsgDate.day != newerMsgDate.day || currentMsgDate.month != newerMsgDate.month || currentMsgDate.year != newerMsgDate.year);
                              if (newerMessage.senderId == message.senderId && !newerHasSeparator) isLastInGroup = false;
                            }

                            Widget chatBubble = Container(
                              // 🌟 NEW: Attach the key here so we can scroll to it
                              key: messageKey,
                              child: Dismissible(
                                key: Key('dismiss_${message.id}'),
                                direction: DismissDirection.startToEnd,
                                onUpdate: (details) { if (details.reached && !details.previousReached) HapticFeedback.lightImpact(); },
                                confirmDismiss: (direction) async { _startReplying(message); return false; },
                                background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 30), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.reply_rounded, color: Colors.white))),
                                child: _buildSmartGlassBubble(message, isMe, _editingMessage?.id == message.id, isFirstInGroup, isLastInGroup),
                              ),
                            );

                            List<Widget> columnChildren = [];

                            // 🌟 PRO FEATURE 4: Keeping standard date separators
                            if (showDateSeparator) columnChildren.add(_buildDateSeparator(message.timestamp.toDate()));

                            if (message.id == oldestUnreadId) {
                              columnChildren.add(
                                  Container(
                                    margin: const EdgeInsets.symmetric(vertical: 16),
                                    child: Row(
                                      children: [
                                        Expanded(child: Divider(color: Colors.redAccent.withOpacity(0.5), thickness: 1)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                          child: const Text("Nouveaux Messages", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(child: Divider(color: Colors.redAccent.withOpacity(0.5), thickness: 1)),
                                      ],
                                    ),
                                  )
                              );
                            }

                            columnChildren.add(chatBubble);

                            return columnChildren.length == 1 ? chatBubble : Column(children: columnChildren);
                          },
                        );
                      },
                    ),
                  ),

                  // 🌟 PRO FEATURE 2: Scroll to Bottom FAB Stack Layer
                  if (_showScrollToBottom)
                    Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20, bottom: 10),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: const Color(0xFF2563EB).withOpacity(0.9),
                          onPressed: () {
                            _scrollController.animateTo(
                              0.0, // 0.0 is the bottom of the list because reverse: true
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                        ),
                      ),
                    ),

                  _buildTypingIndicatorStream(),

                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSuggestionList(),
                          if (_replyToMessage != null) _buildReplyPreview(),
                          _isRecording ? _buildRecordingUI() : _buildGlassInput(isEditing),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageHeader() {
    return StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('channels').doc(widget.channel.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null || !data.containsKey('pinnedMessageId')) return const SizedBox.shrink();

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.push_pin_rounded, color: Colors.orangeAccent),
                  title: Text("Message épinglé par ${data['pinnedMessageSender']}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text(data['pinnedMessageText'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), onPressed: _unpinMessage),
                ),
              ),
            ),
          );
        }
    );
  }

  Widget _buildTypingIndicatorStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('channels').doc(widget.channel.id).collection('typing').where('isTyping', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final typingUsers = snapshot.data!.docs.where((d) => d.id != _currentUserId).toList();
        if (typingUsers.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 8),
          child: Row(
            children: [
              Text("${typingUsers.length} personne(s) écrit...", style: TextStyle(color: Colors.white.withOpacity(0.6), fontStyle: FontStyle.italic, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Text(_formatDateSeparator(date), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _buildGlassAppBar(bool isEditing) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.white.withOpacity(0.05),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 16, left: 8, right: 16),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => isEditing ? _cancelEditing() : Navigator.pop(context)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.tag_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(isEditing ? 'Editing...' : widget.channel.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartGlassBubble(MessageModel message, bool isMe, bool isEditing, bool isFirstInGroup, bool isLastInGroup) {
    // 🌟 NEW: Determine if this message is currently highlighted
    final isHighlighted = _highlightedMessageId == message.id;

    // 🌟 NEW: Define the gradient logic based on state
    List<Color> bubbleGradient;
    if (isHighlighted) {
      bubbleGradient = [Colors.orangeAccent.withOpacity(0.8), Colors.deepOrangeAccent.withOpacity(0.8)];
    } else if (isEditing) {
      bubbleGradient = [Colors.blue.withOpacity(0.4), Colors.blue.withOpacity(0.2)];
    } else if (isMe) {
      bubbleGradient = [const Color(0xFF3B82F6).withOpacity(0.9), const Color(0xFF2563EB).withOpacity(0.9)];
    } else {
      bubbleGradient = [Colors.white.withOpacity(0.18), Colors.white.withOpacity(0.08)];
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),

      // 🌟 PRO FEATURE 1: Double tap to react!
      onDoubleTap: () {
        HapticFeedback.heavyImpact();
        // Automatically add a heart reaction (or toggle it off if already there)
        _announceService.toggleReaction(widget.channel.id, message.id, '❤️');
      },

      child: Container(
        margin: EdgeInsets.only(top: isFirstInGroup ? 12 : 2, bottom: isLastInGroup ? 12 : 2, left: isMe ? 60 : 16, right: isMe ? 16 : 60),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[
              if (isLastInGroup)
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: _getAvatarColor(message.senderName).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: CircleAvatar(radius: 16, backgroundColor: _getAvatarColor(message.senderName), child: Text(_getInitials(message.senderName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                )
              else const SizedBox(width: 32),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && isFirstInGroup)
                    Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text(message.senderName, style: TextStyle(color: _getAvatarColor(message.senderName), fontSize: 13, fontWeight: FontWeight.w700))),

                  // 🌟 NEW: Added AnimatedContainer for smooth color transitions
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(topLeft: Radius.circular((!isMe && !isFirstInGroup) ? 6 : 22), topRight: Radius.circular((isMe && !isFirstInGroup) ? 6 : 22), bottomLeft: Radius.circular((!isMe && !isLastInGroup) ? 6 : 22), bottomRight: Radius.circular((isMe && !isLastInGroup) ? 6 : 22)),
                      border: Border.all(color: Colors.white.withOpacity(isHighlighted ? 0.8 : (isMe ? 0.2 : 0.1)), width: isHighlighted ? 2.0 : 1.2),
                      gradient: LinearGradient(colors: bubbleGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(color: isHighlighted ? Colors.orangeAccent.withOpacity(0.5) : Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.replyToMessageId != null)
                              // 🌟 NEW: Wrapped the reply snippet in GestureDetector
                                GestureDetector(
                                  onTap: () {
                                    if (message.replyToMessageId != null) {
                                      _scrollToMessage(message.replyToMessageId!);
                                    }
                                  },
                                  child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: Colors.white.withOpacity(0.8), width: 3))),
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(message.replyToSenderName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                            // 🌟 PRO FEATURE 5: Truncated replies (maxLines 2)
                                            Text(message.replyToText ?? 'Attachment', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)))
                                          ]
                                      )
                                  ),
                                ),
                              _buildMessageContent(message, isMe),
                              const SizedBox(height: 4),
                              _buildReactionsDisplay(message),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (message.isEdited) Text('(edited) ', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
                                  Text(DateFormat('HH:mm').format(message.timestamp.toDate()), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                                  if (isMe) ...[const SizedBox(width: 4), Icon(Icons.done_all_rounded, size: 14, color: message.readBy.length > 1 ? Colors.lightBlueAccent : Colors.white.withOpacity(0.4))]
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMe) {
    if (message.fileUrl == null && message.messageType != 'text') return Text('Error: File not found', style: TextStyle(color: Colors.red.withOpacity(0.8)));
    switch (message.messageType) {
      case 'text': return _buildTextWithMentionsAndLinks(message.text ?? '', message.mentionedUserIds.contains(_currentUserId));
      case 'voice': return VoiceMessageBubble(audioUrl: message.fileUrl!, isMe: isMe);
      case 'image': return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ImageGalleryPage(imageUrls: [message.fileUrl!], initialIndex: 0))), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(message.fileUrl!, fit: BoxFit.cover)));
      case 'pdf': return GestureDetector(onTap: () => _openPdf(message.fileUrl!, message.fileName ?? 'PDF'), child: _buildFileBubble(message.fileName ?? 'File.pdf', Icons.picture_as_pdf_rounded, Colors.redAccent));
      case 'video': return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerPage(videoUrl: message.fileUrl!))), child: _buildFileBubble(message.fileName ?? 'Video.mp4', Icons.play_circle_fill_rounded, Colors.white));
      default: return GestureDetector(onTap: () => _launchFile(message.fileUrl!), child: _buildFileBubble(message.fileName ?? 'File', Icons.insert_drive_file_rounded, Colors.white70));
    }
  }

  Widget _buildTextWithMentionsAndLinks(String text, bool amIMentioned) {
    final RegExp linkRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final RegExp mentionRegex = RegExp(r'@(\w+)');

    final List<TextSpan> textSpans = [];
    final TextStyle defaultStyle = const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400, height: 1.4);

    // Track if a link was found to build the preview
    String? foundUrl;

    text.split(RegExp(r'(?=\s)|(?<=\s)')).forEach((word) {
      if (linkRegex.hasMatch(word)) {
        foundUrl = word.trim();
        textSpans.add(TextSpan(
          text: word,
          style: defaultStyle.copyWith(color: Colors.lightBlueAccent, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse(word.trim()), mode: LaunchMode.externalApplication),
        ));
      } else if (mentionRegex.hasMatch(word)) {
        textSpans.add(TextSpan(text: word, style: defaultStyle.copyWith(color: amIMentioned ? Colors.black : Colors.cyanAccent, backgroundColor: amIMentioned ? Colors.yellowAccent : Colors.transparent, fontWeight: FontWeight.bold)));
      } else {
        textSpans.add(TextSpan(text: word, style: defaultStyle));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(text: TextSpan(children: textSpans)),

        // 🌟 PRO FEATURE 3: Rich URL Link Preview
        if (foundUrl != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: AnyLinkPreview(
              link: foundUrl!,
              displayDirection: UIDirection.uiDirectionHorizontal,
              // REMOVED: showImage: true, (It is now handled automatically by the package)
              cache: const Duration(hours: 1),
              backgroundColor: Colors.black.withOpacity(0.2),
              errorWidget: const SizedBox.shrink(),
              placeholderWidget: const SizedBox.shrink(),
              bodyStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              onTap: () => launchUrl(Uri.parse(foundUrl!), mode: LaunchMode.externalApplication),
            ),
          ),
      ],
    );
  }

  Widget _buildFileBubble(String fileName, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: iconColor, size: 28), const SizedBox(width: 12), Flexible(child: Text(fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 2))]),
    );
  }

  Widget _buildReactionsDisplay(MessageModel message) {
    if (message.reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: message.reactions.entries.map((entry) {
          final bool iReacted = entry.value.contains(_currentUserId);
          if (entry.value.isEmpty) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); _announceService.toggleReaction(widget.channel.id, message.id, entry.key); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: iReacted ? Colors.white.withOpacity(0.25) : Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(20), border: Border.all(color: iReacted ? Colors.white.withOpacity(0.5) : Colors.transparent)), child: Text('${entry.key} ${entry.value.length}', style: const TextStyle(fontSize: 13, color: Colors.white))),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGlassInput(bool isEditing) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isEditing) IconButton(icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 24)), onPressed: _isUploading ? null : _pickAndUploadFile),
                Expanded(child: Container(margin: const EdgeInsets.only(bottom: 6), child: TextField(controller: _messageController, focusNode: _messageInputFocusNode, style: const TextStyle(color: Colors.white, fontSize: 16), textCapitalization: TextCapitalization.sentences, minLines: 1, maxLines: 6, decoration: InputDecoration(hintText: isEditing ? 'Editing message...' : 'Message', hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))))),
                if (!isEditing) Padding(padding: const EdgeInsets.only(bottom: 4, right: 4), child: GestureDetector(onTap: _isTextEmpty ? _startRecording : _sendNewTextMessage, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: _isTextEmpty ? [Colors.white24, Colors.white10] : [const Color(0xFF3B82F6), const Color(0xFF2563EB)]), shape: BoxShape.circle), child: Icon(_isTextEmpty ? Icons.mic_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 24))))
                else Padding(padding: const EdgeInsets.only(bottom: 4, right: 4), child: IconButton(icon: const Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 36), onPressed: _sendEditMessage))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 30)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FadeTransition(opacity: _recordingAnimationController, child: const Icon(Icons.mic_rounded, color: Colors.redAccent, size: 28)),
                const SizedBox(width: 12),
                Text(_formatRecordingDuration(_recordDuration), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: "FiraCode")),
                Expanded(child: Dismissible(key: const Key('cancel_recording'), direction: DismissDirection.endToStart, confirmDismiss: (_) async { _cancelRecording(); return false; }, child: Center(child: Text('< Slide to cancel', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16))))),
                GestureDetector(onTap: _stopAndSendRecording, child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 24))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Replying to ${_replyToMessage?.senderName ?? 'Unknown'}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)), Text(_replyToMessage?.text ?? "Attachment", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.7)))])),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: _cancelReplying),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionList() {
    if (!_showMentionSuggestions) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.2))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            child: ListView.builder(
              shrinkWrap: true, itemCount: _mentionSuggestions.length, padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final suggestion = _mentionSuggestions[index];
                return ListTile(
                  leading: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_outline, color: Colors.white)),
                  title: Text(suggestion, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onTap: () => _onMentionSuggestionTapped(suggestion),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}