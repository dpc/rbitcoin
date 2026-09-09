//! Most-work ranking helpers (header work sums, LCA on a parent graph).
//!
//! Layer 1 of most-work selection (`docs/architecture.md`): candidate
//! ranking uses header work only. Apply/validation is separate
//! (`ChainHub::accept_branch`).

use bitcoin::Work;

/// Sum header work values (Bitcoin most-work accumulation).
pub fn sum_work(iter: impl Iterator<Item = Work>) -> Work {
    let mut acc: Option<Work> = None;
    for w in iter {
        acc = Some(match acc {
            None => w,
            Some(a) => a + w,
        });
    }
    acc.unwrap_or_else(|| Work::from_be_bytes([0u8; 32]))
}

/// Strictly more work (Bitcoin most-work rule).
#[inline]
pub fn work_better(new: Work, old: Work) -> bool {
    new > old
}

/// Process-local set of invalid block / candidate-tip hashes after failed apply.
#[derive(Debug, Default, Clone)]
pub struct InvalidHashSet {
    hashes: std::collections::HashSet<[u8; 32]>,
}

impl InvalidHashSet {
    pub fn mark(&mut self, hash: [u8; 32]) {
        self.hashes.insert(hash);
    }

    pub fn iter(&self) -> impl Iterator<Item = [u8; 32]> + '_ {
        self.hashes.iter().copied()
    }

    pub fn contains(&self, hash: [u8; 32]) -> bool {
        self.hashes.contains(&hash)
    }

    pub fn is_empty(&self) -> bool {
        self.hashes.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn w(n: u8) -> Work {
        let mut b = [0u8; 32];
        b[31] = n;
        Work::from_be_bytes(b)
    }

    #[test]
    fn sum_work_and_work_better() {
        let z = Work::from_be_bytes([0u8; 32]);
        assert_eq!(sum_work(std::iter::empty()), z);
        assert_eq!(sum_work([w(1)].into_iter()), w(1));
        assert!(work_better(w(2), w(1)));
        assert!(!work_better(w(1), w(2)));
        assert!(!work_better(w(1), w(1)));
    }

    #[test]
    fn invalid_hash_set_marks_and_skips() {
        let mut set = InvalidHashSet::default();
        assert!(set.is_empty());
        let h = [0xab; 32];
        set.mark(h);
        assert!(set.contains(h));
        assert!(!set.is_empty());
        set.mark([0x02; 32]);
        assert!(set.contains([0x02; 32]));
        assert!(!set.contains([0x00; 32]));
    }
}
