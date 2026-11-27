import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/fleet_models.dart';
import 'storage/fleet_store.dart';
import 'theme/app_theme.dart';

const apkUrl = 'https://github.com/kennedy-blip/bima-fleet/releases/download/BimaFleet-latest/app-release.apk';
final money = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
String dateText(DateTime d) => DateFormat('dd MMM yyyy').format(d);
String uid() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';

class FleetController extends ChangeNotifier {
  FleetController(this.store);
  final FleetStore store;
  List<FleetVehicle> vehicles = [];
  List<ServiceRecord> services = [];
  int threshold = 30;
  FleetTheme theme = FleetTheme.transitObsidian;
  bool manager = true;
  Future<void> load() async {
    vehicles = store.vehicles; services = store.services; threshold = store.threshold;
    notifyListeners();
  }
  Future<void> addVehicle(FleetVehicle v) async { vehicles = [...vehicles, v]; await store.saveVehicles(vehicles); notifyListeners(); }
  Future<void> updateVehicle(FleetVehicle v) async { vehicles = vehicles.map((x) => x.id == v.id ? v : x).toList(); await store.saveVehicles(vehicles); notifyListeners(); }
  Future<void> removeVehicle(String id) async { vehicles = vehicles.where((x) => x.id != id).toList(); await store.saveVehicles(vehicles); notifyListeners(); }
  Future<void> addService(ServiceRecord s) async {
    services = [s, ...services]; final i = vehicles.indexWhere((v) => v.id == s.vehicleId);
    if (i >= 0) {
      var v = vehicles[i].copyWith(odometer: max(vehicles[i].odometer, s.odometer));
      if (s.type == 'Oil') v = v.copyWith(lastOilAt: s.odometer);
      if (s.type == 'Tyres') v = v.copyWith(lastTyreAt: s.odometer);
      if (s.type == 'Brakes') v = v.copyWith(lastBrakeAt: s.odometer);
      vehicles = [...vehicles]..[i] = v;
      await store.saveVehicles(vehicles);
    }
    await store.saveServices(services); notifyListeners();
  }
  Future<void> updateOdometer(FleetVehicle v, int value) async {
    if (value < v.odometer) throw ArgumentError('Odometer cannot be lower than the current reading.');
    await updateVehicle(v.copyWith(odometer: value));
  }
  Future<void> setThreshold(int v) async { threshold = v; await store.setThreshold(v); notifyListeners(); }
  int get expiredCount => vehicles.where((v) => [v.insuranceExpiry,v.inspectionExpiry,v.licenseExpiry].any((d)=>v.stateFor(d,threshold:threshold)==ComplianceState.expired)).length;
  int get dueCount => vehicles.where((v) => [v.insuranceExpiry,v.inspectionExpiry,v.licenseExpiry].any((d)=>v.stateFor(d,threshold:threshold)==ComplianceState.expiringSoon)).length;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = FleetStore(); await store.init();
  final controller = FleetController(store); await controller.load();
  runApp(BimaFleetApp(controller: controller));
}

class BimaFleetApp extends StatelessWidget {
  const BimaFleetApp({super.key, required this.controller});
  final FleetController controller;
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (_,__) => MaterialApp(
      debugShowCheckedModeBanner: false, title: 'BimaFleet',
      theme: AppTheme.data(controller.theme),
      home: FleetShell(controller: controller)));
}

class FleetShell extends StatefulWidget {
  const FleetShell({super.key, required this.controller});
  final FleetController controller;
  @override State<FleetShell> createState() => _FleetShellState();
}
class _FleetShellState extends State<FleetShell> {
  int tab = 0;
  FleetController get c => widget.controller;
  @override Widget build(BuildContext context) {
    final pages = [FleetScreen(c), ServiceScreen(c), RenewalsScreen(c), SettingsScreen(c)];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [Container(width: 36,height:36,decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha:.16),borderRadius: BorderRadius.circular(12)),child: Icon(Icons.local_shipping_rounded,color:Theme.of(context).colorScheme.primary)), const SizedBox(width:10), const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('BimaFleet',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),Text('FLEET OPERATIONS OS',style:TextStyle(fontSize:9,letterSpacing:1.5))])]),
        actions: [PopupMenuButton<bool>(tooltip:'Switch role', onSelected:(v)=>setState(()=>c.manager=v), itemBuilder:(_)=>const [PopupMenuItem(value:true,child:Text('Fleet Manager / SACCO Admin')),PopupMenuItem(value:false,child:Text('Driver / Yard Clerk'))], child: Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Chip(avatar:Icon(c.manager?Icons.admin_panel_settings:Icons.badge,size:16),label:Text(c.manager?'MANAGER':'DRIVER'))))]),
      body: AnimatedSwitcher(duration:const Duration(milliseconds:250),child: KeyedSubtree(key:ValueKey(tab),child:pages[tab])),
      bottomNavigationBar: NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [
        NavigationDestination(icon:Icon(Icons.directions_car_outlined),selectedIcon:Icon(Icons.directions_car),label:'Fleet'),
        NavigationDestination(icon:Icon(Icons.build_circle_outlined),selectedIcon:Icon(Icons.build_circle),label:'Service'),
        NavigationDestination(icon:Icon(Icons.event_available_outlined),selectedIcon:Icon(Icons.event_available),label:'Renewals'),
        NavigationDestination(icon:Icon(Icons.tune),label:'Settings'),
      ]),
    );
  }
}

class FleetScreen extends StatelessWidget {
  const FleetScreen(this.c,{super.key}); final FleetController c;
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.fromLTRB(16,8,16,28),children:[
    _hero(context,'Keep every vehicle\nroad-ready.','Compliance, service and renewals in one offline ledger.'),
    const SizedBox(height:16),
    Row(children:[Expanded(child:_metric(context,'VEHICLES','${c.vehicles.length}',Icons.local_shipping)),const SizedBox(width:10),Expanded(child:_metric(context,'EXPIRED','${c.expiredCount}',Icons.error_outline, danger:c.expiredCount>0)),const SizedBox(width:10),Expanded(child:_metric(context,'DUE SOON','${c.dueCount}',Icons.schedule,warning:c.dueCount>0))]),
    const SizedBox(height:20),
    _sectionTitle('Fleet register',trailing:c.manager?TextButton.icon(onPressed:()=>_vehicleDialog(context,c),icon:const Icon(Icons.add),label:const Text('Add vehicle')):null),
    if(c.vehicles.isEmpty) _empty(context,'No vehicles registered','Add your first vehicle to start tracking insurance, inspection and licence dates.',Icons.directions_car_filled_outlined)
    else ...c.vehicles.map((v)=>_vehicleCard(context,c,v)),
  ]);
}

class ServiceScreen extends StatelessWidget {
  const ServiceScreen(this.c,{super.key}); final FleetController c;
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.all(16),children:[
    _hero(context,'Preventive service','Track odometer readings and keep maintenance history close at hand.'),
    const SizedBox(height:16),
    _sectionTitle('Maintenance watch',trailing:TextButton.icon(onPressed:c.vehicles.isEmpty?null:()=>_serviceDialog(context,c),icon:const Icon(Icons.add),label:const Text('Log service'))),
    if(c.vehicles.isEmpty) _empty(context,'Add a vehicle first','Service entries are attached to a vehicle record.',Icons.build)
    else ...c.vehicles.map((v)=>_maintenanceCard(context,c,v)),
    const SizedBox(height:18),_sectionTitle('Service history'),
    if(c.services.isEmpty) _empty(context,'No service entries yet','Your service receipts and garage notes will appear here.',Icons.receipt_long)
    else ...c.services.map((s){final matches=c.vehicles.where((x)=>x.id==s.vehicleId);final v=matches.isEmpty?null:matches.first;return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.build)),title:Text('${s.type} · ${v?.plate??'Vehicle removed'}'),subtitle:Text('${dateText(s.date)} · ${s.odometer} km · ${s.garage}'),trailing:Text(money.format(s.cost),style:const TextStyle(fontWeight:FontWeight.bold))));}),
  ]);
}

class RenewalsScreen extends StatelessWidget {
  const RenewalsScreen(this.c,{super.key}); final FleetController c;
  @override Widget build(BuildContext context) {
    final items=<({FleetVehicle v,String label,DateTime date})>[];
    for(final v in c.vehicles){items.add((v:v,label:'Insurance',date:v.insuranceExpiry));items.add((v:v,label:'Inspection',date:v.inspectionExpiry));items.add((v:v,label:'Vehicle licence',date:v.licenseExpiry));}
    items.sort((a,b)=>a.date.compareTo(b.date));
    final active=items.where((x)=>x.v.daysUntil(x.date)<=60).toList();
    return ListView(padding:const EdgeInsets.all(16),children:[
      _hero(context,'Renew before downtime','A clear queue of expiry dates across your fleet.'),
      const SizedBox(height:16),
      Row(children:[Expanded(child:_metric(context,'OVERDUE','${active.where((x)=>x.v.daysUntil(x.date)<0).length}',Icons.warning_amber_rounded,danger:true)),const SizedBox(width:10),Expanded(child:_metric(context,'NEXT 60 DAYS','${active.where((x)=>x.v.daysUntil(x.date)>=0).length}',Icons.calendar_month))]),
      const SizedBox(height:20),_sectionTitle('Renewal alert queue'),
      if(active.isEmpty)_empty(context,'No renewals in the next 60 days','Dates beyond this window are not shown in this queue.',Icons.event_available)
      else ...active.map((x){final days=x.v.daysUntil(x.date);final color=days<0?Colors.red:days<=c.threshold?Colors.orange:Colors.green;return Card(child:ListTile(leading:CircleAvatar(backgroundColor:color.withValues(alpha:.15),child:Icon(days<0?Icons.error:Icons.event,color:color)),title:Text('${x.v.plate} · ${x.label}',style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${x.v.model} · ${dateText(x.date)}'),trailing:Text(days<0?'${days.abs()}d overdue':'${days}d left',style:TextStyle(color:color,fontWeight:FontWeight.bold))));}),
      const SizedBox(height:18),_sectionTitle('Budget planning'),
      AppTheme.glass(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Renewal fee estimates',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:6),const Text('Add estimated fees in your fleet budget workflow. Actual fees vary by vehicle class and issuing authority.'),const SizedBox(height:12),Text('${active.length} renewal item(s) need review',style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.bold))])),
    ]);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(this.c,{super.key}); final FleetController c;
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    _hero(context,'Control room','Personalize the workspace and protect your local fleet records.'),
    const SizedBox(height:16),_sectionTitle('Appearance'),
    Card(child:Column(children:FleetTheme.values.map((t)=>RadioListTile<FleetTheme>(value:t,groupValue:c.theme,title:Text(switch(t){FleetTheme.transitObsidian=>'Transit Obsidian',FleetTheme.daylightYard=>'Daylight Yard',FleetTheme.roadside=>'High-Contrast Roadside'}),subtitle:Text(switch(t){FleetTheme.transitObsidian=>'Dark glass · cyan and amber',FleetTheme.daylightYard=>'Light glass · high-clarity status',FleetTheme.roadside=>'Bold dark · bright roadside figures'}),onChanged:(v){if(v!=null)c.theme=v; c.notifyListeners();})).toList())),
    const SizedBox(height:16),_sectionTitle('Access & permissions'),
    Card(child:SwitchListTile(value:c.manager,onChanged:(v){c.manager=v;c.notifyListeners();},title:Text(c.manager?'Fleet Manager / SACCO Admin':'Driver / Yard Clerk'),subtitle:Text(c.manager?'Can edit vehicles, rules, budgets and exports.':'Can log odometers and service; cannot edit or delete fleet records.'),secondary:const Icon(Icons.security))),
    const SizedBox(height:16),_sectionTitle('Compliance rules'),
    Card(child:ListTile(leading:const Icon(Icons.notifications_active_outlined),title:const Text('Expiring soon threshold'),subtitle:Text('${c.threshold} days before expiry'),trailing:c.manager?DropdownButton<int>(value:c.threshold,items:[7,14,21,30,45,60].map((n)=>DropdownMenuItem(value:n,child:Text('$n days'))).toList(),onChanged:(v){if(v!=null)c.setThreshold(v);}):null)),
    const SizedBox(height:16),_sectionTitle('Data & APK center'),
    Card(child:Column(children:[
      ListTile(leading:const Icon(Icons.storage),title:const Text('Local storage'),subtitle:Text(c.store.storageStatus)),
      ListTile(leading:const Icon(Icons.ios_share),title:const Text('Export fleet backup'),subtitle:const Text('Share a JSON copy of vehicles and service history'),onTap:()async{await Share.share(c.store.exportJson(),subject:'BimaFleet data backup');}),
      ListTile(leading:const Icon(Icons.android),title:const Text('Download Android APK'),subtitle:const Text('Get the latest release build'),trailing:const Icon(Icons.download),onTap:()async{final uri=Uri.parse(apkUrl);if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&context.mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not open the APK release page.')));}}),
      ListTile(leading:const Icon(Icons.info_outline),title:const Text('BimaFleet v1.0.0'),subtitle:const Text('Offline-first vehicle compliance ledger')),
    ])),
    const SizedBox(height:12),const Text('Data is stored locally on this device/browser. Export backups regularly. This app does not verify government records or automatically send renewal reminders.',style:TextStyle(fontSize:12,color:Colors.grey)),
  ]);
}

Widget _hero(BuildContext context,String title,String sub)=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:LinearGradient(colors:[Theme.of(context).colorScheme.primary.withValues(alpha:.25),Theme.of(context).colorScheme.secondary.withValues(alpha:.08)]),border:Border.all(color:Theme.of(context).colorScheme.primary.withValues(alpha:.2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(sub,style:TextStyle(color:Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha:.75))),const SizedBox(height:14),Row(children:[const Icon(Icons.wifi_off,size:15),const SizedBox(width:6),const Text('OFFLINE-READY LOCAL LEDGER',style:TextStyle(fontSize:10,letterSpacing:1.2,fontWeight:FontWeight.bold))])]);
Widget _metric(BuildContext context,String label,String value,IconData icon,{bool danger=false,bool warning=false})=>AppTheme.glass(padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:18,color:danger?Colors.red:warning?Colors.orange:Theme.of(context).colorScheme.primary),const SizedBox(height:10),Text(value,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(fontSize:9,letterSpacing:.8,fontWeight:FontWeight.bold),maxLines:1,overflow:TextOverflow.ellipsis)]));
Widget _sectionTitle(String title,{Widget? trailing})=>Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800))),if(trailing!=null)trailing]));
Widget _empty(BuildContext context,String title,String sub,IconData icon)=>AppTheme.glass(child:Column(children:[Icon(icon,size:34,color:Theme.of(context).colorScheme.primary),const SizedBox(height:10),Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(sub,textAlign:TextAlign.center,style:const TextStyle(color:Colors.grey))]));
Widget _statusChip(FleetVehicle v,DateTime d,FleetController c){final state=v.stateFor(d,threshold:c.threshold);final color=state==ComplianceState.expired?Colors.red:state==ComplianceState.expiringSoon?Colors.orange:Colors.green;final label=state==ComplianceState.expired?'EXPIRED':state==ComplianceState.expiringSoon?'DUE SOON':'VALID';return Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:color.withValues(alpha:.14),borderRadius:BorderRadius.circular(30)),child:Text(label,style:TextStyle(color:color,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.5)));}
Widget _vehicleCard(BuildContext context,FleetController c,FleetVehicle v)=>Card(margin:const EdgeInsets.only(bottom:10),child:ExpansionTile(leading:CircleAvatar(child:const Icon(Icons.local_shipping),backgroundColor:Theme.of(context).colorScheme.primary.withValues(alpha:.14)),title:Text(v.plate,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${v.model} · ${v.driver}'),childrenPadding:const EdgeInsets.fromLTRB(16,0,16,16),children:[
  _expiryLine('Insurance',v,v.insuranceExpiry,c),_expiryLine('Inspection',v,v.inspectionExpiry,c),_expiryLine('Vehicle licence',v,v.licenseExpiry,c),
  const Divider(),Row(children:[Expanded(child:Text('Odometer  ${v.odometer} km',style:const TextStyle(fontWeight:FontWeight.bold))),TextButton(onPressed:()=>_odometerDialog(context,c,v),child:const Text('Update km'))]),
  if(c.manager)Row(children:[TextButton.icon(onPressed:()=>_vehicleDialog(context,c,existing:v),icon:const Icon(Icons.edit),label:const Text('Edit')),const Spacer(),TextButton.icon(onPressed:()async{final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete vehicle?'),content:Text('Remove ${v.plate} from the fleet register?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));if(ok==true)await c.removeVehicle(v.id);},icon:const Icon(Icons.delete_outline,color:Colors.red),label:const Text('Delete'))])
]));
Widget _expiryLine(String label,FleetVehicle v,DateTime d,FleetController c)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[Expanded(child:Text('$label · ${dateText(d)}')),Text('${v.daysUntil(d)}d',style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(width:8),_statusChip(v,d,c)]));
Widget _maintenanceCard(BuildContext context,FleetController c,FleetVehicle v){final checks=[('Oil',v.lastOilAt,v.oilInterval),('Tyres',v.lastTyreAt,v.tyreInterval),('Brakes',v.lastBrakeAt,v.brakeInterval)];return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${v.plate} · ${v.model}',style:const TextStyle(fontWeight:FontWeight.w800)),Text('Current: ${v.odometer} km',style:const TextStyle(color:Colors.grey)),const SizedBox(height:10),...checks.map((x){final due=x.$1=='Oil'?v.odometer-(x.$2+x.$3):v.odometer-(x.$2+x.$3);final isDue=x.$2==0||due>=0;return Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Expanded(child:Text('${x.$1} service')),Text(x.$2==0?'Not logged':'${max(0,x.$2+x.$3-v.odometer)} km remaining',style:TextStyle(color:isDue?Colors.orange:Colors.green,fontWeight:FontWeight.bold,fontSize:12))]));}),if(!c.manager)Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>_odometerDialog(context,c,v),child:const Text('Update odometer')))])));}
Future<void> _vehicleDialog(BuildContext context,FleetController c,{FleetVehicle? existing})async{
  final plate=TextEditingController(text:existing?.plate??''),model=TextEditingController(text:existing?.model??''),driver=TextEditingController(text:existing?.driver??'');
  DateTime insurance=existing?.insuranceExpiry??DateTime.now().add(const Duration(days:365)),inspection=existing?.inspectionExpiry??DateTime.now().add(const Duration(days:180)),license=existing?.licenseExpiry??DateTime.now().add(const Duration(days:365));
  Future<DateTime?> pick(DateTime d) => showDatePicker(context:context,initialDate:d,firstDate:DateTime(2020),lastDate:DateTime(2045));
  await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:Text(existing==null?'Register vehicle':'Edit vehicle'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:plate,decoration:const InputDecoration(labelText:'Registration / plate number')),
    TextField(controller:model,decoration:const InputDecoration(labelText:'Vehicle make & model')),
    TextField(controller:driver,decoration:const InputDecoration(labelText:'Assigned driver')),
    const SizedBox(height:10),
    ListTile(contentPadding:EdgeInsets.zero,title:const Text('Insurance expiry'),subtitle:Text(dateText(insurance)),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await pick(insurance);if(d!=null)set(()=>insurance=d);}),
    ListTile(contentPadding:EdgeInsets.zero,title:const Text('Inspection expiry'),subtitle:Text(dateText(inspection)),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await pick(inspection);if(d!=null)set(()=>inspection=d);}),
    ListTile(contentPadding:EdgeInsets.zero,title:const Text('Vehicle licence expiry'),subtitle:Text(dateText(license)),trailing:const Icon(Icons.calendar_month),onTap:()async{final d=await pick(license);if(d!=null)set(()=>license=d);}),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()async{if(plate.text.trim().isEmpty||model.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Plate and model are required.')));return;}final v=FleetVehicle(id:existing?.id??uid(),plate:plate.text.trim().toUpperCase(),model:model.text.trim(),driver:driver.text.trim().isEmpty?'Unassigned':driver.text.trim(),insuranceExpiry:insurance,inspectionExpiry:inspection,licenseExpiry:license,odometer:existing?.odometer??0,oilInterval:existing?.oilInterval??5000,tyreInterval:existing?.tyreInterval??40000,brakeInterval:existing?.brakeInterval??20000,lastOilAt:existing?.lastOilAt??0,lastTyreAt:existing?.lastTyreAt??0,lastBrakeAt:existing?.lastBrakeAt??0);if(existing==null)await c.addVehicle(v);else await c.updateVehicle(v);if(ctx.mounted)Navigator.pop(ctx);},child:const Text('Save vehicle'))]})));
}
Future<void> _odometerDialog(BuildContext context,FleetController c,FleetVehicle v)async{
  final ctl=TextEditingController(text:'${v.odometer}');
  await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('Update ${v.plate} odometer'),content:TextField(controller:ctl,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Current kilometres')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()async{final n=int.tryParse(ctl.text);if(n==null||n<v.odometer){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a valid reading not below the current value.')));return;}await c.updateOdometer(v,n);if(ctx.mounted)Navigator.pop(ctx);},child:const Text('Update'))]));
}
Future<void> _serviceDialog(BuildContext context,FleetController c)async{
  String vehicle=c.vehicles.first.id,type='Oil';final odo=TextEditingController(text:'${c.vehicles.first.odometer}'),cost=TextEditingController(text:'0'),garage=TextEditingController(),notes=TextEditingController();DateTime date=DateTime.now();
  await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:const Text('Log service entry'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(value:vehicle,decoration:const InputDecoration(labelText:'Vehicle'),items:c.vehicles.map((v)=>DropdownMenuItem(value:v.id,child:Text(v.plate))).toList(),onChanged:(v){if(v!=null)set(()=>vehicle=v);}),
    DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Service type'),items:['Oil','Tyres','Brakes','General'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)set(()=>type=v);}),
    TextField(controller:odo,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Odometer km')),
    TextField(controller:cost,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cost (KES)')),
    TextField(controller:garage,decoration:const InputDecoration(labelText:'Garage / supplier')),
    TextField(controller:notes,decoration:const InputDecoration(labelText:'Notes / receipt reference')),
    ListTile(contentPadding:EdgeInsets.zero,title:const Text('Service date'),subtitle:Text(dateText(date)),onTap:()async{final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime.now().add(const Duration(days:1)));if(d!=null)set(()=>date=d);}),
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()async{final km=int.tryParse(odo.text),amount=double.tryParse(cost.text);if(km==null||amount==null||amount<0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a valid odometer and non-negative cost.')));return;}await c.addService(ServiceRecord(id:uid(),vehicleId:vehicle,type:type,date:date,odometer:km,cost:amount,garage:garage.text.trim(),notes:notes.text.trim()));if(ctx.mounted)Navigator.pop(ctx);},child:const Text('Save entry'))]})));
}
