require 'fileutils'
require 'tmpdir'
require 'json'
require 'open3'

root = File.expand_path('..', __dir__)
build_root = File.join(root, 'build')
FileUtils.mkdir_p(build_root)
wrapper = File.join(root, 'buildkit.sh')
output, error, result = Open3.capture3('bash', '-n', wrapper)
abort output + error unless result.success?

stub = <<'STUB'
#!/usr/bin/ruby
require 'json'
require 'fileutils'
platform = File.basename($0, '.sh')
File.open(ENV.fetch('SGPLAYER_TEST_CALLS'), 'a') do |file|
  file.puts JSON.generate(platform: platform, configuration: File.basename(Dir.pwd), arguments: ARGV)
end
if platform == 'tvos' && ARGV.include?('--enable-openssl')
  warn 'OpenSSL is not supported on tvOS by this FFmpegKit version'
  exit 200
end
exit 3 if ENV['SGPLAYER_TEST_FAIL'] == File.basename(Dir.pwd)
if platform == 'tvos'
  recipe = File.read(File.join(Dir.pwd, 'scripts/apple/gnutls.sh'))
  abort 'GnuTLS inline compatibility was not prepared' unless recipe.include?('-D_DONT_USE_CTYPE_INLINE_')
  Dir.glob(File.join(Dir.pwd, 'prebuilt/apple-tvos-*/gnutls/lib/libgnutls.a')).each do |archive|
    symbols = File.read(archive)
    if symbols.include?('U _c_isdigit') && !symbols.include?('T _c_isdigit')
      abort 'Broken GnuTLS cache was reused' unless ARGV.include?('--rebuild-gnutls')
      File.write(archive, "00000000 T _c_isdigit\n")
    end
  end
  source = File.join(Dir.pwd, 'src', 'gnutls')
  FileUtils.mkdir_p(source)
  File.write(File.join(source, 'configure.ac'), "AC_INIT([GnuTLS], [3.6.15])\nm4_ifdef([AM_GNU_GETTEXT_REQUIRE_VERSION],[\nAM_GNU_GETTEXT_REQUIRE_VERSION([0.19])\n])\n")
  exit 4 unless system(ENV.fetch('AUTOPOINT'), '--force', chdir: source)
end
bundle = File.join(Dir.pwd, 'prebuilt', "bundle-apple-xcframework-#{platform}")
if ENV['SGPLAYER_TEST_OMIT_BUNDLE'] == File.basename(Dir.pwd)
  FileUtils.rm_rf(bundle)
  exit 0
end
%w[libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale ffmpegkit].each do |library|
  directory = File.join(bundle, "#{library}.xcframework")
  FileUtils.mkdir_p(directory)
  File.write(File.join(directory, 'generated'), platform)
end
STUB

Dir.mktmpdir('buildkit-check-', build_root) do |directory|
  sandbox_root = File.join(directory, 'Frameworks', 'Sources', 'SGPlayer')
  FileUtils.mkdir_p(sandbox_root)
  sandbox_wrapper = File.join(sandbox_root, 'buildkit.sh')
  FileUtils.cp(wrapper, sandbox_wrapper)
  FileUtils.mkdir_p(File.join(sandbox_root, 'scripts'))
  FileUtils.cp(File.join(root, 'scripts/gnutls-autopoint.sh'), File.join(sandbox_root, 'scripts/gnutls-autopoint.sh'))
  FileUtils.cp(File.join(root, 'scripts/prepare-tvos-gnutls.rb'), File.join(sandbox_root, 'scripts/prepare-tvos-gnutls.rb'))
  builds = File.join(sandbox_root, 'build trees')
  frameworks = File.join(directory, 'installed frameworks')
  calls = File.join(directory, 'calls.jsonl')
  binaries = File.join(directory, 'bin')
  FileUtils.mkdir_p(binaries)
  git_stub = File.join(binaries, 'git')
  File.write(git_stub, "#!/bin/bash\nexit 99\n")
  FileUtils.chmod(0755, git_stub)
  autopoint_stub = File.join(binaries, 'autopoint')
  File.write(autopoint_stub, <<'AUTOPOINT')
#!/usr/bin/ruby
source = File.read('configure.ac')
if source.include?('AC_INIT([GnuTLS],')
  abort 'Unfixed GnuTLS macro guard' if source.include?('m4_ifdef([AM_GNU_GETTEXT_REQUIRE_VERSION],')
  abort 'Missing GnuTLS macro guard' unless source.include?('m4_ifdef([AM_GNU_GETTEXT_REQUIRE_][VERSION],')
end
abort 'Autopoint arguments were changed' unless ARGV == ['--force']
AUTOPOINT
  FileUtils.chmod(0755, autopoint_stub)
  xcrun_stub = File.join(binaries, 'xcrun')
  File.write(xcrun_stub, <<'XCRUN')
#!/bin/bash
if [[ "${1:-}" == nm && "${2:-}" == -g && $# -eq 3 ]]; then
  exec /bin/cat "$3"
fi
exec /usr/bin/xcrun "$@"
XCRUN
  FileUtils.chmod(0755, xcrun_stub)

  %w[Debug Release].each do |configuration|
    checkout = File.join(builds, configuration)
    FileUtils.mkdir_p(checkout)
    FileUtils.mkdir_p(File.join(checkout, 'scripts/apple'))
    File.write(File.join(checkout, 'scripts/apple/gnutls.sh'), 'export CFLAGS="$(get_cflags ${LIB_NAME}) -I${SDK_PATH}/usr/include"' + "\n")
    %w[ios macos tvos].each do |platform|
      path = File.join(checkout, "#{platform}.sh")
      File.write(path, stub)
      FileUtils.chmod(0755, path)
    end
    %w[libavfilter libavformat].each do |library|
      stale = File.join(frameworks, 'tvOS', configuration, "#{library}.xcframework")
      FileUtils.mkdir_p(stale)
      File.write(File.join(stale, 'stale'), 'old output')
    end
  end

  environment = {
    'BUILD_DIR' => builds,
    'FRAMEWORK_DIR' => frameworks,
    'SGPLAYER_TEST_CALLS' => calls,
    'SGPLAYER_TEST_FAIL' => nil,
    'SGPLAYER_TEST_OMIT_BUNDLE' => nil,
    'TVOS_DEPLOYMENT_TARGET' => nil,
    'AUTOPOINT' => autopoint_stub,
    'PATH' => "#{binaries}:#{ENV.fetch('PATH')}"
  }
  invoke = lambda do |arguments, overrides = {}|
    File.write(calls, '')
    output, error, result = Open3.capture3(environment.merge(overrides), 'bash', sandbox_wrapper, *arguments, chdir: directory)
    events = File.readlines(calls).map { |line| JSON.parse(line) }
    [output, error, result, events]
  end

  output, error, result, events = invoke.call(['build', 'tvOS', '--probe=two words'])
  abort output + error unless result.success?
  expected_events = [['tvos', 'Debug'], ['tvos', 'Release']]
  abort 'tvOS did not build Debug and Release' unless events.map { |event| [event['platform'], event['configuration']] } == expected_events
  events.each do |event|
    arguments = event.fetch('arguments')
    %w[--enable-tvos-audiotoolbox --enable-tvos-videotoolbox --enable-tvos-bzip2 --enable-tvos-zlib --enable-tvos-libiconv --enable-gnutls --enable-gmp --enable-nettle --no-bitcode --target=11.0 -x].each do |option|
      abort "Missing option: #{option}" unless arguments.include?(option)
    end
    abort 'Unsupported tvOS OpenSSL option was enabled' if arguments.include?('--enable-openssl')
    abort 'Extra argument was split' unless arguments.include?('--probe=two words')
    abort 'Wrong optimization mode' unless arguments.include?(event['configuration'] == 'Debug' ? '-d' : '-s')
  end
  %w[Debug Release].each do |configuration|
    %w[libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale].each do |library|
      installed = File.join(frameworks, 'tvOS', configuration, "#{library}.xcframework")
      abort "Missing installed library: #{library}" unless File.file?(File.join(installed, 'generated'))
      abort "Stale library survived: #{library}" if File.exist?(File.join(installed, 'stale'))
    end
    abort 'Unused ffmpegkit framework was installed' if File.exist?(File.join(frameworks, 'tvOS', configuration, 'ffmpegkit.xcframework'))
  end
  puts 'PASS: tvOS Debug/Release, flags, quoted arguments, installation and stale-output cleanup'

  archive = File.join(builds, 'Debug', 'prebuilt/apple-tvos-arm64/gnutls/lib/libgnutls.a')
  FileUtils.mkdir_p(File.dirname(archive))
  File.write(archive, "                 U _c_isdigit\n")
  output, error, result, events = invoke.call(%w[build tvOS])
  abort output + error unless result.success?
  abort 'Broken Debug cache was not rebuilt' unless events[0]['arguments'].include?('--rebuild-gnutls')
  abort 'Unbuilt Release cache requested a needless rebuild' if events[1]['arguments'].include?('--rebuild-gnutls')
  output, error, result, events = invoke.call(%w[build tvOS])
  abort output + error unless result.success?
  abort 'Valid cache was rebuilt unnecessarily' if events.any? { |event| event['arguments'].include?('--rebuild-gnutls') }
  puts 'PASS: invalid GnuTLS archives rebuild once; valid cache is preserved'

  helper = File.join(sandbox_root, 'scripts/gnutls-autopoint.sh')
  source_directory = File.join(builds, 'Debug', 'src', 'gnutls')
  configure_path = File.join(source_directory, 'configure.ac')
  configured = File.binread(configure_path)
  helper_environment = environment.merge('SGPLAYER_AUTOPOINT' => autopoint_stub)
  _output, error, result = Open3.capture3(helper_environment, 'bash', helper, '--force', chdir: source_directory)
  abort error unless result.success? && File.binread(configure_path) == configured
  unrelated = "AC_INIT([Other], [1.0])\nm4_ifdef([AM_GNU_GETTEXT_REQUIRE_VERSION],[])\n"
  File.binwrite(configure_path, unrelated)
  _output, error, result = Open3.capture3(helper_environment, 'bash', helper, '--force', chdir: source_directory)
  abort error unless result.success? && File.binread(configure_path) == unrelated
  puts 'PASS: GnuTLS autopoint compatibility, original-tool delegation, idempotency and unrelated-source preservation'

  output, error, result, events = invoke.call(['build', 'tvOS'], 'TVOS_DEPLOYMENT_TARGET' => '15.0')
  abort output + error unless result.success?
  abort 'tvOS minimum override was ignored' unless events.all? { |event| event['arguments'].include?('--target=15.0') }
  puts 'PASS: configurable tvOS minimum'

  [%w[build all], ['build'], ['build', '--probe=two words']].each do |arguments|
    output, error, result, events = invoke.call(arguments)
    abort output + error unless result.success?
    abort 'All did not build all six variants' unless events.map { |event| event['platform'] }.sort == %w[ios ios macos macos tvos tvos]
    events.each do |event|
      expected_tls = event['platform'] == 'tvos' ? '--enable-gnutls' : '--enable-openssl'
      abort 'Platform TLS backend changed' unless event['arguments'].include?(expected_tls)
    end
    if arguments.last == '--probe=two words'
      abort 'Default platform lost an extra argument' unless events.all? { |event| event['arguments'].include?('--probe=two words') }
    end
  end
  puts 'PASS: explicit and default all include iOS, macOS and tvOS'

  [[], %w[build unknown-platform], ['unknown-action'], %w[clean tvOS]].each do |arguments|
    _output, _error, result, events = invoke.call(arguments)
    abort 'Invalid command was accepted' if result.success? || !events.empty?
  end
  _output, _error, result, events = invoke.call(%w[build tvOS], 'SGPLAYER_TEST_FAIL' => 'Debug')
  abort 'Failed dependency build did not stop the wrapper' if result.success? || events.size != 1
  puts 'PASS: invalid commands and failed dependency builds stop safely'

  installed_marker = File.join(frameworks, 'tvOS', 'Debug', 'libavcodec.xcframework', 'generated')
  File.write(installed_marker, 'preserve installed framework')
  _output, _error, result, events = invoke.call(%w[build tvOS], 'SGPLAYER_TEST_OMIT_BUNDLE' => 'Debug')
  abort 'Missing build output was accepted' if result.success? || events.size != 1
  abort 'Missing build output destroyed the installed framework' unless File.file?(installed_marker) && File.read(installed_marker) == 'preserve installed framework'
  puts 'PASS: missing build output preserves installed frameworks'

  output, error, result, _events = invoke.call(['clean'])
  abort output + error unless result.success?
  abort 'Clean did not remove local build trees' if File.exist?(File.join(builds, 'Debug')) || File.exist?(File.join(builds, 'Release'))
  abort 'Clean removed installed frameworks' unless File.directory?(File.join(frameworks, 'tvOS', 'Debug', 'libavcodec.xcframework'))
  puts 'PASS: clean preserves installed frameworks'
end

puts 'All fixtures stayed inside SGPlayer; no dependency or app build was run'
