// ignore_for_file: unused_field

import 'package:bluebubbles/database/models.dart';
import 'package:flutter/widgets.dart';

class BubbleEffects extends StatelessWidget {
  const BubbleEffects({
    super.key,
    required this.child,
    required Message message,
    required int part,
    required GlobalKey? globalKey,
    required bool showTail,
  })  : _message = message,
        _part = part,
        _globalKey = globalKey,
        _showTail = showTail;

  final Widget child;
  final Message _message;
  final int _part;
  final GlobalKey? _globalKey;
  final bool _showTail;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
