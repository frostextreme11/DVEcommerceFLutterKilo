import 'dart:convert';
import 'package:http/http.dart' as http;

class RajaOngkirService {
  static const String _baseUrl = 'https://rajaongkir.komerce.id';
  static const String _apiKey = 'ecdd98c4062f483e2d606259bb1101b6';

  // Search for domestic destinations with debouncing support
  static Future<List<Destination>> searchDestinations(
    String query, {
    int limit = 5,
    int offset = 0,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final url =
          '$_baseUrl/api/v1/destination/domestic-destination?search=$query&limit=$limit&offset=$offset';
      print('RajaOngkir API Request: GET $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'key': _apiKey, 'Content-Type': 'application/json'},
      );

      print('RajaOngkir API Response Status: ${response.statusCode}');
      print('RajaOngkir API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['meta']['status'] == 'success') {
          final results = (data['data'] as List)
              .map((item) => Destination.fromJson(item))
              .toList();
          print('Successfully parsed ${results.length} destinations');
          return results;
        } else {
          print('API returned error: ${data['meta']['message']}');
        }
      } else {
        print('API request failed with status: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error searching destinations: $e');
      return [];
    }
  }

  // Calculate shipping costs
  static Future<List<ShippingCost>> calculateShippingCost({
    required String origin,
    required String destination,
    required int weight,
    required String couriers,
    String price = 'lowest',
  }) async {
    try {
      final url = '$_baseUrl/api/v1/calculate/domestic-cost';
      print('RajaOngkir Cost API Request: POST $url');
      print(
        'Body: origin=$origin, destination=$destination, weight=$weight, courier=$couriers, price=$price',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'key': _apiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'origin': origin,
          'destination': destination,
          'weight': weight.toString(),
          'courier': couriers,
          'price': price,
        },
      );

      print('RajaOngkir Cost API Response Status: ${response.statusCode}');
      print('RajaOngkir Cost API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['meta']['status'] == 'success') {
          final results = (data['data'] as List)
              .map((item) => ShippingCost.fromJson(item))
              .toList();
          print('Successfully parsed ${results.length} shipping costs');
          return results;
        } else {
          print('Cost API returned error: ${data['meta']['message']}');
        }
      } else {
        print('Cost API request failed with status: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      print('Error calculating shipping cost: $e');
      return [];
    }
  }

  // Get all available couriers
  static List<Courier> getAvailableCouriers() {
    return [
      Courier(code: 'jne', name: 'JNE'),
      Courier(code: 'sicepat', name: 'SiCepat'),
      Courier(code: 'ide', name: 'IDExpress'),
      Courier(code: 'sap', name: 'SAP Express'),
      Courier(code: 'ninja', name: 'Ninja'),
      Courier(code: 'jnt', name: 'J&T Express'),
      Courier(code: 'tiki', name: 'TIKI'),
      Courier(code: 'wahana', name: 'Wahana Express'),
      Courier(code: 'pos', name: 'POS Indonesia'),
      Courier(code: 'sentral', name: 'Sentral Cargo'),
      Courier(code: 'lion', name: 'Lion Parcel'),
      Courier(code: 'rex', name: 'Royal Express Asia'),
    ];
  }

  // Get hardcoded couriers with zero shipping cost
  static List<ShippingCost> getHardcodedZeroCostCouriers() {
    return [
      ShippingCost(
        name: 'SPX',
        code: 'spx',
        service: 'Resi Otomatis',
        description: 'SPX Resi Otomatis',
        cost: 0,
        etd: '1-2 hari',
      ),
      ShippingCost(
        name: 'J&T Express',
        code: 'jnt',
        service: 'Resi Otomatis',
        description: 'JNT Resi Otomatis',
        cost: 0,
        etd: '1-2 hari',
      ),
    ];
  }

  // Get popular origin cities (these would typically come from API)
  static List<Destination> getPopularOriginCities() {
    return [
      Destination(
        id: 1,
        label: 'JAKARTA PUSAT, GAMBIR, JAKARTA PUSAT, DKI JAKARTA, 10110',
        provinceName: 'DKI JAKARTA',
        cityName: 'JAKARTA PUSAT',
        districtName: 'GAMBIR',
        subdistrictName: 'JAKARTA PUSAT',
        zipCode: '10110',
      ),
      Destination(
        id: 2,
        label: 'BANDUNG, BANDUNG WETAN, BANDUNG, JAWA BARAT, 40115',
        provinceName: 'JAWA BARAT',
        cityName: 'BANDUNG',
        districtName: 'BANDUNG WETAN',
        subdistrictName: 'BANDUNG',
        zipCode: '40115',
      ),
      Destination(
        id: 3,
        label: 'SURABAYA, TEGALSARI, SURABAYA, JAWA TIMUR, 60262',
        provinceName: 'JAWA TIMUR',
        cityName: 'SURABAYA',
        districtName: 'TEGALSARI',
        subdistrictName: 'SURABAYA',
        zipCode: '60262',
      ),
      Destination(
        id: 4,
        label: 'MEDAN, MEDAN BARU, MEDAN, SUMATERA UTARA, 20153',
        provinceName: 'SUMATERA UTARA',
        cityName: 'MEDAN',
        districtName: 'MEDAN BARU',
        subdistrictName: 'MEDAN',
        zipCode: '20153',
      ),
      Destination(
        id: 5,
        label: 'SEMARANG, SEMARANG TENGAH, SEMARANG, JAWA TENGAH, 50138',
        provinceName: 'JAWA TENGAH',
        cityName: 'SEMARANG',
        districtName: 'SEMARANG TENGAH',
        subdistrictName: 'SEMARANG',
        zipCode: '50138',
      ),
    ];
  }
}

class Destination {
  final int id;
  final String label;
  final String provinceName;
  final String cityName;
  final String districtName;
  final String subdistrictName;
  final String zipCode;

  Destination({
    required this.id,
    required this.label,
    required this.provinceName,
    required this.cityName,
    required this.districtName,
    required this.subdistrictName,
    required this.zipCode,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'],
      label: json['label'],
      provinceName: json['province_name'],
      cityName: json['city_name'],
      districtName: json['district_name'],
      subdistrictName: json['subdistrict_name'],
      zipCode: json['zip_code'],
    );
  }

  @override
  String toString() {
    return label;
  }
}

class ShippingCost {
  final String name;
  final String code;
  final String service;
  final String description;
  final int cost;
  final String etd;

  ShippingCost({
    required this.name,
    required this.code,
    required this.service,
    required this.description,
    required this.cost,
    required this.etd,
  });

  factory ShippingCost.fromJson(Map<String, dynamic> json) {
    return ShippingCost(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      service: json['service'] ?? '',
      description: json['description'] ?? '',
      cost: json['cost'] ?? 0,
      etd: json['etd'] ?? '',
    );
  }

  @override
  String toString() {
    return '$name $service - Rp ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }
}

class Courier {
  final String code;
  final String name;

  Courier({required this.code, required this.name});

  @override
  String toString() {
    return name;
  }
}
