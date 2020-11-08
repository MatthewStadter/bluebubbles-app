import 'dart:ui';

import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/layouts/widgets/send_widget.dart';

class MessageView extends StatefulWidget {
  final MessageBloc messageBloc;
  final bool showHandle;
  final Chat chat;

  MessageView({
    Key key,
    this.messageBloc,
    this.showHandle,
    this.chat,
  }) : super(key: key);

  @override
  MessageViewState createState() => MessageViewState();
}

class MessageViewState extends State<MessageView>
    with TickerProviderStateMixin {
  Future<LoadMessageResult> loader;
  bool reachedTopOfChat = false;
  List<Message> _messages = <Message>[];
  GlobalKey<SliverAnimatedListState> _listKey;
  final Duration animationDuration = Duration(milliseconds: 400);
  bool initializedList = false;
  double timeStampOffset = 0;
  ScrollController scrollController = new ScrollController();
  bool showScrollDown = false;
  int scrollState = -1; // -1: stopped, 0: start, 1: update

  /// [CurrentChat] holds all info about the conversation that widgets commonly access
  CurrentChat currentChat;

  @override
  void initState() {
    super.initState();
    widget.messageBloc.stream.listen(handleNewMessage);
    currentChat = CurrentChat.getCurrentChat(widget.messageBloc.currentChat);

    currentChat.init();
    currentChat.updateChatAttachments().then((value) {
      if (this.mounted) setState(() {});
    });
    currentChat.stream.listen((event) {
      if (this.mounted) setState(() {});
    });

    scrollController.addListener(() {
      if (scrollController.hasClients &&
          scrollController.offset >= 500 &&
          !showScrollDown) {
        if (this.mounted)
          setState(() {
            showScrollDown = true;
          });
      } else if (scrollController.hasClients &&
          scrollController.offset < 500 &&
          showScrollDown) {
        if (this.mounted)
          setState(() {
            showScrollDown = false;
          });
      }
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (_messages.length == 0) {
      widget.messageBloc.getMessages();
      if (this.mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    currentChat.dispose();
    super.dispose();
  }

  void handleNewMessage(MessageBlocEvent event) async {
    if (event.type == MessageBlocEventType.insert) {
      currentChat.getAttachmentsForMessage(event.message);
      if (event.outGoing) {
        currentChat.sentMessages.add(event.message.guid);
        Future.delayed(Duration(milliseconds: 500), () {
          currentChat.sentMessages
              .removeWhere((element) => element == event.message.guid);
          _listKey.currentState.setState(() {});
        });
        Navigator.of(context).push(
          SendPageBuilder(
            builder: (context) {
              return SendWidget(
                text: event.message.text,
                tag: "first",
                currentChat: currentChat,
              );
            },
          ),
        );
      }

      bool isNewMessage = true;
      for (Message message in _messages) {
        if (message.guid == event.message.guid) {
          isNewMessage = false;
          break;
        }
      }
      _messages = event.messages;
      if (_listKey != null && _listKey.currentState != null) {
        _listKey.currentState.insertItem(
          event.index != null ? event.index : 0,
          duration: isNewMessage
              ? event.outGoing ? Duration(milliseconds: 500) : animationDuration
              : Duration(milliseconds: 0),
        );
      }
      if (event.message.hasAttachments) {
        await currentChat.updateChatAttachments();
        if (this.mounted) setState(() {});
      }
    } else if (event.type == MessageBlocEventType.update) {
      // if (currentChat.imageAttachments.containsKey(event.oldGuid)) {
      //   Message messageWithROWID =
      //       await Message.findOne({"guid": event.message.guid});
      //   List<Attachment> updatedAttachments =
      //       await Message.getAttachments(messageWithROWID);

      //   currentChat.imageAttachments[event.message.guid] = data;
      // }
      bool updatedAMessage = false;
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].guid == event.oldGuid) {
          debugPrint(
              "(Message status) Update message: [${event.message.text}] - [${event.message.guid}] - [${event.oldGuid}]");
          _messages[i] = event.message;
          if (this.mounted) setState(() {});
          updatedAMessage = true;
          break;
        }
      }
      if (!updatedAMessage) {
        debugPrint(
            "(Message status) FAILED TO UPDATE A MESSAGE: [${event.message.text}] - [${event.message.guid}] - [${event.oldGuid}]");
      }
    } else if (event.type == MessageBlocEventType.remove) {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].guid == event.remove) {
          _messages.removeAt(i);
          _listKey.currentState
              .removeItem(i, (context, animation) => Container());
        }
      }
    } else {
      int originalMessageLength = _messages.length;
      _messages = event.messages;
      _messages
          .forEach((message) => currentChat.getAttachmentsForMessage(message));
      if (_listKey == null) _listKey = GlobalKey<SliverAnimatedListState>();

      if (originalMessageLength < _messages.length) {
        for (int i = originalMessageLength; i < _messages.length; i++) {
          if (_listKey != null && _listKey.currentState != null)
            _listKey.currentState
                .insertItem(i, duration: Duration(milliseconds: 0));
        }
      } else if (originalMessageLength > _messages.length) {
        for (int i = originalMessageLength; i >= _messages.length; i--) {
          if (_listKey != null && _listKey.currentState != null) {
            try {
              _listKey.currentState.removeItem(
                  i, (context, animation) => Container(),
                  duration: Duration(milliseconds: 0));
            } catch (ex) {
              debugPrint("Error removing item animation");
              debugPrint(ex.toString());
            }
          }
        }
      }
      if (_listKey != null && _listKey.currentState != null)
        _listKey.currentState.setState(() {});
      if (this.mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    currentChat.disposeControllers();

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragStart: (details) {},
      onHorizontalDragUpdate: (details) {
        if (!this.mounted) return;

        setState(() {
          timeStampOffset += details.delta.dx * 0.3;
        });
      },
      onHorizontalDragEnd: (details) {
        if (!this.mounted) return;

        setState(() {
          timeStampOffset = 0;
        });
      },
      onHorizontalDragCancel: () {
        if (!this.mounted) return;

        setState(() {
          timeStampOffset = 0;
        });
      },
      child: Stack(alignment: AlignmentDirectional.bottomCenter, children: [
        NotificationListener(
          onNotification: (scrollNotification) {
            if (scrollNotification is ScrollStartNotification &&
                scrollState != 0) {
              scrollState = 0;
            } else if (scrollNotification is ScrollUpdateNotification &&
                scrollState != 1) {
              scrollState = 1;
            } else if (scrollNotification is ScrollEndNotification &&
                scrollState != -1) {
              scrollState = -1;
              setState(() {});
            }

            return true;
          },
          child: CustomScrollView(
            controller: scrollController,
            reverse: true,
            physics: AlwaysScrollableScrollPhysics(
                parent: CustomBouncingScrollPhysics()),
            slivers: <Widget>[
              _listKey != null
                  ? SliverAnimatedList(
                      initialItemCount: _messages.length + 1,
                      key: _listKey,
                      itemBuilder: (BuildContext context, int index,
                          Animation<double> animation) {
                        if (index == _messages.length) {
                          if (loader == null && !reachedTopOfChat) {
                            loader = widget.messageBloc.loadMessageChunk(
                                _messages.length,
                                currentChat: currentChat);
                            loader.then((val) {
                              if (val == LoadMessageResult.FAILED_TO_RETREIVE) {
                                loader = widget.messageBloc.loadMessageChunk(
                                    _messages.length,
                                    currentChat: currentChat);
                              } else if (val ==
                                  LoadMessageResult.RETREIVED_NO_MESSAGES) {
                                reachedTopOfChat = true;
                                loader = null;
                              } else {
                                loader = null;
                              }
                              if (this.mounted) setState(() {});
                            });
                          }

                          return NewMessageLoader();
                        } else if (index > _messages.length) {
                          return Container();
                        }

                        Message olderMessage;
                        Message newerMessage;
                        if (index + 1 >= 0 && index + 1 < _messages.length) {
                          olderMessage = _messages[index + 1];
                        }
                        if (index - 1 >= 0 && index - 1 < _messages.length) {
                          newerMessage = _messages[index - 1];
                        }

                        return SizeTransition(
                          axis: Axis.vertical,
                          sizeFactor: animation.drive(
                              Tween(begin: 0.0, end: 1.0)
                                  .chain(CurveTween(curve: Curves.easeInOut))),
                          child: SlideTransition(
                            position: animation.drive(
                              Tween(
                                begin: Offset(0.0, 1),
                                end: Offset(0.0, 0.0),
                              ).chain(
                                CurveTween(
                                  curve: Curves.easeInOut,
                                ),
                              ),
                            ),
                            child: FadeTransition(
                              opacity: animation,
                              child: Padding(
                                padding: EdgeInsets.only(left: 5.0, right: 5.0),
                                child: MessageWidget(
                                  key: Key(_messages[index].guid),
                                  offset: timeStampOffset,
                                  message: _messages[index],
                                  chat: widget.messageBloc.currentChat,
                                  olderMessage: olderMessage,
                                  newerMessage: newerMessage,
                                  showHandle: widget.showHandle,
                                  // shouldFadeIn:
                                  //     sentMessages.contains(_messages[index].guid),
                                  isFirstSentMessage:
                                      widget.messageBloc.firstSentMessage ==
                                          _messages[index].guid,
                                  // savedAttachmentData:
                                  //     attachments.containsKey(_messages[index].guid)
                                  //         ? attachments[_messages[index].guid]
                                  //         : null,
                                  showHero: index == 0 &&
                                      _messages[index].originalROWID == null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : SliverToBoxAdapter(child: Container()),
              SliverPadding(
                padding: EdgeInsets.all(70),
              ),
            ],
          ),
        ),
        (showScrollDown && scrollState == -1)
            ? ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    height: 35,
                    width: 150,
                    decoration: BoxDecoration(
                        color: Theme.of(context).accentColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10.0)),
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          scrollController.animateTo(
                            0.0,
                            curve: Curves.easeOut,
                            duration: const Duration(milliseconds: 300),
                          );
                        },
                        child: Text(
                          "\u{2193} Scroll to bottom \u{2193}",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Container()
      ]),
    );
  }
}
