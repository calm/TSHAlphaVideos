Pod::Spec.new do |s|
  s.name             = "TSHAlphaVideos"
  s.version          = "1.0.0"
  s.summary          = "Play mp4 videos with alpha background on iOS"
  s.homepage         = "https://github.com/tsheaff/TSHAlphaVideos"
  s.license          = 'Apache'
  s.authors          = { "tsheaff" => "ty.sheaffer@gmail.com", "ctscoville" => "ctscoville@gmail.com" }
  s.platform         = :ios, '7.0'
  s.requires_arc     = true
  s.source           = { :git => "https://github.com/tsheaff/TSHAlphaVideos.git", :tag => s.version.to_s }
  s.source_files     = 'Pod/Classes/*.{h,m,mm,c}'
  s.frameworks       = 'OpenGLES', 'AVFoundation', 'CoreMedia', 'QuartzCore'
end
