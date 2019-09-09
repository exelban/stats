Pod::Spec.new do |s|
	s.name = 'LaunchAtLogin'
	s.version = '2.5.0'
	s.summary = 'Add "Launch at Login" functionality to your sandboxed macOS app in seconds'
	s.license = 'MIT'
	s.homepage = 'https://github.com/sindresorhus/LaunchAtLogin'
	s.social_media_url = 'https://twitter.com/sindresorhus'
	s.authors = { 'Sindre Sorhus' => 'sindresorhus@gmail.com' }
	s.source = { :git => 'https://github.com/sindresorhus/LaunchAtLogin.git', :tag => "v#{s.version}" }
	s.source_files = 'LaunchAtLogin', 'LaunchAtLoginHelper'
	s.resource = 'LaunchAtLogin/copy-helper.sh'
	s.swift_version = '4.2'
	s.platform = :macos, '10.12'
end
