import 'package:flutter/foundation.dart';
import '../services/location_service.dart';

class LocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  bool _isInitialized = false;

  LocationProvider() {
    initialize();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _locationService.initialize();
    _isInitialized = true;
    notifyListeners();
  }

  void setCountry(String countryCode) {
    _locationService.setCountry(countryCode);
    notifyListeners();
  }

  String formatPrice(double price, {String fromCurrencyCode = 'USD'}) {
    return _locationService.formatPrice(price, fromCurrencyCode: fromCurrencyCode);
  }

  String get currencyCode => _locationService.currencyCode;
  String get countryCode => _locationService.countryCode;
  bool get isInIndia => _locationService.countryCode == 'IN';
  
  // List of products that should only be shown in India
  static const List<String> indiaOnlyProducts = [
    'digital kitchen scale',
    'elefit smart bluetooth body fat scale with bright led display',
  ];
  
  bool shouldShowProduct(String productTitle) {
    if (isInIndia) {
      return true; // Show all products in India
    }
    
    // Outside India, hide India-only products
    final titleLower = productTitle.toLowerCase().trim();
    for (var restrictedProduct in indiaOnlyProducts) {
      if (titleLower.contains(restrictedProduct.toLowerCase())) {
        return false;
      }
    }
    return true;
  }
}
