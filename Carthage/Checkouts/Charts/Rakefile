def type
  :project # set `:project` for xcodeproj and `:workspace` for xcworkspace
end

def project_name
  'ChartsDemo-iOS/ChartsDemo-iOS.xcodeproj'
end

def macos_project_name
  'ChartsDemo-macOS/ChartsDemo-macOS.xcodeproj'
end

def configuration
  'Debug'
end

def test_platforms
  %i[
    iOS
    tvOS
  ]
end

def build_platforms
  [
    :macOS
  ]
end

def build_schemes
  %w[
    Charts
  ]
end

def build_demo_schemes
  %i[
    ChartsDemo-iOS
    ChartsDemo-iOS-Swift
  ]
end

def build_macos_demo_schemes
  [
    'ChartsDemo-macOS'
  ]
end

def test_schemes
  [
    'ChartsTests'
  ]
end

def devices
  {
    iOS: {
      sdk: 'iphonesimulator',
      device: "name='iPhone 7'",
      name: 'iPhone 7'
    },
    macOS: {
      sdk: 'macosx',
      device: "arch='x86_64'",
      uuid: nil
    },
    tvOS: {
      sdk: 'appletvsimulator',
      device: "name='Apple TV'",
      name: 'Apple TV'
    }
  }
end

def open_simulator_and_sleep(uuid)
  return if uuid.nil? # Don't need a sleep on macOS because it runs first.
  sh "xcrun instruments -w '#{uuid}' || sleep 15"
end

def xcodebuild(type, name, scheme, configuration, sdk, destination, tasks, xcprety_args)
  # set either workspace or project flag for xcodebuild
  case type
  when :project
    project_type = '-project'
  when :workspace
    project_type = '-workspace'
  else
    abort 'Invalid project type, use `:project` for xcodeproj and `:workspace` for xcworkspace.'
  end

  sh "set -o pipefail && xcodebuild #{project_type} '#{name}' -scheme '#{scheme}' -configuration '#{configuration}' -sdk #{sdk} -destination #{destination} #{tasks} | bundle exec xcpretty -c #{xcprety_args}"
end

def run_xcodebuild(tasks, destination, is_build_demo, xcprety_args)
  sdk = destination[:sdk]
  device = destination[:device]
  uuid = destination[:uuid]

  is_test = tasks.include?('test')
  is_macos = sdk == 'macosx'

  project = is_macos ? macos_project_name : project_name

  schemes_to_execute = []
  if is_test
    schemes_to_execute = test_schemes
  elsif is_build_demo
    schemes_to_execute = is_macos ? build_macos_demo_schemes : build_demo_schemes
  else
    schemes_to_execute = build_schemes
  end

  open_simulator_and_sleep uuid if is_test

  schemes_to_execute.each do |scheme|
    xcodebuild type, project, scheme, configuration, sdk, device, tasks, xcprety_args
  end
end

def execute(tasks, platform, is_build_demo = false, xcprety_args: '')
  # platform specific settings
  destination = devices[platform]

  # check if xcodebuild needs to be run on multiple devices
  if destination.is_a?(Array)
    destination.each do |destination|
      run_xcodebuild tasks, destination, is_build_demo, xcprety_args
    end
  else
    run_xcodebuild tasks, destination, is_build_demo, xcprety_args
  end
end

def arg_to_key(string_key)
  case string_key.downcase
  when 'ios'
    :iOS
  when 'tvos'
    :tvOS
  when 'macos'
    :macOS
  when 'watchos'
    :watchOS
  else
    abort 'Invalid platform, use `iOS`, `tvOS`, `macOS` or `watchOS`'
  end
end

desc 'Run CI tasks. Build and test or build depending on the platform.'
task :ci, [:platform] do |_task, args|
  platform = arg_to_key(args[:platform]) if args.key?(:platform)
  is_build_demo = test_platforms.include?(platform) || build_platforms.include?(platform)

  if test_platforms.include?(platform)  # iOS and tvOS
    if platform == :iOS
      execute 'clean', platform, is_build_demo
      execute 'build', platform, is_build_demo
      execute 'test', platform  # not use demo specifically
    else
      execute 'clean test', platform
    end
  elsif build_platforms.include?(platform)  # macOS
    execute 'clean build', platform, is_build_demo
  else
    test_platforms.each do |platform|
      execute 'clean test', platform
    end
    build_platforms.each do |platform|
      execute 'clean build', platform
    end
  end
end

desc 'updated the podspec on cocoapods'
task :update_pod do
  sh 'bundle exec pod trunk push Charts.podspec --allow-warnings'
end

desc 'generate changelog'
task :generate_changelog do
  sh 'github_changelog_generator'
end