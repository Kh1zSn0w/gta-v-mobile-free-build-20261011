// Network performance reporting is removed in the personal edition.
#include "MRFrameReports.h"
namespace mr {
void frameReportsInstall(id<MTLDevice>) {}
void frameReportsRecord(double, double, uint64_t, bool, const FrameWork &) {}
}
