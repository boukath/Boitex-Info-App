// lib/screens/announce/channel_chat_page.dart

import 'dart:io';
import 'package:boitex_info_app/models/channel_model.dart';
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

// New imports
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show Uint8List;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
// Import foundation for Platform check
import 'package:flutter/foundation.dart' show kIsWeb;

class ChannelChatPage extends StatefulWidget {
  final ChannelModel channel;
  const ChannelChatPage({super.key, required this.channel});

  @override
  State<ChannelChatPage> createState() => _ChannelChatPageState();
}

class _ChannelChatPageState extends State<ChannelChatPage> {
  final AnnounceService _announceService = AnnounceService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isUploading = false;

  void _sendTextMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      _announceService.sendTextMessage(
        widget.channel.id,
        _messageController.text.trim(),
      );
      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif',
          'pdf',
          'mp4', 'mov', 'avi', 'mkv',
          'doc', 'docx', 'xls', 'xlsx', 'zip', 'rar'
        ],
      );

      if (result != null && result.files.single.path != null) {
        setState(() { _isUploading = true; });
        final PlatformFile file = result.files.first;
        await _announceService.sendFileMessage(widget.channel.id, file);
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
    } finally {
      setState(() { _isUploading = false; });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _launchFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $url')),
      );
    }
  }

  Future<void> _openPdf(String url, String title) async {
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
            Navigator.pop(context); // Close the bottom sheet
          },
          // *** THIS IS THE CORRECTED CONFIG ***
          config: Config(
            height: 256,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              // Issue: https://github.com/flutter/flutter/issues/28894
              emojiSizeMax: 28 * (Platform.isIOS ? 1.20 : 1.0),
              columns: 8, // Moved inside EmojiViewConfig
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _announceService.getMessages(widget.channel.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Be the first to say something!'),
                  );
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: Theme.of(context).primaryColor),
            onPressed: _isUploading ? null : _pickAndUploadFile,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                filled: true,
              ),
              onSubmitted: (_) => _sendTextMessage(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
            onPressed: _isUploading ? null : _sendTextMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final bubbleColor = isMe
        ? Theme.of(context).primaryColor.withOpacity(0.8)
        : Theme.of(context).colorScheme.secondary.withOpacity(0.1);
    final textColor = isMe ? Colors.white : Colors.black87;

    return GestureDetector(
      onLongPress: () {
        _showEmojiPicker(message.id);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment:
          isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isMe
                      ? const Radius.circular(12)
                      : const Radius.circular(0),
                  bottomRight: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(12),
                ),
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isMe
                      ? const Radius.circular(12)
                      : const Radius.circular(0),
                  bottomRight: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (message.messageType != 'image')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                message.senderName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            if (!isMe) const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    _buildMessageContent(message, textColor),
                    _buildReactionsDisplay(message, isMe),
                    Padding(
                      padding: message.messageType == 'image'
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

  Widget _buildReactionsDisplay(MessageModel message, bool isMe) {
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: message.reactions.entries.map((entry) {
          final String emoji = entry.key;
          final List<String> userIds = entry.value;
          final bool iReacted = userIds.contains(_currentUserId);

          if (userIds.isEmpty) return const SizedBox.shrink();

          return GestureDetector(
            onTap: () {
              _announceService.toggleReaction(
                widget.channel.id,
                message.id,
                emoji,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: iReacted
                    ? Theme.of(context).primaryColor.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: iReacted
                    ? Border.all(color: Theme.of(context).primaryColor, width: 1)
                    : null,
              ),
              child: Text(
                '$emoji ${userIds.length}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, Color textColor) {
    if (message.fileUrl == null && message.messageType != 'text') {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('Error: File not found', style: TextStyle(color: Colors.red)),
      );
    }
    switch (message.messageType) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, color: Colors.red);
            },
          ),
        );
      case 'pdf':
        return GestureDetector(
          onTap: () {
            _openPdf(message.fileUrl!, message.fileName ?? 'PDF');
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: _buildFileBubble(
              message.fileName ?? 'File.pdf',
              Icons.picture_as_pdf,
              Colors.red,
            ),
          ),
        );
      case 'video':
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerPage(
                  videoUrl: message.fileUrl!,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: _buildFileBubble(
              message.fileName ?? 'Video.mp4',
              Icons.videocam,
              Colors.blue,
            ),
          ),
        );
      default:
        return GestureDetector(
          onTap: () {
            _launchFile(message.fileUrl!);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: _buildFileBubble(
              message.fileName ?? 'File',
              Icons.insert_drive_file,
              Colors.grey,
            ),
          ),
        );
    }
  }

  Widget _buildFileBubble(String fileName, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              fileName,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}