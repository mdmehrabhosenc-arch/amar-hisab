import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HisabDB.instance.init();
  runApp(const AmarHisabApp());
}

final money = NumberFormat('#,##0.##', 'en_US');
String taka(num n) => '৳${money.format(n)}';
String bnDate(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

class HisabDB {
  HisabDB._();
  static final instance = HisabDB._();
  Database? _db;
  Future<void> init() async {
    final base = await getDatabasesPath();
    _db = await openDatabase(p.join(base, 'amar_hisab.db'), version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          date TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )''');
      });
  }
  Database get db => _db!;
  Future<List<Map<String, Object?>>> all() => db.query('transactions', orderBy: 'date DESC, id DESC');
  Future<void> save(Map<String, Object?> row, {int? id}) async {
    if (id == null) { await db.insert('transactions', row); }
    else { await db.update('transactions', row, where: 'id = ?', whereArgs: [id]); }
  }
  Future<void> delete(int id) async => db.delete('transactions', where: 'id = ?', whereArgs: [id]);
}

class AmarHisabApp extends StatelessWidget {
  const AmarHisabApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'আমার হিসাব',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff07866f)),
      scaffoldBackgroundColor: const Color(0xfff5f8f7), appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff087f6a), foregroundColor: Colors.white, centerTitle: false)),
    locale: const Locale('bn'),
    supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  List<Map<String, Object?>> rows = [];
  int tab = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  @override void initState() { super.initState(); refresh(); }
  Future<void> refresh() async { final x = await HisabDB.instance.all(); if (mounted) setState(() => rows = x); }
  DateTime parseDate(Object? v) => DateTime.tryParse('$v') ?? DateTime.now();
  double sumWhere(bool Function(Map<String,Object?>) test) => rows.where(test).fold(0.0, (s,r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
  bool isToday(Map<String,Object?> r) { final d=parseDate(r['date']); final n=DateTime.now(); return d.year==n.year && d.month==n.month && d.day==n.day; }
  bool isMonth(Map<String,Object?> r) { final d=parseDate(r['date']); return d.year==month.year && d.month==month.month; }
  double get todayIn => sumWhere((r)=>r['type']=='আয়' && isToday(r));
  double get todayOut => sumWhere((r)=>r['type']=='ব্যয়' && isToday(r));
  double get monthIn => sumWhere((r)=>r['type']=='আয়' && isMonth(r));
  double get monthOut => sumWhere((r)=>r['type']=='ব্যয়' && isMonth(r));
  double get allBalance => sumWhere((r)=>r['type']=='আয়')-sumWhere((r)=>r['type']=='ব্যয়');

  Future<void> openForm({String type='ব্যয়', Map<String,Object?>? existing}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EntryPage(type: type, existing: existing)));
    await refresh();
  }
  @override Widget build(BuildContext context) {
    final pages = [_dashboard(), _transactions(), _reports()];
    return Scaffold(
      appBar: AppBar(title: const Text('আমার হিসাব', style: TextStyle(fontWeight: FontWeight.bold)), actions: [
        IconButton(tooltip:'রিফ্রেশ', onPressed: refresh, icon: const Icon(Icons.refresh))
      ]),
      body: pages[tab],
      floatingActionButton: tab==0 ? FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [
          ListTile(leading: const Icon(Icons.add_circle, color: Colors.green), title: const Text('নতুন আয় যোগ করুন'), onTap: () { Navigator.pop(context); openForm(type:'আয়'); }),
          ListTile(leading: const Icon(Icons.remove_circle, color: Colors.red), title: const Text('নতুন ব্যয় যোগ করুন'), onTap: () { Navigator.pop(context); openForm(type:'ব্যয়'); }),
        ]))),
        icon: const Icon(Icons.add), label: const Text('হিসাব যোগ করুন')) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v)=>setState(()=>tab=v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label:'হোম'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label:'লেনদেন'),
        NavigationDestination(icon: Icon(Icons.bar_chart), label:'চার্ট'),
      ]),
    );
  }
  Widget _dashboard() {
    final recent = rows.take(5).toList();
    return RefreshIndicator(onRefresh: refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors:[Color(0xff087f6a),Color(0xff28ad91)]), borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('আজকের সারাংশ', style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _whiteMetric('আজকের আয়', todayIn, Icons.trending_up, Colors.green)),
            const SizedBox(width: 10),
            Expanded(child: _whiteMetric('আজকের ব্যয়', todayOut, Icons.trending_down, Colors.red)),
          ]),
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white.withValues(alpha:.17), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('মোট অবশিষ্ট ব্যালেন্স', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(taka(allBalance), style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold))
            ]))
        ])),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _quickButton('নতুন আয়', Icons.add_circle, const Color(0xff07866f), ()=>openForm(type:'আয়'))),
        const SizedBox(width: 12),
        Expanded(child: _quickButton('নতুন ব্যয়', Icons.remove_circle, const Color(0xffe94b54), ()=>openForm(type:'ব্যয়'))),
      ]),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('সাম্প্রতিক লেনদেন', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: ()=>setState(()=>tab=1), child: const Text('সব দেখুন'))
      ]),
      if (recent.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('এখনো কোনো হিসাব যোগ করা হয়নি।'))),
      ...recent.map(_transactionTile),
      const SizedBox(height: 80)
    ]));
  }
  Widget _whiteMetric(String title, double value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13)),
      const SizedBox(height: 6), Text(taka(value), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      Icon(icon, color: color)
    ]));
  Widget _quickButton(String label, IconData icon, Color color, VoidCallback action) => FilledButton(
    style: FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    onPressed: action, child: Column(children:[Icon(icon), const SizedBox(height:5), Text(label)]));
  Widget _transactionTile(Map<String,Object?> r) {
    final income=r['type']=='আয়'; final amount=(r['amount'] as num?)?.toDouble()??0;
    return Card(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: income?const Color(0xffd9f7e9):const Color(0xffffe3e3), child: Icon(income?Icons.arrow_downward:Icons.arrow_upward, color: income?Colors.green:Colors.red)),
      title: Text('${r['category'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ('${r['note'] ?? ''}'.trim().isNotEmpty) Text('${r['note']}', maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(bnDate(parseDate(r['date'])), style: const TextStyle(fontSize: 12, color: Colors.black54))
      ]),
      trailing: Text('${income?'+':'−'}${taka(amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: income?Colors.green:Colors.red)),
      onTap: ()=>openForm(type: '${r['type']}', existing:r),
    ));
  }
  Widget _transactions() {
    final sorted = rows.toList();
    return ListView(padding: const EdgeInsets.all(14), children: [
      const Text('লেনদেনের তালিকা', style: TextStyle(fontSize: 20,fontWeight:FontWeight.bold)),
      const SizedBox(height: 8),
      if (sorted.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('কোনো লেনদেন নেই। + বোতামে চাপ দিয়ে যোগ করুন।'))),
      ...sorted.map((r)=>Dismissible(key:ValueKey(r['id']), background:Container(alignment:Alignment.centerRight,padding:const EdgeInsets.only(right:20),color:Colors.red,child:const Icon(Icons.delete,color:Colors.white)),
        direction:DismissDirection.endToStart, confirmDismiss:(_)=>showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('হিসাব মুছবেন?'),content:const Text('এই লেনদেনটি মুছে ফেলা হবে।'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('না')),TextButton(onPressed:()=>Navigator.pop(c,true),child:const Text('মুছুন'))])).then((v)=>v??false),
        onDismissed:(_) async { await HisabDB.instance.delete(r['id'] as int); refresh(); }, child:_transactionTile(r))),
      const SizedBox(height: 80)
    ]);
  }
  Widget _reports() {
    final labels = ['জানু','ফেব্রু','মার্চ','এপ্রি','মে','জুন','জুলা','আগ','সেপ্টে','অক্টো','নভে','ডিসে'];
    final incomeBars=<BarChartGroupData>[];
    for (int m=1;m<=12;m++) {
      final ins=rows.where((r){final d=parseDate(r['date']);return d.year==month.year&&d.month==m&&r['type']=='আয়';}).fold<double>(0,(s,r)=>s+((r['amount'] as num?)?.toDouble()??0));
      final outs=rows.where((r){final d=parseDate(r['date']);return d.year==month.year&&d.month==m&&r['type']=='ব্যয়';}).fold<double>(0,(s,r)=>s+((r['amount'] as num?)?.toDouble()??0));
      incomeBars.add(BarChartGroupData(x:m-1, barRods:[
        BarChartRodData(toY:ins,width:7,color:const Color(0xff0a9a7b),borderRadius:BorderRadius.circular(3)),
        BarChartRodData(toY:outs,width:7,color:const Color(0xffef5350),borderRadius:BorderRadius.circular(3)),
      ], barsSpace:3));
    }
    return ListView(padding:const EdgeInsets.all(16),children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        const Text('মাসিক রিপোর্ট',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        Row(children:[IconButton(onPressed:()=>setState(()=>month=DateTime(month.year-1,month.month)),icon:const Icon(Icons.chevron_left)),Text('${month.year}'),IconButton(onPressed:()=>setState(()=>month=DateTime(month.year+1,month.month)),icon:const Icon(Icons.chevron_right))])
      ]),
      Row(children:[
        Expanded(child:_reportCard('মোট আয়',monthIn,Colors.green)),
        const SizedBox(width:10),Expanded(child:_reportCard('মোট ব্যয়',monthOut,Colors.red)),
      ]),
      const SizedBox(height:10),_reportCard('অবশিষ্ট / সঞ্চয়',monthIn-monthOut,const Color(0xff6255d9)),
      const SizedBox(height:22),
      const Text('মাস অনুযায়ী আয় ও ব্যয়',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
      const SizedBox(height:12),
      Container(height:260,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:BarChart(BarChartData(
        barGroups:incomeBars, gridData:const FlGridData(show:true), borderData:FlBorderData(show:false),
        titlesData:FlTitlesData(
          topTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
          rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
          leftTitles:const AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:38)),
          bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:32,getTitlesWidget:(v,m)=>Padding(padding:const EdgeInsets.only(top:7),child:Text(labels[v.toInt().clamp(0,11)],style:const TextStyle(fontSize:9))))),
        ),
      ))),
      const SizedBox(height:12),
      const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.circle,color:Color(0xff0a9a7b),size:10),SizedBox(width:5),Text('আয়'),SizedBox(width:18),Icon(Icons.circle,color:Color(0xffef5350),size:10),SizedBox(width:5),Text('ব্যয়')]),
      const SizedBox(height:80)
    ]);
  }
  Widget _reportCard(String title,double value,Color color)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:color.withValues(alpha:.10),borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.black54)),const SizedBox(height:8),Text(taka(value),style:TextStyle(color:color,fontWeight:FontWeight.bold,fontSize:21))]));
}

class EntryPage extends StatefulWidget {
  final String type; final Map<String,Object?>? existing;
  const EntryPage({super.key, required this.type, this.existing});
  @override State<EntryPage> createState()=>_EntryPageState();
}
class _EntryPageState extends State<EntryPage> {
  final formKey=GlobalKey<FormState>();
  final amountCtrl=TextEditingController();
  final noteCtrl=TextEditingController();
  late String type,category;
  late DateTime date;
  bool saving=false;
  final incomeCats=['বেতন','ব্যবসা','ফ্রিল্যান্সিং','উপহার','অন্যান্য'];
  final expenseCats=['খাবার','যাতায়াত','বাসা ভাড়া','বাজার','বিল','চিকিৎসা','শিক্ষা','কেনাকাটা','অন্যান্য'];
  @override void initState(){super.initState();type=widget.existing?['type'] as String? ?? widget.type; category=widget.existing?['category'] as String? ?? (type=='আয়'?'বেতন':'খাবার'); date=DateTime.tryParse('${widget.existing?['date'] ?? ''}')??DateTime.now(); amountCtrl.text=widget.existing?['amount']?.toString()??''; noteCtrl.text='${widget.existing?['note']??''}';}
  @override void dispose(){amountCtrl.dispose();noteCtrl.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final income=type=='আয়';
    return Scaffold(appBar:AppBar(title:Text(widget.existing==null?'নতুন $type যোগ করুন':'হিসাব সম্পাদনা করুন')),body:SafeArea(child:Form(key:formKey,child:ListView(padding:const EdgeInsets.all(18),children:[
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:income?const Color(0xffe0f7ec):const Color(0xffffe5e5),borderRadius:BorderRadius.circular(16)),child:Text(income?'আয়ের বিবরণ লিখুন':'খরচের বিবরণ লিখুন',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:income?Colors.green.shade800:Colors.red.shade800))),
      const SizedBox(height:18),
      const Text('টাকার পরিমাণ (৳)'),
      const SizedBox(height:7),
      TextFormField(controller:amountCtrl,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(prefixText:'৳ ',hintText:'যেমন: ২৫০',border:OutlineInputBorder()),validator:(v){final n=double.tryParse((v??'').replaceAll(',',''));if(n==null||n<=0)return 'সঠিক টাকার পরিমাণ লিখুন';return null;}),
      const SizedBox(height:16),
      const Text('বিভাগ নির্বাচন করুন'),const SizedBox(height:7),
      DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(border:OutlineInputBorder()),items:(income?incomeCats:expenseCats).map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v)=>setState(()=>category=v??category)),
      const SizedBox(height:16),
      Text(income?'আয়ের বিবরণ / কোথা থেকে পেলেন?':'খরচের কারণ / কী কাজে খরচ করলেন?',style:const TextStyle(fontWeight:FontWeight.w600)),
      const SizedBox(height:7),
      TextFormField(controller:noteCtrl,maxLines:3,maxLength:250,decoration:InputDecoration(border:const OutlineInputBorder(),hintText:income?'যেমন: অক্টোবর মাসের বেতন':'যেমন: দুপুরের খাবার, বাস ভাড়া, ওষুধ কেনা')),
      const SizedBox(height:10),
      const Text('তারিখ নির্বাচন করুন'),const SizedBox(height:7),
      OutlinedButton.icon(onPressed:()async{final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2000),lastDate:DateTime(2100),locale:const Locale('bn'));if(d!=null)setState(()=>date=d);},icon:const Icon(Icons.calendar_month),label:Text(bnDate(date)),style:OutlinedButton.styleFrom(padding:const EdgeInsets.all(15))),
      const SizedBox(height:22),
      FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'সংরক্ষণ হচ্ছে...':'হিসাব সংরক্ষণ করুন'),style:FilledButton.styleFrom(backgroundColor:income?const Color(0xff07866f):const Color(0xffe94b54),padding:const EdgeInsets.all(16))),
    ]))));
  }
  Future<void> save()async{
    if(!formKey.currentState!.validate())return;
    setState(()=>saving=true);
    final data=<String,Object?>{'type':type,'amount':double.parse(amountCtrl.text.replaceAll(',','')),'category':category,'note':noteCtrl.text.trim(),'date':DateFormat('yyyy-MM-dd').format(date),'createdAt':DateTime.now().toIso8601String()};
    final id=widget.existing?['id'];
    await HisabDB.instance.save(data,id:id is int?id:null);
    if(mounted){Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('হিসাব সংরক্ষণ হয়েছে')));}
  }
}
