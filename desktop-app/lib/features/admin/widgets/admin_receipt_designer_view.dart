import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/printing_service.dart';
import 'thermal_receipt_print_preview_dialog.dart';

class AdminReceiptDesignerView extends StatefulWidget {
  final String organizationName;
  final String branchName;

  const AdminReceiptDesignerView({
    super.key,
    required this.organizationName,
    required this.branchName,
  });

  @override
  State<AdminReceiptDesignerView> createState() => _AdminReceiptDesignerState();
}

class _AdminReceiptDesignerState extends State<AdminReceiptDesignerView> {
  String _activeSide = 'front'; // 'front' | 'back'
  int _paperWidthMm = 80;

  // Store Logo & Brand Identity
  bool _showLogo = true;
  Uint8List? _logoBytes;
  String _logoFileName = 'giftmart.png';
  double _logoWidth = 160.0;
  bool _logoMonochrome = true;

  // Store Front Branding
  late TextEditingController _storeNameController;
  late TextEditingController _branchTaglineController;
  late TextEditingController _taxPinController;
  late TextEditingController _etrNoteController;
  late TextEditingController _buildingController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _phoneController;
  late TextEditingController _emailWebController;

  // Festive Banners
  bool _festiveEnabled = false;
  String _festivePreset = 'None';
  String _festiveHeader = '* MERRY CHRISTMAS & HAPPY NEW YEAR *';
  String _festiveFooter = 'Thank you for celebrating the holidays with us!';

  // Back of Receipt Branding
  bool _backLogoEnabled = true;
  String _backPromotionTitle = 'SPECIAL PROMOTIONAL VOUCHER';
  String _backPromotionBody = 'Get 10% OFF your next purchase of KES 2,500 or more! Present this receipt at checkout.';
  String _backReturnPolicy = 'Goods once sold are exchangeable within 7 days with original receipt. Non-perishables only. No cash refunds.';
  String _backWarrantyTerms = '1. Electrical appliances carry a 12-month manufacturer warranty.\n2. Fresh bakery, dairy & butchery items must be inspected upon purchase.\n3. Discounted clearance goods are final sale.';

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(text: widget.organizationName.toUpperCase());
    _branchTaglineController = TextEditingController(text: '${widget.branchName} SUPERMARKET & HYPER STORE');
    _taxPinController = TextEditingController(text: 'P051234567Z');
    _etrNoteController = TextEditingController(text: 'KRA eTIMS VALIDATED FISCAL RECEIPT');
    _buildingController = TextEditingController(text: 'Famous Gate Plaza, Ground Floor');
    _streetController = TextEditingController(text: 'Kenyatta Road');
    _cityController = TextEditingController(text: 'Kericho, Kenya');
    _phoneController = TextEditingController(text: '+254 711 000 111');
    _emailWebController = TextEditingController(text: 'info@giftmart.co.ke | www.giftmart.co.ke');

    _loadBrandingPreferences();
  }

  bool _isValidImageBytes(Uint8List? bytes) {
    if (bytes == null || bytes.length < 8) return false;
    // PNG magic: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // JPEG magic: 0xFF 0xD8 0xFF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // GIF magic: 0x47 0x49 0x46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WebP: RIFF
    if (bytes.length >= 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return true;
    return false;
  }

  Future<void> _loadBrandingPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      // Load logo
      _showLogo = prefs.getBool('receipt_show_logo') ?? true;
      _logoWidth = prefs.getDouble('receipt_logo_width') ?? 160.0;
      _logoMonochrome = prefs.getBool('receipt_logo_monochrome') ?? true;
      _logoFileName = prefs.getString('receipt_logo_filename') ?? 'giftmart.png';

      final savedLogoBase64 = prefs.getString('receipt_logo_base64');
      if (savedLogoBase64 != null && savedLogoBase64.isNotEmpty) {
        try {
          final cleanBase64 = savedLogoBase64.contains(',') ? savedLogoBase64.split(',').last : savedLogoBase64;
          final decoded = base64Decode(cleanBase64.trim());
          if (_isValidImageBytes(decoded)) {
            _logoBytes = decoded;
          } else {
            await prefs.remove('receipt_logo_base64');
          }
        } catch (e) {
          debugPrint('Error decoding saved logo: $e');
        }
      }

      if (_logoBytes == null) {
        try {
          if (File('/home/kipchir/giftmart.png').existsSync()) {
            _logoBytes = await File('/home/kipchir/giftmart.png').readAsBytes();
            _logoFileName = 'giftmart.png';
          } else {
            final assetData = await rootBundle.load('assets/images/giftmart.png');
            _logoBytes = assetData.buffer.asUint8List();
            _logoFileName = 'giftmart.png';
          }
        } catch (e) {
          debugPrint('Error loading default logo asset: $e');
        }
      }

      setState(() {
        if (prefs.containsKey('receipt_store_name')) {
          _storeNameController.text = prefs.getString('receipt_store_name')!;
        }
        if (prefs.containsKey('receipt_branch_tagline')) {
          _branchTaglineController.text = prefs.getString('receipt_branch_tagline')!;
        }
        if (prefs.containsKey('receipt_tax_pin')) {
          _taxPinController.text = prefs.getString('receipt_tax_pin')!;
        }
        if (prefs.containsKey('receipt_etr_note')) {
          _etrNoteController.text = prefs.getString('receipt_etr_note')!;
        }
        if (prefs.containsKey('receipt_building')) {
          _buildingController.text = prefs.getString('receipt_building')!;
        }
        if (prefs.containsKey('receipt_street')) {
          _streetController.text = prefs.getString('receipt_street')!;
        }
        if (prefs.containsKey('receipt_city')) {
          _cityController.text = prefs.getString('receipt_city')!;
        }
        if (prefs.containsKey('receipt_phone')) {
          _phoneController.text = prefs.getString('receipt_phone')!;
        }
        if (prefs.containsKey('receipt_emailWeb')) {
          _emailWebController.text = prefs.getString('receipt_emailWeb')!;
        } else if (prefs.containsKey('receipt_email_web')) {
          _emailWebController.text = prefs.getString('receipt_email_web')!;
        }
        _festiveEnabled = prefs.getBool('receipt_festive_enabled') ?? _festiveEnabled;
        _festivePreset = prefs.getString('receipt_festive_preset') ?? _festivePreset;
        _festiveHeader = prefs.getString('receipt_festive_header') ?? _festiveHeader;
        _festiveFooter = prefs.getString('receipt_festive_footer') ?? _festiveFooter;
        _paperWidthMm = prefs.getInt('receipt_paper_width_mm') ?? _paperWidthMm;
        _backLogoEnabled = prefs.getBool('receipt_back_logo_enabled') ?? _backLogoEnabled;
        _backPromotionTitle = prefs.getString('receipt_back_promo_title') ?? _backPromotionTitle;
        _backPromotionBody = prefs.getString('receipt_back_promo_body') ?? _backPromotionBody;
        _backReturnPolicy = prefs.getString('receipt_back_return_policy') ?? _backReturnPolicy;
        _backWarrantyTerms = prefs.getString('receipt_back_warranty_terms') ?? _backWarrantyTerms;
      });
    } catch (e) {
      debugPrint('Error loading receipt branding preferences: $e');
    }
  }

  Future<void> _pickLogoFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg'],
      );
      if (files.isNotEmpty && files.first.path != null) {
        final platformFile = files.first;
        final file = File(platformFile.path!);
        final bytes = await file.readAsBytes();
        setState(() {
          _logoBytes = bytes;
          _logoFileName = platformFile.name;
          _showLogo = true;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('receipt_logo_base64', base64Encode(bytes));
        await prefs.setString('receipt_logo_filename', platformFile.name);
        await prefs.setBool('receipt_show_logo', true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Store logo "${platformFile.name}" loaded & applied to POS registers!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking logo file: $e');
    }
  }

  Future<void> _removeLogo() async {
    setState(() {
      _logoBytes = null;
      _logoFileName = '';
      _showLogo = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('receipt_logo_base64');
    await prefs.remove('receipt_logo_filename');
    await prefs.setBool('receipt_show_logo', false);
  }

  Future<void> _saveBrandingPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('receipt_show_logo', _showLogo);
      await prefs.setDouble('receipt_logo_width', _logoWidth);
      await prefs.setBool('receipt_logo_monochrome', _logoMonochrome);
      await prefs.setString('receipt_logo_filename', _logoFileName);
      if (_logoBytes != null) {
        await prefs.setString('receipt_logo_base64', base64Encode(_logoBytes!));
      }

      await prefs.setString('receipt_store_name', _storeNameController.text.trim());
      await prefs.setString('receipt_branch_tagline', _branchTaglineController.text.trim());
      await prefs.setString('receipt_tax_pin', _taxPinController.text.trim());
      await prefs.setString('receipt_etr_note', _etrNoteController.text.trim());
      await prefs.setString('receipt_building', _buildingController.text.trim());
      await prefs.setString('receipt_street', _streetController.text.trim());
      await prefs.setString('receipt_city', _cityController.text.trim());
      await prefs.setString('receipt_phone', _phoneController.text.trim());
      await prefs.setString('receipt_email_web', _emailWebController.text.trim());
      await prefs.setBool('receipt_festive_enabled', _festiveEnabled);
      await prefs.setString('receipt_festive_preset', _festivePreset);
      await prefs.setString('receipt_festive_header', _festiveHeader);
      await prefs.setString('receipt_festive_footer', _festiveFooter);
      await prefs.setInt('receipt_paper_width_mm', _paperWidthMm);
      await prefs.setBool('receipt_back_logo_enabled', _backLogoEnabled);
      await prefs.setString('receipt_back_promo_title', _backPromotionTitle);
      await prefs.setString('receipt_back_promo_body', _backPromotionBody);
      await prefs.setString('receipt_back_return_policy', _backReturnPolicy);
      await prefs.setString('receipt_back_warranty_terms', _backWarrantyTerms);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt template & logo saved & synced across ${widget.branchName} tills!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving receipt branding: $e');
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _branchTaglineController.dispose();
    _taxPinController.dispose();
    _etrNoteController.dispose();
    _buildingController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailWebController.dispose();
    super.dispose();
  }

  void _applyFestivePreset(String preset) {
    setState(() {
      _festivePreset = preset;
      if (preset == 'Christmas') {
        _festiveEnabled = true;
        _festiveHeader = '* MERRY CHRISTMAS & HAPPY NEW YEAR *';
        _festiveFooter = 'Wishing you joyful holidays from all of us!';
      } else if (preset == 'Eid') {
        _festiveEnabled = true;
        _festiveHeader = '* EID MUBARAK *';
        _festiveFooter = 'Blessed Eid to you and your family!';
      } else if (preset == 'Easter') {
        _festiveEnabled = true;
        _festiveHeader = '* HAPPY EASTER HOLIDAYS *';
        _festiveFooter = 'Warm Easter greetings from our store!';
      } else if (preset == 'Black Friday') {
        _festiveEnabled = true;
        _festiveHeader = '* MEGA BLACK FRIDAY SUPER SAVINGS *';
        _festiveFooter = 'Exclusive discounts available all weekend!';
      } else if (preset == 'Grand Opening') {
        _festiveEnabled = true;
        _festiveHeader = '* GRAND OPENING CELEBRATION *';
        _festiveFooter = 'Thank you for being one of our first valued shoppers!';
      } else {
        _festiveEnabled = false;
      }
    });
  }

  Future<void> _testPrintConfiguredReceipt() async {
    final sampleSale = {
      'showLogo': _showLogo,
      'logoBytes': _logoBytes,
      'logoWidth': _logoWidth,
      'logoMonochrome': _logoMonochrome,
      'storeName': _storeNameController.text.trim().isNotEmpty ? _storeNameController.text.trim() : widget.organizationName.toUpperCase(),
      'branchName': widget.branchName,
      'branchTagline': _branchTaglineController.text.trim(),
      'taxPin': _taxPinController.text.trim(),
      'etrNote': _etrNoteController.text.trim(),
      'building': _buildingController.text.trim(),
      'street': _streetController.text.trim(),
      'city': _cityController.text.trim(),
      'phone': _phoneController.text.trim(),
      'emailWeb': _emailWebController.text.trim(),
      'festiveEnabled': _festiveEnabled,
      'festiveHeader': _festiveHeader,
      'festiveFooter': _festiveFooter,
      'activeSide': _activeSide,
      'paperWidthMm': _paperWidthMm,
      'backLogoEnabled': _backLogoEnabled,
      'backPromotionTitle': _backPromotionTitle,
      'backPromotionBody': _backPromotionBody,
      'backReturnPolicy': _backReturnPolicy,
      'backWarrantyTerms': _backWarrantyTerms,
      'tillNumber': 'LANE-01',
      'receiptNo': 'RCPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      'cashier': 'Faith Chepkemoi',
      'dateTime': DateTime.now(),
      'items': [
        {'name': 'Brookside Whole Milk 500ml', 'unitPrice': 74.0, 'quantity': 2.0, 'taxRate': 16.0},
        {'name': 'Pembe Maize Flour 2kg', 'unitPrice': 210.0, 'quantity': 1.0, 'taxRate': 16.0},
        {'name': 'Fresh Fri Cooking Oil 1L', 'unitPrice': 310.0, 'quantity': 1.0, 'taxRate': 16.0},
      ],
      'subtotal': 668.0,
      'discount': 8.0,
      'tax': 91.03,
      'total': 660.0,
      'paymentMethod': 'M-PESA',
      'amountPaid': 660.0,
      'change': 0.0,
      'mpesaCode': 'SKE98219XZ',
    };

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPrintPreviewDialog(
        saleData: sampleSale,
        paperWidthMm: _paperWidthMm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Configuration Controls (60%)
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Side Switcher & Paper Width
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Front vs Back Tab Switcher
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            _buildSidePill('front', 'Front (Fiscal & Items)'),
                            _buildSidePill('back', 'Back (Branding & Terms)'),
                          ],
                        ),
                      ),

                      // Paper Width
                      Row(
                        children: [
                          _buildWidthPill(80, '80mm Standard'),
                          const SizedBox(width: 8),
                          _buildWidthPill(58, '58mm Compact'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (_activeSide == 'front') ...[
                    // CARD 1: STORE LOGO & BRAND IDENTITY
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(LucideIcons.image, size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Store Logo & Brand Identity',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                                      ),
                                      Text(
                                        'Upload company logo and define master business headers.',
                                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: _showLogo,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setState(() => _showLogo = val),
                              ),
                            ],
                          ),
                          if (_showLogo) ...[
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: _pickLogoFile,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.border(context)),
                                ),
                                child: _logoBytes != null
                                    ? Row(
                                        children: [
                                          Container(
                                            width: 72,
                                            height: 48,
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Image.memory(
                                              _logoBytes!,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.image, size: 28, color: Colors.grey),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _logoFileName,
                                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'High-Contrast Thermal Logo Ready',
                                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: _pickLogoFile,
                                            icon: const Icon(LucideIcons.refreshCw, size: 13),
                                            label: const Text('Replace', style: TextStyle(fontSize: 11.5)),
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: _removeLogo,
                                            icon: const Icon(LucideIcons.trash2, size: 13, color: AppColors.danger),
                                            label: const Text('Remove', style: TextStyle(fontSize: 11.5, color: AppColors.danger)),
                                            style: OutlinedButton.styleFrom(
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          const Icon(LucideIcons.uploadCloud, size: 28, color: AppColors.primary),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Click to upload store logo (PNG, JPG, SVG)',
                                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                          ),
                                          Text(
                                            'Recommended: Transparent PNG (max 500KB)',
                                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Logo Display Width (${_logoWidth.toInt()}px)',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                      ),
                                      Slider(
                                        value: _logoWidth,
                                        min: 80,
                                        max: 240,
                                        divisions: 16,
                                        activeColor: AppColors.primary,
                                        label: '${_logoWidth.toInt()}px',
                                        onChanged: (val) => setState(() => _logoWidth = val),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 5,
                                  child: InkWell(
                                    onTap: () => setState(() => _logoMonochrome = !_logoMonochrome),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _logoMonochrome,
                                          activeColor: AppColors.primary,
                                          onChanged: (val) => setState(() => _logoMonochrome = val ?? true),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'High-Contrast Thermal Monochrome',
                                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Store Header & Fiscal Information
                    Text(
                      'Store Header & Fiscal Information',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                    ),
                    const SizedBox(height: 14),

                    _buildField('Store / Business Name *', _storeNameController, 'e.g. GIFTMART SUPERMARKET', LucideIcons.store),
                    const SizedBox(height: 12),

                    _buildField('Branch Subtitle & Tagline', _branchTaglineController, 'e.g. KERICHO SUPERMARKET & HYPER STORE', LucideIcons.tag),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _buildField('KRA Tax PIN *', _taxPinController, 'e.g. P051234567Z', LucideIcons.hash)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('ETR Note', _etrNoteController, 'e.g. KRA eTIMS VALIDATED FISCAL RECEIPT', LucideIcons.shieldCheck)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _buildField('Building / Mall', _buildingController, 'e.g. Famous Gate Plaza', LucideIcons.building)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Street / Road', _streetController, 'e.g. Kenyatta Road', LucideIcons.mapPin)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('City / Town', _cityController, 'e.g. Kericho, Kenya', LucideIcons.map)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _buildField('Contact Phone', _phoneController, 'e.g. +254 711 000 111', LucideIcons.phone)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Email & Web', _emailWebController, 'e.g. info@giftmart.co.ke', LucideIcons.globe)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Festive Banner Section
                    Text(
                      'Seasonal & Festive Banner Greetings',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip('None'),
                        _buildPresetChip('Christmas'),
                        _buildPresetChip('Eid'),
                        _buildPresetChip('Easter'),
                        _buildPresetChip('Black Friday'),
                        _buildPresetChip('Grand Opening'),
                      ],
                    ),
                    if (_festiveEnabled) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: TextEditingController(text: _festiveHeader),
                        onChanged: (val) => setState(() => _festiveHeader = val),
                        decoration: const InputDecoration(labelText: 'Festive Header Greeting (Top of Receipt)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: TextEditingController(text: _festiveFooter),
                        onChanged: (val) => setState(() => _festiveFooter = val),
                        decoration: const InputDecoration(labelText: 'Festive Footer Wish (Bottom of Receipt)'),
                      ),
                    ],
                  ] else ...[
                    // BACK SIDE CONFIGURATION
                    Text(
                      'Back of Receipt: Image Branding, Adverts & Policies',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                    ),
                    const SizedBox(height: 14),

                    // Logo / Banner Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _backLogoEnabled,
                      activeColor: AppColors.primary,
                      title: Text(
                        'Include High-Contrast Monochrome Store Brand Logo',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                      ),
                      subtitle: Text(
                        'Renders high-resolution vector store crest and QR loyalty barcode on the reverse side of the thermal tape',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                      ),
                      onChanged: (val) => setState(() => _backLogoEnabled = val),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: TextEditingController(text: _backPromotionTitle),
                      onChanged: (val) => setState(() => _backPromotionTitle = val),
                      decoration: const InputDecoration(
                        labelText: 'Promotional Voucher Banner Title',
                        prefixIcon: Icon(LucideIcons.sparkles, size: 16),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: TextEditingController(text: _backPromotionBody),
                      onChanged: (val) => setState(() => _backPromotionBody = val),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Promotional Offer & Discount Conditions',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: TextEditingController(text: _backReturnPolicy),
                      onChanged: (val) => setState(() => _backReturnPolicy = val),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Return, Exchange & Refund Policy',
                        prefixIcon: Icon(LucideIcons.repeat, size: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: TextEditingController(text: _backWarrantyTerms),
                      onChanged: (val) => setState(() => _backWarrantyTerms = val),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Warranty & Purchase Terms',
                        prefixIcon: Icon(LucideIcons.fileText, size: 16),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _testPrintConfiguredReceipt,
                        icon: const Icon(LucideIcons.printer, size: 16),
                        label: const Text('Test Print to POS Hardware'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _saveBrandingPreferences,
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: const Text('Save & Sync to Tills'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Right Column: Live Dual-Sided Thermal Receipt Tape Preview (40%)
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LIVE THERMAL TAPE PREVIEW (${_paperWidthMm}mm)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.8),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Print to POS / Preview PDF',
                        onPressed: _testPrintConfiguredReceipt,
                        icon: const Icon(LucideIcons.printer, size: 16),
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_activeSide.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Thermal Receipt Tape Container (White Paper Style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.black, fontFamily: 'monospace', fontSize: 10.5, height: 1.3),
                  child: _activeSide == 'front' ? _buildFrontPreview() : _buildBackPreview(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFrontPreview() {
    return Column(
      children: [
        // Store Logo Preview
        if (_showLogo && _logoBytes != null && _logoBytes!.isNotEmpty) ...[
          Center(
            child: Container(
              width: (_logoWidth * 0.7).clamp(60.0, 160.0),
              height: 44,
              margin: const EdgeInsets.only(bottom: 6),
              child: Image.memory(
                _logoBytes!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.image, size: 28, color: Colors.grey),
              ),
            ),
          ),
        ],

        if (_festiveEnabled) ...[
          Text(_festiveHeader, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10), textAlign: TextAlign.center),
          const Divider(color: Colors.black54, thickness: 0.8, height: 10),
        ],
        Text(_storeNameController.text.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1), textAlign: TextAlign.center),
        Text(_branchTaglineController.text, style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.center),
        Text('${_buildingController.text}, ${_streetController.text}', style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
        Text(_cityController.text, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
        Text('TEL: ${_phoneController.text}', style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
        Text('PIN: ${_taxPinController.text}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        Text(_etrNoteController.text, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        const Divider(color: Colors.black54, thickness: 0.8, height: 12),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('RCPT: REC-829102'), Text('03/09/26 21:05')]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('Cashier: Faith C.'), Text('Lane: TILL-01')]),
        const Divider(color: Colors.black54, thickness: 0.8, height: 12),

        Row(children: const [
          Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.w800))),
          Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800))),
          Expanded(flex: 3, child: Text('AMT (KES)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const Divider(color: Colors.black54, thickness: 0.5, height: 8),

        Row(children: const [
          Expanded(flex: 5, child: Text('Brookside Milk 500ml')),
          Expanded(flex: 2, child: Text('2', textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('140.00', textAlign: TextAlign.right)),
        ]),
        Row(children: const [
          Expanded(flex: 5, child: Text('Pembe Maize Flour 2kg')),
          Expanded(flex: 2, child: Text('1', textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('210.00', textAlign: TextAlign.right)),
        ]),
        Row(children: const [
          Expanded(flex: 5, child: Text('Fresh Fri Cooking Oil 1L')),
          Expanded(flex: 2, child: Text('1', textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('310.00', textAlign: TextAlign.right)),
        ]),
        const Divider(color: Colors.black54, thickness: 0.8, height: 12),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('SUBTOTAL:'), Text('KES 660.00')]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('16% VAT INCLUDED:'), Text('KES 91.03')]),
        const SizedBox(height: 2),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
          Text('TOTAL AMOUNT:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          Text('KES 660.00', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
        const Divider(color: Colors.black54, thickness: 0.8, height: 12),

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('PAID (M-PESA):'), Text('KES 660.00')]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('M-PESA REF:'), Text('SKE98219XZ', style: TextStyle(fontWeight: FontWeight.w800))]),
        const SizedBox(height: 10),

        BarcodeWidget(barcode: Barcode.code128(), data: 'REC-829102', width: 140, height: 32, drawText: false),
        const SizedBox(height: 6),

        if (_festiveEnabled) ...[
          Text(_festiveFooter, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9), textAlign: TextAlign.center),
          const SizedBox(height: 2),
        ],
        const Text('THANK YOU FOR SHOPPING WITH US!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5), textAlign: TextAlign.center),
        Text(_emailWebController.text, style: const TextStyle(fontSize: 8), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildBackPreview() {
    return Column(
      children: [
        if (_backLogoEnabled) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black87, width: 1.5)),
            child: const Icon(LucideIcons.shoppingBag, size: 28, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(_storeNameController.text.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12), textAlign: TextAlign.center),
          const Divider(color: Colors.black54, thickness: 0.8, height: 14),
        ],

        // Promotion Box
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: Colors.black87, width: 1)),
          child: Column(
            children: [
              Text(_backPromotionTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(_backPromotionBody, style: const TextStyle(fontSize: 8.5), textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Return Policy
        const Text('RETURN & EXCHANGE POLICY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(_backReturnPolicy, style: const TextStyle(fontSize: 8.5), textAlign: TextAlign.center),
        const SizedBox(height: 12),

        // Warranty Terms
        const Text('TERMS & CONDITIONS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 9.5), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(_backWarrantyTerms, style: const TextStyle(fontSize: 8), textAlign: TextAlign.left),
        const SizedBox(height: 12),

        // QR Code
        BarcodeWidget(barcode: Barcode.qrCode(), data: 'https://hirallpos.com/promotions', width: 44, height: 44),
        const SizedBox(height: 4),
        const Text('Scan for customer club rewards & offers', style: TextStyle(fontSize: 7.5), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSidePill(String side, String label) {
    final isSelected = _activeSide == side;
    return InkWell(
      onTap: () => setState(() => _activeSide = side),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildWidthPill(int width, String label) {
    final isSelected = _paperWidthMm == width;
    return InkWell(
      onTap: () => setState(() => _paperWidthMm = width),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border(context)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label) {
    final isSelected = _festivePreset == label;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary(context))),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.card(context),
      onSelected: (_) => _applyFestivePreset(label),
    );
  }
}
