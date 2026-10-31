import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const blue = Color(0xFF2457D6), navy = Color(0xFF101B35), bg = Color(0xFFF4F7FC);
const line = Color(0xFFE3E9F2), muted = Color(0xFF68758A), red = Color(0xFFD93D4F);
const orange = Color(0xFFE99A26), green = Color(0xFF23845B), teal = Color(0xFF12A6A6);

void main() => runApp(const AmaneApp());

enum Status { nouveau, verification, secours, traite }
extension StatusInfo on Status {
  String get label => ['Nouveau','En vérification','Secours contactés','Traité'][index];
  Color get color => [red,orange,blue,green][index];
}
class Report {
  Report({required this.id,required this.location,required this.lat,required this.lng,
    required this.victims,required this.state,required this.time,required this.status});
  final String id, location, state;
  final double lat,lng;
  final int victims;
  final DateTime time;
  Status status;
  String get priority {
    final s=state.toLowerCase();
    if(s.contains('inconscient')||s.contains('grave')||s.contains('incendie')||victims>=4)return 'P1';
    if(s.contains('léger')||s.contains('leger')||victims>=2)return 'P2';
    return 'P3';
  }
}
class Facility {
  const Facility(this.name,this.type,this.wilaya,this.lat,this.lng);
  final String name,type,wilaya; final double lat,lng;
  bool get hospital=>type.toLowerCase().contains('hôpital')||type.toLowerCase().contains('hopital');
}
abstract class Repository {
  bool get demo;
  Future<List<Report>> reports();
  Future<List<Facility>> facilities();
  Future<void> update(Report r,Status s);
}
class DemoRepository implements Repository {
  List<Report>? cache;
  @override bool get demo=>true;
  @override Future<List<Report>> reports() async {
    if(cache!=null)return cache!;
    const cities=< (String,double,double)>[
      ('Alger',36.75,3.06),('Oran',35.70,-.63),('Constantine',36.365,6.615),('Annaba',36.90,7.77),
      ('Béjaïa',36.75,5.06),('Sétif',36.19,5.41),('Tlemcen',34.88,-1.32),('Biskra',34.85,5.73),
      ('Ouargla',31.95,5.32),('Ghardaïa',32.49,3.67),('Tizi Ouzou',36.72,4.05),('Batna',35.56,6.17),
      ('Blida',36.47,2.83),('Guelma',36.46,7.43)];
    const states=['Inconscient','Blessés graves','Blessés légers','Indéterminé'];
    final rnd=Random(12); final now=DateTime.now();
    cache=List.generate(36,(i){
      final c=cities[rnd.nextInt(cities.length)]; final n=rnd.nextInt(6);
      return Report(id:'AM-${(i+1).toString().padLeft(4,'0')}',location:c.$1,
        lat:c.$2+(rnd.nextDouble()-.5)*.12,lng:c.$3+(rnd.nextDouble()-.5)*.12,
        victims:n,state:n==0?'Aucune victime déclarée':states[rnd.nextInt(states.length)],
        time:now.subtract(Duration(minutes:rnd.nextInt(14*24*60))),status:Status.values[rnd.nextInt(4)]);
    });
    return cache!;
  }
  @override Future<List<Facility>> facilities() async => const [
    Facility('Établissement démo — Alger Centre','Hôpital','Alger',36.752,3.042),
    Facility('Clinique démo — Alger','Clinique','Alger',36.77,3.06),
    Facility('Établissement démo — Oran','Hôpital','Oran',35.697,-.633),
    Facility('Polyclinique démo — Constantine','Polyclinique','Constantine',36.365,6.61),
    Facility('Établissement démo — Béjaïa','Hôpital','Béjaïa',36.755,5.07),
    Facility('Clinique démo — Sétif','Clinique','Sétif',36.19,5.41),
    Facility('Établissement démo — Blida','Hôpital','Blida',36.47,2.83)];
  @override Future<void> update(Report r,Status s) async {r.status=s;}
}

class AmaneApp extends StatelessWidget {
  const AmaneApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'AMANE | أمان',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:blue),
      scaffoldBackgroundColor:bg,cardTheme:const CardThemeData(color:Colors.white,elevation:0)),
    home:const Dashboard());
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard> {
  final Repository repo=DemoRepository();
  final MapController map=MapController();
  final search=TextEditingController();
  List<Report> data=[]; List<Facility> sites=[];
  bool loading=true; String? error; int page=0,days=7;
  String query=''; Status? statusFilter; String? priorityFilter;
  bool showReports=true,showHospitals=true,showClinics=true;
  static const titles=['Vue générale','Centre des alertes','Carte opérationnelle','Établissements de santé','Analyses & statistiques','Paramètres'];
  static const icons=[Icons.space_dashboard,Icons.notifications_active_outlined,Icons.map_outlined,Icons.local_hospital_outlined,Icons.query_stats,Icons.settings_outlined];
  @override void initState(){super.initState();load();}
  @override void dispose(){search.dispose();map.dispose();super.dispose();}
  Future<void> load() async {
    setState(()=>{loading=true,error=null});
    try {final r=await repo.reports();final f=await repo.facilities();if(!mounted)return;setState(()=>{data=r,sites=f,loading=false});}
    catch(e){if(!mounted)return;setState(()=>{error=e.toString(),loading=false});}
  }
  List<Report> get period {
    if(days==0)return data;
    final cutoff=DateTime.now().subtract(Duration(days:days));
    return data.where((r)=>r.time.isAfter(cutoff)).toList();
  }
  List<Report> get filtered {
    final q=query.toLowerCase().trim();
    final a=period.where((r)=>(statusFilter==null||r.status==statusFilter)&&
      (priorityFilter==null||r.priority==priorityFilter)&&
      (q.isEmpty||'${r.id} ${r.location} ${r.state}'.toLowerCase().contains(q))).toList();
    a.sort((x,y)=>y.time.compareTo(x.time));return a;
  }
  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(ctx,c){
    final wide=c.maxWidth>=980;
    return Scaffold(drawer:wide?null:Drawer(backgroundColor:navy,child:SafeArea(child:sidebar(true))),
      body:Row(children:[if(wide)SizedBox(width:248,child:sidebar(false)),
        Expanded(child:Column(children:[header(wide),Expanded(child:loading?const Center(child:CircularProgressIndicator()):
          error!=null?errorPanel():body(wide))]))]));
  });
  Widget sidebar(bool drawer)=>Container(color:navy,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Padding(padding:EdgeInsets.fromLTRB(22,25,12,28),child:Row(children:[
      Icon(Icons.shield_rounded,color:Color(0xFF7CA2FF),size:34),SizedBox(width:10),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('AMANE',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900,letterSpacing:1.4)),
        Text('أمان • Centre de supervision',style:TextStyle(color:Color(0xFFB9C6DC),fontSize:10))])])),
    for(int i=0;i<titles.length;i++) Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:3),
      child:ListTile(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
        selected:page==i,selectedTileColor:const Color(0xFF293D64),leading:Icon(icons[i],color:page==i?Colors.white:const Color(0xFFB9C6DC)),
        title:Text(titles[i],style:TextStyle(fontSize:12,color:page==i?Colors.white:const Color(0xFFB9C6DC),fontWeight:page==i?FontWeight.bold:FontWeight.normal)),
        onTap:(){setState(()=>page=i);if(drawer)Navigator.pop(context);})),
    const Spacer(),Container(margin:const EdgeInsets.all(15),padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:const Color(0xFF1A2948),borderRadius:BorderRadius.circular(12)),
      child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('● MODE DÉMONSTRATION',style:TextStyle(color:Color(0xFFFFCF7A),fontSize:10,fontWeight:FontWeight.bold)),
        SizedBox(height:7),Text('Les signalements et établissements affichés sont fictifs.',style:TextStyle(color:Color(0xFFB9C6DC),fontSize:11,height:1.4))]))
  ]));
  Widget header(bool wide)=>Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
    decoration:const BoxDecoration(color:Colors.white,border:Border(bottom:BorderSide(color:line))),
    child:SafeArea(bottom:false,child:Row(children:[
      if(!wide)Builder(builder:(c)=>IconButton(onPressed:()=>Scaffold.of(c).openDrawer(),icon:const Icon(Icons.menu))),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(titles[page],style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:navy)),
        const Text('Supervision des alertes et aide à la décision',style:TextStyle(fontSize:10,color:muted))])),
      if(wide)const Chip(avatar:Icon(Icons.science_outlined,size:15,color:orange),label:Text('DÉMO',style:TextStyle(fontSize:10)),backgroundColor:Color(0xFFFFF4E2)),
      IconButton(tooltip:'Recharger',onPressed:load,icon:const Icon(Icons.refresh)),
      IconButton(tooltip:'Nouvelles alertes',onPressed:()=>setState(()=>page=1),icon:const Icon(Icons.notifications_none)),
    ])));
  Widget body(bool wide){switch(page){case 0:return overview(wide);case 1:return alerts();case 2:return mapPage();case 3:return facilities();case 4:return analytics(wide);default:return settings();}}
  Widget scroll(List<Widget> children)=>ListView(padding:const EdgeInsets.all(18),children:children);
  Widget panel(Widget child,{EdgeInsets padding=const EdgeInsets.all(17)})=>Container(padding:padding,
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:line),
      boxShadow:const [BoxShadow(color:Color(0x05000000),blurRadius:12,offset:Offset(0,4))]),child:child);
  Widget title(String t,{String? sub,Widget? trailing})=>Row(children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800,color:navy)),
      if(sub!=null)Padding(padding:const EdgeInsets.only(top:4),child:Text(sub,style:const TextStyle(fontSize:11,color:muted)))])),if(trailing!=null)trailing]);
  Widget pill(String text,Color color)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
    decoration:BoxDecoration(color:color.withOpacity(.11),borderRadius:BorderRadius.circular(20)),child:Text(text,style:TextStyle(color:color,fontSize:10,fontWeight:FontWeight.w800)));
  Color pColor(String p)=>p=='P1'?red:p=='P2'?orange:green;
  String date(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  Widget periodSelect()=>DropdownButton<int>(value:days,underline:const SizedBox(),items:const[
    DropdownMenuItem(value:1,child:Text('24 h')),DropdownMenuItem(value:7,child:Text('7 jours')),
    DropdownMenuItem(value:14,child:Text('14 jours')),DropdownMenuItem(value:0,child:Text('Tout'))],
    onChanged:(v){if(v!=null)setState(()=>days=v);});
  Widget overview(bool wide){
    final a=period;final open=a.where((r)=>r.status!=Status.traite).length;
    final kpis=[
      ('Signalements','${a.length}',Icons.warning_amber_rounded,blue,'Signalements sur la période'),
      ('À traiter','$open',Icons.pending_actions,orange,'Nouveaux et en cours'),
      ('Priorité critique','${a.where((r)=>r.priority=='P1'&&r.status!=Status.traite).length}',Icons.crisis_alert,red,'À examiner en premier'),
      ('Victimes déclarées','${a.fold<int>(0,(s,r)=>s+r.victims)}',Icons.groups_outlined,teal,'Total déclaré par témoins')];
    return scroll([
      Row(children:[const Expanded(child:Text('Tableau de bord',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy))),periodSelect()]),
      const SizedBox(height:4),const Text('Vue synthétique de l’activité AMANE.',style:TextStyle(color:muted,fontSize:12)),const SizedBox(height:16),
      GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:wide?4:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:wide?1.7:1.45,
        children:kpis.map((k)=>panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:38,height:38,decoration:BoxDecoration(color:k.$4.withOpacity(.1),borderRadius:BorderRadius.circular(11)),child:Icon(k.$3,color:k.$4)),
          const Spacer(),Text(k.$2,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:navy)),
          Text(k.$1,style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold,color:navy)),const SizedBox(height:4),
          Text(k.$5,style:const TextStyle(fontSize:9,color:muted),maxLines:2,overflow:TextOverflow.ellipsis)
        ]),padding:const EdgeInsets.all(14))).toList()),
      const SizedBox(height:14),
      wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:3,child:mapPanel(365)),const SizedBox(width:14),Expanded(flex:2,child:urgentPanel())])
        :Column(children:[mapPanel(290),const SizedBox(height:14),urgentPanel()]),
      const SizedBox(height:14),
      wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:trend()),const SizedBox(width:14),Expanded(child:statusPanel())])
        :Column(children:[trend(),const SizedBox(height:14),statusPanel()]),
      const SizedBox(height:10),const Text('Prototype de démonstration : aucun signalement n’est transmis aux secours.',style:TextStyle(fontSize:11,color:muted))
    ]);
  }
  Widget reportTile(Report r)=>InkWell(onTap:()=>showReport(r),child:Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Row(children:[
    Container(width:4,height:42,decoration:BoxDecoration(color:pColor(r.priority),borderRadius:BorderRadius.circular(5))),const SizedBox(width:10),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${r.id} · ${r.location}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:navy),maxLines:1,overflow:TextOverflow.ellipsis),
      const SizedBox(height:4),Text('${r.victims} victime(s) · ${date(r.time)}',style:const TextStyle(fontSize:10,color:muted),maxLines:1,overflow:TextOverflow.ellipsis)])),
    const SizedBox(width:7),pill(r.priority,pColor(r.priority)),const SizedBox(width:5),pill(r.status.label,r.status.color)
  ])));
  Widget urgentPanel(){
    final a=period.where((r)=>r.status!=Status.traite).toList()..sort((x,y)=>x.priority.compareTo(y.priority));
    return panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      title('Alertes à examiner',sub:'Signalements non clôturés',trailing:TextButton(onPressed:()=>setState(()=>page=1),child:const Text('Tout voir'))),
      if(a.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Aucune alerte ouverte.',style:TextStyle(color:muted))),
      ...a.take(6).map((r)=>Column(children:[reportTile(r),const Divider(height:1,color:line)]))
    ]));
  }
  Widget mapPanel(double height)=>panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    title('Carte opérationnelle',sub:'Signalements et établissements',trailing:TextButton(onPressed:()=>setState(()=>page=2),child:const Text('Ouvrir'))),
    const SizedBox(height:12),SizedBox(height:height,child:mapView()),
    const SizedBox(height:10),const Wrap(spacing:12,runSpacing:6,children:[
      _Dot(color:red,text:'P1 critique'),_Dot(color:orange,text:'P2 élevée'),_Dot(color:green,text:'P3 standard'),_Dot(color:blue,text:'Établissement')])
  ]),padding:const EdgeInsets.all(13));
  Widget mapView(){
    final markers=<Marker>[];
    if(showReports)for(final r in period){markers.add(Marker(point:LatLng(r.lat,r.lng),width:30,height:30,
      child:GestureDetector(onTap:()=>showReport(r),child:Container(decoration:BoxDecoration(color:pColor(r.priority),shape:BoxShape.circle,border:Border.all(color:Colors.white,width:2)),
        child:const Icon(Icons.car_crash,color:Colors.white,size:16)))));}
    for(final f in sites){if((f.hospital&&!showHospitals)||(!f.hospital&&!showClinics))continue;
      markers.add(Marker(point:LatLng(f.lat,f.lng),width:28,height:30,child:GestureDetector(onTap:()=>showFacility(f),
        child:Container(decoration:BoxDecoration(color:blue,borderRadius:BorderRadius.circular(7),border:Border.all(color:Colors.white,width:2)),child:const Icon(Icons.local_hospital,color:Colors.white,size:16)))));}
    return ClipRRect(borderRadius:BorderRadius.circular(11),child:FlutterMap(mapController:map,
      options:const MapOptions(initialCenter:LatLng(32.8,3.1),initialZoom:4.7,minZoom:3,maxZoom:16),
      children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.example.flutter_dashboard'),
        MarkerLayer(markers:markers),const RichAttributionWidget(attributions:[TextSourceAttribution('© OpenStreetMap contributors')])]));
  }
  Widget alerts()=>scroll([
    Row(children:[const Expanded(child:Text('Gestion des signalements',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy))),periodSelect()]),
    const SizedBox(height:14),panel(Column(children:[
      TextField(controller:search,decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Rechercher ID, wilaya, état…',filled:true,fillColor:bg,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide.none),
        suffixIcon:query.isEmpty?null:IconButton(onPressed:(){search.clear();setState(()=>query='');},icon:const Icon(Icons.close))),onChanged:(v)=>setState(()=>query=v)),
      const SizedBox(height:12),Wrap(spacing:10,runSpacing:8,children:[
        SizedBox(width:190,child:DropdownButtonFormField<Status?>(value:statusFilter,decoration:const InputDecoration(labelText:'Statut',border:OutlineInputBorder(),isDense:true),
          items:[const DropdownMenuItem<Status?>(value:null,child:Text('Tous les statuts')),for(final s in Status.values)DropdownMenuItem<Status?>(value:s,child:Text(s.label))],onChanged:(v)=>setState(()=>statusFilter=v))),
        SizedBox(width:190,child:DropdownButtonFormField<String?>(value:priorityFilter,decoration:const InputDecoration(labelText:'Priorité',border:OutlineInputBorder(),isDense:true),
          items:const [DropdownMenuItem<String?>(value:null,child:Text('Toutes')),DropdownMenuItem<String?>(value:'P1',child:Text('P1 critique')),DropdownMenuItem<String?>(value:'P2',child:Text('P2 élevée')),DropdownMenuItem<String?>(value:'P3',child:Text('P3 standard'))],onChanged:(v)=>setState(()=>priorityFilter=v))),
        OutlinedButton.icon(onPressed:(){search.clear();setState(()=>{query='',statusFilter=null,priorityFilter=null});},icon:const Icon(Icons.filter_alt_off),label:const Text('Effacer filtres'))
      ]),
      const SizedBox(height:10),Align(alignment:Alignment.centerLeft,child:Text('${filtered.length} résultat(s)',style:const TextStyle(color:muted,fontSize:12))),
      const Divider(height:24),if(filtered.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Aucun résultat.')),
      ...filtered.map((r)=>Column(children:[reportTile(r),const Divider(height:1,color:line)]))
    ]))
  ]);
  Widget mapPage()=>scroll([
    Row(children:[const Expanded(child:Text('Carte de supervision',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy))),periodSelect()]),
    const SizedBox(height:12),panel(Wrap(spacing:8,runSpacing:8,children:[
      FilterChip(label:const Text('Signalements'),selected:showReports,onSelected:(v)=>setState(()=>showReports=v)),
      FilterChip(label:const Text('Hôpitaux'),selected:showHospitals,onSelected:(v)=>setState(()=>showHospitals=v)),
      FilterChip(label:const Text('Cliniques / polycliniques'),selected:showClinics,onSelected:(v)=>setState(()=>showClinics=v)),
      ActionChip(avatar:const Icon(Icons.center_focus_strong,size:16),label:const Text('Centrer Algérie'),onPressed:()=>map.move(const LatLng(32.8,3.1),4.7))
    ])),
    const SizedBox(height:12),mapPanel(MediaQuery.of(context).size.height*.58),
    const SizedBox(height:8),const Text('La présence d’un établissement ne confirme pas sa disponibilité ni sa capacité en temps réel.',style:TextStyle(fontSize:11,color:muted))
  ]);
  Widget facilities()=>scroll([
    const Text('Établissements de santé',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),
    const SizedBox(height:5),const Text('Référentiel de démonstration à vérifier avant tout usage réel.',style:TextStyle(color:muted,fontSize:12)),const SizedBox(height:14),
    panel(Column(children:[...sites.map((f)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(backgroundColor:blue.withOpacity(.1),child:Icon(f.hospital?Icons.local_hospital:Icons.medical_services,color:blue)),
      title:Text(f.name,style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),subtitle:Text('${f.type} · ${f.wilaya}\n${f.lat}, ${f.lng}',style:const TextStyle(fontSize:11)),isThreeLine:true,
      trailing:const Icon(Icons.chevron_right),onTap:()=>showFacility(f)))]))
  ]);
  Widget analytics(bool wide)=>scroll([
    const Text('Analyses & statistiques',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),
    const SizedBox(height:5),const Text('Les chiffres ci-dessous concernent les signalements chargés, pas le bilan national officiel.',style:TextStyle(color:muted,fontSize:12)),
    const SizedBox(height:14),wide?Row(children:[Expanded(child:trend()),const SizedBox(width:14),Expanded(child:statusPanel())]):Column(children:[trend(),const SizedBox(height:14),statusPanel()]),
    const SizedBox(height:14),panel(const Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.info_outline,color:orange),SizedBox(width:10),Expanded(child:Text('Les statistiques historiques agrégées doivent rester séparées des alertes individuelles. Importez une source officielle validée pour présenter un bilan national.',style:TextStyle(fontSize:12,color:muted,height:1.5)))]))
  ]);
  List<int> counts(){final now=DateTime.now();final today=DateTime(now.year,now.month,now.day);
    return List.generate(14,(i){final d=today.subtract(Duration(days:13-i));return data.where((r)=>!r.time.isBefore(d)&&r.time.isBefore(d.add(const Duration(days:1)))).length;});}
  Widget trend()=>panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    title('Évolution quotidienne',sub:'14 derniers jours'),const SizedBox(height:18),
    SizedBox(height:205,child:BarChart(BarChartData(
      maxY:max(4,counts().fold<int>(0,(a,b)=>a>b?a:b).toDouble()+1),alignment:BarChartAlignment.spaceAround,borderData:FlBorderData(show:false),
      gridData:FlGridData(show:true,drawVerticalLine:false,getDrawingHorizontalLine:(v)=>FlLine(color:line)),
      titlesData:FlTitlesData(topTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
        leftTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:25,interval:1,getTitlesWidget:(v,m)=>Text(v.toInt().toString(),style:const TextStyle(fontSize:9,color:muted)))),
        bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:24,interval:2,getTitlesWidget:(v,m){final d=DateTime.now().subtract(Duration(days:13-v.toInt()));return Text('${d.day}/${d.month}',style:const TextStyle(fontSize:9,color:muted));})),
      ),
      barGroups:List.generate(14,(i)=>BarChartGroupData(x:i,barRods:[BarChartRodData(toY:counts()[i].toDouble(),width:10,color:blue,borderRadius:const BorderRadius.vertical(top:Radius.circular(4)))])),
      barTouchData:BarTouchData(enabled:true,touchTooltipData:BarTouchTooltipData(getTooltipItem:(g,gi,r,ri)=>BarTooltipItem('${r.toY.toInt()} signalement(s)',const TextStyle(color:Colors.white,fontSize:11))))
    )))
  ]));
  Widget statusPanel()=>panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    title('Répartition des statuts',sub:'Traitement des signalements'),const SizedBox(height:16),
    for(final s in Status.values)...[
      Row(children:[Expanded(child:Text(s.label,style:const TextStyle(fontSize:11,color:muted))),Text('${period.where((r)=>r.status==s).length}',style:const TextStyle(fontWeight:FontWeight.bold,color:navy))]),
      const SizedBox(height:6),ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(minHeight:8,value:period.isEmpty?0:period.where((r)=>r.status==s).length/period.length,backgroundColor:line,color:s.color)),
      const SizedBox(height:13)
    ],
    const Divider(),Row(children:[const Expanded(child:Text('Taux traité',style:TextStyle(fontSize:11,color:muted))),Text(period.isEmpty?'—':'${(100*period.where((r)=>r.status==Status.traite).length/period.length).round()}%',style:const TextStyle(fontWeight:FontWeight.w900,color:green,fontSize:19))])
  ]));
  Widget settings()=>scroll([
    const Text('Paramètres & intégrations',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:14),
    panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      title('État de la plateforme',sub:'Configuration actuelle'),const SizedBox(height:12),
      settingRow(Icons.storage,'Source de données','Jeu fictif intégré'),
      settingRow(Icons.cloud_off,'Serveur / base de données','Non connecté'),
      settingRow(Icons.lock_outline,'Authentification','Non développée'),
      settingRow(Icons.emergency,'Transmission aux secours','Inactive — aucun envoi réel'),
      settingRow(Icons.list_alt,'Signalements chargés','${data.length}'),
      const Divider(height:25),const Text('Limites du prototype',style:TextStyle(fontWeight:FontWeight.w800,color:navy)),
      const SizedBox(height:6),const Text('Les changements de statut sont conservés uniquement en mémoire pendant cette session. Ils ne sont pas enregistrés dans Excel ni envoyés à un serveur.',style:TextStyle(fontSize:12,color:muted,height:1.5)),
      const SizedBox(height:14),Wrap(spacing:10,children:[
        FilledButton.icon(onPressed:load,icon:const Icon(Icons.refresh),label:const Text('Recharger')),
        OutlinedButton.icon(onPressed:()=>showAboutDialog(context:context,applicationName:'AMANE | أمان',applicationVersion:'Prototype',children:[const Text('Prototype de supervision. Ne remplace pas les services d’urgence et ne transmet aucune alerte.')]),icon:const Icon(Icons.info_outline),label:const Text('À propos'))
      ])
    ]))
  ]);
  Widget settingRow(IconData icon,String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(children:[
    Container(width:36,height:36,decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(9)),child:Icon(icon,color:blue,size:18)),
    const SizedBox(width:10),Expanded(child:Text(label,style:const TextStyle(fontSize:12,color:muted))),Flexible(child:Text(value,textAlign:TextAlign.end,style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold,color:navy)))
  ]));
  Widget errorPanel()=>Center(child:Padding(padding:const EdgeInsets.all(24),child:panel(Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.error_outline,color:red,size:42),const SizedBox(height:10),const Text('Chargement impossible',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    const SizedBox(height:8),Text(error??'Erreur inconnue',textAlign:TextAlign.center,style:const TextStyle(color:muted)),const SizedBox(height:12),
    FilledButton.icon(onPressed:load,icon:const Icon(Icons.refresh),label:const Text('Réessayer'))
  ]))));
  Widget detail(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    SizedBox(width:120,child:Text(label,style:const TextStyle(fontSize:11,color:muted))),Expanded(child:Text(value,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:navy)))
  ]));
  Future<void> showReport(Report r)=>showModalBottomSheet(context:context,isScrollControlled:true,backgroundColor:Colors.transparent,builder:(ctx)=>StatefulBuilder(builder:(ctx,modalSet)=>Container(
    constraints:BoxConstraints(maxHeight:MediaQuery.of(ctx).size.height*.9),padding:EdgeInsets.fromLTRB(20,18,20,22+MediaQuery.of(ctx).viewInsets.bottom),
    decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(r.id,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:navy))),pill(r.priority,pColor(r.priority)),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))]),
      Text(r.location,style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold)),const SizedBox(height:4),Text(date(r.time),style:const TextStyle(fontSize:11,color:muted)),
      const SizedBox(height:14),detail('État déclaré',r.state),detail('Victimes',r.victims.toString()),detail('Coordonnées','${r.lat.toStringAsFixed(5)}, ${r.lng.toStringAsFixed(5)}'),
      const SizedBox(height:14),const Text('Mettre à jour le statut',style:TextStyle(fontWeight:FontWeight.bold,color:navy)),const SizedBox(height:8),
      DropdownButtonFormField<Status>(value:r.status,decoration:const InputDecoration(border:OutlineInputBorder()),items:[for(final s in Status.values)DropdownMenuItem(value:s,child:Text(s.label))],onChanged:(v){if(v!=null)modalSet(()=>r.status=v);}),
      const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()async{await repo.update(r,r.status);if(!mounted)return;setState((){});Navigator.pop(ctx);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Statut mis à jour pour cette session.')));},icon:const Icon(Icons.save),label:const Text('Enregistrer le statut'))),
      const SizedBox(height:8),const Text('Démo : la modification n’est pas enregistrée dans une base distante.',style:TextStyle(fontSize:10,color:muted))
    ]))
  )));
  Future<void> showFacility(Facility f)=>showModalBottomSheet(context:context,backgroundColor:Colors.transparent,builder:(ctx)=>Container(
    padding:const EdgeInsets.all(22),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
    child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Icon(Icons.local_hospital,color:blue,size:28),const SizedBox(width:10),Expanded(child:Text(f.name,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(ctx),icon:const Icon(Icons.close))]),
      detail('Type',f.type),detail('Wilaya',f.wilaya),detail('Coordonnées','${f.lat}, ${f.lng}'),
      const SizedBox(height:8),const Text('Disponibilité et capacité non vérifiées en temps réel.',style:TextStyle(fontSize:11,color:muted)),
      const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:(){Navigator.pop(ctx);setState(()=>page=2);map.move(LatLng(f.lat,f.lng),11);},child:const Text('Voir sur la carte')))
    ])
  ));
}
class _Dot extends StatelessWidget {
  const _Dot({required this.color,required this.text});final Color color;final String text;
  @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[
    Container(width:8,height:8,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:5),Text(text,style:const TextStyle(fontSize:10,color:muted))
  ]);
}
