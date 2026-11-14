#!/bin/bash
set -euo pipefail

ruby - <<'RUBY'
path = 'configure.ac'
if File.file?(path)
    source = File.binread(path)
    if source.include?('AC_INIT([GnuTLS],')
        updated = source.gsub('m4_ifdef([AM_GNU_GETTEXT_REQUIRE_VERSION],',
                              'm4_ifdef([AM_GNU_GETTEXT_REQUIRE_][VERSION],')
        File.binwrite(path, updated) unless updated == source
    end
end
RUBY

exec "${SGPLAYER_AUTOPOINT:-autopoint}" "$@"
