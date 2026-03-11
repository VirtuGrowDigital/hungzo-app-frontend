import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:http/http.dart' as http;
import 'package:hungzo_app/services/Api/api_constants.dart';

class CartController extends GetxController {

  /// ================= STATE =================

  final RxList<CartItem> cartItems = <CartItem>[].   obs;
  final RxBool isLoading = false.obs;

  /// 🔥 LOCAL PRICE STATE
  final RxDouble subtotal = 0.0.obs;
  final RxDouble deliveryFee = 0.0.obs;
  final RxDouble platformFee = 12.0.obs; // fixed example
  final RxDouble totalAmount = 0.0.obs;


  final String cartUrl = "${ApiConstants.baseURL}cart";

  final FlutterSecureStorage secureStorage =
  const FlutterSecureStorage();

  @override
  void onReady() {
    super.onReady();
    fetchCart();
  }

  // =====================================================
  // 🔥 MAIN CALCULATION FUNCTION (VERY IMPORTANT)
  // =====================================================

  void calculateTotals() {

    /// subtotal
    double sub = cartItems.fold(
      0,
          (sum, item) => sum + (item.price * item.quantity),
    );

    subtotal.value = sub;



    /// total
    totalAmount.value =
        subtotal.value + deliveryFee.value + platformFee.value;
  }

  // =====================================================
  // FETCH CART
  // =====================================================

  Future<void> fetchCart() async {
    try {
      isLoading(true);

      final token = await secureStorage.read(key: 'accessToken');
      if (token == null) return;

      final response = await http.get(
        Uri.parse(cartUrl),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          // Safely update existing observables
          subtotal.value = (data["subTotal"] ?? 0).toDouble();
          deliveryFee.value = (data["deliveryCharge"] ?? 0).toDouble();
          platformFee.value = (data["platformFee"] ?? 0).toDouble();
          totalAmount.value = (data["totalAmount"] ?? 0).toDouble();

          final List<dynamic> itemsList = data['items'] ?? [];
          cartItems.value = itemsList.map((e) => CartItem.fromJson(e)).toList();

          /// 🔥 calculate totals locally
          calculateTotals();
        } catch (e) {
          print("Error parsing cart JSON: $e");
        }
      } else {
        print("Failed to fetch cart. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("fetchCart error: $e");
    } finally {
      isLoading(false);
    }
  }
  // =====================================================
  // REMOVE
  // =====================================================

  void removeItem(CartItem item) {
    cartItems.remove(item);
    calculateTotals();
  }

  // =====================================================
  // QUANTITY UPDATE (LIVE)
  // =====================================================

  void increaseQty(CartItem item) {
    item.quantity++;
    cartItems.refresh();
    calculateTotals(); // 🔥 live update
  }

  void decreaseQty(CartItem item) {
    item.quantity--;

    if (item.quantity < 1) {
      cartItems.remove(item);
    }

    cartItems.refresh();
    calculateTotals(); // 🔥 live update
  }
}


/// ---------------- MODEL ----------------
class CartItem {
  final String productId;
  final String varietyId;
  final String name;
  final String image;
  final double price;
  int quantity;

  CartItem({
    required this.productId,
    required this.varietyId,
    required this.name,
    required this.image,
    required this.price,
    required this.quantity,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId'],
      varietyId: json['variety']['id'],
      name: json['productName'],
      image: json['image'],
      price: (json['variety']['price'] as num).toDouble(),
      quantity: json['quantity'],
    );
  }
}
