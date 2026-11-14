require 'json'
require 'open3'

targets = {
  'iOS' => ['SGPlayer iOS', 'IPHONEOS_DEPLOYMENT_TARGET'],
  'macOS' => ['SGPlayer macOS', 'MACOSX_DEPLOYMENT_TARGET'],
  'tvOS' => ['SGPlayer tvOS', 'TVOS_DEPLOYMENT_TARGET']
}
abort 'Usage: deployment-target.rb iOS|macOS|tvOS Debug|Release [project.pbxproj]' unless (2..3).cover?(ARGV.size)
platform, configuration, project_path = ARGV
abort "Unknown platform: #{platform}" unless targets.key?(platform)
project_path ||= File.expand_path('../SGPlayer.xcodeproj/project.pbxproj', __dir__)
output, _error, result = Open3.capture3('plutil', '-convert', 'json', '-o', '-', project_path)
abort "Cannot parse Xcode project: #{project_path}" unless result.success?
project = JSON.parse(output)
objects = project.fetch('objects')
target_name, setting = targets.fetch(platform)
target = objects.values.find { |object| object['isa'] == 'PBXNativeTarget' && object['name'] == target_name }
abort "Missing Xcode target: #{target_name}" unless target

configuration_settings = lambda do |owner|
  list = objects.fetch(owner.fetch('buildConfigurationList'))
  match = list.fetch('buildConfigurations').map { |identifier| objects.fetch(identifier) }.find { |entry| entry['name'] == configuration }
  abort "Missing #{configuration} configuration for #{owner['name'] || 'project'}" unless match
  match.fetch('buildSettings', {})
end

project_settings = configuration_settings.call(objects.fetch(project.fetch('rootObject')))
target_settings = configuration_settings.call(target)
inherited = project_settings[setting].to_s.strip
value = target_settings.fetch(setting, inherited).to_s.strip
value = inherited if value.empty?
value = value.gsub('$(inherited)', inherited).gsub('${inherited}', inherited).strip
abort "Unresolved #{setting} for #{target_name} #{configuration}: #{value.inspect}" unless value.match?(/\A\d+(?:\.\d+){0,2}\z/)
puts value
