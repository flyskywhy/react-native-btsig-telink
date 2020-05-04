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
  s.source_files          = 'ios/**/*'
  s.pod_target_xcconfig   = { "GCC_PREPROCESSOR_DEFINITIONS" => "WIN32=1 IOS_APP_ENABLE=1"}
  s.dependency 'React'
  s.dependency 'SigMeshOC'
end
