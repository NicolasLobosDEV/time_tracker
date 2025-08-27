// lib/models/line_item.dart
import 'dart:convert';

class LineItem {
  final String description;
  final double quantity; // Represents hours
  final double unitPrice; // Represents hourly rate

  LineItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  // Methods to convert to/from JSON so we can save it in the database
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory LineItem.fromJson(Map<String, dynamic> json) {
    return LineItem(
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }
}

// Helper functions to encode/decode a list of items
String lineItemsToJson(List<LineItem> items) {
  return jsonEncode(items.map((item) => item.toJson()).toList());
}

List<LineItem> lineItemsFromJson(String jsonString) {
  final List<dynamic> parsed = jsonDecode(jsonString);
  return parsed.map((json) => LineItem.fromJson(json)).toList();
}