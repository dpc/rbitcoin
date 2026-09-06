#![no_main]

use std::sync::atomic::{AtomicU64, Ordering};

use libfuzzer_sys::fuzz_target;
use rbitcoin_fuzz::{compare_script_kernel, parse_kernel_input, KernelCmp};

static COMPARISONS: AtomicU64 = AtomicU64::new(0);

fn note_comparison() {
    let n = COMPARISONS.fetch_add(1, Ordering::Relaxed) + 1;
    if n == 1 || n.is_multiple_of(1000) {
        eprintln!("script-kernel: comparisons={n}");
    }
}

fuzz_target!(|data: &[u8]| {
    let Some((sig, pk, flags)) = parse_kernel_input(data) else {
        return;
    };
    match compare_script_kernel(&sig, &pk, flags) {
        KernelCmp::Agree { .. } => note_comparison(),
        KernelCmp::Disagree { ours, core } => {
            panic!("script_kernel: ours={ours} core={core} flags={flags:#x} sig={sig:?} pk={pk:?}");
        }
    }
});
