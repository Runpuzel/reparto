import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_actions.dart';

class OrderChatScreen extends StatefulWidget {
  const OrderChatScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() { _message.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await supabase.from('order_messages').insert({
        'order_id': widget.orderId,
        'sender_id': currentAuthUser!.id,
        'body': body,
      });
      _message.clear();
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentAuthUser?.id;
    final stream = supabase.from('order_messages').stream(primaryKey: ['message_id'])
        .eq('order_id', widget.orderId).order('created_at');
    return Scaffold(
      appBar: AppBar(title: const Text('Order chat')),
      body: Column(children: [
        MaterialBanner(
          content: const Text('Keep communication and payment inside the app. Contact details and links are blocked.'),
          actions: const [SizedBox.shrink()],
          leading: const Icon(Icons.shield_outlined),
        ),
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) _scroll.animateTo(
                _scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
            });
            if (rows.isEmpty) return const Center(child: Text('No messages yet. Start the order conversation.'));
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final row = rows[i]; final mine = row['sender_id'] == uid;
                final time = DateTime.tryParse('${row['created_at']}')?.toLocal();
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${row['body']}'),
                      if (time != null) Text(Formatters.dateTime(time), style: Theme.of(context).textTheme.labelSmall),
                    ]),
                  ),
                );
              },
            );
          },
        )),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(children: [
            Expanded(child: TextField(controller: _message, maxLength: 1000, minLines: 1, maxLines: 4,
              decoration: const InputDecoration(hintText: 'Message about this order…', counterText: ''))),
            IconButton(onPressed: _sending ? null : _send, icon: const Icon(Icons.send), tooltip: 'Send'),
          ]),
        )),
      ]),
    );
  }
}
