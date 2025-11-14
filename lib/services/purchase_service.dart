import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  PurchaseService._();
  static final instance = PurchaseService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  Future<void> initialize() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (available) {
      // Listen to purchase updates
      _inAppPurchase.purchaseStream.listen((List<PurchaseDetails> purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        // Handle stream being closed
      }, onError: (error) {
        // Handle error here.
      });
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Grant entitlement
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> makePurchase(String productId) async {
     final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({productId});
    if (response.notFoundIDs.isNotEmpty) {
      // Handle the error.
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }
}
