require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name                = "RNAudioStreaming"
  s.version             = package['version']
  s.summary             = package['description']
  s.homepage            = "https://github.com/tlenclos/react-native-audio-streaming"
  s.license             = package['license']
  s.author              = package['author']
  s.source              = { :git => package['repository']['url'], :tag => "v#{s.version}" }
  s.source_files        = "ios/**/*.{h,m}"
  s.requires_arc        = true
  s.platform            = :ios, "7.0"
  s.preserve_paths      = "**/*.js"

  s.dependency 'React-Core'

end
