require 'json'

package = JSON.parse(File.read(File.join(__dir__, '../package.json')))

Pod::Spec.new do |s|
  s.name                  = 'SigMeshOC'
  s.version               = package['version']
  s.summary               = package['description']
  s.homepage              = package['homepage']
  s.license               = package['license']
  s.author                = package['author']
  s.source                = { :git => 'https://github.com/flyskywhy/react-native-btsig-telink.git', :tag => s.version.to_s }
  s.ios.deployment_target = '9.0'
  s.vendored_frameworks   = 'Build/Products/SigMeshOC/Release-iphoneos/SigMeshOC.framework'
end
