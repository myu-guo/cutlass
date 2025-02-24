// Adapted from https://github.com/deepseek-ai/FlashMLA/blob/main/csrc/named_barrier.h

#pragma once

#include "cutlass/barrier.h"

namespace flash {

////////////////////////////////////////////////////////////////////////////////////////////////////
// Enumerates the reserved named barriers to avoid potential conflicts

enum class NamedBarriers {
    SReady = 1,
    SoftmaxReady = 2,
};

} // flash