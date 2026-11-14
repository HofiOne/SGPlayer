#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
shader_dir="$script_dir/../SGPlayer/Classes/Core/SGMetal"
output_header="${1:-$shader_dir/SGMetalShader_tvOSSimulator.h}"
minimum_tvos_version="${TVOS_SIMULATOR_DEPLOYMENT_TARGET:-13.0}"
mkdir -p "$script_dir/../build"
build_dir="$(mktemp -d "$script_dir/../build/sgplayer-tvos-simulator-shader.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

sdk_path="$(xcrun --sdk appletvsimulator --show-sdk-path)"
xcrun --sdk appletvsimulator metal -c "$shader_dir/SGMetalShader.metal" \
    -target "air64-apple-tvos${minimum_tvos_version}-simulator" -isysroot "$sdk_path" \
    -std=ios-metal2.1 -o "$build_dir/SGMetalShader.air"
xcrun --sdk appletvsimulator metallib "$build_dir/SGMetalShader.air" \
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

printf 'Generated tvOS Simulator shader: %s\n' "$output_header"
