import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void sendEffectAction(
  BuildContext context,
  TickerProvider _,
  String __,
  String ___,
  String? ____,
  int? _____,
  String? ______,
  Future<void> Function({String? effect}) sendMessage,
  List<Mentionable> _______,
) {
  if (!ss.settings.enablePrivateAPI.value) return;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Message effects unavailable'),
      content: const Text(
        'This build does not include message effect rendering. '
        'You can still send your message without an effect.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await sendMessage();
          },
          child: Text(
            'Send',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}
