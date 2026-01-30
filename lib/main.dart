import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ARInternationalApp());
}

class ARInternationalApp extends StatelessWidget {
  const ARInternationalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AR International',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const SplashScreen(),
    );
  }
}

/* ================= SPLASH SCREEN ================= */
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthWrapper()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff, size: 100, color: Colors.blueAccent),
            SizedBox(height: 20),
            Text("AR INTERNATIONAL", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2)),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }
}

/* ================= AUTH WRAPPER ================= */
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return snap.hasData ? const Dashboard() : const LoginScreen();
      },
    );
  }
}

/* ================= LOGIN SCREEN ================= */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), pass = TextEditingController();
  bool loading = false;

  login() async {
    if (email.text.isEmpty || pass.text.isEmpty) return;
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: pass.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login Failed!")));
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Login to Dashboard", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: email, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: pass, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
              const SizedBox(height: 20),
              loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: login, child: const Text("LOGIN")),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================= DASHBOARD ================= */
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String role = "staff", search = "", selectedAgent = "All Agents";
  List<String> agents = ["All Agents"];
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadRoleAndAgents();
  }

  loadRoleAndAgents() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      final d = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
      if (d.exists) setState(() => role = d['role'] ?? "staff");
    }
    FirebaseFirestore.instance.collection('agents').snapshots().listen((s) {
      if (mounted) setState(() => agents = ["All Agents", ...s.docs.map((e) => e['name'].toString())]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AR International ($role)"),
        actions: [
          if (role == "admin") IconButton(icon: const Icon(Icons.people), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAgents()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clients').orderBy('timestamp', descending: true).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snap.data!.docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            final matchS = m['name'].toString().toLowerCase().contains(search) || m['passport'].toString().toLowerCase().contains(search);
            final matchA = selectedAgent == "All Agents" || m['agent'] == selectedAgent;
            return matchS && matchA;
          }).toList();

          double total = docs.fold(0, (sum, d) => sum + (d['payment'] ?? 0).toDouble());

          return Column(
            children: [
              if (role == "admin") Card(margin: const EdgeInsets.all(10), color: Colors.blueGrey[900], child: ListTile(title: const Text("Total Collection"), subtitle: Text("৳ ${NumberFormat('#,###').format(total)}", style: const TextStyle(fontSize: 20, color: Colors.greenAccent)))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  Expanded(child: DropdownButtonFormField(value: selectedAgent, items: agents.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => selectedAgent = v.toString()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(decoration: const InputDecoration(labelText: "Search Passport/Name"), onChanged: (v) => setState(() => search = v.toLowerCase()))),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(d['name']),
                        subtitle: Text("PP: ${d['passport']} | Agent: ${d['agent']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.print, color: Colors.blueAccent), onPressed: () => printReceipt(d)),
                            if (role == "admin") IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => docs[i].reference.delete()),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => addClientDialog(), child: const Icon(Icons.add)),
    );
  }

  /* ================= ADD CLIENT ================= */
  addClientDialog() {
    final name = TextEditingController(), passport = TextEditingController(), payment = TextEditingController();
    String? agent;
    Uint8List? img;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("New Client Entry"),
          content: SingleChildScrollView(
            child: Column(children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
              TextField(controller: passport, decoration: const InputDecoration(labelText: "Passport No")),
              TextField(controller: payment, decoration: const InputDecoration(labelText: "Payment"), keyboardType: TextInputType.number),
              DropdownButtonFormField(hint: const Text("Select Agent"), items: agents.where((e) => e != "All Agents").map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => agent = v.toString()),
              const SizedBox(height: 15),
              img == null 
                ? ElevatedButton(onPressed: () async {
                    final x = await picker.pickImage(source: ImageSource.gallery);
                    if (x != null) {
                      final b = await x.readAsBytes();
                      setS(() => img = b);
                    }
                  }, child: const Text("Pick Passport Photo"))
                : Image.memory(img!, height: 100),
            ]),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (name.text.isEmpty || agent == null) return;
                String? url;
                if (img != null) {
                  final ref = FirebaseStorage.instance.ref().child('docs/${DateTime.now().msSinceEpoch}');
                  await ref.putData(img!);
                  url = await ref.getDownloadURL();
                }
                await FirebaseFirestore.instance.collection('clients').add({
                  'name': name.text,
                  'passport': passport.text.toUpperCase(),
                  'payment': double.tryParse(payment.text) ?? 0.0,
                  'agent': agent,
                  'img': url,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }

  /* ================= PRINT RECEIPT ================= */
  Future<void> printReceipt(Map<String, dynamic> d) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Column(children: [
      pw.Center(child: pw.Text("AR INTERNATIONAL", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
      pw.Divider(),
      pw.SizedBox(height: 20),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text("Client: ${d['name']}"),
        pw.Text("Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}"),
      ]),
      pw.Text("Passport: ${d['passport']}"),
      pw.Text("Agent: ${d['agent']}"),
      pw.SizedBox(height: 20),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        border: pw.Border.all(),
        child: pw.Text("Total Amount Paid: BDT ${d['payment']}/-", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 50),
      pw.Text("Authorized Signature: ___________________"),
    ])));
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}

/* ================= MANAGE AGENTS ================= */
class ManageAgents extends StatelessWidget {
  const ManageAgents({super.key});
  @override
  Widget build(BuildContext context) {
    final c = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text("Agents List")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('agents').snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(children: snap.data!.docs.map((d) => ListTile(title: Text(d['name']), trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => d.reference.delete()))).toList());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text("Add Agent"),
          content: TextField(controller: c, decoration: const InputDecoration(hintText: "Name")),
          actions: [ElevatedButton(onPressed: () {
            if (c.text.isNotEmpty) FirebaseFirestore.instance.collection('agents').add({'name': c.text});
            Navigator.pop(context);
          }, child: const Text("Add"))],
        )),
        child: const Icon(Icons.add),
      ),
    );
  }
}
