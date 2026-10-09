import { parseAllowedCidr, isAllowedLanAddress } from "./lan_network.js";

export type Config = {
  demoMode: boolean;
  allowedCidr: string | undefined;
  host: string;
  port: number;
  databaseUrl: string;
  tokenSecret: string;
  serviceToken: string;
  advertisedWebSocketUrl: string;
};

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

export function loadConfig(): Config {
  const tokenSecret = required("FOREST_ARENA_TOKEN_SECRET");
  const serviceToken = required("FOREST_ARENA_SERVICE_TOKEN");
  if (tokenSecret.length < 32 || serviceToken.length < 32) {
    throw new Error("development secrets must contain at least 32 characters");
  }
  const demoMode = process.env.FOREST_ARENA_DEMO_MODE === "true";
  const allowedCidr = process.env.FOREST_ARENA_ALLOWED_CIDR;
  const host = process.env.FOREST_ARENA_API_HOST ?? "127.0.0.1";
  if (demoMode) {
    if (!allowedCidr) throw new Error("FOREST_ARENA_ALLOWED_CIDR is required in demo mode");
    parseAllowedCidr(allowedCidr);
    if (!isAllowedLanAddress(host, allowedCidr)) throw new Error("demo API host must be a specific allowed LAN address");
  }
  return {
    demoMode,
    allowedCidr,
    host,
    port: Number(process.env.FOREST_ARENA_API_PORT ?? "3000"),
    databaseUrl: required("DATABASE_URL"),
    tokenSecret,
    serviceToken,
    advertisedWebSocketUrl: process.env.FOREST_ARENA_ADVERTISED_WS_URL ?? "ws://127.0.0.1:7777",
  };
}
