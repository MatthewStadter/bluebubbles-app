import 'dart:async';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/stickers_widget.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../../helpers/utils.dart';
import '../../../repository/models/message.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({
    Key key,
    this.message,
    this.chat,
    this.olderMessage,
    this.newerMessage,
    this.showHandle,
    this.customContent,
    this.shouldFadeIn,
    this.isFirstSentMessage,
    this.showHero,
    this.savedAttachmentData,
    this.offset,
    this.currentPlayingVideo,
    this.changeCurrentPlayingVideo,
    this.allAttachments,
  }) : super(key: key);

  final Message message;
  final Chat chat;
  final Message newerMessage;
  final Message olderMessage;
  final bool showHandle;
  final bool shouldFadeIn;
  final bool isFirstSentMessage;
  final bool showHero;
  final SavedAttachmentData savedAttachmentData;
  final double offset;
  final Map<String, VideoPlayerController> currentPlayingVideo;
  final Function(Map<String, VideoPlayerController>) changeCurrentPlayingVideo;
  final List<Attachment> allAttachments;

  final List<Widget> customContent;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> {
  List<Attachment> attachments = <Attachment>[];
  List<Message> associatedMessages = [];
  bool showTail = true;
  Widget blurredImage;
  OverlayEntry _entry;
  Completer<void> associatedMessageRequest;

  @override
  void initState() {
    super.initState();
    fetchAssociatedMessages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchAssociatedMessages();
  }

  Future<void> fetchAssociatedMessages() async {
    // If there is already a request being made, return that request
    if (associatedMessageRequest != null &&
        !associatedMessageRequest.isCompleted) {
      return associatedMessageRequest.future;
    }

    // Create a new request and get the messages
    associatedMessageRequest = new Completer();
    List<Message> messages = await widget.message.getAssociatedMessages();

    // bool hasChanges = false;
    if (messages.length != associatedMessages.length) {
      associatedMessages = messages;
      // hasChanges = true;
    }

    // NOTE: Not sure if we need to re-render
    // if (this.mounted && hasChanges) {
    //   setState(() {});
    // }

    associatedMessageRequest.complete();
  }

  bool withinTimeThreshold(Message first, Message second, {threshold: 5}) {
    if (first == null || second == null) return false;
    return second.dateCreated.difference(first.dateCreated).inMinutes.abs() >
        threshold;
  }

  Map<String, String> _buildTimeStamp(BuildContext context) {
    if (widget.newerMessage != null &&
        (!isEmptyString(widget.message.text) ||
            widget.message.hasAttachments) &&
        withinTimeThreshold(widget.message, widget.newerMessage,
            threshold: 30)) {
      DateTime timeOfnewerMessage = widget.newerMessage.dateCreated;
      String time = new DateFormat.jm().format(timeOfnewerMessage);
      String date;
      if (widget.newerMessage.dateCreated.isToday()) {
        date = "Today";
      } else if (widget.newerMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${timeOfnewerMessage.month.toString()}/${timeOfnewerMessage.day.toString()}/${timeOfnewerMessage.year.toString()}";
      }
      return {"date": date, "time": time};
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.newerMessage != null) {
      showTail = withinTimeThreshold(widget.message, widget.newerMessage,
              threshold: 1) ||
          !sameSender(widget.message, widget.newerMessage) ||
          (widget.message.isFromMe &&
              widget.newerMessage.isFromMe &&
              widget.message.dateDelivered != null &&
              widget.newerMessage.dateDelivered == null);
    }

    if (widget.message != null &&
        isEmptyString(widget.message.text) &&
        !widget.message.hasAttachments) {
      return GroupEvent(message: widget.message);
    }

    ////////// READ //////////
    /// This widget and code below will handle building out the following:
    /// -> Attachments
    /// -> Reactions
    /// -> Stickers
    /// -> URL Previews
    /// -> Big Emojis??
    ////////// READ //////////

    // Build the attachments widget
    Widget widgetAttachments = widget.savedAttachmentData != null
        ? MessageAttachments(
            message: widget.message,
            savedAttachmentData: widget.savedAttachmentData,
            showTail: showTail,
            showHandle: widget.showHandle,
            controllers: widget.currentPlayingVideo,
            changeCurrentPlayingVideo: widget.changeCurrentPlayingVideo,
            allAttachments: widget.allAttachments,
          )
        : Container();

    // Build any reactions and insert them into the message stack
    ReactionsWidget reactions = ReactionsWidget(
        message: widget.message, associatedMessages: associatedMessages);
    List<Widget> msgStackChildren = [reactions];

    // TODO: URL Preview widget requires the following
    // No attachments because if there are none, it will reach out to the server
    // The main message (for metadata fetching)
    if (widget.message.hasDdResults) {
      msgStackChildren.insert(0, UrlPreviewWidget())
    }

    // Add the correct type of message to the message stack
    if (widget.message.isFromMe && !widget.message.hasDdResults) {
      msgStackChildren.insert(
          0,
          SentMessage(
            offset: widget.offset,
            timeStamp: _buildTimeStamp(context),
            message: widget.message,
            chat: widget.chat,
            savedAttachmentData: widget.savedAttachmentData,
            showDeliveredReceipt:
                widget.customContent == null && widget.isFirstSentMessage,
            showTail: showTail,
            limited: widget.customContent == null,
            shouldFadeIn: widget.shouldFadeIn,
            customContent: widget.customContent,
            isFromMe: widget.message.isFromMe,
            attachments: widgetAttachments,
            showHero: widget.showHero,
          ));
    } else if (!widget.message.hasDdResults) {
      msgStackChildren.insert(
          0,
          ReceivedMessage(
            offset: widget.offset,
            timeStamp: _buildTimeStamp(context),
            savedAttachmentData: widget.savedAttachmentData,
            showTail: showTail,
            olderMessage: widget.olderMessage,
            message: widget.message,
            showHandle: widget.showHandle,
            customContent: widget.customContent,
            isFromMe: widget.message.isFromMe,
            attachments: widgetAttachments,
          ));
    }

    return WillPopScope(
        onWillPop: () async {
          if (_entry != null) {
            try {
              _entry.remove();
            } catch (e) {}
            _entry = null;
            return true;
          } else {
            return true;
          }
        },
        child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: () async {
              Feedback.forLongPress(context);
              Overlay.of(context).insert(_createMessageDetailsPopup());
            },
            child: Stack(
                alignment: widget.message.isFromMe
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                children: [
                  Stack(
                      alignment: (widget.message.isFromMe)
                          ? Alignment.topRight
                          : Alignment.topLeft,
                      children: msgStackChildren),
                  StickersWidget(messages: this.associatedMessages)
                ])));
  }

  OverlayEntry _createMessageDetailsPopup() {
    _entry = OverlayEntry(
      builder: (context) => MessageDetailsPopup(
        entry: _entry,
        message: widget.message,
      ),
    );
    return _entry;
  }
}
