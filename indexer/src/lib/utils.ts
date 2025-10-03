import { ByteArray, bytesToString, Hex, hexToBytes, keccak256 } from 'viem'

export function makeNode({
  parentNode,
  labelHash,
}: {
  parentNode: Hex
  labelHash: Hex
}) {
  return keccak256((parentNode + labelHash.split('0x')[1]) as Hex)
}

export function dnsDecodeName(encodedName: Hex) {
  return bytesToPacket(hexToBytes(encodedName))
}

function bytesToPacket(bytes: ByteArray): string {
  let offset = 0
  let result = ''

  while (offset < bytes.length) {
    const len = bytes[offset]
    if (len === 0) {
      offset += 1
      break
    }

    result += `${bytesToString(bytes.subarray(offset + 1, offset + len! + 1))}.`
    offset += len! + 1
  }

  return result.replace(/\.$/, '')
}
