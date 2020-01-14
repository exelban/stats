Pod::Spec.new do |s|
  s.name = "Charts"
  s.version = "2.1.4a"
  s.summary = "ios-charts is a powerful & easy to use chart library for iOS"
  s.homepage = "https://github.com/danielgindi/ios-charts"
  s.license = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  s.authors = "Daniel Cohen Gindi", "Philipp Jahoda"
  s.ios.deployment_target = "8.0"
  s.source = { :git => "https://github.com/danielgindi/ios-charts.git", :tag => "v#{s.version}" }
  s.source_files = "Classes", "Charts/Classes/**/*.swift"
  s.frameworks = "Foundation", "UIKit", "CoreGraphics"
end
