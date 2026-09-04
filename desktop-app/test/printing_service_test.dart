import 'package:flutter_test/flutter_test.dart';
import 'package:hirall_pos/core/services/printing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrintingService Thermal Receipt PDF Generation Tests', () {
    test('generateThermalReceiptPdf creates valid 80mm front receipt with custom branding', () async {
      final saleData = {
        'storeName': 'GIFTMART SUPERMARKET',
        'branchName': 'KERICHO',
        'branchTagline': 'KERICHO SUPERMARKET & HYPER STORE',
        'taxPin': 'P051234567Z',
        'etrNote': 'KRA eTIMS VALIDATED FISCAL RECEIPT',
        'building': 'Famous Gate Plaza, Ground Floor',
        'street': 'Kenyatta Road',
        'city': 'Kericho, Kenya',
        'phone': '+254 711 000 111',
        'emailWeb': 'info@giftmart.co.ke | www.giftmart.co.ke',
        'festiveEnabled': true,
        'festiveHeader': '* MERRY CHRISTMAS & HAPPY NEW YEAR *',
        'festiveFooter': 'Wishing you joyful holidays from all of us!',
        'activeSide': 'front',
        'tillNumber': 'LANE-01',
        'receiptNo': 'REC-829102',
        'cashier': 'Faith Chepkemoi',
        'dateTime': DateTime(2026, 9, 4, 10, 30),
        'items': [
          {'name': 'Brookside Dairy Best Whole Milk 500ml', 'unitPrice': 70.0, 'quantity': 2.0, 'taxRate': 16.0},
          {'name': 'Pembe Maize Meal Flour 2kg', 'unitPrice': 210.0, 'quantity': 1.0, 'taxRate': 16.0},
        ],
        'subtotal': 350.0,
        'discount': 0.0,
        'tax': 48.28,
        'total': 350.0,
        'paymentMethod': 'M-PESA',
        'amountPaid': 350.0,
        'change': 0.0,
        'mpesaCode': 'SKE98219XZ',
      };

      final bytes = await PrintingService.instance.generateThermalReceiptPdf(saleData, paperWidthMm: 80);
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // PDF magic bytes start with %PDF
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('generateThermalReceiptPdf creates valid 58mm compact dual-sided receipt with sanitized characters', () async {
      final saleData = {
        'storeName': 'NAIVAS EXPRESS • NAIROBI',
        'branchName': 'CBD',
        'branchTagline': '⚡ SUPER SAVINGS MEGASTORE ⚡',
        'taxPin': 'P059998887A',
        'activeSide': 'both',
        'backLogoEnabled': true,
        'backPromotionTitle': '★ SPECIAL PROMOTIONAL VOUCHER ★',
        'backPromotionBody': 'Get 10% OFF your next purchase of KES 2,500 or more! Present receipt at checkout.',
        'backReturnPolicy': 'Goods once sold are exchangeable within 7 days with original receipt.',
        'backWarrantyTerms': '1. Electrical appliances carry a 12-month manufacturer warranty.',
        'items': [
          {'name': 'Fresh Fri Cooking Oil 1L', 'unitPrice': 310.0, 'quantity': 1.0, 'taxRate': 16.0},
        ],
        'subtotal': 310.0,
        'discount': 0.0,
        'tax': 42.76,
        'total': 310.0,
        'paymentMethod': 'CASH',
        'amountPaid': 500.0,
        'change': 190.0,
      };

      final bytes = await PrintingService.instance.generateThermalReceiptPdf(saleData, paperWidthMm: 58);
      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('sanitizePdfText converts non-ASCII characters to standard ASCII symbols safely', () {
      final input = '• Bullet ★ Star ⚡ Lightning — EmDash – EnDash “DoubleQuotes” ‘SingleQuotes’';
      final sanitized = PrintingService.sanitizePdfText(input);
      expect(sanitized, equals('| Bullet * Star * Lightning - EmDash - EnDash "DoubleQuotes" \'SingleQuotes\''));
    });
  });
}
