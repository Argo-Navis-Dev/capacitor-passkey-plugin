import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@available(iOS 15.0, *)
@objc(PasskeyPlugin)
public class PasskeyPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "PasskeyPlugin"
    public let jsName = "PasskeyPlugin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "createPasskey", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "authenticate", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = PasskeyPluginImpl()
    
    @objc func createPasskey(_ call: CAPPluginCall) {
        print("CreatePasskey called with", call.options)
        
        guard let publicKey = call.getObject("publicKey") as? [String: Any] else {
            call.reject("Missing or invalid 'publicKey' parameter")
            return
        }
        guard let publicKeyData = try? JSONSerialization.data(withJSONObject: publicKey) else {
            call.reject("Failed to serialize 'publicKey' to JSON")
            return
        }
        
        call.resolve([
            "value": implementation.createPasskey(publicKeyData)
        ])
    }
    
    @objc func authenticate(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.authenticate(value)
        ])
    }
}
