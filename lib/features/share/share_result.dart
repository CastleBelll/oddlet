import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Grabs the card behind [cardKey] as a PNG and hands it to the share sheet.
///
/// The card is a real part of the tree, drawn underneath the reveal and
/// completely covered by it. That keeps it laid out and painted, which is what
/// [RenderRepaintBoundary.toImage] needs, without asking the reveal to be
/// designed at two sizes at once.
Future<void> shareCapturedCard({
  required GlobalKey cardKey,
  required String creatureId,
}) async {
  try {
    final boundary =
        cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return;
    }

    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/oddlet_$creatureId.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  } catch (error, stack) {
    // A failed share must not take the reveal down with it, but it is worth
    // knowing about: this is the whole viral loop.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'oddlet',
        context: ErrorDescription('sharing $creatureId'),
      ),
    );
  }
}
