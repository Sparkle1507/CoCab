import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:razorpay_flutter/razorpay_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import '../../../core/theme.dart';
import '../../../core/app_state.dart';
import '../../../navigation/main_navigation_screen.dart';
import '../../parcel/screens/parcel_booking_screen.dart';
import '../../laundry/screens/laundry_screens.dart';

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

  List<LatLng> _routePoints = [];
  LatLng? _dropoffLatLng;
  bool _isShowingCarSelection = false;
  List<Marker> _dummyCars = [];
  String _destinationName = "";
  var _currentRideData;
  int _selectedCarIndex = 0;

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
  void dispose() { 
    _debounce?.cancel(); 
    _bannerTimer?.cancel(); 
    _bannerController.dispose(); 
    super.dispose(); 
  }

  void _generateDummyCars(LatLng center) {
    _dummyCars = [];
    final random = math.Random();
    for (int i = 0; i < 7; i++) {
      double latOffset = (random.nextDouble() - 0.5) * 0.02;
      double lngOffset = (random.nextDouble() - 0.5) * 0.02;
      double heading = random.nextDouble() * 360;
      
      _dummyCars.add(
        Marker(
          point: LatLng(center.latitude + latOffset, center.longitude + lngOffset),
          width: 36, height: 36,
          child: Transform.rotate(
            angle: heading * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 14, height: 6, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 6),
                  Container(width: 14, height: 4, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(1))),
                ],
              ),
            )
          )
        )
      );
    }
  }

  Future<void> _fetchRouteAndShowVehicles(String placeName, LatLng dropLatLng, {String? vehicleType}) async {
    final locState = LocationState.current.value;
    showDialog(context: context, barrierDismissible: false, builder: (c) => Center(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: const CircularProgressIndicator(color: kPremiumBlack))));
    
    try {
      String waypoints = '${locState.pickup.longitude},${locState.pickup.latitude};${dropLatLng.longitude},${dropLatLng.latitude}';
      final routeRes = await http.get(Uri.parse('https://router.project-osrm.org/route/v1/driving/$waypoints?geometries=geojson'));
      List<LatLng> fetchedRoute = [];
      if (routeRes.statusCode == 200) {
        final d = jsonDecode(routeRes.body);
        if (d['code'] == 'Ok') {
          fetchedRoute = (d['routes'][0]['geometry']['coordinates'] as List).map((p) => LatLng(p[1], p[0])).toList();
        }
      }

      final url = Uri.parse('http://127.0.0.1:8000/check_route?a_lat=${locState.pickup.latitude}&a_lon=${locState.pickup.longitude}&b_lat=${passengerB.latitude}&b_lon=${passengerB.longitude}&c_lat=${dropLatLng.latitude}&c_lon=${dropLatLng.longitude}');
      final response = await http.post(url);
      
      if(mounted) Navigator.pop(context); 
      
      if (response.statusCode == 200) {
        var baseData = jsonDecode(response.body);
        
        setState(() {
          _routePoints = fetchedRoute;
          _dropoffLatLng = dropLatLng;
          _destinationName = placeName;
          _currentRideData = baseData;
          _selectedCarIndex = 0;
          _isShowingCarSelection = true; 
          AppState.showBottomNav.value = false; 
          _generateDummyCars(locState.pickup);
        });

        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([locState.pickup, dropLatLng]),
          padding: const EdgeInsets.only(top: 100, bottom: 450, left: 50, right: 50),
        ));
      }
    } catch (e) {
      if(mounted) Navigator.pop(context);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server Error! Check Backend 🖥️❌'), backgroundColor: Colors.red));
    }
  }

  Widget _buildCarSelectionSheet(LocationData locState) {
    int baseFare = _currentRideData?["solo_fare"] ?? 300;

    final List<Map<String, dynamic>> rides = [
      {"title":"Book Any","subtitle":"Mini, Prime Sedan, Prime Plus","eta":"1 min","priceText":"₹${(baseFare * 0.95).round()} - ₹${(baseFare * 1.35).round()}","singlePrice":baseFare,"img":"https://cdn-icons-png.flaticon.com/512/3097/3097180.png","isRange":true},
      {"title":"Auto","subtitle":"Quickest auto ride in town","eta":"1 min","priceText":"₹${(baseFare * 0.55).round()}","singlePrice":(baseFare * 0.55).round(),"img":"https://cdn-icons-png.flaticon.com/512/1048/1048313.png","isRange":false},
      {"title":"Mini Non AC","subtitle":"Budget-friendly everyday hatchbacks","eta":"2 mins","priceText":"₹${(baseFare * 0.85).round()}","singlePrice":(baseFare * 0.85).round(),"img":"https://cdn-icons-png.flaticon.com/512/3725/3725112.png","isRange":false},
      {"title":"Prime Sedan","subtitle":"Comfortable sedans with extra legroom","eta":"3 mins","priceText":"₹${(baseFare * 1.15).round()}","singlePrice":(baseFare * 1.15).round(),"img":"https://cdn-icons-png.flaticon.com/512/3097/3097180.png","isRange":false},
      {"title":"Prime Plus","subtitle":"Top-rated drivers & premium cars","eta":"4 mins","priceText":"₹${(baseFare * 1.35).round()}","singlePrice":(baseFare * 1.35).round(),"img":"https://cdn-icons-png.flaticon.com/512/3097/3097180.png","isRange":false},
      {"title":"Prime SUV","subtitle":"7-seater for family & heavy luggage","eta":"5 mins","priceText":"₹${(baseFare * 1.6).round()}","singlePrice":(baseFare * 1.6).round(),"img":"https://cdn-icons-png.flaticon.com/512/3097/3097180.png","isRange":false},
      {"title":"Bike","subtitle":"Beat the traffic","eta":"1 min","priceText":"₹${(baseFare * 0.35).round()}","singlePrice":(baseFare * 0.35).round(),"img":"https://cdn-icons-png.flaticon.com/512/3753/3753264.png","isRange":false},
      {"title":"Parcel","subtitle":"Fast door-to-door courier service","eta":"10 mins","priceText":"Starting ₹60","singlePrice":60,"img":"https://cdn-icons-png.flaticon.com/512/2769/2769339.png","isRange":false},
      {"title":"Laundry","subtitle":"Doorstep pickup, wash & deliver","eta":"30 mins","priceText":"₹75/kg","singlePrice":75,"img":"https://cdn-icons-png.flaticon.com/512/3003/3003984.png","isRange":false},
    ];

    if (_selectedCarIndex >= rides.length) _selectedCarIndex = 0;
    final selectedRideTitle = rides[_selectedCarIndex]['title'];

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.40,
      maxChildSize: 0.85,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, -6))]
          ),
          child: ClipRRect( 
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFFF7F8FA),
                  child: ListView.builder(
                    controller: scrollController, 
                    padding: const EdgeInsets.only(top: 120, bottom: 140, left: 16, right: 16),
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      final item = rides[index];
                      final isSelected = _selectedCarIndex == index;
                      return GestureDetector(
                        onTap: () {
                           setState(() => _selectedCarIndex = index);
                           if (item['title'] == 'Parcel') {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ParcelBookingScreen(pickupAddress: locState.address, dropAddress: _destinationName, baseFare: item['singlePrice'])));
                           } else if (item['title'] == 'Laundry') {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const LaundryShopsScreen()));
                           }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? kPremiumBlack : Colors.transparent, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]
                          ),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  Image.network(item['img'], width: 56, height: 32, fit: BoxFit.contain),
                                  const SizedBox(height: 4),
                                  Text(item['eta'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPremiumBlack)),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(item['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kPremiumBlack)),
                                        if (item['isRange'] == true) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey)
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(item['subtitle'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Text(item['priceText'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kPremiumBlack)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Positioned(
                  top: 0, left: 0, right: 0,
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Container(width: 44, height: 5, decoration: BoxDecoration(color: kBorderGrey, borderRadius: BorderRadius.circular(10))),
                          
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    const Icon(Icons.circle, color: kPremiumGreen, size: 10),
                                    Container(width: 1.5, height: 26, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(vertical: 4)),
                                    const Icon(Icons.circle, color: Colors.red, size: 10),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(locState.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kPremiumBlack)),
                                      const SizedBox(height: 20),
                                      Text(_destinationName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kPremiumBlack)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.schedule_rounded, size: 18, color: Colors.black87),
                                      SizedBox(height: 2),
                                      Text('Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))]),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDockAction(Icons.payments_rounded, 'Cash', kPremiumGreen)),
                            Container(width: 1, height: 20, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
                            Expanded(child: _buildDockAction(Icons.local_offer_rounded, 'Coupon', kPremiumGreen)),
                            Container(width: 1, height: 20, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
                            Expanded(child: _buildDockAction(Icons.person_rounded, 'Myself', kPremiumBlack)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: kPremiumBlack, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () {
                              if (selectedRideTitle == 'Parcel') {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => ParcelBookingScreen(pickupAddress: locState.address, dropAddress: _destinationName, baseFare: rides[_selectedCarIndex]['singlePrice'])));
                              } else if (selectedRideTitle == 'Laundry') {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const LaundryShopsScreen()));
                              } else {
                                _showSoloOrShareStep2(_destinationName, _dropoffLatLng!, _currentRideData, rides[_selectedCarIndex]);
                              }
                            },
                            child: Text(selectedRideTitle.startsWith('Book') ? selectedRideTitle : 'Book $selectedRideTitle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDockAction(IconData icon, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPremiumBlack)),
      ],
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
                        // ✨ SHOW EXACT WARNING POPUP UI IF 'SHARED' IS SELECTED ✨
                        if (selectedMode == 'shared') {
                          bool? proceed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return Dialog(
                                backgroundColor: Colors.white,
                                surfaceTintColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Orange Warning Icon with double circle glow effect
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF9E6), 
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFFEF08A), width: 3), 
                                        ),
                                        child: const Icon(Icons.error_outline_rounded, color: Color(0xFFF59E0B), size: 32), 
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Title
                                      const Text('Heads up before you go!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                                      const SizedBox(height: 12),
                                      
                                      // Body Text with Bold highlights
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: const TextSpan(
                                          style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.5, fontFamily: 'Roboto'),
                                          children: [
                                            TextSpan(text: 'It might take '),
                                            TextSpan(text: 'extra time', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                                            TextSpan(text: ', and you\'ll be traveling with\n'),
                                            TextSpan(text: 'co-passengers', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                                            TextSpan(text: ' — is that okay?'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      
                                      // Faint Divider
                                      Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                                      const SizedBox(height: 24),
                                      
                                      // Yes, Proceed Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pop(dialogContext, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kPremiumIndigo,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          child: const Text('Yes, Proceed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // No, Go Back Button
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, false),
                                        style: TextButton.styleFrom(
                                          splashFactory: NoSplash.splashFactory,
                                        ),
                                        child: const Text('No, Go Back', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, fontSize: 14)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );

                          if (proceed != true) {
                            return; 
                          }
                        }

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
                    if (hasGesture && position.center != null && !_isShowingCarSelection) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () => LocationState.updateLocation(position.center!));
                    }
                  },
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.cocab'),
                  if (_routePoints.isNotEmpty) 
                    PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 5.0, color: const Color(0xFF1E293B))]), 
                  if (_isShowingCarSelection && _dummyCars.isNotEmpty)
                    MarkerLayer(markers: _dummyCars),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: locState.pickup,
                        width: 60, height: 60,
                        child: _isShowingCarSelection 
                          ? Container(width: 14, height: 14, decoration: BoxDecoration(color: kPremiumGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)]))
                          : Container(
                              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color.fromARGB(255, 141, 243, 202).withOpacity(0.2)),
                              child: Center(
                                child: Transform.rotate(
                                  angle: 0.5, 
                                  child: const Icon(Icons.navigation_rounded, color: Color(0xFF047857), size: 28),
                                ),
                              ),
                            ),
                      ),
                      if (_dropoffLatLng != null)
                        Marker(
                          point: _dropoffLatLng!,
                          width: 20, height: 20,
                          child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)])),
                        ),
                    ],
                  ),
                ],
              ),

              if (!_isShowingCarSelection) ...[
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 52, height: 52, alignment: Alignment.center, 
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 7))]), 
                          child: const Icon(Icons.local_taxi_rounded, color: kPremiumBlack, size: 27)
                        ),
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
                            color: const Color.fromARGB(229, 2, 218, 132), 
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
                            ],
                          ),
                        ),
                      ),
                      Container(width: 2, height: 16, color: kPremiumGreen),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: kPremiumGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)])),
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
                            
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: openSearch,
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                                      BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
                                    ],
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.search_rounded, color: Colors.black, size: 26),
                                      SizedBox(width: 12),
                                      Text('Where are you going?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
                                    ],
                                  ),
                                ),
                              ),
                            ),

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
              ] else ...[
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
                        onPressed: () {
                          setState(() {
                            _isShowingCarSelection = false;
                            AppState.showBottomNav.value = true; 
                            _routePoints = [];
                            _dropoffLatLng = null;
                            _dummyCars = [];
                          });
                          _mapController.move(locState.pickup, 15.0);
                        }, 
                      )
                    )
                  )
                ),
                _buildCarSelectionSheet(locState),
              ]
            ],
          ),
        );
      },
    );
  }
}

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
  LatLng? _selectedDropoff;
  String? _selectedDropoffName;

  final List<Map<String, dynamic>> recentPlaces = [
    {"name": "Home", "address": "24, Anna Nagar West, Chennai", "icon": Icons.home_rounded, "color": Colors.orange, "lat": 13.0850, "lon": 80.2100},
    {"name": "Office", "address": "Tidel Park, Taramani, Chennai", "icon": Icons.work_rounded, "color": Colors.brown, "lat": 12.9896, "lon": 80.2475},
    {"name": "Phoenix MarketCity", "address": "Velachery Main Rd, Velachery", "icon": Icons.shopping_bag_rounded, "color": Colors.blue, "lat": 12.9915, "lon": 80.2160},
    {"name": "Chennai Airport", "address": "Tirusulam, Chennai - 600016", "icon": Icons.flight_rounded, "color": Colors.indigo, "lat": 12.9716, "lon": 80.1891},
  ];

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
    bool isReadyToNavigate = _selectedDropoff != null && _selectedDropoffName != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kPremiumBlack, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Plan your ride', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPremiumBlack, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('Set pickup & drop location', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    ],
                  )
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20), 
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 5))]), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.circle, color: kPremiumGreen, size: 12), 
                            const SizedBox(width: 16), 
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PICKUP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1.0)),
                                  TextField(
                                    controller: _pickupController, 
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kPremiumBlack),
                                    decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero, isDense: true)
                                  ),
                                ],
                              )
                            )
                          ]
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 5, top: 8, bottom: 8), 
                          child: Container(width: 2, height: 24, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.red, size: 18), 
                            const SizedBox(width: 16), 
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('DROP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1.0)),
                                  TextField(
                                    controller: _destinationController, focusNode: _dropoffFocus, autofocus: true, 
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kPremiumBlack),
                                    decoration: InputDecoration(hintText: 'Where to?', hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero, isDense: true), 
                                    onChanged: (q) { 
                                      if (_debounce?.isActive ?? false) _debounce!.cancel(); 
                                      _debounce = Timer(const Duration(milliseconds: 500), () => _search(q)); 
                                    }
                                  ),
                                ],
                              )
                            )
                          ]
                        ),
                      ]
                    )
                  ),
                  Positioned(
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200, width: 1.5),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            String temp = _pickupController.text;
                            setState(() {
                              _pickupController.text = _destinationController.text;
                              _destinationController.text = temp;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_vert_rounded, color: kPremiumIndigo, size: 16),
                                SizedBox(width: 4),
                                Text('Swap', style: TextStyle(color: kPremiumIndigo, fontWeight: FontWeight.w800, fontSize: 12))
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            Expanded(
              child: _searchResults.isEmpty 
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 10),
                    const Text('RECENT PLACES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    ...recentPlaces.map((place) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                          child: Icon(place['icon'], color: place['color'], size: 20),
                        ),
                        title: Text(place['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        subtitle: Text(place['address'], style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        onTap: () {
                          setState(() {
                            _destinationController.text = place['name'];
                            _selectedDropoffName = place['name'];
                            _selectedDropoff = LatLng(place['lat'], place['lon']);
                          });
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    )).toList(),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
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
                          setState(() {
                            _destinationController.text = name;
                            _selectedDropoffName = name;
                            _selectedDropoff = LatLng(double.parse(p['lat']), double.parse(p['lon']));
                          });
                          FocusScope.of(context).unfocus();
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
                ),
            ),
            
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, -5))],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: isReadyToNavigate ? () {
                    Navigator.pop(context, {
                      'pickup': _selectedPickup, 
                      'dropoff': _selectedDropoff, 
                      'dropoffName': _selectedDropoffName
                    });
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReadyToNavigate ? kPremiumBlack : Colors.grey.shade200,
                    foregroundColor: isReadyToNavigate ? Colors.white : Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: const Text('Select a destination', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            )
          ]
        )
      ),
    );
  }
}

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