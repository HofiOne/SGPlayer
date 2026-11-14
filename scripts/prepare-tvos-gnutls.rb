require 'open3'

checkout = File.expand_path(ARGV.fetch(0))
recipe = File.join(checkout, 'scripts', 'apple', 'gnutls.sh')
source = File.read(recipe)
unless source.include?('-D_DONT_USE_CTYPE_INLINE_')
  original = 'export CFLAGS="$(get_cflags ${LIB_NAME}) -I${SDK_PATH}/usr/include"'
  abort 'Unrecognized FFmpegKit GnuTLS CFLAGS setup' unless source.scan(original).size == 1
  replacement = original + <<'BASH'

if [[ ${FFMPEG_KIT_BUILD_TYPE} == tvos ]]; then
  export CFLAGS="${CFLAGS} -D_DONT_USE_CTYPE_INLINE_"
fi
BASH
  File.write(recipe, source.sub(original, replacement.chomp))
end

archives = Dir.glob(File.join(checkout, 'prebuilt', 'apple-tvos-*', 'gnutls', 'lib', 'libgnutls.a'))
archives.each do |archive|
  symbols, _error, result = Open3.capture3('xcrun', 'nm', '-g', archive)
  abort 'Could not inspect cached tvOS GnuTLS archive' unless result.success?
  if symbols.match?(/\bU _c_isdigit$/) && !symbols.match?(/\bT _c_isdigit$/)
    puts 'rebuild-gnutls'
    break
  end
end
