// lib/screens/announce/channel_chat_page.dart
import 'dart:ui';
import 'dart:io';
import 'dart:convert'; // ✅ ADDED FOR B2
import 'dart:math'; // ✅ --- ADDED FOR FILE SIZE FORMATTING ---

import 'package:crypto/crypto.dart'; // ✅ ADDED FOR B2
import 'package:path/path.dart' as path; // ✅ ADDED FOR B2

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
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show Uint8List;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Platform;

class ChannelChatPage extends StatefulWidget {
  final ChannelModel channel;
  const ChannelChatPage({super.key, required this.channel});
  @override
  State createState() => _ChannelChatPageState();
}

class _ChannelChatPageState extends State<ChannelChatPage> {
  final AnnounceService _announceService = AnnounceService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isUploading = false;

  // ✅ --- NEW: State for editing ---
  final FocusNode _messageInputFocusNode = FocusNode();
  MessageModel? _editingMessage; // Holds the message being edited
  // ✅ --- END NEW ---


  // --- State for mention suggestions ---
  bool _showMentionSuggestions = false;
  List<String> _mentionSuggestions = [];
  int _mentionTriggerIndex = -1;
  // --- END ---

  // ✅ --- START: ADDED B2 UPLOAD LOGIC ---

  // Copied from add_sav_ticket_page.dart
  final String _getB2UploadUrlCloudFunctionUrl =
      'https://getb2uploadurl-onxwq446zq-ew.a.run.app';

  /// Fetches B2 upload credentials from your Cloud Function.
  /// Copied from add_sav_ticket_page.dart.
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
  /// This is a web/mobile compatible version of the logic
  /// from add_sav_ticket_page.dart.
  Future<String?> _uploadBytesToB2(
      Uint8List fileBytes, String fileName, Map<String, dynamic> b2Creds) async {
    try {
      final sha1Hash = sha1.convert(fileBytes).toString();
      final uploadUri = Uri.parse(b2Creds['uploadUrl'] as String);

      // Determine mime type (optional but helpful)
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
        // ✅ --- MODIFIED: Removed 'apk' mime type detection ---
      } else {
        mimeType = 'b2/x-auto'; // Backblaze default
      }

      final resp = await http.post(
        uploadUri,
        headers: {
          'Authorization': b2Creds['authorizationToken'] as String,
          'X-Bz-File-Name': Uri.encodeComponent(fileName), // Use Uri.encodeComponent for safety
          'Content-Type': mimeType,
          'X-Bz-Content-Sha1': sha1Hash,
          'Content-Length': fileBytes.length.toString(),
        },
        body: fileBytes,
      );

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        // Correctly encode each part of the path
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
  // ✅ --- END: ADDED B2 UPLOAD LOGIC ---


  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageInputFocusNode.dispose(); // ✅ NEW
    super.dispose();
  }

  void _onTextChanged() {
    // ✅ --- MODIFIED ---
    // Don't show suggestions if we are editing a message
    if (_editingMessage != null) {
      setState(() => _showMentionSuggestions = false);
      return;
    }
    // ✅ --- END MODIFIED ---

    final text = _messageController.text;
    final selection = _messageController.selection;

    if (selection.start == -1) {
      if (_showMentionSuggestions) {
        setState(() => _showMentionSuggestions = false);
      }
      return;
    }
    final textBeforeCursor = text.substring(0, selection.start);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex == -1) {
      if (_showMentionSuggestions) {
        setState(() => _showMentionSuggestions = false);
      }
      return;
    }
    final query = textBeforeCursor.substring(atIndex + 1);

    if (query.contains(' ')) {
      if (_showMentionSuggestions) {
        setState(() => _showMentionSuggestions = false);
      }
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

  // ✅ --- MODIFIED: Renamed to _sendNewTextMessage ---
  void _sendNewTextMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _announceService.sendTextMessage(
        widget.channel.id,
        _messageController.text.trim(),
      );
      _messageController.clear();
      setState(() {
        _showMentionSuggestions = false;
      });
    }
  }
  // ✅ --- END MODIFIED ---


  // ✅ --- START: NEW FUNCTIONS FOR EDIT/DELETE ---

  /// Handles sending the edited message
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

  /// Puts the app into "edit mode" for a specific message
  void _startEditing(MessageModel message) {
    setState(() {
      _editingMessage = message;
      _messageController.text = message.text ?? '';
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
      _showMentionSuggestions = false;
    });
    _messageInputFocusNode.requestFocus();
  }

  /// Cancels "edit mode" and clears the text field
  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
    });
    _messageController.clear();
    _messageInputFocusNode.unfocus();
  }

  /// Shows the confirmation dialog before deleting a message
  void _deleteMessage(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le message?'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce message? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              _announceService.deleteMessage(widget.channel.id, message.id);
              Navigator.pop(context); // Close the confirmation dialog
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  /// Shows the bottom sheet with "Edit" and "Delete" options
  void _showMessageOptions(MessageModel message) {
    // Only show options if the user is the sender
    if (message.senderId != _currentUserId) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              // Only show "Edit" for text messages
              if (message.messageType == 'text')
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Modifier le message'),
                  onTap: () {
                    Navigator.pop(context); // Close the bottom sheet
                    _startEditing(message);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Supprimer le message', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet
                  _deleteMessage(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  // ✅ --- END: NEW FUNCTIONS ---

  // ✅ --- MODIFIED: Removed 'apk' to prevent crash ---
  void _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'pdf', 'mp4', 'mov', 'avi', 'mkv',
          'doc', 'docx', 'xls', 'xlsx', 'zip', 'rar',
          // 'apk', // ✅ --- REMOVED TO PREVENT OutOfMemoryError ---
        ],
        withData: kIsWeb, // Use 'true' for web, 'false' for mobile
      );

      if (result != null && result.files.single != null) {
        setState(() {
          _isUploading = true;
        });

        final PlatformFile platformFile = result.files.first;

        // Get file bytes (cross-platform way)
        Uint8List? fileBytes;
        if (kIsWeb) {
          fileBytes = platformFile.bytes;
        } else if (platformFile.path != null) {
          // This path is safe for small files, but would crash on large ones.
          // Since we removed 'apk', we are only handling smaller files.
          fileBytes = await File(platformFile.path!).readAsBytes();
        }

        if (fileBytes == null) {
          throw Exception("Impossible de lire les octets du fichier.");
        }

        // 1. Get B2 credentials
        final b2Credentials = await _getB2UploadCredentials();
        if (b2Credentials == null) {
          throw Exception('Impossible de récupérer les accès B2.');
        }

        // 2. Upload to B2 using the new bytes-based function
        final String? downloadUrl =
        await _uploadBytesToB2(fileBytes, platformFile.name, b2Credentials);

        if (downloadUrl == null) {
          throw Exception('Échec de l\'upload du fichier sur B2.');
        }

        // 3. Determine file type for the message
        String messageType = 'file'; // Default
        final extension = platformFile.extension?.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
          messageType = 'image';
        } else if (extension == 'pdf') {
          messageType = 'pdf';
        } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension)) {
          messageType = 'video';
        }
        // ✅ --- MODIFIED: Removed 'apk' detection logic ---

        // 4. Call the (new) service method to save the URL and metadata
        await _announceService.saveFileMessageWithUrl(
          channelId: widget.channel.id,
          fileUrl: downloadUrl,
          fileName: platformFile.name,
          messageType: messageType,
          fileSize: platformFile.size,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur upload fichier: $e')));
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
      Navigator.pop(context); // Hide loading dialog
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
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  void _showEmojiPicker(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmojiPicker(
          onEmojiSelected: (Category? category, Emoji emoji) {
            _announceService.toggleReaction(
              widget.channel.id,
              messageId,
              emoji.emoji,
            );
            Navigator.pop(context);
          },
          config: Config(
            height: 256,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: 28 * (Platform.isIOS ? 1.20 : 1.0),
              columns: 8,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
            swapCategoryAndBottomBar: false,
            skinToneConfig: const SkinToneConfig(enabled: false),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              indicatorColor: Theme.of(context).primaryColor,
              iconColorSelected: Theme.of(context).primaryColor,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            searchViewConfig: SearchViewConfig(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        );
      },
    );
  }

  // ✅ --- START: NEW HELPER FUNCTION ---
  /// Formats bytes into a human-readable string (e.g., "1.2 MB")
  String _formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
  // ✅ --- END: NEW HELPER FUNCTION ---


  @override
  Widget build(BuildContext context) {
    // ✅ --- NEW ---
    final bool isEditing = _editingMessage != null;
    // ✅ --- END NEW ---

    return Scaffold(
      // ✅ --- MODIFIED: Show "Editing..." in app bar ---
      appBar: AppBar(
        title: Text(isEditing ? 'Modification...' : widget.channel.name),
        // Add a cancel button to the app bar when editing
        leading: isEditing
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelEditing,
        )
            : null, // Will show default back button
      ),
      // ✅ --- END MODIFIED ---
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFFE3F0FF),
              Colors.white
            ],
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
                    return Center(
                        child: Text("Error loading messages: ${snapshot.error}",
                            style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text("Be the first to say something!",
                            style: TextStyle(color: Colors.grey)));
                  }
                  final messages = snapshot.data!;

                  // ✅ --- START: IMPROVED AUTO-SCROLL ---
                  // Check if we are already at the bottom BEFORE the frame renders
                  bool isAtBottom = true; // Default to true if not scrollable
                  if (_scrollController.hasClients) {
                    isAtBottom = _scrollController.position.atEdge &&
                        _scrollController.position.pixels ==
                            _scrollController.position.maxScrollExtent;
                  }

                  // Schedule the scroll for AFTER the frame has rendered
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // Only auto-scroll if we were at the bottom
                    if (isAtBottom) {
                      _scrollToBottom();
                    }
                  });
                  // ✅ --- END: IMPROVED AUTO-SCROLL ---

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: false,
                    itemCount: messages.length,
                    padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == _currentUserId;
                      // ✅ --- MODIFIED: Pass 'isEditingThisMessage' ---
                      final bool isEditingThisMessage =
                          _editingMessage?.id == message.id;
                      return _buildMessageBubble(
                          message, isMe, isEditingThisMessage);
                      // ✅ --- END MODIFIED ---
                    },
                  );
                },
              ),
            ),
            if (_isUploading)
              const Padding(
                  padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
            _buildSuggestionList(),
            _buildMessageInput(isEditing), // ✅ MODIFIED: Pass isEditing
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionList() {
    if (!_showMentionSuggestions) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 150, // Max height for the suggestion list
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        itemCount: _mentionSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _mentionSuggestions[index];
          return ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.blueAccent),
            title: Text(suggestion, style: const TextStyle(fontWeight: FontWeight.bold)),
            dense: true,
            onTap: () {
              _onMentionSuggestionTapped(suggestion);
            },
          );
        },
      ),
    );
  }

  // ✅ --- MODIFIED: Accept 'isEditing' parameter ---
  Widget _buildMessageInput(bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        // ✅ Show a different color when editing
        color: isEditing ? Colors.blue[50] : Colors.white.withOpacity(0.90),
        borderRadius: _showMentionSuggestions
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ✅ --- MODIFIED: Show cancel button when editing, attach button when not ---
          if (isEditing)
            IconButton(
              icon: Icon(Icons.close, color: Colors.redAccent),
              onPressed: _cancelEditing,
              tooltip: 'Annuler la modification',
            )
          else
            IconButton(
              icon: Icon(Icons.attach_file, color: const Color(0xFF6AA3FF)),
              onPressed: _isUploading ? null : _pickAndUploadFile,
            ),
          // ✅ --- END MODIFIED ---

          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageInputFocusNode, // ✅ ADDED
              decoration: InputDecoration(
                // ✅ MODIFIED: Change hint text based on mode
                hintText: isEditing
                    ? 'Modification...'
                    : 'Type a message... (try @Username)',
                // ✅ END MODIFIED
                hintStyle: TextStyle(color: Color(0xFFB4C7DF)),
                border: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
              ),
              style: const TextStyle(color: Colors.black87),
              // ✅ MODIFIED: Change submit logic based on mode
              onSubmitted: (_) =>
              isEditing ? _sendEditMessage() : _sendNewTextMessage(),
              // ✅ END MODIFIED
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 5,
            ),
          ),
          IconButton(
            // ✅ MODIFIED: Change icon and logic based on mode
            icon: Icon(
              isEditing ? Icons.check_rounded : Icons.send,
              color: const Color(0xFF3380FF),
            ),
            onPressed: _isUploading
                ? null
                : (isEditing ? _sendEditMessage : _sendNewTextMessage),
            tooltip: isEditing ? 'Sauvegarder' : 'Envoyer',
            // ✅ END MODIFIED
          ),
        ],
      ),
    );
  }

  // -------- Bubble UI ---------
  // ✅ --- MODIFIED: Accept 'isEditingThisMessage' ---
  Widget _buildMessageBubble(
      MessageModel message, bool isMe, bool isEditingThisMessage) {
    // ✅ --- END MODIFIED ---

    final borderRadius = BorderRadius.circular(24.0);
    // ✅ --- MODIFIED: Highlight the bubble being edited ---
    final bubbleColor = isEditingThisMessage
        ? Colors.blue[100]
        : (isMe ? const Color(0xFFEDF4FF) : const Color(0xFFF8FBFF));
    // ✅ --- END MODIFIED ---
    final bubbleBorder = Border.all(
      color: isMe
          ? const Color(0xFFB4D0FF).withOpacity(0.43)
          : const Color(0xFFBFCDEB).withOpacity(0.45),
      width: 1.2,
    );
    final textColor = isMe ? const Color(0xFF174485) : const Color(0xFF335075);

    // ✅ --- MODIFIED: Wrap bubble in GestureDetector for long press ---
    return GestureDetector(
      onLongPress: () {
        // Only allow actions on your own messages
        if (isMe) {
          _showMessageOptions(message);
        }
      },
      // ✅ --- END MODIFIED ---
      child: Container(
        margin: EdgeInsets.symmetric(
            vertical: 8, horizontal: isMe ? 20 : 8),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.lightBlueAccent.withOpacity(0.22),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    message.senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Colors.white,
                      letterSpacing: 0.18,
                    ),
                  ),
                ),
              ),
            Stack(
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width *
                        (kIsWeb ? 0.54 : 0.80),
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                    border: bubbleBorder,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(isMe ? 0.09 : 0.08),
                        blurRadius: 22,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        _buildMessageContent(
                            message, textColor),
                        SizedBox(
                            height: message.reactions.isNotEmpty ? 8 : 2),
                        _buildReactionsDisplay(message, isMe),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          // ✅ --- MODIFIED: Show '(modifié)' text ---
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.isEdited)
                                Text(
                                  '(modifié)  ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8BA2BA).withOpacity(0.8),
                                    fontFamily: "FiraCode",
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              Text(
                                message.timestamp != null
                                    ? DateFormat('HH:mm').format(
                                    message.timestamp!.toDate())
                                    : '--:--',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8BA2BA),
                                  fontFamily: "FiraCode",
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          // ✅ --- END MODIFIED ---
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
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: message.reactions.entries.map((entry) {
          final String emoji = entry.key;
          final List userIds = entry.value;
          final bool iReacted = userIds.contains(_currentUserId);
          if (userIds.isEmpty) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () {
              _announceService.toggleReaction(
                  widget.channel.id, message.id, emoji);
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: iReacted
                    ? const Color(0xFF6AA3FF).withOpacity(0.10)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: iReacted
                    ? Border.all(
                  color: const Color(0xFF6AA3FF).withOpacity(0.18),
                  width: 1.1,
                )
                    : null,
              ),
              child: Text('$emoji ${userIds.length}',
                  style: TextStyle(
                      fontSize: 12,
                      color: isMe
                          ? const Color(0xFF24509E)
                          : const Color(0xFF2F406D))),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ✅ --- MODIFIED: Added 'apk' case ---
  Widget _buildMessageContent(MessageModel message, Color textColor) {
    final bool amIMentioned = message.mentionedUserIds.contains(_currentUserId);

    if (message.fileUrl == null && message.messageType != 'text') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Text('Error: File not found',
            style: TextStyle(color: Colors.red.withOpacity(0.8))),
      );
    }
    switch (message.messageType) {
      case 'text':
        return _buildTextWithMentions(message.text ?? '', textColor, amIMentioned);
      case 'image':
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageGalleryPage(
                  imageUrls: [message.fileUrl!],
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                message.fileUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))));
                },
                errorBuilder: (context, error, stackTrace) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Icon(Icons.broken_image,
                        color: Colors.red.withOpacity(0.7), size: 40),
                  );
                },
              ),
            ),
          ),
        );
      case 'pdf':
        return GestureDetector(
          onTap: () =>
              _openPdf(message.fileUrl!, message.fileName ?? 'PDF'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _buildFileBubble(
                message.fileName ?? 'File.pdf',
                Icons.picture_as_pdf_rounded,
                Colors.red.shade700),
          ),
        );
      case 'video':
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    VideoPlayerPage(videoUrl: message.fileUrl!),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _buildFileBubble(
                message.fileName ?? 'Video.mp4',
                Icons.videocam_rounded,
                Colors.blue.shade700),
          ),
        );
    // ✅ --- START: NEW CASE ---
      case 'apk':
        return GestureDetector(
          onTap: () => _launchFile(message.fileUrl!),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _buildApkBubble(message), // Use new bubble
          ),
        );
    // ✅ --- END: NEW CASE ---
      default:
        return GestureDetector(
          onTap: () => _launchFile(message.fileUrl!),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _buildFileBubble(
                message.fileName ?? 'File',
                Icons.insert_drive_file_rounded,
                Colors.grey.shade700),
          ),
        );
    }
  }


  Widget _buildFileBubble(String fileName, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
              style: const TextStyle(
                color: Color(0xFF27416A),
                fontWeight: FontWeight.w500,
                fontSize: 13,
                fontFamily: "FiraCode",
                letterSpacing: 0.24,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ --- START: NEW WIDGET ---
  /// Builds the special blue bubble for APK files
  Widget _buildApkBubble(MessageModel message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blue circle icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF3380FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.android, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          // File name and size
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File name
                Text(
                  message.fileName ?? 'application.apk',
                  style: const TextStyle(
                    color: Color(0xFF174485),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: "Inter",
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                // File size
                if (message.fileSize != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      _formatBytes(message.fileSize!),
                      style: const TextStyle(
                        color: Color(0xFF27416A),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        fontFamily: "FiraCode",
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ✅ --- END: NEW WIDGET ---

  Widget _buildTextWithMentions(String text, Color defaultColor, bool amIMentioned) {
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final List<TextSpan> textSpans = [];

    final TextStyle defaultStyle = TextStyle(
      color: defaultColor,
      fontSize: 15,
      fontFamily: "Inter",
      fontWeight: FontWeight.w500,
      letterSpacing: 0.02,
      height: 1.33,
    );

    final TextStyle mentionStyle = defaultStyle.copyWith(
      color: Colors.blue.shade700,
      fontWeight: FontWeight.bold,
    );

    final TextStyle selfMentionStyle = mentionStyle.copyWith(
      backgroundColor: Colors.blue.withOpacity(0.15),
    );

    int lastMatchEnd = 0;
    for (final Match match in mentionRegex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        textSpans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: defaultStyle,
          ),
        );
      }
      final String mentionText = match.group(0)!;
      textSpans.add(
        TextSpan(
          text: mentionText,
          style: amIMentioned ? selfMentionStyle : mentionStyle,
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      textSpans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: defaultStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: textSpans),
    );
  }
}