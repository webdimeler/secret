import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const url = 'https://ywhwqpijlevtoqvhodkf.supabase.co';
const publicKey = 'sb_publishable_x2MuIwfoQKZ6R33K1Tl4_Q_8HZJIUSY';
const pink = Color(0xFFBD557E);
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
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: pink), scaffoldBackgroundColor: const Color(0xFFFFF8FA)),
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

  @override void initState() { super.initState(); load(); }
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
    appBar:AppBar(title:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('secret',style:TextStyle(color:pink,fontSize:24,fontWeight:FontWeight.w900,letterSpacing:1.5)),
      Text('K F S · YOUR STYLE',style:TextStyle(fontSize:9,color:Colors.black54,letterSpacing:2)),
    ]),actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh))]),
    body:IndexedStack(index:tab,children:[home(),categoriesPage(),cartPage(),contactPage()]),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:[
      const NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'المتجر'),
      const NavigationDestination(icon:Icon(Icons.grid_view_outlined),label:'الأقسام'),
      NavigationDestination(icon:Badge(isLabelVisible:count>0,label:Text(count.toString()),child:const Icon(Icons.shopping_bag_outlined)),label:'السلة'),
      const NavigationDestination(icon:Icon(Icons.chat_bubble_outline),label:'تواصل'),
    ]),
  );
  Widget home()=>RefreshIndicator(onRefresh:load,child:CustomScrollView(slivers:[
    if(cms['announcement_visible'] != false) SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(14,8,14,0),child:Text((cms['announcement']??'لمستك الخاصة تبدأ من هنا ✦ توصيل داخل كفر الشيخ والمناطق المحيطة').toString(),textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:pink,fontWeight:FontWeight.w700)))),
    SliverToBoxAdapter(child:Container(margin:const EdgeInsets.all(14),padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFFF8E5ED),Color(0xFFFFF9FB)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text((cms['hero_eyebrow']??'YOUR STYLE, YOUR SECRET').toString(),style:const TextStyle(color:pink,fontWeight:FontWeight.w900,fontSize:11)),
      const SizedBox(height:8),Text((cms['hero_title']??'تفاصيل صغيرة،\nإطلالة مختلفة.').toString(),style:const TextStyle(fontSize:30,height:1.3,fontWeight:FontWeight.w900)),
      const SizedBox(height:8),Text((cms['hero_description']??'اختاري القطع اللي تشبهك من تشكيلتنا المختارة — لأن أناقتك ليها حكاية.').toString(),style:const TextStyle(height:1.8)),
    ]))),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:TextField(controller:search,onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(hintText:'ابحثي عن منتج أو وصف…',prefixIcon:const Icon(Icons.search),suffixIcon:query.isEmpty?null:IconButton(onPressed:(){search.clear();setState(()=>query='');},icon:const Icon(Icons.close)))))),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(14),child:Text(category.isEmpty?'قطع هتحبيها 🤍':category,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)))),
    if(loading)const SliverFillRemaining(child:Center(child:CircularProgressIndicator()))
    else if(error!=null)SliverFillRemaining(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!),FilledButton(onPressed:load,child:const Text('إعادة المحاولة'))])))
    else if(filtered.isEmpty)const SliverFillRemaining(child:Center(child:Text('لا توجد منتجات مطابقة حاليًا.')))
    else SliverPadding(padding:const EdgeInsets.fromLTRB(12,0,12,16),sliver:SliverGrid(delegate:SliverChildBuilderDelegate((ctx,i)=>productCard(filtered[i]),childCount:filtered.length),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:.57))),
    SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(16),child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFFF2DCE6),borderRadius:BorderRadius.circular(18)),child:const Text('اختيارات بعناية • طلب سهل وواضح • إحنا قريبين منك')))),
  ]));
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
