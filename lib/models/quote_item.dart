class QuoteItem {
  final String productId;
  final String name;
  final String reference;
  final double price;
  int quantity;

  QuoteItem({
    required this.productId,
    required this.name,
    required this.reference,
    required this.price,
    this.quantity = 1,
  });

  double get total => price * quantity;
}