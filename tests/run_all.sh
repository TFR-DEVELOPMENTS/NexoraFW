#!/bin/sh
# Usage: NEXORO_ROOT=. sh tests/run_all.sh   (needs lua5.4, lua-cjson, a MariaDB socket at /tmp/mdb.sock or NEXORO_TEST_SOCKET)
for t in run run2 run3 run4 run5 run6 run7 run8 run9 run10 run11 run12 run13 run14 run15 run16 run17 run18 run19 run20; do lua5.4 tests/$t.lua | tail -1; done

# Static checks across every resource (manifests, dependencies, exports, callbacks, start order)
python3 tests/integrity.py || exit 1
