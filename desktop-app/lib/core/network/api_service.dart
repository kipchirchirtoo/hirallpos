import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class ApiService {
  final String baseUrl;
  String? _token;

  ApiService({this.baseUrl = AppConstants.defaultApiUrl});

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // 1. Organization Onboarding (Step 1-4)
  Future<Map<String, dynamic>> registerOrg({
    required String name,
    required String businessType,
    required String ownerName,
    required String phoneNumber,
    required String email,
    required String password,
    String primaryBranchName = 'Main Branch',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-org'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'business_type': businessType,
        'owner_name': ownerName,
        'phone_number': phoneNumber,
        'email': email,
        'password': password,
        'primary_branch_name': primaryBranchName,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data['access_token'] != null) {
        _token = data['access_token'];
      }
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Registration failed.');
    }
  }

  // 2. M-Pesa STK Push
  Future<Map<String, dynamic>> triggerMpesaStk({
    required String organizationId,
    required String phoneNumber,
    required double amount,
    String accountReference = 'Setup Fee',
    String transactionDesc = 'Hirall POS Setup',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/billing/mpesa-stk'),
      headers: _headers,
      body: jsonEncode({
        'organization_id': organizationId,
        'phone_number': phoneNumber,
        'amount': amount,
        'account_reference': accountReference,
        'transaction_desc': transactionDesc,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Failed to trigger M-Pesa payment.');
    }
  }

  // 3. License Verification (First-run activation)
  Future<Map<String, dynamic>> verifyLicense({
    required String licenseKey,
    String? deviceId,
    String? deviceName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-license'),
      headers: _headers,
      body: jsonEncode({
        'license_key': licenseKey,
        'device_id': deviceId,
        'device_name': deviceName,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'License validation failed.');
    }
  }

  // 4. Email/Password Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _token = data['access_token'];
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Login failed. Please check credentials.');
    }
  }

  // 5. PIN Login
  Future<Map<String, dynamic>> pinLogin({
    required String organizationId,
    required String branchId,
    required String pinCode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/pin-login'),
      headers: _headers,
      body: jsonEncode({
        'organization_id': organizationId,
        'branch_id': branchId,
        'pin_code': pinCode,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _token = data['access_token'];
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Invalid PIN code.');
    }
  }

  // 5. Products & Categories
  Future<List<dynamic>> getProducts(String orgId, {String? branchId}) async {
    final uri = Uri.parse('$baseUrl/products/org/$orgId').replace(
      queryParameters: {
        if (branchId != null) 'branch_id': branchId,
      },
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getCategories(String orgId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products/categories/$orgId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  // 6. Record Sale
  Future<Map<String, dynamic>> recordSale(String branchId, Map<String, dynamic> saleData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sales/branch/$branchId'),
      headers: _headers,
      body: jsonEncode(saleData),
    );
    return jsonDecode(response.body);
  }

  // 7. Record Expense
  Future<Map<String, dynamic>> recordExpense(Map<String, dynamic> expenseData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/accounting/expenses'),
      headers: _headers,
      body: jsonEncode(expenseData),
    );
    return jsonDecode(response.body);
  }

  // 8. Record Till Reconciliation
  Future<Map<String, dynamic>> recordTillReconciliation(Map<String, dynamic> reconData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/accounting/reconciliations'),
      headers: _headers,
      body: jsonEncode(reconData),
    );
    return jsonDecode(response.body);
  }
}
