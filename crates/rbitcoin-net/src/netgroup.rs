//! Outbound / inbound netgroup key: asmap ASN, or IPv4 `/16` / IPv6 `/32`.

use crate::asmap::AsMap;
use std::net::{IpAddr, SocketAddr};

/// Stable neighborhood key. With asmap, the ASN (IPv4 and IPv6 that map to
/// the same ASN share a key). Without, Core-style prefix groups.
pub fn netgroup(addr: SocketAddr, asmap: Option<&AsMap>) -> u64 {
    if let Some(m) = asmap {
        return u64::from(m.mapped_as(addr.ip()));
    }
    prefix_group(addr.ip())
}

fn prefix_group(ip: IpAddr) -> u64 {
    match ip {
        IpAddr::V4(v4) => {
            let o = v4.octets();
            (u64::from(o[0]) << 8) | u64::from(o[1])
        }
        IpAddr::V6(v6) => {
            let o = v6.octets();
            u64::from(u32::from_be_bytes([o[0], o[1], o[2], o[3]]))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::asmap::{two_prefix_asmap_bytes, AsMap};
    use std::net::{Ipv4Addr, Ipv6Addr};

    fn v4(a: u8, b: u8, c: u8, d: u8) -> SocketAddr {
        SocketAddr::new(IpAddr::V4(Ipv4Addr::new(a, b, c, d)), 8333)
    }

    #[test]
    fn netgroup_prefix_ipv4_slash16() {
        assert_eq!(
            netgroup(v4(1, 2, 3, 4), None),
            netgroup(v4(1, 2, 9, 9), None)
        );
        assert_ne!(
            netgroup(v4(1, 2, 3, 4), None),
            netgroup(v4(1, 3, 0, 1), None)
        );
    }

    #[test]
    fn netgroup_prefix_ipv6_slash32() {
        let a = SocketAddr::new(
            IpAddr::V6(Ipv6Addr::new(0x2001, 0xdb8, 0, 0, 0, 0, 0, 1)),
            1,
        );
        let b = SocketAddr::new(
            IpAddr::V6(Ipv6Addr::new(0x2001, 0xdb8, 1, 0, 0, 0, 0, 1)),
            1,
        );
        let c = SocketAddr::new(
            IpAddr::V6(Ipv6Addr::new(0x2001, 0xdb9, 0, 0, 0, 0, 0, 1)),
            1,
        );
        assert_eq!(netgroup(a, None), netgroup(b, None));
        assert_ne!(netgroup(a, None), netgroup(c, None));
    }

    #[test]
    fn netgroup_asmap_two_asns() {
        let m = AsMap::from_bytes(two_prefix_asmap_bytes()).unwrap();
        let a = v4(1, 2, 3, 4);
        let b = v4(1, 2, 9, 9);
        let c = v4(3, 4, 0, 1);
        assert_eq!(netgroup(a, Some(&m)), netgroup(b, Some(&m)));
        assert_ne!(netgroup(a, Some(&m)), netgroup(c, Some(&m)));
        let v6 = SocketAddr::new(
            IpAddr::V6(Ipv6Addr::new(0, 0, 0, 0, 0, 0xffff, 0x0102, 0x0304)),
            1,
        );
        assert_eq!(netgroup(a, Some(&m)), netgroup(v6, Some(&m)));
    }
}
