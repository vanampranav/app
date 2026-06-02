import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Address {
  final String id;
  final String firstName;
  final String lastName;
  final String company;
  final String address1;
  final String address2;
  final String city;
  final String province;
  final String country;
  final String zip;
  final String phone;
  final bool isDefault;

  Address({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.company = '',
    required this.address1,
    this.address2 = '',
    required this.city,
    required this.province,
    required this.country,
    required this.zip,
    this.phone = '',
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'company': company,
      'address1': address1,
      'address2': address2,
      'city': city,
      'province': province,
      'country': country,
      'zip': zip,
      'phone': phone,
      'isDefault': isDefault,
    };
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      company: json['company'] ?? '',
      address1: json['address1'] ?? '',
      address2: json['address2'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      country: json['country'] ?? '',
      zip: json['zip'] ?? '',
      phone: json['phone'] ?? '',
      isDefault: json['isDefault'] ?? false,
    );
  }

  Address copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? province,
    String? country,
    String? zip,
    String? phone,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      company: company ?? this.company,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      zip: zip ?? this.zip,
      phone: phone ?? this.phone,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  
  String get fullAddress {
    List<String> parts = [address1];
    if (address2.isNotEmpty) parts.add(address2);
    parts.add(city);
    if (province.isNotEmpty) parts.add(province);
    parts.add(zip);
    parts.add(country);
    return parts.join(', ');
  }

  // Format for Shopify checkout autofill
  Map<String, String> toShopifyFormat() {
    return {
      'shipping_address[first_name]': firstName,
      'shipping_address[last_name]': lastName,
      'shipping_address[company]': company,
      'shipping_address[address1]': address1,
      'shipping_address[address2]': address2,
      'shipping_address[city]': city,
      'shipping_address[province]': province,
      'shipping_address[country]': country,
      'shipping_address[zip]': zip,
      'shipping_address[phone]': phone,
    };
  }
}

class AddressModel extends ChangeNotifier {
  List<Address> _addresses = [];
  bool _isLoading = false;

  List<Address> get addresses => _addresses;
  bool get isLoading => _isLoading;
  
  Address? get defaultAddress {
    try {
      return _addresses.firstWhere((address) => address.isDefault);
    } catch (e) {
      // No default address found, return first address if available, otherwise null
      return _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  Future<void> loadAddresses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesJson = prefs.getStringList('user_addresses') ?? [];
      
      _addresses = addressesJson
          .map((json) => Address.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      _addresses = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveAddresses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesJson = _addresses
          .map((address) => jsonEncode(address.toJson()))
          .toList();
      
      await prefs.setStringList('user_addresses', addressesJson);
    } catch (e) {
      debugPrint('Error saving addresses: $e');
    }
  }

  Future<void> addAddress(Address address) async {
    // If this is the first address or marked as default, make it default
    if (_addresses.isEmpty || address.isDefault) {
      // Remove default from other addresses
      _addresses = _addresses.map((addr) => addr.copyWith(isDefault: false)).toList();
    }

    _addresses.add(address);
    await saveAddresses();
    notifyListeners();
  }

  Future<void> updateAddress(Address updatedAddress) async {
    final index = _addresses.indexWhere((addr) => addr.id == updatedAddress.id);
    if (index != -1) {
      // If setting as default, remove default from others
      if (updatedAddress.isDefault) {
        _addresses = _addresses.map((addr) => 
          addr.id == updatedAddress.id ? addr : addr.copyWith(isDefault: false)
        ).toList();
      }
      
      _addresses[index] = updatedAddress;
      await saveAddresses();
      notifyListeners();
    }
  }

  Future<void> deleteAddress(String addressId) async {
    final addressToDelete = _addresses.firstWhere((addr) => addr.id == addressId);
    _addresses.removeWhere((addr) => addr.id == addressId);
    
    // If we deleted the default address, make the first remaining address default
    if (addressToDelete.isDefault && _addresses.isNotEmpty) {
      _addresses[0] = _addresses[0].copyWith(isDefault: true);
    }
    
    await saveAddresses();
    notifyListeners();
  }

  Future<void> setDefaultAddress(String addressId) async {
    _addresses = _addresses.map((addr) => 
      addr.copyWith(isDefault: addr.id == addressId)
    ).toList();
    
    await saveAddresses();
    notifyListeners();
  }

  // Generate JavaScript for Shopify checkout autofill
  String generateAutofillScript() {
    final defaultAddr = defaultAddress;
    if (defaultAddr == null) return '';

    final fields = defaultAddr.toShopifyFormat();
    final scriptParts = <String>[];

    fields.forEach((fieldName, value) {
      if (value.isNotEmpty) {
        scriptParts.add('''
          var field_$fieldName = document.querySelector('input[name="$fieldName"], input[id*="${fieldName.replaceAll('[', '_').replaceAll(']', '_')}"]');
          if (field_$fieldName) {
            field_$fieldName.value = "$value";
            field_$fieldName.dispatchEvent(new Event('input', { bubbles: true }));
            field_$fieldName.dispatchEvent(new Event('change', { bubbles: true }));
          }
        ''');
      }
    });

    return '''
      try {
        console.log('Auto-filling address for: ${defaultAddr.fullName}');
        ${scriptParts.join('\n')}
        
        // Also try common Shopify field selectors
        var firstNameField = document.querySelector('#checkout_shipping_address_first_name, [data-backup="first_name"]');
        if (firstNameField) firstNameField.value = "${defaultAddr.firstName}";
        
        var lastNameField = document.querySelector('#checkout_shipping_address_last_name, [data-backup="last_name"]');
        if (lastNameField) lastNameField.value = "${defaultAddr.lastName}";
        
        var address1Field = document.querySelector('#checkout_shipping_address_address1, [data-backup="address1"]');
        if (address1Field) address1Field.value = "${defaultAddr.address1}";
        
        var cityField = document.querySelector('#checkout_shipping_address_city, [data-backup="city"]');
        if (cityField) cityField.value = "${defaultAddr.city}";
        
        var zipField = document.querySelector('#checkout_shipping_address_zip, [data-backup="zip"]');
        if (zipField) zipField.value = "${defaultAddr.zip}";
        
        console.log('Address autofill completed');
      } catch (e) {
        console.error('Address autofill error:', e);
      }
    ''';
  }
}
