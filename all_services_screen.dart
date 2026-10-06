import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/app_state.dart';
import '../../laundry/screens/laundry_screens.dart';
import '../../parcel/screens/parcel_booking_screen.dart';

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
            padding: const EdgeInsets.all(20), 
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              // ✨ PUDHU CODE: Local Asset Image add panniyachu ✨
              image: const DecorationImage(
                image: AssetImage("assets/images/services_banner.png"), // <-- LOCAL IMAGE
                fit: BoxFit.cover,
                // colorFilter thevai illa, original green design theliva theriyum!
              ),
            ), 
            child: Row(
              children: [
                Container(
                  width: 48, 
                  height: 48, 
                  alignment: Alignment.center, 
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(16),
                  ), 
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 25),
                ), 
                const SizedBox(width: 13), 
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text('Everything you need', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)), 
                      SizedBox(height: 4), 
                      Text('Ride, send, clean and explore from CoCab.', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ), 
          const SizedBox(height: 18),
          const Text('Explore services', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95, 
            children: [
              _buildServiceCard(context, 'Laundry', 'https://cdn-icons-png.flaticon.com/512/3003/3003984.png', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LaundryShopsScreen()));
              }),
              _buildServiceCard(context, 'Parcel', 'https://cdn-icons-png.flaticon.com/512/2769/2769339.png', () { 
                Navigator.push(context, MaterialPageRoute(builder: (context) => ParcelBookingScreen(
                  pickupAddress: LocationState.current.value.address,
                  dropAddress: 'Select Drop Location',
                  baseFare: 60,
                ))); 
              }),
              _buildServiceCard(context, 'Food', 'https://cdn-icons-png.flaticon.com/512/1046/1046784.png', () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Food delivery coming soon! 🍔')));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String imgUrl, VoidCallback onTap) {
    final iconTint = title == 'Laundry' ? kPremiumIndigo : (title == 'Parcel' ? kPremiumGreen : const Color(0xFFF59E0B));
    return GestureDetector(
      onTap: onTap, 
      child: Container(
        padding: const EdgeInsets.all(15), 
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorderGrey.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconTint.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Image.network(imgUrl, width: 68, height: 68),
              ),
            ), 
            const SizedBox(height: 13), 
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), 
            const SizedBox(height: 3), 
            Row(
              children: [
                const Expanded(
                  child: Text('Open service', style: TextStyle(fontSize: 10.5, color: kTextGrey, fontWeight: FontWeight.w600)),
                ), 
                Icon(Icons.arrow_forward_rounded, size: 17, color: iconTint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}