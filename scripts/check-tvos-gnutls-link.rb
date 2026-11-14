require 'open3'
require 'tmpdir'
require 'shellwords'

root = File.expand_path('..', __dir__)
checkout = File.join(root, 'build', ARGV.fetch(0, 'Debug'))
source = File.join(checkout, 'src', 'gnutls')
prefix = File.join(checkout, 'prebuilt', 'apple-tvos-arm64')

def run(*arguments, **options)
  output, error, result = Open3.capture3(*arguments, **options)
  abort output + error unless result.success?
  output
end

sdk = run('xcrun', '--sdk', 'appletvos', '--show-sdk-path').strip
environment = {'PKG_CONFIG_PATH' => nil, 'PKG_CONFIG_LIBDIR' => File.join(prefix, 'pkgconfig')}
cflags = Shellwords.split(run(environment, 'pkg-config', '--cflags', 'gnutls', 'gmp'))
libraries = Shellwords.split(run(environment, 'pkg-config', '--libs', '--static', 'gnutls', 'gmp'))

Dir.mktmpdir('gnutls-link-check-', File.join(root, 'build')) do |directory|
  object = File.join(directory, 'c-ctype.o')
  common = ['xcrun', '--sdk', 'appletvos', 'clang', '-target', 'arm64-apple-tvos11.0', '-isysroot', sdk]
  run(*common, '-std=c99', '-D_DONT_USE_CTYPE_INLINE_', '-I', source, '-I', File.join(source, 'gl'),
      '-c', File.join(source, 'gl/c-ctype.c'), '-o', object)
  symbols = run('xcrun', 'nm', '-g', object)
  abort 'Gnulib did not emit c_isdigit' unless symbols.match?(/\bT _c_isdigit$/)
  puts 'PASS: the real Gnulib source emits the missing c_isdigit definition'

  program = "#include <gnutls/gnutls.h>\nint main(void) { return gnutls_global_init(); }\n"
  probe = File.join(directory, 'probe.o')
  run(*common, *cflags, '-x', 'c', '-', '-c', '-o', probe, stdin_data: program)
  run(*common, probe, object, *libraries, '-framework', 'Security', '-framework', 'CoreFoundation',
      '-o', File.join(directory, 'gnutls-link-check'))
  puts 'PASS: gnutls_global_init links with the existing tvOS libraries and repaired Gnulib object'
end

puts 'Only isolated C objects and a link probe were built; no library or app was rebuilt'
