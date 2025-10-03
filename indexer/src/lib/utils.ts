import { Hex, keccak256 } from 'viem'

export function makeNode({
  parentNode,
  labelHash,
}: {
  parentNode: Hex
  labelHash: Hex
}) {
  return keccak256((parentNode + labelHash.split('0x')[1]) as Hex)
}
