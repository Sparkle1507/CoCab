import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool isFirebaseWorking = false;

// ==========================================
// 🎨 1. CORE THEME & CONSTANTS (Polished)
// ==========================================
const Color kPremiumBlack = Color(0xFF121826);
const Color kPremiumIndigo = Color(0xFF5B5CEB);
const Color kPremiumGreen = Color(0xFF17B978);
const Color kBackgroundLight = Color(0xFFF4F6FA);
const Color kCardWhite = Color(0xFFFFFFFF);
const Color kTextGrey = Color(0xFF667085);
const Color kBorderGrey = Color(0xFFE3E7EF);

// ==========================================
// 🧠 2. NATIVE STATE MANAGEMENT
// ==========================================
class AppState {
  static final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);
  static final ValueNotifier<String> userPhone = ValueNotifier("+91 9876543210");

  static Future<void> checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isLoggedIn.value = prefs.getBool('isLoggedIn') ?? false;
    userPhone.value = prefs.getString('userPhone') ?? "+91 9876543210";
  }

  static Future<void> login(String phone) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userPhone', "+91 $phone");
    userPhone.value = "+91 $phone";
    isLoggedIn.value = true;
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try { await FirebaseAuth.instance.signOut(); } catch (e) {}
    isLoggedIn.value = false;
  }
}

class LocationData {
  final LatLng pickup;
  final String address;
  LocationData({required this.pickup, required this.address});
}

class LocationState {
  static final LatLng userHomeLocation = const LatLng(13.0827, 80.2707);
  static final ValueNotifier<LocationData> current = ValueNotifier(LocationData(pickup: userHomeLocation, address: "Fetching address..."));

  static Future<void> updateLocation(LatLng newLoc) async {
    current.value = LocationData(pickup: newLoc, address: "Fetching address...");
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${newLoc.latitude}&lon=${newLoc.longitude}&format=json');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String displayName = data['display_name'] ?? "Selected Location";
        List<String> parts = displayName.split(',');
        String shortAddress = parts.length > 2 ? "${parts[0].trim()}, ${parts[1].trim()}, ${parts[2].trim()}" : displayName;
        current.value = LocationData(pickup: newLoc, address: shortAddress);
      } else {
        current.value = LocationData(pickup: newLoc, address: "Location Selected");
      }
    } catch (e) {
      current.value = LocationData(pickup: newLoc, address: "Location Selected");
    }
  }
}

// ==========================================
// 🚀 3. APP ENTRY POINT
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await AppState.checkLogin();
  try { await Firebase.initializeApp(); isFirebaseWorking = true; } catch (e) { isFirebaseWorking = false; }
  runApp(const CabApp());
}

class CabApp extends StatelessWidget {
  const CabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppState.isLoggedIn,
      builder: (context, isLoggedIn, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CoCab Premium',
          theme: ThemeData(
             useMaterial3: true,
             primaryColor: kPremiumIndigo,
             scaffoldBackgroundColor: kBackgroundLight,
             fontFamily: 'Roboto',
             colorScheme: ColorScheme.fromSeed(seedColor: kPremiumIndigo, brightness: Brightness.light),
             appBarTheme: const AppBarTheme(
               elevation: 0,
               scrolledUnderElevation: 0,
               backgroundColor: kBackgroundLight,
               foregroundColor: kPremiumBlack,
               centerTitle: false,
               surfaceTintColor: Colors.transparent,
               systemOverlayStyle: SystemUiOverlayStyle.dark,
               titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPremiumBlack, letterSpacing: -0.6),
             ),
             inputDecorationTheme: const InputDecorationTheme(
               filled: true,
               fillColor: Colors.white,
               border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide.none),
               enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: kBorderGrey)),
               focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: kPremiumIndigo, width: 1.6)),
               contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
             ),
             elevatedButtonTheme: ElevatedButtonThemeData(
               style: ElevatedButton.styleFrom(
                 elevation: 0,
                 minimumSize: const Size(double.infinity, 54),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                 textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
               ),
             ),
             outlinedButtonTheme: OutlinedButtonThemeData(
               style: OutlinedButton.styleFrom(
                 minimumSize: const Size(double.infinity, 52),
                 side: const BorderSide(color: kBorderGrey),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                 textStyle: const TextStyle(fontWeight: FontWeight.w800),
               ),
             ),
             snackBarTheme: SnackBarThemeData(
               behavior: SnackBarBehavior.floating,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
               backgroundColor: kPremiumBlack,
               contentTextStyle: const TextStyle(fontWeight: FontWeight.w700),
             ),
           ),
          home: isLoggedIn ? const MainNavigationScreen() : const LoginScreen(),
        );
      }
    );
  }
}

// ==========================================
// 📱 4. LOGIN & OTP SCREENS
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  void _sendOtp() async {
    String phoneNumber = _phoneController.text.trim();
    if (phoneNumber.length != 10) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => OtpScreen(phone: phoneNumber)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPremiumBlack,
      body: Stack(
        children: [
          Positioned(
            top: -120, right: -80, 
            child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: kPremiumIndigo.withOpacity(0.28)))
          ),
          Positioned(
            bottom: -140, left: -80, 
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: kPremiumGreen.withOpacity(0.10)))
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 54, height: 54, 
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.10))), 
                      child: const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 30)
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(20)), 
                      child: const Row(children: [
                        Icon(Icons.shield_outlined, size: 15, color: kPremiumGreen), 
                        SizedBox(width: 6), 
                        Text('Safe & smart', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11))
                      ])
                    )
                  ]),
                  const SizedBox(height: 54),
                  const Text('Ride better.', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1.8)),
                  const SizedBox(height: 6),
                  Text('Premium rides,\nshared smartly.', style: TextStyle(color: Colors.white.withOpacity(0.66), fontSize: 20, height: 1.25, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 42),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.075), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.08))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text('Enter your mobile number', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          style: const TextStyle(fontSize: 19, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1),
                          decoration: InputDecoration(
                            counterText: '', 
                            prefixText: '+91  ', 
                            prefixStyle: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 18, fontWeight: FontWeight.w700), 
                            hintText: '00000 00000', 
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontWeight: FontWeight.w600, letterSpacing: 2), 
                            filled: true, 
                            fillColor: Colors.white.withOpacity(0.06), 
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), 
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18)
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 58, 
                          width: double.infinity, 
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOtp, 
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kPremiumBlack, disabledBackgroundColor: Colors.white24), 
                            child: _isLoading 
                              ? const SizedBox(width: 23, height: 23, child: CircularProgressIndicator(strokeWidth: 2.5, color: kPremiumBlack)) 
                              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 20)])
                          )
                        ),
                      ]
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(child: Text('By continuing, you agree to CoCab\'s terms & privacy policy.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 11, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OtpScreen extends StatelessWidget {
  final String phone;
  OtpScreen({super.key, required this.phone});
  final TextEditingController _otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPremiumBlack,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            Container(width: 68, height: 68, alignment: Alignment.center, decoration: BoxDecoration(color: kPremiumIndigo.withOpacity(0.18), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 34)),
            const SizedBox(height: 28),
            const Text('Verify your number', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.2)),
            const SizedBox(height: 8),
            Text('Enter the 6-digit code sent to +91 $phone', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.58), fontWeight: FontWeight.w500)),
            const SizedBox(height: 28),
            TextField(
              controller: _otpController, 
              keyboardType: TextInputType.number, 
              maxLength: 6, 
              textAlign: TextAlign.center, 
              autofocus: true, 
              style: const TextStyle(fontSize: 26, letterSpacing: 14, color: Colors.white, fontWeight: FontWeight.w800), 
              decoration: InputDecoration(counterText: '', filled: true, fillColor: Colors.white.withOpacity(0.07), hintText: '••••••', hintStyle: TextStyle(color: Colors.white.withOpacity(0.16), letterSpacing: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 22))
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56, 
              child: ElevatedButton(
                onPressed: () async { await AppState.login(phone); Navigator.pop(context); }, 
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kPremiumBlack), 
                child: const Text('Confirm & Continue', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))
              )
            ),
            const SizedBox(height: 14),
            TextButton(onPressed: () {}, child: Text('Didn\'t receive a code?', style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700))),
            const Spacer(),
          ]),
        ),
      ),
    );
  }
}

// ==========================================
// 🌟 5. MAIN NAVIGATION & HOME SCREEN 🌟
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [const HomeScreen(), const AllServicesScreen(), const TravelScreen(), const AccountScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96), 
              borderRadius: BorderRadius.circular(24), 
              boxShadow: [BoxShadow(color: kPremiumBlack.withOpacity(0.10), blurRadius: 28, offset: const Offset(0, 10))], 
              border: Border.all(color: Colors.white)
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: kPremiumBlack,
              unselectedItemColor: kTextGrey,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              showUnselectedLabels: true,
              items: [
                BottomNavigationBarItem(icon: _navIcon(Icons.home_filled, 0), label: 'Ride'),
                BottomNavigationBarItem(icon: _navIcon(Icons.grid_view_rounded, 1), label: 'Services'),
                BottomNavigationBarItem(icon: _navIcon(Icons.flight_takeoff_rounded, 2), label: 'Travel'),
                BottomNavigationBarItem(icon: _navIcon(Icons.person_rounded, 3), label: 'Account'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final selected = _currentIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220), 
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), 
      decoration: BoxDecoration(color: selected ? kPremiumBlack : Colors.transparent, borderRadius: BorderRadius.circular(16)), 
      child: Icon(icon, color: selected ? Colors.white : kTextGrey, size: 21)
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  Timer? _debounce;
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  final LatLng passengerB = const LatLng(13.0300, 80.1700);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => LocationState.updateLocation(LocationState.userHomeLocation));
    _startBannerAutoSlide();
  }

  void _startBannerAutoSlide() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerController.hasClients) {
        int nextIndex = (_currentBannerIndex + 1) % 5;
        _bannerController.animateToPage(nextIndex, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() { _debounce?.cancel(); _bannerTimer?.cancel(); _bannerController.dispose(); super.dispose(); }

  Future<void> _fetchRouteAndShowVehicles(String placeName, LatLng dropLatLng, {String? vehicleType}) async {
    final locState = LocationState.current.value;
    showDialog(context: context, barrierDismissible: false, builder: (c) => Center(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: const CircularProgressIndicator(color: kPremiumBlack))));
    try {
      final url = Uri.parse('http://127.0.0.1:8000/check_route?a_lat=${locState.pickup.latitude}&a_lon=${locState.pickup.longitude}&b_lat=${passengerB.latitude}&b_lon=${passengerB.longitude}&c_lat=${dropLatLng.latitude}&c_lon=${dropLatLng.longitude}');
      final response = await http.post(url);
      if(mounted) Navigator.pop(context); 
      
      if (response.statusCode == 200) {
        var baseData = jsonDecode(response.body);
        _showExactOlaBottomSheet(placeName, dropLatLng, baseData, vehicleType: vehicleType);
      }
    } catch (e) {
      if(mounted) Navigator.pop(context);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server Error! Check Backend 🖥️❌'), backgroundColor: Colors.red));
    }
  }

  void _showExactOlaBottomSheet(String destination, LatLng dropLatLng, var baseData, {String? vehicleType}) {
    int baseFare = baseData["solo_fare"] ?? 300;

    final List<Map<String, dynamic>> rides = [
      {"title":"Book Any","subtitle":"Mini, Prime Sedan, Prime Plus","eta":"1 min","priceText":"₹${(baseFare * 0.95).round()} - ₹${(baseFare * 1.35).round()}","singlePrice":baseFare,"img":"https://cdn-icons-png.flaticon.com/512/3097/3097180.png","isRange":true},
      {"title":"Auto","subtitle":"Quickest auto ride in town","eta":"1 min","priceText":"₹${(baseFare * 0.55).round()}","singlePrice":(baseFare * 0.55).round(),"img":"https://cdn-icons-png.flaticon.com/512/1048/1048313.png","isRange":false},
      {"title":"Mini","subtitle":"Comfortable, economical hatchbacks","eta":"2 mins","priceText":"₹$baseFare","singlePrice":baseFare,"img":"https://cdn-icons-png.flaticon.com/512/3725/3725112.png","isRange":false},
      {"title":"Bike","subtitle":"Beat the traffic","eta":"1 min","priceText":"₹${(baseFare * 0.35).round()}","singlePrice":(baseFare * 0.35).round(),"img":"https://cdn-icons-png.flaticon.com/512/3753/3753264.png","isRange":false},
      {"title":"Prime SUV","subtitle":"Spacious 6-seaters","eta":"4 mins","priceText":"₹${(baseFare * 1.7).round()}","singlePrice":(baseFare * 1.7).round(),"img":"https://cdn-icons-png.flaticon.com/512/3204/3204066.png","isRange":false},
      {"title":"Prime Sedan","subtitle":"Spacious sedans with top partners","eta":"3 mins","priceText":"₹${(baseFare * 1.25).round()}","singlePrice":(baseFare * 1.25).round(),"img":"https://cdn-icons-png.flaticon.com/512/3097/3097180.png","isRange":false},
      {"title":"Prime Plus","subtitle":"Top rated drivers, zero cancellations","eta":"3 mins","priceText":"₹${(baseFare * 1.5).round()}","singlePrice":(baseFare * 1.5).round(),"img":"https://cdn-icons-png.flaticon.com/512/3204/3204066.png","isRange":false},
      {"title":"Mini Non AC","subtitle":"Pocket-friendly rides","eta":"2 mins","priceText":"₹${(baseFare * 0.85).round()}","singlePrice":(baseFare * 0.85).round(),"img":"https://cdn-icons-png.flaticon.com/512/3725/3725112.png","isRange":false},
      {"title":"Parcel","subtitle":"Send packages across the city","eta":"5 mins","priceText":"₹${(baseFare * 0.4).round()}","singlePrice":(baseFare * 0.4).round(),"img":"https://cdn-icons-png.flaticon.com/512/2769/2769339.png","isRange":false},
      {"title":"Laundry","subtitle":"Doorstep pickup & drop","eta":"30 mins","priceText":"₹${(baseFare * 0.6).round()}","singlePrice":(baseFare * 0.6).round(),"img":"https://cdn-icons-png.flaticon.com/512/3003/3003984.png","isRange":false},
      {"title":"Rental","subtitle":"Hourly rentals for city tours","eta":"5 mins","priceText":"","singlePrice":0,"img":"https://cdn-icons-png.flaticon.com/512/2830/2830305.png","isRange":false},
    ];

    int selectedIndex = 0;
    if (vehicleType != null) {
      final foundIndex = rides.indexWhere((r) => r['title'] == vehicleType);
      if (foundIndex != -1) selectedIndex = foundIndex;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selectedRide = rides[selectedIndex];
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: const BoxDecoration(
              color: kCardWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false, 
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 44, height: 5, decoration: BoxDecoration(color: kBorderGrey, borderRadius: BorderRadius.circular(10))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        const Text('Choose your ride', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14), 
                          decoration: BoxDecoration(color: kBackgroundLight, borderRadius: BorderRadius.circular(18)), 
                          child: Row(
                            children: [
                              const Icon(Icons.route_rounded, color: kPremiumIndigo, size: 22), 
                              const SizedBox(width: 10), 
                              Expanded(child: Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))), 
                              const Icon(Icons.chevron_right_rounded, color: kTextGrey)
                            ]
                          )
                        ),
                      ]
                    )
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12), 
                      itemCount: rides.length, 
                      itemBuilder: (context, index) {
                        final item = rides[index];
                        final isSelected = selectedIndex == index;
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedIndex = index), 
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180), 
                            margin: const EdgeInsets.only(bottom: 9), 
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), 
                            decoration: BoxDecoration(
                              color: isSelected ? kPremiumBlack : Colors.white, 
                              borderRadius: BorderRadius.circular(20), 
                              border: Border.all(color: isSelected ? kPremiumBlack : kBorderGrey.withOpacity(0.7)), 
                              boxShadow: isSelected ? [BoxShadow(color: kPremiumBlack.withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 7))] : []
                            ), 
                            child: Row(
                              children: [
                                Container(
                                  width: 68, height: 54, padding: const EdgeInsets.all(7), 
                                  decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.10) : kBackgroundLight, borderRadius: BorderRadius.circular(15)), 
                                  child: Image.network(item['img'], fit: BoxFit.contain)
                                ), 
                                const SizedBox(width: 13), 
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(child: Text(item['title'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : kPremiumBlack))), 
                                          if (item['isRange'] == true) ...[
                                            const SizedBox(width: 5), 
                                            Icon(Icons.info_outline_rounded, size: 15, color: isSelected ? Colors.white60 : kTextGrey)
                                          ]
                                        ]
                                      ), 
                                      const SizedBox(height: 3), 
                                      Text(item['subtitle'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white70 : kTextGrey, fontWeight: FontWeight.w600)), 
                                      const SizedBox(height: 5), 
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 14, color: isSelected ? Colors.white60 : kTextGrey), 
                                          const SizedBox(width: 4), 
                                          Text(item['eta'], style: TextStyle(fontSize: 11, color: isSelected ? Colors.white70 : kTextGrey, fontWeight: FontWeight.w800))
                                        ]
                                      )
                                    ]
                                  )
                                ), 
                                const SizedBox(width: 8), 
                                Text(item['priceText'], style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : kPremiumBlack))
                              ]
                            )
                          )
                        );
                      }
                    )
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14), 
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -8))]), 
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDockAction(Icons.payments_rounded, 'Cash', kPremiumGreen)), 
                            const SizedBox(width: 10), 
                            Expanded(child: _buildDockAction(Icons.local_offer_rounded, 'Coupon', kPremiumIndigo)), 
                            const SizedBox(width: 10), 
                            Expanded(child: _buildDockAction(Icons.person_rounded, 'Myself', kTextGrey))
                          ]
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity, height: 56, 
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: kPremiumBlack, foregroundColor: Colors.white), 
                            onPressed: () { 
                              Navigator.pop(ctx); 
                              _showSoloOrShareStep2(destination, dropLatLng, baseData, selectedRide); 
                            }, 
                            child: Text(selectedRide['title'] == 'Book Any' ? 'Continue with Book Any' : 'Continue with ${selectedRide['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))
                          )
                        ),
                      ]
                    )
                  ),
                ]
              )
            ),
          );
        },
      ),
    );
  }

  Widget _buildDockAction(IconData icon, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), 
      decoration: BoxDecoration(color: kBackgroundLight, borderRadius: BorderRadius.circular(15), border: Border.all(color: kBorderGrey.withOpacity(0.55))), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(icon, size: 17, color: iconColor), 
          const SizedBox(width: 6), 
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPremiumBlack)))
        ]
      )
    );
  }

  void _showSoloOrShareStep2(String destination, LatLng dropLatLng, var baseData, Map<String, dynamic> selectedCar) {
    String selectedMode = 'shared';
    int singlePrice = selectedCar['singlePrice'];
    int soloFare = singlePrice;
    int sharedFare = (singlePrice * 0.65).round();
    bool isRental = selectedCar['title'] == 'Rental';
    String soloPriceStr = isRental ? '' : '₹$soloFare';
    String sharedPriceStr = isRental ? '' : '₹$sharedFare';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: const BoxDecoration(color: kCardWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: SafeArea(
              top: false, 
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: kBorderGrey, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 18),
                  const Text('Ride your way', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.9)),
                  const SizedBox(height: 5),
                  Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextGrey, fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => setModalState(() => selectedMode = 'solo'), 
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180), 
                      padding: const EdgeInsets.all(16), 
                      decoration: BoxDecoration(color: selectedMode == 'solo' ? kPremiumBlack : kBackgroundLight, borderRadius: BorderRadius.circular(22), border: Border.all(color: selectedMode == 'solo' ? kPremiumBlack : kBorderGrey)), 
                      child: Row(
                        children: [
                          Container(
                            width: 46, height: 46, alignment: Alignment.center, 
                            decoration: BoxDecoration(color: selectedMode == 'solo' ? Colors.white12 : Colors.white, borderRadius: BorderRadius.circular(15)), 
                            child: Icon(Icons.person_rounded, color: selectedMode == 'solo' ? Colors.white : kPremiumBlack, size: 24)
                          ), 
                          const SizedBox(width: 13), 
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text('Solo / Private', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: selectedMode == 'solo' ? Colors.white : kPremiumBlack)), 
                                const SizedBox(height: 3), 
                                Text(isRental ? 'Hourly basis' : 'Private & direct', style: TextStyle(fontSize: 12, color: selectedMode == 'solo' ? Colors.white70 : kTextGrey, fontWeight: FontWeight.w600))
                              ]
                            )
                          ), 
                          if (soloPriceStr.isNotEmpty) 
                            Text(soloPriceStr, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: selectedMode == 'solo' ? Colors.white : kPremiumBlack))
                        ]
                      )
                    )
                  ),
                  const SizedBox(height: 11),
                  GestureDetector(
                    onTap: () => setModalState(() => selectedMode = 'shared'), 
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180), 
                      padding: const EdgeInsets.all(16), 
                      decoration: BoxDecoration(color: selectedMode == 'shared' ? kPremiumIndigo : Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: selectedMode == 'shared' ? kPremiumIndigo : kBorderGrey)), 
                      child: Row(
                        children: [
                          Container(
                            width: 46, height: 46, alignment: Alignment.center, 
                            decoration: BoxDecoration(color: selectedMode == 'shared' ? Colors.white24 : kBackgroundLight, borderRadius: BorderRadius.circular(15)), 
                            child: Icon(Icons.people_alt_rounded, color: selectedMode == 'shared' ? Colors.white : kPremiumIndigo, size: 24)
                          ), 
                          const SizedBox(width: 13), 
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Row(
                                  children: [
                                    Text('CoCab Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: selectedMode == 'shared' ? Colors.white : kPremiumBlack)), 
                                    if (!isRental) ...[
                                      const SizedBox(width: 7), 
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), 
                                        decoration: BoxDecoration(color: selectedMode == 'shared' ? Colors.white : kPremiumGreen, borderRadius: BorderRadius.circular(8)), 
                                        child: Text('SAVE', style: TextStyle(color: selectedMode == 'shared' ? kPremiumIndigo : Colors.white, fontSize: 9, fontWeight: FontWeight.w900))
                                      )
                                    ]
                                  ]
                                ), 
                                const SizedBox(height: 3), 
                                Text('Share with a compatible rider', style: TextStyle(fontSize: 12, color: selectedMode == 'shared' ? Colors.white70 : kTextGrey, fontWeight: FontWeight.w600))
                              ]
                            )
                          ), 
                          if (sharedPriceStr.isNotEmpty) 
                            Text(sharedPriceStr, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white))
                        ]
                      )
                    )
                  ),
                  const SizedBox(height: 12),
                  if (!isRental && selectedMode == 'shared') 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), 
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(14)), 
                      child: Row(
                        children: [
                          const Icon(Icons.savings_rounded, color: kPremiumGreen, size: 19), 
                          const SizedBox(width: 8), 
                          Text('You save ₹${soloFare - sharedFare} on this ride', style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w800, fontSize: 12))
                        ]
                      )
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity, height: 56, 
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: selectedMode == 'solo' ? kPremiumBlack : kPremiumIndigo), 
                      onPressed: () async { 
                        Navigator.pop(ctx); 
                        baseData['solo_fare'] = soloFare; 
                        baseData['shared_fare'] = sharedFare; 
                        baseData['savings'] = soloFare - sharedFare; 
                        baseData['status'] = selectedMode == 'solo' ? 'Solo Cab Booked' : 'Shared Cab Booked'; 
                        baseData['car_type'] = selectedCar['title']; 
                        try { 
                          await http.post(Uri.parse('http://127.0.0.1:8000/save_ride'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(baseData)).timeout(const Duration(seconds: 3)); 
                        } catch (e) {} 
                        if (mounted) { 
                          Navigator.push(context, MaterialPageRoute(builder: (context) => RideTrackingScreen(pickup: LocationState.current.value.pickup, dropoff: dropLatLng, rideData: baseData, rideType: selectedMode))); 
                        } 
                      }, 
                      child: Text(
                        selectedMode == 'solo' ? (isRental ? 'Confirm Solo' : 'Confirm Solo ($soloPriceStr)') : (isRental ? 'Confirm Share' : 'Confirm Share ($sharedPriceStr)'), 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)
                      )
                    )
                  ),
                ]
              )
            ),
          );
        },
      ),
    );
  }

  Widget _quickServiceImageItemExact(String imageUrl, String label, String priceOrSub, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorderGrey.withOpacity(0.65)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Container(
                    width: 42, height: 36, padding: const EdgeInsets.all(4), 
                    decoration: BoxDecoration(color: kBackgroundLight, borderRadius: BorderRadius.circular(11)), 
                    child: Image.network(imageUrl, fit: BoxFit.contain)
                  ), 
                  const Icon(Icons.arrow_forward_rounded, size: 15, color: kTextGrey)
                ]
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kPremiumBlack)),
              const SizedBox(height: 2),
              Text(priceOrSub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5, color: kTextGrey)),
            ]
          ),
        ),
      ),
    );
  }

  Widget _buildSingleBanner5Slides() {
     final List<Map<String, dynamic>> slides = [
      {"tag": "OUTSTATION", "title": "Drawn to quick vacations?", "sub": "Book an Outstation ride for your weekend", "c1": const Color(0xFF1E3A8A), "c2": const Color(0xFF3B82F6), "icon": Icons.flight_takeoff_rounded},
      {"tag": "LAUNDRY", "title": "Fresh Clothes, Zero Effort!", "sub": "Doorstep pickup & deliver within 24 hrs", "c1": const Color(0xFF065F46), "c2": const Color(0xFF10B981), "icon": Icons.local_laundry_service_rounded},
      {"tag": "PARCEL", "title": "Send Packages Across City", "sub": "Fastest door-to-door courier delivery", "c1": const Color(0xFF92400E), "c2": const Color(0xFFF59E0B), "icon": Icons.local_shipping_rounded},
      {"tag": "MOTO", "title": "Beat Traffic on a Bike!", "sub": "Affordable solo rides starting at ₹19", "c1": const Color(0xFF4C1D95), "c2": const Color(0xFF8B5CF6), "icon": Icons.two_wheeler_rounded},
      {"tag": "REFERRAL", "title": "Invite Friends & Win ₹250", "sub": "Get rewards on their first shared trip", "c1": const Color(0xFF831843), "c2": const Color(0xFFEC4899), "icon": Icons.card_giftcard_rounded},
    ];

    return Column(
      children: [
        SizedBox(
          height: 145,
          child: PageView.builder(
            controller: _bannerController, onPageChanged: (index) => setState(() => _currentBannerIndex = index),
            itemCount: slides.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [slides[index]["c1"], slides[index]["c2"]]), borderRadius: BorderRadius.circular(24)),
                child: Stack(
                  children: [
                    Positioned(right: -10, bottom: -15, child: Icon(slides[index]["icon"], size: 100, color: Colors.white.withOpacity(0.15))),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(slides[index]["tag"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))),
                        const Spacer(),
                        Text(slides[index]["title"], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        Text(slides[index]["sub"], style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LocationData>(
      valueListenable: LocationState.current,
      builder: (context, locState, child) {
        Future<void> openSearch({String? vehicleType}) async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => DestinationSearchScreen(pickupAddress: locState.address, pickupLatLng: locState.pickup)));
          if (result != null) {
            LatLng newPickup = result['pickup'], dropLatLng = result['dropoff'];
            String placeName = result['dropoffName'];
            LocationState.updateLocation(newPickup);
            _mapController.move(newPickup, 15.0);
            _fetchRouteAndShowVehicles(placeName, dropLatLng, vehicleType: vehicleType);
          }
        }

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: locState.pickup,
                  initialZoom: 15.0,
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture && position.center != null) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () => LocationState.updateLocation(position.center!));
                    }
                  },
                ),
                children: [TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.cocab')],
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 52, height: 52, alignment: Alignment.center, 
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 7))]), 
                        child: const Icon(Icons.local_taxi_rounded, color: kPremiumBlack, size: 27)
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: openSearch, 
                          child: Container(
                            height: 52, padding: const EdgeInsets.symmetric(horizontal: 16), 
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 7))]), 
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, color: kTextGrey, size: 22), 
                                const SizedBox(width: 10), 
                                const Expanded(child: Text('Where are you going?', style: TextStyle(color: kPremiumBlack, fontWeight: FontWeight.w800, fontSize: 15))), 
                                Icon(Icons.tune_rounded, color: kTextGrey.withOpacity(0.8), size: 19)
                              ]
                            )
                          )
                        )
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _mapController.move(locState.pickup, 15.0), 
                        child: Container(
                          width: 52, height: 52, alignment: Alignment.center, 
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 7))]), 
                          child: const Icon(Icons.my_location_rounded, color: kPremiumBlack, size: 22)
                        )
                      ),
                    ]
                  ),
                ),
              ),

              Align(
                alignment: const Alignment(0, -0.75), 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: openSearch,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 240), 
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: kPremiumBlack, 
                          borderRadius: BorderRadius.circular(30), 
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (locState.address == "Fetching address...") 
                              const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))),
                            Expanded(
                              child: Text(locState.address, 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2), 
                                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis
                              )
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 2, height: 16, color: kPremiumBlack),
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: kPremiumBlack, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)])),
                  ],
                ),
              ),

              DraggableScrollableSheet(
                initialChildSize: 0.54,
                minChildSize: 0.42, 
                maxChildSize: 0.85, 
                snap: true, 
                builder: (context, scrollController) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    decoration: const BoxDecoration(
                      color: kCardWhite, 
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)), 
                      boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 36, offset: Offset(0, -10))]
                    ),
                    child: SafeArea(
                      top: false,
                      child: ListView(
                        controller: scrollController, 
                        physics: const ClampingScrollPhysics(), 
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          Center(child: Container(margin: const EdgeInsets.only(bottom: 16), width: 42, height: 5, decoration: BoxDecoration(color: kBorderGrey, borderRadius: BorderRadius.circular(10)))),
                          const Text('Let\'s get you moving', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: kPremiumBlack, letterSpacing: -0.8)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: kTextGrey), 
                              const SizedBox(width: 5), 
                              Expanded(child: Text(locState.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kTextGrey, fontWeight: FontWeight.w600)))
                            ]
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _quickServiceImageItemExact('https://cdn-icons-png.flaticon.com/512/3753/3753264.png', 'Bike', '₹19 onwards', () => openSearch(vehicleType: 'Bike')),
                              _quickServiceImageItemExact('https://cdn-icons-png.flaticon.com/512/1048/1048313.png', 'Auto', 'Quick & cheap', () => openSearch(vehicleType: 'Auto')),
                              _quickServiceImageItemExact('https://cdn-icons-png.flaticon.com/512/3097/3097180.png', 'Cabs', 'Comfy rides', () => openSearch(vehicleType: 'Mini')),
                            ]
                          ),
                          const SizedBox(height: 16),
                          _buildSingleBanner5Slides(),
                          const SizedBox(height: 60), 
                        ]
                      )
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 🔍 6. SEARCH DESTINATION
// ==========================================
class DestinationSearchScreen extends StatefulWidget {
  final String pickupAddress;
  final LatLng pickupLatLng;
  final String? initialDestination; 
  const DestinationSearchScreen({super.key, required this.pickupAddress, required this.pickupLatLng, this.initialDestination});
  @override State<DestinationSearchScreen> createState() => _DestinationSearchScreenState();
}

class _DestinationSearchScreenState extends State<DestinationSearchScreen> {
  late TextEditingController _pickupController;
  late TextEditingController _destinationController;
  final FocusNode _dropoffFocus = FocusNode();
  List<dynamic> _searchResults = [];
  Timer? _debounce;
  late LatLng _selectedPickup;

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController(text: widget.pickupAddress);
    _destinationController = TextEditingController(text: widget.initialDestination ?? "");
    _selectedPickup = widget.pickupLatLng;
    
    if (widget.initialDestination != null && widget.initialDestination!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(widget.initialDestination!);
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) { setState(() => _searchResults = []); return; }
    try {
      final response = await http.get(Uri.parse('https://nominatim.openstreetmap.org/search?q=$query, Tamil Nadu&format=json&limit=5'));
      if (response.statusCode == 200) setState(() => _searchResults = jsonDecode(response.body));
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8), 
          child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19), onPressed: () => Navigator.pop(context))
        ), 
        title: const Text('Plan your ride')
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 16), 
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14), 
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 5))]), 
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.my_location_rounded, color: kPremiumGreen, size: 19)), 
                        const SizedBox(width: 10), 
                        Expanded(child: TextField(controller: _pickupController, decoration: const InputDecoration(hintText: 'Pickup location', border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero)))
                      ]
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 18), 
                      child: Align(alignment: Alignment.centerLeft, child: Container(width: 2, height: 18, decoration: BoxDecoration(color: kBorderGrey, borderRadius: BorderRadius.circular(4))))
                    ),
                    Row(
                      children: [
                        Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 19)), 
                        const SizedBox(width: 10), 
                        Expanded(
                          child: TextField(
                            controller: _destinationController, focusNode: _dropoffFocus, autofocus: true, 
                            decoration: const InputDecoration(hintText: 'Where to?', border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero), 
                            onChanged: (q) { 
                              if (_debounce?.isActive ?? false) _debounce!.cancel(); 
                              _debounce = Timer(const Duration(milliseconds: 500), () => _search(q)); 
                            }
                          )
                        )
                      ]
                    ),
                  ]
                )
              ),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: Text(_searchResults.isEmpty ? 'Search a place' : 'Suggestions', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kPremiumBlack))),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8), 
                  itemCount: _searchResults.length, 
                  separatorBuilder: (_, __) => const SizedBox(height: 8), 
                  itemBuilder: (ctx, i) { 
                    final p = _searchResults[i]; 
                    final name = p['display_name'].split(',')[0]; 
                    return Material(
                      color: Colors.white, borderRadius: BorderRadius.circular(18), 
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18), 
                        onTap: () { 
                          Navigator.pop(context, {'pickup': _selectedPickup, 'dropoff': LatLng(double.parse(p['lat']), double.parse(p['lon'])), 'dropoffName': name}); 
                        }, 
                        child: Padding(
                          padding: const EdgeInsets.all(14), 
                          child: Row(
                            children: [
                              Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: kBackgroundLight, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.place_rounded, color: kPremiumIndigo, size: 20)), 
                              const SizedBox(width: 12), 
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                  children: [
                                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)), 
                                    const SizedBox(height: 3), 
                                    Text(p['display_name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kTextGrey, fontWeight: FontWeight.w500))
                                  ]
                                )
                              ), 
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kTextGrey)
                            ]
                          )
                        )
                      )
                    ); 
                  }
                )
              )
            ]
          )
        )
      ),
    );
  }
}

// ==========================================
// 🏎️ 7. LIVE TRACKING SCREEN (CAR RIDE)
// ==========================================
class RideTrackingScreen extends StatefulWidget {
  final LatLng pickup;
  final LatLng dropoff;
  final Map<String, dynamic> rideData;
  final String rideType;
  const RideTrackingScreen({super.key, required this.pickup, required this.dropoff, required this.rideData, required this.rideType});
  @override State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _carController;
  late Animation<double> _carAnimation;
  late LatLng _startLocation;
  late LatLng _currentLocation;
  double _carHeading = 0.0;
  final LatLng passengerB = const LatLng(13.0300, 80.1700);
  String _rideStatus = "Finding your captain...";
  bool _driverAssigned = false;
  bool _tripCompleted = false; 
  List<LatLng> _routePoints = [];
  List<double> _cumulativeDistances = [];
  double _totalDistance = 0.0;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _startLocation = LatLng(widget.pickup.latitude - 0.015, widget.pickup.longitude - 0.015);
    _currentLocation = _startLocation;
    _carController = AnimationController(vsync: this, duration: const Duration(seconds: 18)); 
    _carAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _carController, curve: Curves.easeInOut));
    _carAnimation.addListener(_updatePosition);
    _carController.addStatusListener((s) { if (s == AnimationStatus.completed && mounted) setState(() { _tripCompleted = true; _rideStatus = "Arrived at Destination"; }); });
    _fetchRoute();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Successful! ID: ${r.paymentId} ✅'), backgroundColor: kPremiumGreen));
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (route) => false);
    });
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed! ❌ ${r.message}'), backgroundColor: Colors.red)));
  }

  Future<void> _fetchRoute() async {
    String waypoints = '${_startLocation.longitude},${_startLocation.latitude};${widget.pickup.longitude},${widget.pickup.latitude}';
    if (widget.rideType == "shared") waypoints += ';${passengerB.longitude},${passengerB.latitude}';
    waypoints += ';${widget.dropoff.longitude},${widget.dropoff.latitude}';
    try {
      final res = await http.get(Uri.parse('https://router.project-osrm.org/route/v1/driving/$waypoints?geometries=geojson'));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['code'] == 'Ok') {
          _routePoints = (d['routes'][0]['geometry']['coordinates'] as List).map((p) => LatLng(p[1], p[0])).toList();
          final distObj = const Distance(); _cumulativeDistances = [0.0]; _totalDistance = 0.0;
          for (int i = 0; i < _routePoints.length - 1; i++) { double dist = distObj.distance(_routePoints[i], _routePoints[i+1]); _totalDistance += dist; _cumulativeDistances.add(_totalDistance); }
        }
      }
    } catch (e) {}
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) { setState(() { _rideStatus = "En Route to Destination"; _driverAssigned = true; }); _carController.forward(); }
    });
  }

  void _updatePosition() {
    if (_routePoints.isEmpty || _totalDistance == 0) return;
    double target = _carAnimation.value * _totalDistance;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      if (target <= _cumulativeDistances[i + 1]) {
        double p = (target - _cumulativeDistances[i]) / (_cumulativeDistances[i + 1] - _cumulativeDistances[i]);
        setState(() { 
          _currentLocation = LatLng(_routePoints[i].latitude + (_routePoints[i+1].latitude - _routePoints[i].latitude) * p, _routePoints[i].longitude + (_routePoints[i+1].longitude - _routePoints[i].longitude) * p);
          _carHeading = _calculateBearing(_routePoints[i], _routePoints[i+1]);
        });
        _mapController.move(_currentLocation, 15.5);
        break;
      }
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180, lon1 = start.longitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180, lon2 = end.longitude * math.pi / 180;
    double dLon = lon2 - lon1; double y = math.sin(dLon) * math.cos(lat2); double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return ((math.atan2(y, x) * 180 / math.pi) + 360) % 360 * math.pi / 180; 
  }

  @override void dispose() { _carController.dispose(); _razorpay.clear(); super.dispose(); }

  Widget _buildF1CarMarker() {
    return Transform.rotate(angle: _carHeading, child: SizedBox(width: 30, height: 56, child: Stack(alignment: Alignment.center, children: [Positioned(top: 8, left: 0, child: Container(width: 6, height: 14, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(3)))), Positioned(top: 8, right: 0, child: Container(width: 6, height: 14, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(3)))), Positioned(bottom: 6, left: 0, child: Container(width: 7, height: 16, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(3)))), Positioned(bottom: 6, right: 0, child: Container(width: 7, height: 16, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(3)))), Positioned(top: 0, child: Container(width: 22, height: 4, decoration: BoxDecoration(color: kPremiumIndigo, borderRadius: BorderRadius.circular(2)))), Positioned(bottom: 0, child: Container(width: 26, height: 6, decoration: BoxDecoration(color: kPremiumBlack, borderRadius: BorderRadius.circular(2)))), Positioned(top: 4, bottom: 4, child: Container(width: 10, decoration: BoxDecoration(color: kPremiumIndigo, borderRadius: BorderRadius.circular(4)))), Positioned(top: 20, bottom: 14, child: Container(width: 18, decoration: BoxDecoration(color: kPremiumBlack, borderRadius: BorderRadius.circular(6)))), Positioned(top: 24, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 2)])))])));
  }

  @override
  Widget build(BuildContext context) {
    final fare = widget.rideType == 'solo' ? widget.rideData['solo_fare'] : widget.rideData['shared_fare'];
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, 
            options: MapOptions(initialCenter: widget.pickup, initialZoom: 14.5), 
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.cocab'),
              if (_routePoints.isNotEmpty) 
                PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 5.5, color: kPremiumIndigo)]),
              MarkerLayer(
                markers: [
                  Marker(point: widget.pickup, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: kPremiumGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8)]))), 
                  Marker(point: widget.dropoff, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8)]))), 
                  if (_driverAssigned) 
                    Marker(point: _currentLocation, width: 96, height: 96, child: Stack(alignment: Alignment.center, children: [Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: kPremiumIndigo.withOpacity(0.12))), _buildF1CarMarker()]))
                ]
              ),
            ]
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16), 
              child: GestureDetector(
                onTap: () => Navigator.pop(context), 
                child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))]), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 19))
              )
            )
          ),
          Align(
            alignment: Alignment.bottomCenter, 
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), padding: const EdgeInsets.fromLTRB(18, 14, 18, 18), 
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 28, offset: const Offset(0, 8))]), 
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, 
                children: [
                  Row(
                    children: [
                      Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: _tripCompleted ? const Color(0xFFECFDF5) : kBackgroundLight, borderRadius: BorderRadius.circular(15)), child: Icon(_tripCompleted ? Icons.check_circle_rounded : Icons.local_taxi_rounded, color: _tripCompleted ? kPremiumGreen : kPremiumBlack, size: 25)), 
                      const SizedBox(width: 12), 
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_rideStatus, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kPremiumBlack)), const SizedBox(height: 3), Text(_tripCompleted ? 'Thanks for riding with CoCab' : 'Your ride is being handled safely', style: const TextStyle(fontSize: 11.5, color: kTextGrey, fontWeight: FontWeight.w600))])), 
                      if (!_tripCompleted) 
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: kPremiumBlack, borderRadius: BorderRadius.circular(12)), child: const Column(children: [Text('OTP', style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700)), SizedBox(height: 1), Text('1616', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))]))
                    ]
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: kBackgroundLight, borderRadius: BorderRadius.circular(17)), 
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Estimated fare', style: TextStyle(color: kTextGrey, fontWeight: FontWeight.w700, fontSize: 12)), Text('₹$fare', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kPremiumBlack))])
                  ),
                  const SizedBox(height: 12),
                  if (!_tripCompleted) 
                    SizedBox(width: double.infinity, height: 50, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel Ride'))) 
                  else 
                    SizedBox(width: double.infinity, height: 54, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: kPremiumBlack), onPressed: () { var options = {'key': 'rzp_test_TYJRj3FXddpH6m', 'amount': (widget.rideType == 'solo' ? widget.rideData['solo_fare'] : widget.rideData['shared_fare']) * 100, 'name': 'CoCab', 'prefill': {'contact': AppState.userPhone.value}}; js.context.callMethod('eval', ['''var rzp = new Razorpay(${jsonEncode(options)}); rzp.open();''']); }, child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_rounded, size: 17), SizedBox(width: 7), Text('Pay securely via Razorpay', style: TextStyle(fontWeight: FontWeight.w900))]))),
                ]
              )
            )
          ),
        ]
      ),
    );
  }
}

// ==========================================
// ✨ 8. SERVICES TAB & LAUNDRY FLOW ✨
// ==========================================

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});
  @override State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight, 
      appBar: AppBar(title: const Text('Services')), 
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 120), 
        children: [
          Container(
            padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: kPremiumBlack, borderRadius: BorderRadius.circular(26)), 
            child: Row(
              children: [
                Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 25)), 
                const SizedBox(width: 13), 
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text('Everything you need', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), 
                      SizedBox(height: 4), 
                      Text('Ride, send, clean and explore from CoCab.', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500))
                    ]
                  )
                )
              ]
            )
          ),
          const SizedBox(height: 18),
          const Text('Explore services', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95, 
            children: [
              _buildServiceCard(context, 'Laundry', 'https://cdn-icons-png.flaticon.com/512/3003/3003984.png', () { Navigator.push(context, MaterialPageRoute(builder: (context) => const LaundryShopsScreen())); }),
              _buildServiceCard(context, 'Parcel', 'https://cdn-icons-png.flaticon.com/512/2769/2769339.png', () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcel service coming soon! 📦'))); }),
              _buildServiceCard(context, 'Food', 'https://cdn-icons-png.flaticon.com/512/1046/1046784.png', () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Food delivery coming soon! 🍔'))); }),
            ]
          ),
        ]
      )
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String imgUrl, VoidCallback onTap) {
    final iconTint = title == 'Laundry' ? kPremiumIndigo : (title == 'Parcel' ? kPremiumGreen : const Color(0xFFF59E0B));
    return GestureDetector(
      onTap: onTap, 
      child: Container(
        padding: const EdgeInsets.all(15), 
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kBorderGrey.withOpacity(0.7)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 15, offset: const Offset(0, 5))]), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Expanded(child: Container(width: double.infinity, alignment: Alignment.center, decoration: BoxDecoration(color: iconTint.withOpacity(0.09), borderRadius: BorderRadius.circular(18)), child: Image.network(imgUrl, width: 68, height: 68))), 
            const SizedBox(height: 13), 
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), 
            const SizedBox(height: 3), 
            Row(
              children: [
                const Expanded(child: Text('Open service', style: TextStyle(fontSize: 10.5, color: kTextGrey, fontWeight: FontWeight.w600))), 
                Icon(Icons.arrow_forward_rounded, size: 17, color: iconTint)
              ]
            )
          ]
        )
      )
    );
  }
}

class LaundryShopsScreen extends StatefulWidget {
  const LaundryShopsScreen({super.key});
  @override
  State<LaundryShopsScreen> createState() => _LaundryShopsScreenState();
}

class _LaundryShopsScreenState extends State<LaundryShopsScreen> {
  List<dynamic> realShops = [];
  List<dynamic> filteredShops = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRealShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealShops() async {
    final locState = LocationState.current.value;
    try {
      final url = Uri.parse('http://127.0.0.1:8000/nearby_laundries?lat=${locState.pickup.latitude}&lon=${locState.pickup.longitude}');
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            realShops = data['shops'] ?? [];
            filteredShops = realShops;
            isLoading = false;
          });
        }
      } else {
         if (mounted) setState(() { realShops = []; filteredShops = []; isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { realShops = []; filteredShops = []; isLoading = false; });
    }
  }

  void _filterShops(String query) {
    if (query.isEmpty) {
      setState(() => filteredShops = realShops);
      return;
    }
    setState(() {
      filteredShops = realShops.where((shop) {
        final name = (shop['name'] ?? '').toLowerCase();
        final address = (shop['address'] ?? '').toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || address.contains(searchLower);
      }).toList();
    });
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_laundry_service_outlined, size: 80, color: kBorderGrey),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kPremiumBlack), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: kTextGrey, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight, 
      appBar: AppBar(title: const Text('Nearest Laundries'), actions: [IconButton(onPressed: _fetchRealShops, icon: const Icon(Icons.refresh_rounded))]), 
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14), 
              child: TextField(
                controller: _searchController, onChanged: _filterShops, 
                decoration: InputDecoration(
                  hintText: 'Search area or shop name...', prefixIcon: const Icon(Icons.search_rounded), 
                  suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchController.clear(); _filterShops(''); setState(() {}); }) : null
                )
              )
            ),
            Expanded(
              child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: kPremiumIndigo)) 
                : realShops.isEmpty 
                  ? _buildEmptyState('No shops found nearby', 'Try changing your pickup location on the home screen.') 
                  : filteredShops.isEmpty 
                    ? _buildEmptyState('No match found', 'We couldn\'t find any shop matching your search.') 
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), 
                        itemCount: filteredShops.length, 
                        itemBuilder: (context, index) { 
                          final shop = filteredShops[index]; 
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), 
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: kBorderGrey.withOpacity(0.65)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]), 
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Row(
                                  children: [
                                    Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.local_laundry_service_rounded, color: kPremiumIndigo, size: 22)), 
                                    const SizedBox(width: 11), 
                                    Expanded(child: Text(shop['name'] ?? 'Laundry Shop', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))), 
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)), child: Text(shop['distance'] ?? 'N/A', style: const TextStyle(color: kPremiumIndigo, fontWeight: FontWeight.w900, fontSize: 11)))
                                  ]
                                ), 
                                const SizedBox(height: 11), 
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 17, color: kTextGrey), 
                                    const SizedBox(width: 7), 
                                    Expanded(child: Text(shop['address'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w600)))
                                  ]
                                ), 
                                const SizedBox(height: 7), 
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 17, color: kTextGrey), 
                                    const SizedBox(width: 7), 
                                    Text(shop['phone'] ?? 'Not available', style: const TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w600))
                                  ]
                                ), 
                                const SizedBox(height: 13), 
                                SizedBox(
                                  width: double.infinity, height: 49, 
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: kPremiumBlack), 
                                    onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => LaundryTrackingScreen(shopData: shop))); }, 
                                    child: const Text('Book Wash Pickup', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white))
                                  )
                                )
                              ]
                            )
                          ); 
                        }
                      )
            )
          ]
        )
      )
    );
  }
}

class LaundryTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> shopData;
  const LaundryTrackingScreen({super.key, required this.shopData});
  @override State<LaundryTrackingScreen> createState() => _LaundryTrackingScreenState();
}

class _LaundryTrackingScreenState extends State<LaundryTrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _carController;
  late Animation<double> _carAnimation;
  
  LatLng _userLocation = LocationState.current.value.pickup;
  late LatLng _shopLocation;
  late LatLng _currentLocation;
  
  List<LatLng> _routePoints = [];
  String _status = "Assigning Captain...";
  String _actionText = "";
  int _flowStep = 0; 

  @override
  void initState() {
    super.initState();
    _shopLocation = LatLng(widget.shopData["lat"] ?? 13.0, widget.shopData["lng"] ?? 80.2);
    _currentLocation = _userLocation;
    
    _carController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _carAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _carController, curve: Curves.linear));
    _carAnimation.addListener(_updatePosition);
    _carController.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        if (_flowStep == 2) setState(() { _flowStep = 3; _status = "Clothes Washing at ${widget.shopData['name']} 🫧"; _actionText = "Wash Complete - Bring Back"; });
        if (_flowStep == 4) setState(() { _flowStep = 5; _status = "Rider Arrived at Your Location"; _actionText = "Verify Delivery OTP: 9999"; });
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() { _flowStep = 1; _status = "Rider Arrived!"; _actionText = "Verify Pickup OTP: 1616 & Upload Photo"; });
    });
  }

  void _generateSimpleRoute(LatLng start, LatLng end) {
    _routePoints = [start, LatLng(start.latitude, end.longitude), end];
  }

  void _updatePosition() {
    if (_routePoints.isEmpty) return;
    double p = _carAnimation.value;
    if (p < 0.5) {
      double localP = p * 2;
      _currentLocation = LatLng(_routePoints[0].latitude + (_routePoints[1].latitude - _routePoints[0].latitude) * localP, _routePoints[0].longitude + (_routePoints[1].longitude - _routePoints[0].longitude) * localP);
    } else {
      double localP = (p - 0.5) * 2;
      _currentLocation = LatLng(_routePoints[1].latitude + (_routePoints[2].latitude - _routePoints[1].latitude) * localP, _routePoints[1].longitude + (_routePoints[2].longitude - _routePoints[1].longitude) * localP);
    }
    setState(() {});
    _mapController.move(_currentLocation, 14.0);
  }

  void _handleActionButton() {
    if (_flowStep == 1) {
      showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text("Photo Uploaded ✅"),
        content: const Text("Clothes verified. Rider is taking them to the shop."),
        actions: [TextButton(onPressed: () {
          Navigator.pop(context);
          setState(() { _flowStep = 2; _status = "Heading to Shop..."; _actionText = ""; });
          _generateSimpleRoute(_userLocation, _shopLocation);
          _carController.forward(from: 0);
        }, child: const Text("OK", style: TextStyle(color: kPremiumIndigo)))],
      ));
    } else if (_flowStep == 3) {
      setState(() { _flowStep = 4; _status = "Washed Clothes Returning..."; _actionText = ""; });
      _generateSimpleRoute(_shopLocation, _userLocation);
      _carController.forward(from: 0);
    } else if (_flowStep == 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery Successful! 👕✨'), backgroundColor: kPremiumGreen));
      Navigator.pop(context);
    }
  }

  @override void dispose() { _carController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, options: MapOptions(initialCenter: _userLocation, initialZoom: 13.0), 
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.cocab'), 
              if (_routePoints.isNotEmpty) 
                PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 4.0, color: kPremiumIndigo)]), 
              MarkerLayer(
                markers: [
                  Marker(point: _userLocation, child: const Icon(Icons.home_rounded, color: kPremiumGreen, size: 34)), 
                  Marker(point: _shopLocation, child: const Icon(Icons.local_laundry_service_rounded, color: kPremiumIndigo, size: 34)), 
                  if (_flowStep == 2 || _flowStep == 4) 
                    Marker(point: _currentLocation, child: const Icon(Icons.directions_bike_rounded, color: kPremiumBlack, size: 36))
                ]
              )
            ]
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16), 
              child: GestureDetector(
                onTap: () => Navigator.pop(context), 
                child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))]), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 19))
              )
            )
          ),
          Align(
            alignment: Alignment.bottomCenter, 
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), padding: const EdgeInsets.all(18), 
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 28, offset: const Offset(0, 8))]), 
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, 
                children: [
                  Row(
                    children: [
                      Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: kBackgroundLight, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.local_laundry_service_rounded, color: kPremiumIndigo, size: 24)), 
                      const SizedBox(width: 12), 
                      Expanded(child: Text(_status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kPremiumBlack))),
                    ]
                  ), 
                  const SizedBox(height: 8), 
                  Text(widget.shopData['name'] ?? 'Laundry partner', style: const TextStyle(color: kTextGrey, fontWeight: FontWeight.w600, fontSize: 12)), 
                  if (_actionText.isNotEmpty) ...[
                    const SizedBox(height: 14), 
                    SizedBox(
                      width: double.infinity, height: 52, 
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kPremiumIndigo), 
                        onPressed: _handleActionButton, 
                        child: Text(_actionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))
                      )
                    )
                  ]
                ]
              )
            )
          )
        ]
      )
    );
  }
}

class TravelScreen extends StatelessWidget { 
  const TravelScreen({super.key}); 
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight, appBar: AppBar(title: const Text('Travel')), 
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28), 
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(24), 
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: kBorderGrey.withOpacity(0.7)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 18, offset: const Offset(0, 5))]), 
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Container(width: 68, height: 68, alignment: Alignment.center, decoration: BoxDecoration(color: kPremiumIndigo.withOpacity(0.10), shape: BoxShape.circle), child: const Icon(Icons.flight_takeoff_rounded, color: kPremiumIndigo, size: 32)), 
                const SizedBox(height: 18), 
                const Text('Travel is coming soon', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), 
                const SizedBox(height: 7), 
                const Text('Airport rides and intercity travel will appear here.', textAlign: TextAlign.center, style: TextStyle(color: kTextGrey, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4))
              ]
            )
          )
        )
      )
    );
  }
}

// ==========================================
// 👤 9. ACCOUNT SCREEN (RAPIDO CLONE UI)
// ==========================================
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Widget _buildMenuItem(IconData icon, String title, {String? subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 24.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.black87, size: 26),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      ]
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, indent: 74, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF1E3A8A), size: 28),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("HARIGARAN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(
                              AppState.userPhone.value.replaceAll('+91 ', ''), 
                              style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFBBF24), size: 28),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Text("4.67 My Rating", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          _buildMenuItem(Icons.help_outline_rounded, "Help"),
          _buildMenuItem(Icons.account_balance_wallet_outlined, "Payment"),
          _buildMenuItem(Icons.history_rounded, "My Rides", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RideHistoryScreen()));
          }),
          _buildMenuItem(Icons.verified_user_outlined, "Safety"),
          _buildMenuItem(Icons.card_giftcard_rounded, "Refer and Earn", subtitle: "Get ₹50"),
          _buildMenuItem(Icons.workspace_premium_outlined, "My Rewards"),
          _buildMenuItem(Icons.notifications_none_rounded, "Notifications"),
          _buildMenuItem(Icons.shield_outlined, "Claims"),
          _buildMenuItem(Icons.settings_outlined, "Settings", onTap: () {
             AppState.logout(); 
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ==========================================
// 📜 10. RIDE HISTORY SCREEN (PREMIUM UI)
// ==========================================
class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});
  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<dynamic> _rides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRideHistory();
  }

  Future<void> _fetchRideHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:8000/rides')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        setState(() {
          _rides = jsonDecode(res.body);
          _isLoading = false;
        });
        return;
      }
    } catch (e) {}

    setState(() {
      _rides = [
        {
          "id": 101,
          "status": "Shared Cab Booked",
          "shared_distance_km": 4.8,
          "solo_fare": 280,
          "shared_fare": 175,
          "savings": 105,
        },
        {
          "id": 100,
          "status": "Solo Cab Booked",
          "shared_distance_km": 2.5,
          "solo_fare": 95,
          "shared_fare": 95,
          "savings": 0,
        }
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight, 
      appBar: AppBar(title: const Text('Your Trips'), actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchRideHistory)]), 
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kPremiumIndigo)) 
        : _rides.isEmpty 
          ? const Center(child: Text('No past rides found', style: TextStyle(color: kTextGrey, fontWeight: FontWeight.w800))) 
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), 
              itemCount: _rides.length, 
              itemBuilder: (context, index) { 
                final ride = _rides[index]; 
                final bool isShared = (ride['savings'] ?? 0) > 0; 
                final fare = ride['shared_fare'] ?? ride['solo_fare'] ?? 0; 
                return Container(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), 
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23), border: Border.all(color: kBorderGrey.withOpacity(0.65)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))]), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Row(
                        children: [
                          Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: isShared ? const Color(0xFFEEF2FF) : kBackgroundLight, borderRadius: BorderRadius.circular(15)), child: Icon(isShared ? Icons.people_alt_rounded : Icons.local_taxi_rounded, color: isShared ? kPremiumIndigo : kPremiumBlack, size: 23)), 
                          const SizedBox(width: 11), 
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isShared ? 'CoCab Share' : 'Solo Ride', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)), const SizedBox(height: 3), Text('Ride #${ride['id'] ?? index + 1}', style: const TextStyle(color: kTextGrey, fontSize: 11, fontWeight: FontWeight.w700))])), 
                          Text('₹$fare', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))
                        ]
                      ), 
                      const SizedBox(height: 15), 
                      Row(
                        children: [
                          Column(children: [Container(width: 9, height: 9, decoration: const BoxDecoration(color: kPremiumGreen, shape: BoxShape.circle)), Container(width: 2, height: 24, color: kBorderGrey), Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle))]), 
                          const SizedBox(width: 11), 
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Pickup location', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextGrey)), const SizedBox(height: 8), Text('Drop location • ${ride['shared_distance_km'] ?? 0} km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPremiumBlack))]))
                        ]
                      ), 
                      if (isShared) ...[
                        const SizedBox(height: 12), 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), 
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(13)), 
                          child: Row(
                            children: [
                              const Icon(Icons.savings_rounded, color: kPremiumGreen, size: 17), 
                              const SizedBox(width: 7), 
                              Text('Saved ₹${ride['savings']} with CoCab', style: const TextStyle(color: Color(0xFF047857), fontSize: 11.5, fontWeight: FontWeight.w900))
                            ]
                          )
                        )
                      ]
                    ]
                  )
                ); 
              }
            )
    );
  }
}