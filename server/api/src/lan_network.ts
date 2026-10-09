import { isIP } from "node:net";

function ipv4(address: string): number | undefined {
  const normalized = address.startsWith("::ffff:") ? address.slice(7) : address;
  if (isIP(normalized) !== 4) return undefined;
  return normalized.split(".").reduce((result, part) => (result * 256 + Number(part)) >>> 0, 0);
}

export function parseAllowedCidr(value: string): { network: number; mask: number } {
  const parts = value.split("/");
  const address = ipv4(parts[0] ?? "");
  const prefix = Number(parts[1]);
  if (parts.length !== 2 || !/^\d+$/.test(parts[1] ?? "") || address === undefined || prefix < 8 || prefix > 32) {
    throw new Error("FOREST_ARENA_ALLOWED_CIDR must be a private IPv4 CIDR");
  }
  const mask = (0xffffffff << (32 - prefix)) >>> 0;
  const network = (address & mask) >>> 0;
  const privateRanges = [[0x0a000000, 8], [0xac100000, 12], [0xc0a80000, 16], [0x7f000000, 8]];
  if (!privateRanges.some(([base, bits]) => prefix >= bits! && ((network & (0xffffffff << (32 - bits!))) >>> 0) === base)) {
    throw new Error("FOREST_ARENA_ALLOWED_CIDR must be a private IPv4 CIDR");
  }
  return { network, mask };
}

export function isAllowedLanAddress(address: string | undefined, cidr: string): boolean {
  if (address === "::1") return true;
  const candidate = address === undefined ? undefined : ipv4(address);
  if (candidate === undefined) return false;
  if ((candidate >>> 24) === 127) return true;
  const { network, mask } = parseAllowedCidr(cidr);
  return ((candidate & mask) >>> 0) === network;
}
