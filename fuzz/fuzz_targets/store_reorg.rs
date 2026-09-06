#![no_main]

use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::OnceLock;

use libfuzzer_sys::fuzz_target;
use rbitcoin_consensus::Milestone;
use rbitcoin_fuzz::tmp_dir;
use rbitcoin_net::{
    check_diff_env, diff_regtest_params, store_reorg_apply, ChainHub,
};
use rbitcoin_query::Query;

struct Base {
    hub: ChainHub,
    _store: PathBuf,
}

static BASE: OnceLock<Base> = OnceLock::new();
static COMPARISONS: AtomicU64 = AtomicU64::new(0);

fn harness_failure(what: &str) -> ! {
    eprintln!("=== STORE-REORG FUZZ HARNESS FAILURE ===");
    eprintln!("{what}");
    std::process::exit(2);
}

fn note_comparison(k: u32) {
    let n = COMPARISONS.fetch_add(k as u64, Ordering::Relaxed) + k as u64;
    if n == 1 || n.is_multiple_of(100) {
        eprintln!("store-reorg: comparisons={n}");
    }
}

fn base() -> &'static Base {
    BASE.get_or_init(|| {
        if std::env::var_os("RBITCOIN_HEAD_SCALE").is_none() {
            std::env::set_var("RBITCOIN_HEAD_SCALE", "tiny");
        }
        if std::env::var_os("RBITCOIN_IO").is_none() {
            std::env::set_var("RBITCOIN_IO", "fd");
        }
        let head = std::env::var("RBITCOIN_HEAD_SCALE").ok();
        let io = std::env::var("RBITCOIN_IO").ok();
        if let Err(e) = check_diff_env(head.as_deref(), io.as_deref()) {
            harness_failure(e);
        }
        let store = tmp_dir("rbtc-store-reorg");
        let q = Query::open_or_create(store.join("store")).unwrap_or_else(|e| {
            harness_failure(&format!("query open: {e}"));
        });
        let hub = ChainHub::new(q, diff_regtest_params(), Milestone::NONE);
        hub.ensure_genesis()
            .unwrap_or_else(|e| harness_failure(&format!("genesis: {e}")));
        Base {
            hub,
            _store: store,
        }
    })
}

fuzz_target!(|data: &[u8]| {
    let b = base();
    match store_reorg_apply(&b.hub, data) {
        Ok(n) if n > 0 => note_comparison(n),
        Ok(_) => {}
        Err(msg) => panic!("store_reorg: {msg}"),
    }
});
