import 'dart:typed_data';

import 'package:bluebubbles/app/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart' as path;
import 'package:universal_io/io.dart';

class AttachmentListItem extends StatefulWidget {
  AttachmentListItem({
    Key? key,
    required this.file,
    required this.onRemove,
  }) : super(key: key);
  final PlatformFile file;
  final Function() onRemove;

  @override
  State<AttachmentListItem> createState() => _AttachmentListItemState();
}

class _AttachmentListItemState extends State<AttachmentListItem> {
  Uint8List? preview;
  String mimeType = "Unknown File Type";

  @override
  void initState() {
    super.initState();
    loadPreview();
  }

  Future<void> loadPreview() async {
    mimeType = mime(widget.file.name) ?? "Unknown File Type";
    if (mimeType.startsWith("video/") && widget.file.path != null) {
      try {
        preview = await as.getVideoThumbnail(widget.file.path!);
      } catch (ex) {
        preview = fs.noVideoPreviewIcon;
      }

      if (mounted) setState(() {});
    } else if (mimeType.startsWith("image/")) {
      // Compress the file, using a dummy attachment object
      if (mimeType == "image/heic"
          || mimeType == "image/heif"
          || mimeType == "image/tif"
          || mimeType == "image/tiff") {
        Attachment fakeAttachment = Attachment(
            transferName: widget.file.path,
            mimeType: mimeType,
            bytes: widget.file.bytes
        );
        preview = await as.loadAndGetProperties(fakeAttachment, actualPath: widget.file.path!, onlyFetchData: true);
      } else {
        preview = widget.file.bytes ?? await File(widget.file.path!).readAsBytes();
      }

      if (mounted) setState(() {});
    }
  }

  Widget getThumbnail() {
    if (preview != null) {
      final bool hideAttachments =
          ss.settings.redactedMode.value && ss.settings.hideAttachments.value;
      final bool hideAttachmentTypes =
          ss.settings.redactedMode.value && ss.settings.hideAttachmentTypes.value;

      final mimeType = mime(widget.file.name);

      return Stack(children: <Widget>[
        InkWell(
          child: Image.memory(
            preview!,
            height: 100,
            width: 100,
            fit: BoxFit.cover,
          ),
          onTap: () async {
            if (mimeType == null) return;
            if (!mounted) return;

            Attachment fakeAttachment =
                Attachment(transferName: widget.file.name, mimeType: mimeType, bytes: widget.file.bytes);
            await Navigator.of(Get.context!).push(
              MaterialPageRoute(
                builder: (context) => AttachmentFullscreenViewer(
                  attachment: fakeAttachment,
                  showInteractions: false,
                ),
              ),
            );
          },
        ),
        if (hideAttachments)
          Positioned.fill(
            child: Container(
              color: context.theme.colorScheme.properSurface,
            ),
          ),
        if (hideAttachments && !hideAttachmentTypes)
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                mimeType!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ]);
    } else {
      if (mimeType.startsWith("video/") || mimeType.startsWith("image/")) {
        // If the preview is null and the mimetype is video or image,
        // then that means that we are in the process of loading things
        return Container(
          height: 100,
          child: Center(
            child: buildProgressIndicator(context),
          ),
        );
      } else {
        String name = path.basename(widget.file.name);
        if (mimeType == "text/x-vcard") {
          name = "Contact: ${name.split(".")[0]}";
        }

        return Container(
          height: 100,
          width: 100,
          color: context.theme.colorScheme.properSurface,
          padding: EdgeInsets.only(top: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                getAttachmentIcon(mimeType),
                color: context.theme.colorScheme.properOnSurface,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Text(
                    name,
                    style: context.theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 5.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: <Widget>[
            getThumbnail(),
            if (mimeType.startsWith("video/"))
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  ss.settings.skin.value == Skins.iOS ? CupertinoIcons.play : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
            GestureDetector(
              onTap: widget.onRemove,
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    color: context.theme.colorScheme.properSurface.withOpacity(0.7),
                  ),
                  width: 25,
                  height: 25,
                  child: Icon(
                    ss.settings.skin.value == Skins.iOS ? CupertinoIcons.xmark : Icons.close,
                    color: context.theme.colorScheme.onBackground,
                    size: 15,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
