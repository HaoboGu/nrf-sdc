#!/usr/bin/env bash
set -euo pipefail

# Dependency versions
CMSIS5_REPO="https://github.com/ARM-software/CMSIS_5.git"
CMSIS5_REF="master"

NRFX_REPO="https://github.com/NordicSemiconductor/nrfx.git"
NRFX_REF="v4.2.0"

NRFXLIB_REPO="https://github.com/nrfconnect/sdk-nrfxlib.git"
NRFXLIB_REF="v3.3.0-rc1"

THIRD_PARTY="nrf-mpsl-sys/third_party"

sparse_clone() {
    local repo="$1"
    local ref="$2"
    local dest="$3"
    shift 3
    local dirs=("$@")

    echo "Fetching $repo @ $ref -> $dest"

    rm -rf "$dest"
    mkdir -p "$dest"

    git -C "$dest" init -q
    git -C "$dest" remote add origin "$repo"
    git -C "$dest" sparse-checkout init --cone
    git -C "$dest" sparse-checkout set "${dirs[@]}"
    git -C "$dest" fetch --filter=blob:none --depth 1 origin "$ref"
    git -C "$dest" checkout FETCH_HEAD
    rm -rf "$dest/.git"

    echo "  Done."
}

# Delete all files in a directory except those named in the remaining arguments
keep_only() {
    local dir="$1"
    shift
    local keep=("$@")

    local find_args=()
    for f in "${keep[@]}"; do
        find_args+=( ! -name "$f" )
    done
    find "$dir" -maxdepth 1 -type f "${find_args[@]}" -delete
}

# ── CMSIS_5: only the Core headers + license ──
sparse_clone "$CMSIS5_REPO" "$CMSIS5_REF" "$THIRD_PARTY/arm/CMSIS_5" \
    CMSIS/Core/Include
# Remove top-level files we don't need (PDFs, build scripts, etc.)
keep_only "$THIRD_PARTY/arm/CMSIS_5" LICENSE.txt

# ── nrfx: specific headers from mdk, drivers, hal, haly, templates ──
sparse_clone "$NRFX_REPO" "$NRFX_REF" "$THIRD_PARTY/nordic/nrfx" \
    bsp/stable drivers hal haly templates
# Remove top-level files except LICENSE and nrfx.h
keep_only "$THIRD_PARTY/nordic/nrfx" LICENSE nrfx.h
# drivers: only need the top-level .h files, not include/ or src/ subdirs
rm -rf "$THIRD_PARTY/nordic/nrfx/drivers/include" \
       "$THIRD_PARTY/nordic/nrfx/drivers/src"
# hal: only need nrf_common.h and nrf_clock.h
keep_only "$THIRD_PARTY/nordic/nrfx/hal" nrf_common.h nrf_clock.h
# haly: only need nrfy_common.h
keep_only "$THIRD_PARTY/nordic/nrfx/haly" nrfy_common.h
# templates: only need nrfx_glue.h
keep_only "$THIRD_PARTY/nordic/nrfx/templates" nrfx_glue.h
# bsp/stable: keep the BSP entrypoint and the SoC headers bindgen needs.
# The nrfx 4.x MDK headers now have deeper cross-header include chains
# (notably for nRF54H20 core-role variants), so keep the full MDK header set
# instead of a fragile hand-maintained subset.
keep_only "$THIRD_PARTY/nordic/nrfx/bsp/stable" nrfx_bsp.h nrfx_ext.h
rm -rf "$THIRD_PARTY/nordic/nrfx/bsp/stable/templates"
keep_only "$THIRD_PARTY/nordic/nrfx/bsp/stable/soc" \
    nrfx_irqs.h nrfx_mdk_fixups.h nrfx_mdk_fixups_ext.h nrfx_soc_defines.h
find "$THIRD_PARTY/nordic/nrfx/bsp/stable/mdk" -maxdepth 1 -type f ! -name '*.h' -delete

# ── nrfxlib: mpsl + softdevice_controller headers and libs ──
sparse_clone "$NRFXLIB_REPO" "$NRFXLIB_REF" "$THIRD_PARTY/nordic/nrfxlib" \
    mpsl/include \
    mpsl/lib/nrf52 mpsl/lib/nrf53 mpsl/lib/nrf54l mpsl/lib/nrf54l_ns \
    mpsl/lib/nrf54lm mpsl/lib/nrf54lm_ns mpsl/lib/nrf54h \
    mpsl/fem/include mpsl/fem/common \
    mpsl/fem/simple_gpio mpsl/fem/nrf21540_gpio mpsl/fem/nrf21540_gpio_spi \
    softdevice_controller/include \
    softdevice_controller/lib/nrf52 softdevice_controller/lib/nrf53 \
    softdevice_controller/lib/nrf54l softdevice_controller/lib/nrf54l_ns \
    softdevice_controller/lib/nrf54lm softdevice_controller/lib/nrf54lm_ns \
    softdevice_controller/lib/nrf54h

# Verify key files exist
echo ""
echo "Verifying fetched files..."
MISSING=0
for f in \
    "$THIRD_PARTY/arm/CMSIS_5/LICENSE.txt" \
    "$THIRD_PARTY/arm/CMSIS_5/CMSIS/Core/Include/core_cm4.h" \
    "$THIRD_PARTY/arm/CMSIS_5/CMSIS/Core/Include/core_cm33.h" \
    "$THIRD_PARTY/nordic/nrfx/nrfx.h" \
    "$THIRD_PARTY/nordic/nrfx/bsp/stable/nrfx_bsp.h" \
    "$THIRD_PARTY/nordic/nrfx/bsp/stable/mdk/nrf.h" \
    "$THIRD_PARTY/nordic/nrfx/bsp/stable/mdk/nrf52840.h" \
    "$THIRD_PARTY/nordic/nrfx/bsp/stable/soc/nrfx_irqs.h" \
    "$THIRD_PARTY/nordic/nrfx/drivers/nrfx_common.h" \
    "$THIRD_PARTY/nordic/nrfx/hal/nrf_common.h" \
    "$THIRD_PARTY/nordic/nrfx/haly/nrfy_common.h" \
    "$THIRD_PARTY/nordic/nrfx/templates/nrfx_glue.h" \
    "$THIRD_PARTY/nordic/nrfxlib/LICENSE" \
    "$THIRD_PARTY/nordic/nrfxlib/mpsl/include/mpsl.h" \
    "$THIRD_PARTY/nordic/nrfxlib/softdevice_controller/include/sdc.h" \
; do
    if [ ! -f "$f" ]; then
        echo "  MISSING: $f"
        MISSING=1
    fi
done

if [ "$MISSING" -eq 0 ]; then
    echo "All key files present."
else
    echo "ERROR: Some expected files are missing!"
    exit 1
fi
