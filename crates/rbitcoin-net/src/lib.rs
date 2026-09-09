//! Bitcoin P2P: BIP324 v2 transport, headers/blocks, tip follow, tip-mode **tx relay**.

mod asmap;
mod block_diff;
mod cache;
mod chain;
mod codec;
mod compact;
mod error;
mod eviction;
mod ibd;
mod most_work;
mod msg_decode;
mod netgroup;
mod peer;
mod peer_dos;
mod peers;
mod reactor;
mod seeds;
mod serve_perf;
mod service;
mod tip_accept;
mod tx_relay;
mod v2;
mod versionbits_warn;

pub use asmap::{AsMap, TWO_PREFIX_ASMAP};
pub use block_diff::{
    basic_auth_b64, build_jsonrpc_http_request, check_diff_env, compare_cmpct_reorg_one,
    compare_csv_age_one, compare_fork_n_one, compare_fork_one, compare_mempool_one, compare_one,
    compare_script_one, compare_script_verify_one, compare_spend_one, diff_regtest_params,
    genesis_diff_tip, mine_diff_pad, mine_diff_stem, parse_submitblock_json,
    parse_testmempoolaccept_json, rewind_oracle_until, split_http_body, store_reorg_apply,
    store_reorg_corrupt_is_finding, store_reorg_recycle_hub, store_reorg_step,
    submit_pad_to_oracle, wait_for_file, BlockOracle, CompareOne, DiffPad, DiffTip, OracleReply,
    StoreReorgOp, DIFF_MATURE_PAD_HEIGHT, DIFF_REORG_N, DIFF_TEST_PAD_HEIGHT,
};
pub use cache::BlockCache;
pub use chain::{AcceptOutcome, ChainHub, ChainTipInfo, TipEvent};
pub use compact::{
    classify_v2_cmpct_peer, cmpct_missing_for_case, encode_cmpctblock_v2,
    encode_getheaders_empty_v2, encode_ping_v2, encode_pong_v2, encode_sendcmpct_hb_v2,
    encode_tx_v2, encode_verack_v2, prepare_cmpct_fuzz_case, prepare_cmpct_fuzz_hsi, CmpctFuzzCase,
    CmpctPeerFrame,
};
pub use error::NetError;
pub use ibd::{
    format_tip_perf_sizes, read_proc_rss, IbdConfig, ProcRss, TipPerfSizes,
    DEFAULT_BLOCKS_IN_TRANSIT_PER_PEER, DEFAULT_IBD_WINDOW,
};
pub use most_work::sum_work;
pub use netgroup::netgroup;
pub use peer::{flush_tx_invs, force_announce_txid, local_service_flags, V2PlainSession};
pub use peer_dos::DEFAULT_MAX_INBOUND;
pub use peers::{
    parse_peer_addr, pick_stale_follow_evict, DialRequest, LivePeer, PeerConnType, PeerHub,
    PeerInfo, PingAction,
};
pub use rbitcoin_mempool::AcceptError;
pub(crate) use rbitcoin_mempool::MempoolGraphStats;
pub use reactor::BlockingRegion;
pub use seeds::{
    default_port, dns_seeds, fixed_seed_hosts, resolve_all_seeds, resolve_dns_seeds,
    resolve_fixed_seeds, AddrMan, PeerEntry, PeerFlags,
};
pub use serve_perf::{format_serve_perf, sample_reset_serve_perf, ServePerfSample};
pub use service::{NetConfig, P2PHandle, P2PNode};
pub use tx_relay::{ElectrumMempoolItem, MempoolAnnounce, MempoolHub, MempoolPerfSample};
pub use v2::{parse_v2_regtest, parse_v2_regtest_named, WireBytes};
pub use versionbits_warn::warning_strings;

/// Default number of **live download peers** during IBD (`IbdConfig::target_peers`
/// and node `--max-outbound` default).
///
/// This is **not** the seed candidate pool size. The node dials a larger sample
/// of seed addresses (typically `2 × target`, clamped) so failed connects still
/// leave enough live peers.
pub const DEFAULT_IBD_TARGET_PEERS: u32 = 16;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn outbound_defaults() {
        assert_eq!(DEFAULT_IBD_TARGET_PEERS, 16);
    }
}
