#!/bin/sh
# Filter SDF file for iverilog compatibility:
#  - Remove INTERCONNECT entries (iverilog crashes on intermodpath)
#  - Remove COND entries (iverilog doesn't support conditional delays)
#  - Fix :: format in header (insert typ value between min::max)
#  - Change DIVIDER from . to / (avoids treating dots as hierarchy)
#  - Rename flattened escaped instances: dco_inst\.xxx -> dco_inst__xxx
#    (iverilog SDF parser can't handle dots in flat instance names)
#  - Remove CELL blocks left empty after filtering

sed -e '/INTERCONNECT/d' \
    -e 's/\([0-9.]*\)::\([0-9.]*\)/\1:\1:\2/' \
    -e '/COND/{N;d;}' \
    -e 's/(DIVIDER \.)/(DIVIDER \/)/' \
    -e 's/dco_inst\\\./dco_inst__/g' \
    -e 's/dco_inst\./dco_inst__/g' \
    "$1" | \
awk '
/^\(CELL/ || /^ \(CELL/ { cell_buf = $0; in_cell = 1; has_iopath = 0; next }
in_cell { cell_buf = cell_buf "\n" $0 }
in_cell && /IOPATH/ { has_iopath = 1 }
in_cell && /^ \)$/ {
    if (has_iopath) print cell_buf
    in_cell = 0
    next
}
!in_cell { print }
'
