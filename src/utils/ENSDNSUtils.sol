// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @author raffy.eth
library ENSDNSUtils {
    error InvalidName();

    // [ens]  "aaa.bb.c"
    // [dns] "3aaa2bb1c0"

    // ens.length = dns.length-2
    // ens is offset 1-byte with lengths replaced with "."

    function dnsDecode(
        bytes memory dns
    ) internal pure returns (string memory ens) {
        unchecked {
            uint256 n = dns.length;
            if (n == 1 && dns[0] == 0) return ""; // only valid answer is root
            if (n < 3) revert InvalidName();
            ens = new string(n -= 2); // always 2-shorter
            // we clobber 31-=bytes beyond the end
            // it's ok since we don't call anything
            uint256 start;
            assembly {
                start := add(dns, 32)
            }
            // we only need one pointer since the diff between ens and dns is constant
            uint256 diff;
            assembly {
                diff := sub(sub(ens, 1), dns)
            } // shifted, but mangles length
            uint256 src = start;
            while (true) {
                uint256 word;
                assembly {
                    word := mload(src)
                }
                uint256 len = word >> 248; // read length from msb
                if (len == 0) break;
                uint256 end = src + len;
                if (end > start + n) revert InvalidName(); // block malicious encodings
                word = (46 << 248) | ((word << 8) >> 8); // replace length with "."
                assembly {
                    mstore(add(src, diff), word)
                }
                for (uint256 p = src + 32; p <= end; p += 32) {
                    // memcpy the rest
                    assembly {
                        mstore(add(p, diff), mload(p))
                    }
                }
                src = 1 + end;
            }
            // we break the loop before adding the last empty label
            // so theres only one extra period
            if (src - start != n + 1) revert InvalidName();
            assembly {
                mstore(ens, n)
            } // fix mangled length
        }
    }

    function dnsEncode(
        string memory ens
    ) internal pure returns (bytes memory dns) {
        unchecked {
            uint256 n;
            assembly {
                n := mload(ens)
            }
            if (n == 0) return hex"00"; // root
            dns = new bytes(n + 2); // always 2-longer
            uint256 w;
            uint256 e;
            uint256 r;
            assembly {
                e := add(dns, 32)
                r := e // remember start
                ens := add(ens, 32)
                for {
                    let i := 0
                } lt(i, n) {
                    i := add(i, 1)
                } {
                    let b := shr(248, mload(add(ens, i))) // read byte
                    if eq(b, 46) {
                        // found "."
                        w := sub(e, r)
                        if or(iszero(w), gt(w, 255)) {
                            break
                        } // something wrong
                        mstore8(r, w)
                        r := add(e, 1) // update start
                    }
                    {
                        e := add(e, 1)
                        mstore8(e, b)
                    }
                }
            }
            w = e - r;
            if (w == 0) revert InvalidName(); // empty label
            if (w > 255) return ""; // label too long
            assembly {
                mstore8(r, w)
            } // store final length
        }
    }
}
