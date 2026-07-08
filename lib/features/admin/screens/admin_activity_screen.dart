import 'package:flutter/material.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});
  @override State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}
class _AdminActivityScreenState extends State<AdminActivityScreen> {
  late Future<Map<String,dynamic>> data = load();
  Future<Map<String,dynamic>> load() async => Map<String,dynamic>.from(await supabase.rpc('admin_marketplace_activity'));
  @override Widget build(BuildContext context) => FutureBuilder<Map<String,dynamic>>(
    future:data,builder:(context,s){
      if(s.hasError)return Center(child:Text('${s.error}'));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final d=s.data!, top=List<Map<String,dynamic>>.from(d['top_products']??[]), none=List<Map<String,dynamic>>.from(d['no_sales']??[]), recent=List<Map<String,dynamic>>.from(d['recent_orders']??[]);
      return RefreshIndicator(onRefresh:() async{setState(()=>data=load());await data;},child:ListView(padding:const EdgeInsets.all(AppSpacing.md),children:[
        Wrap(spacing:10,runSpacing:10,children:[metric('All orders','${d['total_orders']}',Icons.receipt_long),metric('Completed','${d['completed_orders']}',Icons.check_circle),metric('Cancelled','${d['cancelled_orders']}',Icons.cancel),metric('Active','${d['active_orders']}',Icons.timelapse),metric('Gross sales',Formatters.money(d['gross_sales']??0),Icons.payments),metric('Chat messages','${d['messages']}',Icons.chat)]),
        title('Most-bought items'),if(top.isEmpty)const Text('No completed sales yet.'),...top.map((x)=>ListTile(leading:const Icon(Icons.trending_up),title:Text('${x['product_name']}'),subtitle:Text('${x['quantity']} units'),trailing:Text(Formatters.money(x['revenue']??0)))),
        title('Products with no sales'),if(none.isEmpty)const Text('Every product has a completed sale.'),...none.map((x)=>ListTile(leading:const Icon(Icons.inventory_2_outlined),title:Text('${x['product_name']}'),subtitle:Text('${x['business_name']}'))),
        title('Recent order activity'),...recent.map((x)=>ListTile(leading:const Icon(Icons.receipt_outlined),title:Text('${x['business_name']} · ${Formatters.money(x['total_amount']??0)}'),subtitle:Text('${x['order_status']}'),trailing:Text('#${x['order_id'].toString().substring(0,8)}'))),
      ]));
    });
  Widget title(String v)=>Padding(padding:const EdgeInsets.only(top:24,bottom:8),child:Text(v,style:Theme.of(context).textTheme.titleLarge));
  Widget metric(String l,String v,IconData i)=>SizedBox(width:170,child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(i),const SizedBox(height:8),Text(v,style:Theme.of(context).textTheme.titleLarge),Text(l)]))));
}
