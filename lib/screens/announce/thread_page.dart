// lib/screens/announce/thread_page.dart

import 'dart:io';
import 'package:boitex_info_app/models/message_model.dart';
import 'package:boitex_info_app/services/announce_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Viewer page imports
import 'package:boitex_info_app/widgets/pdf_viewer_page.dart';
import 'package:boitex_info_app/widgets/video_player_page.dart';
import 'package:boitex_info_app/widgets/image_gallery_page.dart';

// Imports for reactions
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show Uint8List;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Platform;

class ThreadPage extends StatefulWidget {
  final String channelId;
  final MessageModel parentMessage; // Pass the whole parent message

  const ThreadPage({
    super.key,
    required this.channelId,
    required this.parentMessage,
  });

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final AnnounceService _announceService = AnnounceService();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isUploading = false;

  // --- Sending Replies ---
  void _sendReplyMessage() {
    if (_replyController.text.trim().isNotEmpty) {
      // Call sendTextMessage WITH the threadParentId
      _announceService.sendTextMessage(
        widget.channelId,
        _replyController.text.trim(),
        threadParentId: widget.parentMessage.id, // Set the parent ID!
      );
      _replyController.clear();
      // Don't need autoscroll on send here, happens via WidgetsBinding
    }
  }

  void _pickAndSendReplyFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'pdf', 'mp4', 'mov', 'avi', 'mkv',
          'doc', 'docx', 'xls', 'xlsx', 'zip', 'rar'
        ],
      );
      if (result != null && result.files.single.path != null) {
        setState(() { _isUploading = true; });
        final PlatformFile file = result.files.first;
        // Call sendFileMessage WITH the threadParentId
        await _announceService.sendFileMessage(
            widget.channelId,
            file,
            threadParentId: widget.parentMessage.id // Set the parent ID!
        );
        // Don't need autoscroll on send here
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    } finally {
      setState(() { _isUploading = false; });
    }
  }

  // --- Navigation & Helpers ---
  void _scrollToBottom() {
    // Scroll reply list to bottom (use jumpTo for instant scroll)
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<void> _launchFile(String url) async {
    // Uses url_launcher to open non-standard file types
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $url')),
      );
    }
  }

  Future<void> _openPdf(String url, String title) async {
    // Downloads PDF bytes and navigates to the PdfViewerPage
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        Navigator.pop(context); // Hide loading dialog
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
      Navigator.pop(context); // Hide loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening PDF: $e')),
      );
    }
  }

  void _showEmojiPicker(String messageId) {
    // Shows the emoji picker bottom sheet
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmojiPicker(
          onEmojiSelected: (Category? category, Emoji emoji) {
            _announceService.toggleReaction(
              widget.channelId, // Use channelId from widget
              messageId,
              emoji.emoji,
            );
            Navigator.pop(context); // Close the bottom sheet
          },
          config: Config(
            height: 256,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: 28 * (Platform.isIOS ? 1.20 : 1.0),
              columns: 8,
            ),
            swapCategoryAndBottomBar: false,
            skinToneConfig: const SkinToneConfig(),
            categoryViewConfig: const CategoryViewConfig(),
            bottomActionBarConfig: const BottomActionBarConfig(),
            searchViewConfig: const SearchViewConfig(),
          ),
        );
      },
    );
  }


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
      ),
      body: Column(
        children: [
          // --- Parent Message Display ---
          _buildParentMessageHeader(widget.parentMessage),
          const Divider(height: 1), // Separator

          // --- Replies List ---
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _announceService.getReplies(widget.channelId, widget.parentMessage.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No replies yet.", style: TextStyle(color: Colors.grey)));
                }
                final replies = snapshot.data!;

                // Scroll to bottom after the frame is built
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  // Replies are ordered oldest first, so NO reverse: true
                  itemCount: replies.length,
                  itemBuilder: (context, index) {
                    final reply = replies[index];
                    final isMe = reply.senderId == _currentUserId;
                    // Use the unified bubble builder
                    return _buildMessageBubble(reply, isMe, isReply: true);
                  },
                );
              },
            ),
          ),

          // Upload Indicator
          if (_isUploading) const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),

          // --- Reply Input Bar ---
          _buildReplyInput(),
        ],
      ),
    );
  }

  // --- Parent Message Header ---
  Widget _buildParentMessageHeader(MessageModel message) {
    // Renders the original message at the top of the thread
    return Container(
      color: Theme.of(context).canvasColor.withOpacity(0.5), // Subtle background differentiation
      padding: const EdgeInsets.all(8.0),
      child: _buildMessageBubble(message, message.senderId == _currentUserId, isParent: true),
    );
  }


  // --- Reply Input Bar ---
  Widget _buildReplyInput() {
    // Input bar specifically for sending replies in the thread
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow( color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0,-2))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: Theme.of(context).primaryColor),
            onPressed: _isUploading ? null : _pickAndSendReplyFile, // Call reply file picker
          ),
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: InputDecoration(
                hintText: 'Reply in thread...', // Different hint text
                border: InputBorder.none,
                filled: true,
                // Use theme color or default grey
                fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).colorScheme.surfaceVariant,
              ),
              onSubmitted: (_) => _sendReplyMessage(), // Call reply send function
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            onPressed: _isUploading ? null : _sendReplyMessage, // Call reply send function
          ),
        ],
      ),
    );
  }


  // --- Unified Message Bubble Builder ---
  Widget _buildMessageBubble(MessageModel message, bool isMe, {bool isReply = false, bool isParent = false}) {
    // Central function to build any message bubble (parent or reply)
    final bubbleColor = isMe
        ? Theme.of(context).primaryColor.withOpacity(0.8)
        : Theme.of(context).colorScheme.secondary.withOpacity(0.1);
    final textColor = isMe ? Colors.white : Colors.black87;
    // Only show reply count on the parent message *when viewed in the main channel list*
    final bool showReplyIndicator = !isReply && !isParent && message.replyCount > 0;
    // Define borderRadius here
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
    );

    return GestureDetector(
      onLongPress: () { if (!isParent) _showEmojiPicker(message.id); }, // Allow reactions on replies too, but not parent header
      child: Container(
        // Add subtle horizontal margin change for replies (visual indentation)
        margin: EdgeInsets.symmetric(
            vertical: 4,
            horizontal: isReply && !isParent ? (isMe ? 12 : 20) : 8 // Indent replies slightly more
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Bubble container
            Container(
              padding: EdgeInsets.zero, // Padding handled inside ClipRRect
              decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: borderRadius // Use defined borderRadius
              ),
              // Adjust max width slightly for replies if indented
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isParent ? 0.9 : (isReply ? 0.65 : 0.7))),
              child: ClipRRect(
                borderRadius: borderRadius, // Use defined borderRadius
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Sender Name (adjust padding/visibility based on context)
                    if (message.messageType != 'image' && !isMe)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    if (message.messageType != 'image' && !isMe) const SizedBox(height: 4),

                    // Content
                    _buildMessageContent(message, textColor),

                    // Reactions (Show on parent and replies)
                    _buildReactionsDisplay(message, isMe),

                    // Reply Count Indicator (Only shown in main channel view)
                    if (showReplyIndicator)
                      _buildReplyIndicator(message, isMe), // This is only called from ChannelChatPage now

                    // Timestamp
                    Padding(
                      padding: (message.messageType == 'image' && !showReplyIndicator && message.reactions.isEmpty)
                          ? const EdgeInsets.fromLTRB(12, 4, 12, 8)
                          : const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Text(
                        DateFormat('HH:mm').format(message.timestamp.toDate()),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Reply Indicator ---
  Widget _buildReplyIndicator(MessageModel message, bool isMe){
    // Builds the "💬 X Replies" text, clickable to open the thread
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: InkWell( // Make it tappable
        onTap: () {
          // In ThreadPage, this ideally shouldn't be called, but safe fallback
          // In ChannelChatPage, it correctly navigates
          // _navigateToThread(message); // This function doesn't exist here, logic moved
        },
        child: Text(
          '💬 ${message.replyCount} ${message.replyCount == 1 ? "Reply" : "Replies"}',
          style: TextStyle(
            fontSize: 11,
            color: isMe ? Colors.white70 : Colors.blue.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // --- Reactions Display ---
  Widget _buildReactionsDisplay(MessageModel message, bool isMe) {
    // Builds the row of emoji reaction chips
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink(); // Use SizedBox.shrink for zero size
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0), // Spacing below content
      child: Wrap( // Use Wrap for multi-line reactions if needed
        spacing: 4, // Horizontal space between chips
        runSpacing: 4, // Vertical space if wraps
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start, // Align based on sender
        children: message.reactions.entries.map((entry) {
          final String emoji = entry.key;
          final List<String> userIds = entry.value;
          final bool iReacted = userIds.contains(_currentUserId);

          if (userIds.isEmpty) return const SizedBox.shrink(); // Skip empty lists

          return GestureDetector( // Allow tapping chip to toggle reaction
            onTap: () {
              _announceService.toggleReaction(
                widget.channelId, // Use channelId from widget
                message.id,
                emoji,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: iReacted // Highlight if current user reacted
                    ? Theme.of(context).primaryColor.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: iReacted // Add border if current user reacted
                    ? Border.all(color: Theme.of(context).primaryColor, width: 1)
                    : null,
              ),
              child: Text(
                '$emoji ${userIds.length}', // Display emoji and count
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Message Content Builder ---
  Widget _buildMessageContent(MessageModel message, Color textColor) {
    // Determines the type of content and builds the appropriate widget
    if (message.fileUrl == null && message.messageType != 'text') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Add padding here
        child: Text('Error: File not found', style: TextStyle(color: Colors.red.withOpacity(0.8))),
      );
    }
    switch (message.messageType) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Add padding here
          child: Text(
            message.text ?? '',
            style: TextStyle(color: textColor),
          ),
        );
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
          child: Image.network(
            message.fileUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              // Consistent loading indicator size
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ));
            },
            errorBuilder: (context, error, stackTrace) {
              return Padding( // Add padding around error icon
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Icon(Icons.broken_image, color: Colors.red.withOpacity(0.7)),
              );
            },
          ),
        );
      case 'pdf':
        return GestureDetector(
          onTap: () { _openPdf(message.fileUrl!, message.fileName ?? 'PDF'); },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), // Add vertical padding
            child: _buildFileBubble(message.fileName ?? 'File.pdf', Icons.picture_as_pdf, Colors.red),
          ),
        );
      case 'video':
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerPage(videoUrl: message.fileUrl!),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), // Add vertical padding
            child: _buildFileBubble(message.fileName ?? 'Video.mp4', Icons.videocam, Colors.blue),
          ),
        );
      default: // 'file' or other unknown types
        return GestureDetector(
          onTap: () { _launchFile(message.fileUrl!); },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), // Add vertical padding
            child: _buildFileBubble(message.fileName ?? 'File', Icons.insert_drive_file, Colors.grey),
          ),
        );
    }
  }

  // --- File Bubble Builder ---
  Widget _buildFileBubble(String fileName, IconData icon, Color iconColor) {
    // Builds the visual representation for non-image files
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Adjusted padding
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05), // More subtle background
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Don't take full width
        children: [
          Icon(icon, color: iconColor, size: 20), // Standard icon size
          const SizedBox(width: 8),
          Flexible( // Allow text to wrap/ellipsis if too long
            child: Text(
              fileName,
              style: TextStyle(
                color: Colors.grey.shade800, // Darker grey text
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis, // Add ellipsis for long names
              maxLines: 1, // Ensure single line
            ),
          ),
        ],
      ),
    );
  }

} // End of _ThreadPageState