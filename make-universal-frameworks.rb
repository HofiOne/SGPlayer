#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'pathname'
require 'tmpdir'

libraries = %w[libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale]
platforms = {
  'iOS' => {
    'iphoneos' => ['ios', nil, %w[arm64]],
    'iphonesimulator' => ['ios', 'simulator', %w[arm64 x86_64]],
    'mac-catalyst' => ['ios', 'maccatalyst', %w[arm64 x86_64]]
  },
  'macOS' => {'macos' => ['macos', nil, %w[arm64 x86_64]]},
  'tvOS' => {
    'appletvos' => ['tvos', nil, %w[arm64]],
    'appletvsimulator' => ['tvos', 'simulator', %w[arm64 x86_64]]
  }
}
options = {
  build_root: File.expand_path('build', __dir__),
  output_root: File.expand_path('../..', __dir__),
  configuration: 'Debug',
  platform: 'all',
  libraries: [],
  dry_run: false
}
parser = OptionParser.new do |arguments|
  arguments.banner = 'Usage: make-universal-frameworks.rb [options]'
  arguments.on('--configuration NAME', %w[Debug Release all], 'Debug (default), Release, or all') { |value| options[:configuration] = value }
  arguments.on('--platform NAME', platforms.keys + ['all'], 'iOS, macOS, tvOS, or all (default)') { |value| options[:platform] = value }
  arguments.on('--library NAME', libraries, 'Package only this library; may be repeated') { |value| options[:libraries] << value }
  arguments.on('--build-root PATH', 'FFmpegKit build root; default: build beside this script') { |value| options[:build_root] = File.expand_path(value) }
  arguments.on('--output-root PATH', 'Installation root; default: Frameworks, two levels above this script') { |value| options[:output_root] = File.expand_path(value) }
  arguments.on('--dry-run', 'Validate inputs and print the plan without changing files') { options[:dry_run] = true }
  arguments.on('-h', '--help', 'Show this help') { puts arguments; exit }
end

def command(*arguments)
  output, error, result = Open3.capture3(*arguments)
  raise "Command failed: #{arguments.join(' ')}\n#{output}#{error}" unless result.success?
  output
end

def plist(path)
  JSON.parse(command('plutil', '-convert', 'json', '-o', '-', path))
end

def validate_package(path, inputs)
  actual = plist(File.join(path, 'Info.plist')).fetch('AvailableLibraries')
  expected = inputs.map { |input| [input[:platform], input[:variant], input[:architectures].sort] }
  found = actual.map do |library|
    identifier = library.fetch('LibraryIdentifier')
    relative = library.fetch('LibraryPath')
    framework = File.join(path, identifier, relative)
    raise "Missing packaged framework: #{framework}" unless File.directory?(framework)
    binary = File.join(framework, File.basename(framework, '.framework'))
    architectures = command('xcrun', 'lipo', '-archs', binary).split.sort
    raise "Incorrect architecture metadata: #{binary}" unless architectures == library.fetch('SupportedArchitectures').sort
    [library.fetch('SupportedPlatform'), library['SupportedPlatformVariant'], architectures]
  end
  raise "Incorrect platform slices: #{path}" unless found.sort_by(&:inspect) == expected.sort_by(&:inspect)
end

begin
  parser.parse!
  raise OptionParser::InvalidArgument, ARGV.join(' ') unless ARGV.empty?
  configurations = options[:configuration] == 'all' ? %w[Debug Release] : [options[:configuration]]
  selected_platforms = options[:platform] == 'all' ? platforms.keys : [options[:platform]]
  selected_libraries = options[:libraries].empty? ? libraries : options[:libraries].uniq
  plans = []

  configurations.each do |configuration|
    prebuilt = File.join(options[:build_root], configuration, 'prebuilt')
    selected_platforms.each do |platform|
      selected_libraries.each do |library|
        inputs = platforms.fetch(platform).map do |bundle, specification|
          framework = File.join(prebuilt, "bundle-apple-framework-#{bundle}", "#{library}.framework")
          binary = File.join(framework, library)
          raise "Missing platform framework: #{binary}" unless File.file?(binary)
          architectures = command('xcrun', 'lipo', '-archs', binary).split
          missing = specification[2] - architectures
          raise "Missing architectures #{missing.join(', ')} in #{binary}" unless missing.empty?
          {path: framework, platform: specification[0], variant: specification[1], architectures: architectures}
        end
        relative = File.join(platform, configuration, "#{library}.xcframework")
        plans << {relative: relative, inputs: inputs}
        puts "#{relative}: #{inputs.map { |input| "#{input[:variant] || input[:platform]}[#{input[:architectures].join(',')}]" }.join(' + ')}"
      end
    end
  end

  if options[:dry_run]
    puts "Validated #{plans.size} XCFramework packages; no files changed. Output root: #{options[:output_root]}"
    exit
  end

  FileUtils.mkdir_p(options[:output_root])
  Dir.mktmpdir('.universal-frameworks-', options[:output_root]) do |temporary|
    plans.each do |plan|
      output = File.join(temporary, 'packages', plan[:relative])
      FileUtils.mkdir_p(File.dirname(output))
      arguments = ['xcrun', 'xcodebuild', '-create-xcframework']
      plan[:inputs].each { |input| arguments.concat(['-framework', input[:path]]) }
      command(*arguments, '-output', output)
      validate_package(output, plan[:inputs])
    end

    plans.each do |plan|
      destination = File.join(options[:output_root], plan[:relative])
      prepared = File.join(temporary, 'packages', plan[:relative])
      backup = File.join(temporary, 'previous', plan[:relative])
      FileUtils.mkdir_p(File.dirname(destination))
      existed = File.exist?(destination) || File.symlink?(destination)
      if existed
        FileUtils.mkdir_p(File.dirname(backup))
        File.rename(destination, backup)
      end
      begin
        File.rename(prepared, destination)
      rescue StandardError
        File.rename(backup, destination) if existed
        raise
      end
      puts "Installed #{destination}"
    end
  end
  puts "Created and validated #{plans.size} universal XCFramework packages."
rescue OptionParser::ParseError, StandardError => error
  warn error.message
  exit 1
end
