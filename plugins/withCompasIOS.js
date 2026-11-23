const { withAppDelegate, withInfoPlist } = require('@expo/config-plugins');

// iOS-only setup applied on every `expo prebuild`, so the generated ios/ folder never needs hand edits.

// iOS 27 stops apps at launch unless they adopt the UIScene life cycle. Expo ships
// ExpoAppSceneDelegate for this; it needs the AppDelegate to expose its React Native
// factory and to leave window creation to the scene delegate.
function withSceneLifecycle(config) {
  config = withAppDelegate(config, (config) => {
    let src = config.modResults.contents;
    if (!src.includes('ExpoReactNativeFactoryProvider')) {
      src = src.replace(
        'class AppDelegate: ExpoAppDelegate {',
        'class AppDelegate: ExpoAppDelegate, ExpoReactNativeFactoryProvider {',
      );
    }
    // The scene delegate creates the window and starts React Native, so drop the template's copy.
    src = src.replace(
      /\n#if os\(iOS\) \|\| os\(tvOS\)\n\s*window = UIWindow\(frame: UIScreen\.main\.bounds\)\n\s*factory\.startReactNative\([\s\S]*?\)\n#endif\n/,
      '\n',
    );
    if (src.includes('window = UIWindow(frame:')) {
      throw new Error('withCompasIOS: AppDelegate template changed; update the scene life cycle patch.');
    }
    config.modResults.contents = src;
    return config;
  });

  return withInfoPlist(config, (config) => {
    config.modResults.UIApplicationSceneManifest = {
      UIApplicationSupportsMultipleScenes: false,
      UISceneConfigurations: {
        UIWindowSceneSessionRoleApplication: [
          {
            UISceneConfigurationName: 'Default Configuration',
            UISceneDelegateClassName: 'EXExpoAppSceneDelegate',
          },
        ],
      },
    };
    return config;
  });
}

// The player is reached over plain http:// on the local network and advertised over Bonjour.
function withLocalNetwork(config) {
  return withInfoPlist(config, (config) => {
    const plist = config.modResults;
    plist.NSLocalNetworkUsageDescription =
      'compás finds and controls your Compás player on your Wi-Fi network.';
    plist.NSBonjourServices = Array.from(new Set([...(plist.NSBonjourServices || []), '_compas-remote._tcp']));
    plist.NSAppTransportSecurity = { ...(plist.NSAppTransportSecurity || {}), NSAllowsLocalNetworking: true };
    // Music is copied in through the Files app ("On My iPhone") or Finder file sharing.
    plist.UIFileSharingEnabled = true;
    plist.LSSupportsOpeningDocumentsInPlace = true;
    return config;
  });
}

module.exports = function withCompasIOS(config) {
  return withLocalNetwork(withSceneLifecycle(config));
};
