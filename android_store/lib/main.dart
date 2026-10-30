import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const url = 'https://ywhwqpijlevtoqvhodkf.supabase.co';
const publicKey = 'sb_publishable_x2MuIwfoQKZ6R33K1Tl4_Q_8HZJIUSY';
const pink = Color(0xFFB84F78);
const plum = Color(0xFF6F3455);
const ink = Color(0xFF28232A);
const canvas = Color(0xFFFFFAFC);
final db = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: url, anonKey: publicKey);
  runApp(const SecretApp());
}
class SecretApp extends StatelessWidget {
  const SecretApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Secret KFS', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: pink).copyWith(primary: pink, secondary: plum), scaffoldBackgroundColor: canvas, appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: ink, elevation: 0, surfaceTintColor: Colors.transparent, centerTitle: true), cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(22)), side: BorderSide(color: Color(0xFFF1E4EA)))), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: Color(0xFFF0E2E9))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: Color(0xFFF0E2E9))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: pink, width: 1.5))), snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))))),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
    home: const StorePage(),
  );
}
class Product {
  final String id, name, description, category;
  final double price;
  final double? oldPrice;
  final int stock;
  final bool featured;
  final List<String> images, sizes, colors;
  Product(Map<String,dynamic> m)
    : id = m['id'].toString(), name = (m['name'] ?? '').toString(),
      description = (m['description'] ?? '').toString(), category = (m['category'] ?? 'أخرى').toString(),
      price = double.tryParse(m['price'].toString()) ?? 0, oldPrice = m['compare_at_price'] == null ? null : double.tryParse(m['compare_at_price'].toString()), stock = int.tryParse(m['stock_quantity'].toString()) ?? 0,
      featured = m['is_featured'] == true,
      images = (m['image_urls'] as List? ?? []).map((e) => e.toString()).toList(),
      sizes = (m['sizes'] as List? ?? []).map((e) => e.toString()).toList(),
      colors = (m['colors'] as List? ?? []).map((e) => e.toString()).toList();
}
class Line {
  final Product p; final String size, color; int qty;
  Line(this.p, this.size, this.color, {this.qty = 1});
  double get total => p.price * qty;
}
String money(num n) => n.toStringAsFixed(n % 1 == 0 ? 0 : 2) + ' ج.م';

class StorePage extends StatefulWidget {
  const StorePage({super.key});
  @override State<StorePage> createState() => _StorePageState();
}
class _StorePageState extends State<StorePage> {
  bool loading = true; String? error; String query = '', category = ''; int tab = 0;
  List<Product> products = []; Map<String,dynamic> settings = {}, cms = {};
  final search = TextEditingController(); final Map<String,Line> cart = {};
  int get count => cart.values.fold(0, (n,x) => n + x.qty);
  double get total => cart.values.fold(0.0, (n,x) => n + x.total);
  List<String> get categories => products.map((p)=>p.category).toSet().toList()..sort();
  List<Product> get filtered => products.where((p) => (category.isEmpty || p.category == category) && (query.isEmpty || (p.name+' '+p.category+' '+p.description).toLowerCase().contains(query.toLowerCase()))).toList();


  List<Map<String,dynamic>> orderHistory = [];
  static const orderHistoryKey = 'secret_order_history_v1';
  Future<void> loadOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(orderHistoryKey);
    if (raw != null) {
      try { orderHistory = (jsonDecode(raw) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList(); }
      catch (_) { orderHistory = []; }
    }
    final now = DateTime.now();
    orderHistory = orderHistory.where((o) {
      final stamp = DateTime.tryParse((o['created_at'] ?? '').toString());
      if (stamp == null) return true;
      final age = now.difference(stamp).inDays;
      final status = (o['status'] ?? 'new').toString().toLowerCase();
      if (status == 'delivered') return age < 30;
      return age < 5;
    }).toList();
    await saveOrderHistory();
  }
  Future<void> saveOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(orderHistoryKey, jsonEncode(orderHistory));
  }
  Widget ordersPage() => RefreshIndicator(
    onRefresh: loadOrderHistory,
    child: orderHistory.isEmpty
      ? ListView(children: const [SizedBox(height:100), Icon(Icons.receipt_long_outlined,size:58,color:pink), SizedBox(height:12), Center(child:Text('لا توجد طلبات محفوظة حتى الآن',style:TextStyle(fontWeight:FontWeight.w700)))])
      : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orderHistory.length,
        separatorBuilder: (_,__)=>const SizedBox(height:10),
        itemBuilder:(context,index) {
          final o=orderHistory[index];
          final items=(o['items'] as List? ?? []);
          final status=(o['status']??'new').toString();
          const labels={'new':'قيد المراجعة','confirmed':'تم التأكيد','preparing':'قيد التجهيز','out_for_delivery':'خرج للتوصيل','delivered':'تم التسليم','cancelled':'ملغي'};
          final date=DateTime.tryParse((o['created_at']??'').toString());
          return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Icon(Icons.receipt_long,color:plum),const SizedBox(width:8),Expanded(child:Text('طلب #${o['order_number']??'—'}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16))),Text(labels[status]??status,style:const TextStyle(color:pink,fontWeight:FontWeight.w800))]),
            if(date!=null) Padding(padding:const EdgeInsets.only(top:5),child:Text('${date.day}/${date.month}/${date.year}',style:const TextStyle(color:Colors.black54))),
            const Divider(),
            ...items.map((it){final m=Map<String,dynamic>.from(it as Map);return Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text('${m['name']??'منتج'} × ${m['quantity']??1}${(m['size']??'').toString().isNotEmpty?' · مقاس ${m['size']}':''}${(m['color']??'').toString().isNotEmpty?' · ${m['color']}':''}'));}),
            Align(alignment:Alignment.centerLeft,child:Text('الإجمالي: ${money((o['total']??0) as num)}',style:const TextStyle(fontWeight:FontWeight.w900,color:plum))),
          ])));
        }),
  );

  @override void initState() { super.initState(); load(); loadOrderHistory(); }
  @override void dispose() { search.dispose(); super.dispose(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final r = await Future.wait([
        db.from('products').select('id,name,description,category,price,compare_at_price,image_urls,sizes,colors,stock_quantity,is_featured,created_at').eq('is_active', true).order('created_at', ascending: false),
        db.from('store_settings').select('*').eq('id', 1).maybeSingle(),
        db.from('site_content').select('content').eq('id', 1).maybeSingle(),
      ]);
      products = (r[0] as List).map((e)=>Product(Map<String,dynamic>.from(e))).toList();
      settings = Map<String,dynamic>.from((r[1] as Map?) ?? {});
      final cmsRow = Map<String,dynamic>.from((r[2] as Map?) ?? {});
      cms = Map<String,dynamic>.from((cmsRow['content'] as Map?) ?? {});
      await restoreCart();
    } catch (_) { error = 'تعذر تحميل المنتجات. تحققي من الإنترنت ثم حاولي مرة أخرى.'; }
    if (mounted) setState(() => loading = false);
  }
  Future<void> restoreCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('secret_cart_v1');
      if (raw == null) return;
      final saved = jsonDecode(raw) as List;
      for (final item in saved) {
        final m = Map<String,dynamic>.from(item as Map);
        Product? p;
        for (final candidate in products) { if (candidate.id == m['product_id']) { p = candidate; break; } }
        if (p == null || p.stock < 1) continue;
        final qty = int.tryParse('${m['quantity']}') ?? 1;
        if (qty < 1) continue;
        final size = (m['size'] ?? '').toString(), color = (m['color'] ?? '').toString();
        final key = p.id+'|'+size+'|'+color;
        cart[key] = Line(p,size,color,qty: qty > p.stock ? p.stock : (qty > 20 ? 20 : qty));
      }
    } catch (_) {}
  }
  Future<void> saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secret_cart_v1', jsonEncode(cart.values.map((x) => {'product_id':x.p.id,'quantity':x.qty,'size':x.size,'color':x.color}).toList()));
    } catch (_) {}
  }
  Future<void> track(String event, {String? productId}) async {
    try { await db.from('site_analytics').insert({'event_name':event,'page_path':'/android','product_id':productId}); } catch (_) {}
  }
  void add(Product p, String size, String color) {
    final key = p.id+'|'+size+'|'+color;
    if (p.stock < 1) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المنتج غير متوفر حاليًا'))); return; }
    if (cart[key] == null) { cart[key] = Line(p,size,color); }
    else if (cart[key]!.qty < p.stock && cart[key]!.qty < 20) { cart[key]!.qty++; }
    else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('وصلتِ للكمية المتاحة'))); return; }
    setState(() {});
    saveCart();
  }
  Future<void> showProduct(Product p) async {
    track('product_click', productId:p.id);
    String size = p.sizes.isEmpty ? '' : p.sizes.first, color = p.colors.isEmpty ? '' : p.colors.first;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,backgroundColor:Colors.white,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>SafeArea(child:SingleChildScrollView(
        padding:EdgeInsets.fromLTRB(18,18,18,20+MediaQuery.of(ctx).viewInsets.bottom),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
          if(p.images.isNotEmpty) ClipRRect(borderRadius:BorderRadius.circular(16),child:Image.network(p.images.first,height:230,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const SizedBox(height:70,child:Icon(Icons.image_not_supported)))),
          const SizedBox(height:12), Text(p.name,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
          Text(p.category,style:const TextStyle(color:Colors.black54)), Text(money(p.price),style:const TextStyle(color:pink,fontSize:21,fontWeight:FontWeight.w900)),
          if(p.oldPrice != null && p.oldPrice! > p.price) Text('بدلًا من '+money(p.oldPrice!),style:const TextStyle(color:Colors.black45,decoration:TextDecoration.lineThrough)),
          if(p.description.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(p.description)),
          if(p.sizes.isNotEmpty) DropdownButtonFormField<String>(value:size,decoration:const InputDecoration(labelText:'المقاس'),items:p.sizes.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>refresh(()=>size=v??size)),
          if(p.colors.isNotEmpty) Padding(padding:const EdgeInsets.only(top:10),child:DropdownButtonFormField<String>(value:color,decoration:const InputDecoration(labelText:'اللون'),items:p.colors.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v)=>refresh(()=>color=v??color))),
          const SizedBox(height:16), FilledButton(onPressed:p.stock>0?(){add(p,size,color);Navigator.pop(ctx);}:null,child:Text(p.stock>0?'أضيفي للسلة':'غير متوفر')),
        ]),
      ))));
  }
  Widget input(TextEditingController c,String label,{bool requiredField=false,TextInputType? keyboard,int maxLines=1}) => Padding(
    padding:const EdgeInsets.only(bottom:10),child:TextFormField(controller:c,keyboardType:keyboard,maxLines:maxLines,decoration:InputDecoration(labelText:label),
      validator: requiredField ? (v) { final minLength = label.contains('الهاتف') ? 7 : label.contains('العنوان') ? 5 : 2; if (v == null || v.trim().length < minLength) return 'من فضلك أدخلي ' + label + ' بشكل صحيح'; return null; } : null));
  Future<void> checkout() async {
    if(cart.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('السلة فارغة')));return;}
    final form=GlobalKey<FormState>();
    final name=TextEditingController(),phone=TextEditingController(),address=TextEditingController(),email=TextEditingController(),notes=TextEditingController(),delivery=TextEditingController();
    bool sending=false;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,backgroundColor:Colors.white,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>SafeArea(child:SingleChildScrollView(
        padding:EdgeInsets.fromLTRB(18,20,18,20+MediaQuery.of(ctx).viewInsets.bottom),
        child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('بيانات التوصيل',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
          const Padding(padding:EdgeInsets.symmetric(vertical:8),child:Text('تكلفة التوصيل تُحدد عند تأكيد المتجر.')),
          input(name,'الاسم بالكامل',requiredField:true),input(phone,'رقم الهاتف',requiredField:true,keyboard:TextInputType.phone),
          input(address,'العنوان بالتفصيل',requiredField:true,maxLines:2),input(email,'البريد الإلكتروني (اختياري)',keyboard:TextInputType.emailAddress),
          input(delivery,'شركة الشحن (اختياري)'),input(notes,'ملاحظات على الطلب',maxLines:2),
          Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text('الإجمالي المبدئي: '+money(total),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18))),
          FilledButton(onPressed:sending?null:() async {
            if(!(form.currentState?.validate()??false))return; refresh(()=>sending=true);
            try {
              final response=await db.functions.invoke('create-customer-order',body:{
                'customer_name':name.text.trim(),'phone':phone.text.trim(),'address':address.text.trim(),'email':email.text.trim(),
                'notes':notes.text.trim(),'delivery_service':delivery.text.trim(),
                'items':cart.values.map((x)=>{'product_id':x.p.id,'quantity':x.qty,'selected_size':x.size,'selected_color':x.color}).toList(),
              });
              final data=Map<String,dynamic>.from(response.data as Map? ?? {});
              if(response.status>=400||data['error']!=null)throw Exception(data['error']??'تعذر تسجيل الطلب');
              final order=Map<String,dynamic>.from(data['order'] as Map? ?? {});
              final number=(order['order_number']??'—').toString();
              orderHistory.insert(0, {
                'order_number': number,
                'created_at': (order['created_at'] ?? DateTime.now().toIso8601String()).toString(),
                'total': (order['total'] ?? total),
                'status': (order['status'] ?? 'new').toString(),
                'items': cart.values.map((x)=>{'name':x.p.name,'quantity':x.qty,'size':x.size,'color':x.color,'price':x.p.price}).toList(),
              });
              await saveOrderHistory();
              if(!mounted)return; setState(()=>cart.clear()); saveCart(); Navigator.pop(ctx);
              await showDialog<void>(context:context,builder:(d)=>AlertDialog(
                icon:const Icon(Icons.check_circle_outline,color:Colors.green,size:42),title:const Text('تم استلام طلبك ♡'),
                content:Text('رقم الطلب: #'+number+'\nالإجمالي المبدئي: '+money((order['total'] as num?)?.toDouble()??0)+'\n'+(data['message']??'').toString()),
                actions:[FilledButton(onPressed:()=>Navigator.pop(d),child:const Text('تمام'))]));
              track('order_created');
            } catch(e){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
            finally{if(ctx.mounted)refresh(()=>sending=false);}
          },child:Text(sending?'جارٍ تسجيل الطلب…':'تأكيد الطلب')),
        ])),
      ))));
    name.dispose();phone.dispose();address.dispose();email.dispose();notes.dispose();delivery.dispose();
  }
  Future<void> contact({bool map=false}) async {
    final value=map?(settings['map_query']??'Secret KFS، كفر الشيخ').toString():(settings['whatsapp_number']??'201550121102').toString();
    final uri=map?Uri.https('www.google.com','/maps/search/',{'api':'1','query':value}):Uri.parse('https://wa.me/'+value.replaceAll(RegExp(r'\D'),''));
    await launchUrl(uri,mode:LaunchMode.externalApplication);
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(toolbarHeight:88,title:Column(mainAxisSize:MainAxisSize.min,children:[
      ShaderMask(shaderCallback:(bounds)=>const LinearGradient(colors:[plum,pink,Color(0xFFD98CA9)]).createShader(bounds),
        child:const Text('S E C R E T',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w800,letterSpacing:2.8,height:1.1))),
      const SizedBox(height:5),
      const Text('K F S  •  YOUR STYLE, YOUR STORY',style:TextStyle(fontSize:9,color:Color(0xFF82717B),letterSpacing:1.7,fontWeight:FontWeight.w600)),
    ]),actions:[IconButton(onPressed:load,tooltip:'تحديث المنتجات',icon:const Icon(Icons.refresh_rounded))]),
    body:IndexedStack(index:tab,children:[home(),categoriesPage(),cartPage(),contactPage(),ordersPage()]),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:[
      const NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'المتجر'),
      const NavigationDestination(icon:Icon(Icons.grid_view_outlined),label:'الأقسام'),
      NavigationDestination(icon:Badge(isLabelVisible:count>0,label:Text(count.toString()),child:const Icon(Icons.shopping_bag_outlined)),label:'السلة'),
      const NavigationDestination(icon:Icon(Icons.chat_bubble_outline),label:'تواصل'),
      const NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'طلباتي'),
    ]),
  );
  Widget home()=>RefreshIndicator(onRefresh:load,child:CustomScrollView(slivers:[
    if(cms['announcement_visible'] != false) SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(14,8,14,0),child:Text((cms['announcement']??'لمستك الخاصة تبدأ من هنا ✦ توصيل داخل كفر الشيخ والمناطق المحيطة').toString(),textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:pink,fontWeight:FontWeight.w700)))),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(14,14,14,8),child:
      TweenAnimationBuilder<double>(tween:Tween(begin:.94,end:1),duration:const Duration(milliseconds:650),curve:Curves.easeOutCubic,
        builder:(context,scale,child)=>Transform.scale(scale:scale,child:child),
        child:Container(padding:const EdgeInsets.all(23),decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(30),
          gradient:const LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[Color(0xFF713B5C),Color(0xFFAD567C),Color(0xFFD58CA8)]),
          boxShadow:[BoxShadow(color:plum.withOpacity(.16),blurRadius:24,offset:Offset(0,12))]),
          child:Stack(children:[
            const Positioned(left:-10,top:-22,child:Icon(Icons.auto_awesome,size:104,color:Color(0x22FFFFFF))),
            Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),decoration:BoxDecoration(color:Colors.white.withOpacity(.16),borderRadius:BorderRadius.circular(30),border:Border.all(color:Colors.white.withOpacity(.2))),
                child:Text((cms['hero_eyebrow']??'CURATED FOR YOU  ✦').toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:10,letterSpacing:1.4))),
              const SizedBox(height:17),
              Text((cms['hero_title']??'ستايلك…\\nعلى طريقتك.').toString(),style:const TextStyle(fontSize:31,height:1.28,fontWeight:FontWeight.w900,color:Colors.white)),
              const SizedBox(height:10),
              Text((cms['hero_description']??'اكتشفي قطعًا مختارة بعناية، لتفاصيل صغيرة تصنع فرقًا كبيرًا.').toString(),style:const TextStyle(height:1.8,fontSize:13,color:Color(0xFFFBEFF4))),
              const SizedBox(height:19),
              Wrap(spacing:8,runSpacing:8,children:[
                _heroPill(Icons.favorite_border_rounded,'اختيارات مميزة'),
                _heroPill(Icons.local_shipping_outlined,'توصيل سهل'),
              ]),
            ]),
          ]),
        ),
      ),
    )),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:TextField(controller:search,onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(hintText:'ابحثي عن منتج أو وصف…',prefixIcon:const Icon(Icons.search),suffixIcon:query.isEmpty?null:IconButton(onPressed:(){search.clear();setState(()=>query='');},icon:const Icon(Icons.close)))))),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(14),child:Text(category.isEmpty?'قطع هتحبيها 🤍':category,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)))),
    if(loading)const SliverFillRemaining(child:Center(child:CircularProgressIndicator()))
    else if(error!=null)SliverFillRemaining(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!),FilledButton(onPressed:load,child:const Text('إعادة المحاولة'))])))
    else if(filtered.isEmpty)const SliverFillRemaining(child:Center(child:Text('لا توجد منتجات مطابقة حاليًا.')))
    else SliverPadding(padding:const EdgeInsets.fromLTRB(12,0,12,16),sliver:SliverGrid(delegate:SliverChildBuilderDelegate((ctx,i)=>productCard(filtered[i]),childCount:filtered.length),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:.57))),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(16),child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFF2DCE6),borderRadius:BorderRadius.circular(18)),child:const Text('اختيارات بعناية • طلب سهل وواضح • إحنا قريبين منك')))),
  ]));
  Widget _heroPill(IconData icon,String label)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),
    decoration:BoxDecoration(color:Colors.white.withOpacity(.14),borderRadius:BorderRadius.circular(30),border:Border.all(color:Colors.white.withOpacity(.24))),
    child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:14,color:Colors.white),const SizedBox(width:6),Text(label,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w600))]),
  );
  Widget productCard(Product p)=>InkWell(onTap:()=>showProduct(p),borderRadius:BorderRadius.circular(16),child:Container(clipBehavior:Clip.antiAlias,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFF0DFE6))),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Expanded(child:Stack(fit:StackFit.expand,children:[
      if(p.images.isNotEmpty)Image.network(p.images.first,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const ColoredBox(color:Color(0xFFF7EAF0),child:Icon(Icons.shopping_bag_outlined,color:pink,size:38))) else const ColoredBox(color:Color(0xFFF7EAF0),child:Icon(Icons.shopping_bag_outlined,color:pink,size:38)),
      if(p.featured)const Positioned(top:8,right:8,child:DecoratedBox(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.all(Radius.circular(20))),child:Padding(padding:EdgeInsets.symmetric(horizontal:8,vertical:4),child:Text('اختيارنا ♡',style:TextStyle(color:pink,fontSize:10,fontWeight:FontWeight.bold))))),
    ])),
    Padding(padding:const EdgeInsets.all(9),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(p.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
      Text(p.category,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.black54,fontSize:11)),
      const SizedBox(height:4),Text(money(p.price),style:const TextStyle(color:pink,fontWeight:FontWeight.w900)),
      if(p.oldPrice != null && p.oldPrice! > p.price) Text(money(p.oldPrice!),style:const TextStyle(fontSize:10,color:Colors.black45,decoration:TextDecoration.lineThrough)),
      SizedBox(width:double.infinity,height:32,child:FilledButton.tonal(onPressed:()=>showProduct(p),child:const Text('عرض المنتج',style:TextStyle(fontSize:11)))),
    ])),
  ])));
  Widget categoriesPage()=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('اختاري قسمك المفضل',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:14),
    Wrap(spacing:8,runSpacing:8,children:[
      ChoiceChip(label:const Text('كل المنتجات'),selected:category.isEmpty,onSelected:(_)=>setState(() { category=''; tab=0; })),
      ...categories.map((c)=>ChoiceChip(label:Text(c),selected:category==c,onSelected:(_)=>setState(() { category=c; tab=0; }))),
    ]),
    const SizedBox(height:14),const Text('اختاري قسمًا لعرض منتجاته في صفحة المتجر.',style:TextStyle(color:Colors.black54)),
  ]);
  Widget cartPage(){
    if(cart.isEmpty)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.shopping_bag_outlined,size:62,color:pink),const SizedBox(height:12),const Text('سلتك لسه فاضية',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:10),FilledButton(onPressed:()=>setState(()=>tab=0),child:const Text('ابدئي التسوق'))]));
    return Column(children:[
      Expanded(child:ListView(padding:const EdgeInsets.all(12),children:[
        const Text('سلة مشترياتك',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
        ...cart.entries.map((e){final x=e.value;return Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
          SizedBox(width:70,height:80,child:x.p.images.isEmpty?const Icon(Icons.shopping_bag_outlined):Image.network(x.p.images.first,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported))),
          const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(x.p.name,style:const TextStyle(fontWeight:FontWeight.bold)),if(x.size.isNotEmpty)Text('المقاس: '+x.size),if(x.color.isNotEmpty)Text('اللون: '+x.color),
            Text(money(x.total),style:const TextStyle(color:pink,fontWeight:FontWeight.w900)),
            Row(children:[
              IconButton(onPressed:() { setState(() { if(x.qty>1) { x.qty--; } else { cart.remove(e.key); } }); saveCart(); },icon:const Icon(Icons.remove_circle_outline)),
              Text(x.qty.toString()),
              IconButton(onPressed:() { setState(() { if(x.qty<x.p.stock&&x.qty<20) x.qty++; }); saveCart(); },icon:const Icon(Icons.add_circle_outline)),
              IconButton(onPressed:() { setState(() => cart.remove(e.key)); saveCart(); },icon:const Icon(Icons.delete_outline,color:Colors.red)),
            ]),
          ])),
        ])));}),
      ])),
      Container(color:Colors.white,padding:const EdgeInsets.all(16),child:SafeArea(top:false,child:Column(children:[
        Row(children:[const Expanded(child:Text('الإجمالي المبدئي',style:TextStyle(fontWeight:FontWeight.bold))),Text(money(total),style:const TextStyle(fontSize:20,color:pink,fontWeight:FontWeight.w900))]),
        const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton(onPressed:checkout,child:const Text('إتمام الطلب'))),
      ]))),
    ]);
  }
  Widget contactPage()=>ListView(padding:const EdgeInsets.all(18),children:[
    const Text('إحنا قريبين منك 🤍',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
    const SizedBox(height:8),const Text('عندك سؤال عن منتج أو طلب؟ تواصلي معنا مباشرة.'),
    Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.chat,color:Colors.green),title:const Text('تواصلي عبر واتساب'),subtitle:Text((settings['whatsapp_number']??'01550121102').toString()),onTap:()=>contact())),
    Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.location_on_outlined,color:pink),title:const Text('موقع المتجر على الخريطة'),subtitle:Text((settings['map_query']??'Secret KFS، كفر الشيخ').toString()),onTap:()=>contact(map:true))),
    Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.email_outlined,color:pink),title:const Text('البريد الإلكتروني'),subtitle:Text((settings['contact_email']??'secretkfs.work@gmail.com').toString()),onTap:()=>launchUrl(Uri.parse('mailto:'+((settings['contact_email']??'secretkfs.work@gmail.com').toString())),mode:LaunchMode.externalApplication))),
    const SizedBox(height:24),const Text('Secret KFS · YOUR STYLE',textAlign:TextAlign.center,style:TextStyle(color:pink,fontWeight:FontWeight.w900)),
  ]);
}

