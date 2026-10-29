// SPDX-License-Identifier: GPL-3.0-or-later
// Paleblood Engine: FSR 3.1 frame-generation passes built in the engine (vk_fsr3fg_shaders.h).
// bbport 0.7 measured 34.9 -> 38.4 FPS with frame generation on a Steam Deck from these shaders
// together with its early frame retire; here the frame-retire signal is queued at the frame's
// end in stream order (Liverpool::SignalDecodedFrames), ahead of the presenter's passes, so the
// game never waits for the interpolation.

#include "video_core/renderer_vulkan/vk_fsr3fg_shaders.h"

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "video_core/host_shaders/fsr3fg_fi_interpolation_check_comp.h"
#include "video_core/host_shaders/fsr3fg_fi_interpolation_comp.h"
#include "video_core/host_shaders/fsr3fg_fi_interpolation_plain_comp.h"
#include "video_core/host_shaders/fsr3fg_of_v5_comp.h"
#include "video_core/host_shaders/fsr3fg_of_v5_fast_comp.h"
#include "video_core/host_shaders/fsr3fg_of_v5_plain_comp.h"
#include "video_core/renderer_vulkan/vk_instance.h"

// fsr-vulkan src/ffx_vk_fsr3_3_1_6_framegen_shaderblobs.cpp (gpu/patches/fsr-vulkan/0002).
extern "C" bool (*ffxVk316FramegenModuleOverride)(const char* filename, const uint32_t** words,
                                                  size_t* wordCount);

namespace Vulkan::Fsr3FgShaders {

namespace {

constexpr const char* OpticalFlowSearch =
    "fsr3_3_1_6_of_ffx_opticalflow_compute_optical_flow_advanced_pass_v5.spv";
constexpr const char* Interpolation = "fsr3_3_1_6_fi_ffx_frameinterpolation.spv";

bool g_int16 = false;

bool EnvIs(const char* name, char value) {
    const char* env = std::getenv(name);
    return env && env[0] == value && env[1] == '\0';
}

template <size_t N>
bool Use(const uint32_t (&code)[N], const uint32_t** words, size_t* count) {
    *words = code;
    *count = N;
    return true;
}

bool Override(const char* filename, const uint32_t** words, size_t* count) {
    // BB_FG_OWN_PLAIN=1 (a check): the passes built here without bbport's changes, the SDK's
    // code through this build; BB_FG_OWN_OF=0 / BB_FG_OWN_FI=0: the SDK's own module for one.
    static const bool plain = EnvIs("BB_FG_OWN_PLAIN", '1');
    if (std::strcmp(filename, Interpolation) == 0) {
        static bool told = false;
        if (EnvIs("BB_FG_OWN_FI", '0')) {
            return false;
        }
        // BB_FI_CHECK=1: the frame drawn as 16 x the difference between the filtered sample and
        // the SDK's four weighted loads, magenta where a gathered motion-field texel differs
        // from its load (black everywhere = the passes agree).
        static const bool check = EnvIs("BB_FI_CHECK", '1');
        if (!told) {
            told = true;
            std::printf("Frame generation: interpolation pass built in the engine (%s)\n",
                        check   ? "CHECK: the difference to the SDK's loads, x16 (BB_FI_CHECK)"
                        : plain ? "the SDK's code, BB_FG_OWN_PLAIN"
                                : "hardware bilinear, gathered motion fields");
        }
        if (check) {
            return Use(FSR3FG_FI_INTERPOLATION_CHECK_COMP, words, count);
        }
        return plain ? Use(FSR3FG_FI_INTERPOLATION_PLAIN_COMP, words, count)
                     : Use(FSR3FG_FI_INTERPOLATION_COMP, words, count);
    }
    if (std::strcmp(filename, OpticalFlowSearch) != 0 || EnvIs("BB_FG_OWN_OF", '0')) {
        return false;
    }
    static bool told = false;
    if (!g_int16 && !plain) {
        if (!told) {
            told = true;
            std::printf("Frame generation: optical flow search kept as the SDK's (no 16-bit "
                        "integers on this GPU)\n");
        }
        return false;
    }
    // BB_OF_FAST=1: no search on the finest level (its vectors from the coarser one): a
    // 16-pixel block's motion at 2-pixel steps instead of an 8-pixel block's, for most of the
    // flow's cost.
    static const bool fast = EnvIs("BB_OF_FAST", '1');
    if (!told) {
        told = true;
        std::printf("Frame generation: optical flow search built in the engine (%s)%s\n",
                    plain ? "the SDK's code, BB_FG_OWN_PLAIN" : "packed SAD",
                    fast ? "; the finest level not searched (BB_OF_FAST)" : "");
    }
    if (plain) {
        return Use(FSR3FG_OF_V5_PLAIN_COMP, words, count);
    }
    return fast ? Use(FSR3FG_OF_V5_FAST_COMP, words, count)
                : Use(FSR3FG_OF_V5_COMP, words, count);
}

} // namespace

void Install(const Instance& instance) {
    static bool done = false;
    if (done) {
        return;
    }
    done = true;
    if (EnvIs("BB_FFX_OWN_SHADERS", '0')) {
        std::printf("Frame generation: the SDK's own modules (BB_FFX_OWN_SHADERS=0)\n");
        return;
    }
    g_int16 = instance.IsShaderInt16Supported();
    ffxVk316FramegenModuleOverride = &Override;
}

} // namespace Vulkan::Fsr3FgShaders
