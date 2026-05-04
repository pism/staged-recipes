#!/usr/bin/env python3
"""Strip ``channel_sources`` / ``channel_targets`` from a conda-forge global
pinning file while preserving every other line *exactly*, including the
``# [linux]`` / ``# [osx]`` / ``# [unix]`` selector comments rattler-build
uses to filter list entries per-platform.

Why not just round-trip through PyYAML?

The conda-forge global pinning encodes per-platform values via comment
selectors:

    c_compiler_version:           # [unix]
      - 14                        # [linux]
      - 19                        # [osx]

PyYAML treats those as plain comments and discards them, so a YAML
load+dump produces lists with all entries unconditionally — which then
breaks rattler-build's ``zip_keys`` length checks.

Used by the ``rattler-osx`` pixi task. rattler-build refuses to start when
both ``channel_sources`` (a variant key) and ``-c`` (channels) are set;
this script removes those two entries from the pinning so we can keep
using ``-c`` for the local channel.
"""

import re
import sys

src, dst = sys.argv[1], sys.argv[2]

# Match a top-level YAML key. Conda-forge pinning uses 0-indent for keys
# (no leading whitespace), and entries underneath are indented or start
# with ``-`` (list items).
TOP_LEVEL_KEY = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):")

DROP = {"channel_sources", "channel_targets"}

with open(src) as f:
    lines = f.readlines()

out = []
skip = False
for line in lines:
    m = TOP_LEVEL_KEY.match(line)
    if m:
        # New top-level key starts here. Decide whether to skip its block.
        skip = m.group(1) in DROP
    if not skip:
        out.append(line)

with open(dst, "w") as f:
    f.writelines(out)
