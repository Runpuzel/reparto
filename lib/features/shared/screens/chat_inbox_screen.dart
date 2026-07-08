import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';

class ChatInboxScreen extends StatelessWidget {
  const ChatInboxScreen({super.key});
  @override Widget build(BuildContext context) {
    final stream=supabase.from('order_messages').stream(primaryKey:['message_id']).order('created_at',ascending:false);
    return StreamBuilder<List<Map<String,dynamic>>>(stream:stream,builder:(context,s){
      if(s.hasError)return Center(child:Text('${s.error}'));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final latest=<String,Map<String,dynamic>>{};
      for(final m in s.data!) latest.putIfAbsent('${m['order_id']}',()=>m);
      if(latest.isEmpty)return const Center(child:Text('Your order conversations will appear here.'));
      return ListView(padding:const EdgeInsets.all(AppSpacing.sm),children:latest.values.map((m){
        final dt=DateTime.tryParse('${m['created_at']}')?.toLocal();
        return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.chat_bubble_outline)),title:Text('Order #${m['order_id'].toString().substring(0,8).toUpperCase()}'),subtitle:Text('${m['body']}',maxLines:1,overflow:TextOverflow.ellipsis),trailing:dt==null?null:Text(Formatters.dateTime(dt)),onTap:()=>context.push('/order/${m['order_id']}/chat')));
      }).toList());
    });
  }
}
