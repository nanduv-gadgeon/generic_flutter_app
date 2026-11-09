import Flutter
import LocalAuthentication
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BiometricEnrollment") {
      BiometricEnrollment.register(with: registrar)
    }
  }
}

/// Notices when Face ID / Touch ID enrolment changes after biometric login was turned on.
///
/// "remember" saves LAContext.evaluatedPolicyDomainState in the Keychain (this device only);
/// iOS changes that value whenever a face or fingerprint is added or removed. "changed" compares.
/// Kept in this file so the Xcode project does not need a new source file.
enum BiometricEnrollment {
  private static let service = "biometric_enrollment"
  private static let account = "biometric_enrollment_v1"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "app/biometric_enrollment", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "remember": result(remember())
      case "changed": result(changed())
      case "forget":
        forget()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Nil when no face or fingerprint is enrolled.
  private static func currentState() -> Data? {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    else { return nil }
    return context.evaluatedPolicyDomainState
  }

  private static func remember() -> Bool {
    guard let state = currentState() else { return false }
    forget()
    let item: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: state,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
  }

  /// True when nothing was saved, or the enrolment differs from the saved one.
  private static func changed() -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var found: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
      let saved = found as? Data
    else { return true }
    return currentState() != saved
  }

  private static func forget() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }
}
