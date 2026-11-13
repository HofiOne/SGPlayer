#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
shader_dir="$script_dir/../SGPlayer/Classes/Core/SGMetal"
output_header="${1:-$shader_dir/SGMetalShader_iOSSimulator.h}"
minimum_ios_version="${IPHONEOS_DEPLOYMENT_TARGET:-15.0}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/sgplayer-ios-simulator-shader.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun --sdk iphonesimulator metal -c "$shader_dir/SGMetalShader.metal" \
    -target "air64-apple-ios${minimum_ios_version}-simulator" -isysroot "$sdk_path" \
    -std=ios-metal2.1 -o "$build_dir/SGMetalShader.air"
xcrun --sdk iphonesimulator metallib "$build_dir/SGMetalShader.air" \
    -o "$build_dir/SGMetalShader.metallib"

ruby - "$build_dir/SGMetalShader.metallib" "$output_header" <<'RUBY'
metallib = File.binread(ARGV.fetch(0))
abort 'Invalid Metal library output' unless metallib.start_with?('MTLB')

File.open(ARGV.fetch(1), 'w') do |header|
    header.puts '#import <Foundation/Foundation.h>', '', 'const int8_t metallib[] = {'
    metallib.unpack('c*').each_slice(8) do |bytes|
        header.puts "    #{bytes.join(', ')},"
    end
    header.puts '};'
end
RUBY

printf 'Generated iOS Simulator shader: %s\n' "$output_header"
