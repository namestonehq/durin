import { type ByteArray, type Hex } from 'viem'
import { bytesToString, parseAbi, toBytes } from 'viem/utils'

export const resolverAbi = parseAbi([
  'function stuffedResolveCall(bytes calldata name, bytes calldata data, uint64 targetChainId, address targetRegistryAddress) view returns (bytes memory)',
  'function resolve(bytes name, bytes data) view returns (bytes memory)',
  'function addr(bytes32 node) view returns (address)',
  'function addr(bytes32 node, uint256 coinType) view returns (bytes memory)',
  'function text(bytes32 node, string key) view returns (string memory)',
  'function contenthash(bytes32 node) view returns (bytes memory)',
  'function ABI(bytes32 node, uint256 contentTypes) view returns (uint256, bytes memory)',
])

export function dnsDecodeName(encodedName: Hex): string {
  const bytesName = toBytes(encodedName)
  return bytesToPacket(bytesName)
}

// Taken from ensjs https://github.com/ensdomains/ensjs/blob/main/packages/ensjs/src/utils/hexEncodedName.ts
function bytesToPacket(bytes: ByteArray): string {
  let offset = 0
  let result = ''

  while (offset < bytes.length) {
    const len = bytes[offset]
    if (len === 0) {
      offset += 1
      break
    }

    result += `${bytesToString(bytes.subarray(offset + 1, offset + len + 1))}.`
    offset += len + 1
  }

  return result.replace(/\.$/, '')
}
