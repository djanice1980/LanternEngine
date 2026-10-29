// SPDX-License-Identifier: GPL-3.0-or-later
// Paleblood Engine: FSR 3.1 frame-generation passes built in the engine (host_shaders/fsr3fg,
// bbport's faster optical-flow search and interpolation pass) in place of the SDK modules
// embedded in fsr-vulkan. BB_FFX_OWN_SHADERS=0: the embedded modules. BB_OF_FAST=1: the finest
// optical-flow level is not searched (its vectors from the coarser one).
#pragma once

namespace Vulkan {

class Instance;

namespace Fsr3FgShaders {

/// Before the first frame-generation context is made: the blob accessor takes the passes built
/// here (fsr-vulkan patch 0002, ffxVk316FramegenModuleOverride). Once; later calls return.
void Install(const Instance& instance);

} // namespace Fsr3FgShaders

} // namespace Vulkan
