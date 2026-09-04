class AppConstants {
  static const String appName = 'Hirall POS';
  static const String appVersion = '2.0.0';
  
  // API URL for local or deployed backend (configured via --dart-define=API_URL=...)
  static const String defaultApiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.100.30:8000/api/v1',
  );
  static const String powersyncUrl = 'https://sync.powersync.com';

  // Currency
  static const String defaultCurrency = 'KES';
  static const double standardVatRate = 0.16; // 16% VAT in Kenya

  // Storage Keys
  static const String keyToken = 'jwt_access_token';
  static const String keyLicense = 'license_key';
  static const String keyOrgId = 'organization_id';
  static const String keyOrgName = 'organization_name';
  static const String keyBranchId = 'branch_id';
  static const String keyBranchName = 'branch_name';
  static const String keyBusinessType = 'business_type';
  static const String keyUserRole = 'user_role';
  static const String keyUserName = 'user_name';
  static const String keyEnabledModules = 'enabled_modules';
  static const String keyIsActivated = 'is_activated';
}
