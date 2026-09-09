//! Confirm **load** stage types shared with wire pin / assemble.
//!
//! Parent outs / denserels are pipeline-local ([`crate::BatchParents`]).
//! Spend edges are batch-local ([`SpendEdges`]). Header plans live on
//! [`crate::confirm_parent_cache::ConfirmParentCache`].

use super::*;
use crate::U64Map;

/// Spend-fk → pin-time spend edges (assemble + write).
pub type SpendEdges = U64Map<Vec<crate::SpendEdge>>;

impl Query {
    /// Snapshot: `(ready_through, ahead, sparse_parents, bodies, header_plans)`.
    ///
    /// Scan watermark is gone (wire pin is the load path). `ready_through` /
    /// `ahead` / sparse / bodies stay 0 so IBD `ibd: sizes` tuple shape is
    /// unchanged; `header_plans` is the live occupancy.
    pub fn parent_cache_perf_snapshot(&self) -> (u32, u32, usize, usize, usize) {
        (0, 0, 0, 0, self.confirm_parents.header_plan_count())
    }

    pub fn advance_parent_cache_tip(&self, tip: u32) {
        self.confirm_parents.advance_tip(tip);
    }
}
