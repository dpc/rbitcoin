//! Node lifecycle, configuration, and process orchestration.

mod cli;
mod config;
mod error;
mod inhibit;
mod regtest_rpc;
mod run;

pub use cli::cli_main;
pub use config::{DatadirOpts, ListenOpts, MempoolOpts, NodeConfig, RpcOpts};
pub use error::NodeError;
pub use inhibit::SuspendInhibit;
pub use regtest_rpc::HubRegtest;
pub use run::{run_node, run_p2p, NodeHandle};
