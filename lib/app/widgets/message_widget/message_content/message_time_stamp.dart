import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MessageTimeStamp extends StatelessWidget {
  const MessageTimeStamp({Key? key, required this.message, this.singleLine = false, this.useYesterday = false, this.shownByTap = false})
      : super(key: key);
  final Message message;
  final bool singleLine;
  final bool useYesterday;
  final bool shownByTap;

  @override
  Widget build(BuildContext context) {
    if (/*cm.activeChat == null*/ true) return Container();

    /*return StreamBuilder<double>(
        stream: cm.activeChat?.timeStampOffsetStream.stream,
        builder: (context, snapshot) {
          double offset = cm.activeChat?.timeStampOffset ?? 0;
          String text = buildTime(message.dateCreated).toLowerCase();
          if (!message.dateCreated!.isToday()) {
            String formatted = buildDate(message.dateCreated);
            text = "$formatted${singleLine ? " " : "\n"}$text";
          }

          return AnimatedContainer(
            duration: Duration(milliseconds: offset == 0 ? 150 : 0),
            width: (!shownByTap &&
                (ss.settings.skin.value == Skins.iOS ||
                    ss.settings.skin.value == Skins.Material))
                ? (-offset).clamp(0, 70).toDouble()
                : (singleLine)
                    ? 100
                    : 70,
            height: (!message.dateCreated!.isToday() && !singleLine) ? 30 : 15,
            child: Stack(
              alignment: message.isFromMe! ? Alignment.bottomRight : Alignment.bottomLeft,
              children: [
                AnimatedPositioned(
                  // width: ,
                  width: (singleLine) ? 100 : 70,
                  left: (offset).clamp(0, 70).toDouble(),
                  duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                  child: Text(
                    text,
                    textAlign: (message.isFromMe! && ss.settings.skin.value == Skins.Samsung)
                        ? TextAlign.right
                        : TextAlign.left,
                    style: context.theme.textTheme.labelSmall!.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.normal),
                    overflow: TextOverflow.visible,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          );
        });*/
  }
}
