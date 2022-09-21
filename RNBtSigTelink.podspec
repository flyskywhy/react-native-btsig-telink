require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name                  = 'RNBtSigTelink'
  s.version               = package['version']
  s.summary               = package['description']
  s.homepage              = package['homepage']
  s.license               = package['license']
  s.author                = package['author']
  s.source                = { :git => 'https://github.com/flyskywhy/react-native-btsig-telink.git', :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.prefix_header_file    = 'TelinkSigMeshLib/TelinkSigMeshLib/TelinkSigMeshLibPrefixHeader.pch'
  s.dependency 'React'

  # s.source_files          = 'ios/**/*',
  #                           'TelinkSigMeshLib/TelinkSigMeshLib/**/*.h'
  # s.dependency 'TelinkSigMeshLib'
  #
  # If you want to use the original telink Script.sh to build TelinkSigMeshLib.framework, you need uncomment
  # above and comment below after -------.
  # Here is the Script.sh usage:
  # Open `TelinkSigMeshLib/TelinkSigMeshLib.xcodeproj` by Xcode, in 'Signing & Capabilities' of Target 的 'TelinkSigMeshLib',
  # choose `Team` to your Apple ID, then close Xcode and
  #     cd node_modules/react-native-btsig-telink/TelinkSigMeshLib/
  #     ./Script.sh
  # to get the build results:
  #     TelinkSigMeshLib/Build/Products/TelinkSigMeshLib/Release-iphoneos/TelinkSigMeshLib.framework/
  # then in `ios/Podfile`, add
  #     pod 'TelinkSigMeshLib', :path => '../node_modules/react-native-btsig-telink/TelinkSigMeshLib'
  # -------
  s.source_files          = 'ios/**/*',
                            'TelinkSigMeshLib/TelinkSigMeshLib/**/*.{h,m}'
  s.exclude_files         = 'TelinkSigMeshLib/TelinkSigMeshLib/Third Library/GMEllipticCurveCrypto/test.m'
  s.pod_target_xcconfig   = {
    "HEADER_SEARCH_PATHS" => "\"$(PODS_TARGET_SRCROOT)/TelinkSigMeshLib/TelinkSigMeshLib/Third Library/OpenSSL/include\"",
  }
  s.libraries    = 'crypto', 'ssl'
  s.xcconfig   = {
    "LIBRARY_SEARCH_PATHS" => "$(PROJECT_DIR)/../node_modules/react-native-btsig-telink/TelinkSigMeshLib/TelinkSigMeshLib/Third\\ Library/OpenSSL/lib",
  }
end
