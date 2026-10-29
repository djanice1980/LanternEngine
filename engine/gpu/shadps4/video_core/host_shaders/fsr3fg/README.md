# FSR 3.1 frame-generation passes built in the engine

Two of the FSR 3.1.6 frame-generation passes are compiled here from the SDK's GLSL, in place of
the modules embedded in `third_party/fsr-vulkan` (`vk_fsr3fg_shaders.cpp` hands them to the
SDK's blob accessor through `ffxVk316FramegenModuleOverride`, patch 0002 of
`gpu/patches/fsr-vulkan`):

- `fsr3fg_of_v5.comp`: the optical-flow search (`ComputeOpticalFlowAdvanced`), with bbport's
  packed-SAD sums (`BB_OF_PACKED_SAD`: |a - b| = 2 max(a, b) - a - b in packed 16-bit lanes,
  bit-identical results) and its optional skip of the finest level (`BB_OF_LEVEL0_PREDICT`,
  `BB_OF_FAST=1` at run time).
- `fsr3fg_fi_interpolation.comp`: the interpolation pass, with one hardware bilinear sample in
  place of four loads where all taps are inside the rectangle (`BB_FI_HARDWARE_BILINEAR`) and
  one gather per motion field in place of eight loads (`BB_FI_GATHER_FIELD`).

The headers here overlay the SDK's (`-I` order in `gpu/CMakeLists.txt`): the three changed by
bbport (deadinside28/bloodborne_pc 0.7, `gpu/upscale/shaders/ffx`; AMD's MIT files with bbport's
GPL-2.0-or-later changes), and the 3.1.6 GLSL callbacks for frame interpolation made from the
SDK 1.1.4 ones. Everything else comes from `fsr-vulkan/upstream/ffx-2.3.0` (the 3.1.6 Kit) and
`ffx-1.1.4` (the GLSL callbacks). `BB_FFX_OWN_SHADERS=0` keeps the embedded modules.
