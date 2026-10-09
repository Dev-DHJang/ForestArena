import test from "node:test";
import assert from "node:assert/strict";
import { normalizeNickname } from "../src/demo_guests.js";
import { isAllowedLanAddress, parseAllowedCidr } from "../src/lan_network.js";

test("nickname uses NFC without trim and accepts only 2 to 12 permitted characters", () => {
  assert.equal(normalizeNickname("나비_Ab12"), "나비_Ab12");
  assert.equal(normalizeNickname("가나"), "가나");
  assert.equal(normalizeNickname("abcdefghijkl"), "abcdefghijkl");
  for (const value of [null, 42, "가", "abcdefghijklm", " 이름", "이름 ", "a-b", "🙂🙂", "aa\n", "éé", "ㄱㄴ"]) {
    assert.throws(() => normalizeNickname(value), /invalid_nickname/);
  }
});

test("CIDR admits socket LAN and loopback, rejects public and outside addresses", () => {
  const cidr = "192.168.10.0/24";
  for (const value of ["192.168.10.1", "192.168.10.255", "::ffff:192.168.10.20", "127.0.0.1", "::1"]) assert.equal(isAllowedLanAddress(value, cidr), true);
  for (const value of ["192.168.11.1", "8.8.8.8", "::ffff:8.8.8.8", "::", "0.0.0.0", "2001:db8::1", undefined]) assert.equal(isAllowedLanAddress(value, cidr), false);
  for (const value of ["0.0.0.0/0", "8.8.8.0/24", "192.168.0.0/15", "192.168.0.0/33", "192.168.0.0/x", "192.168.0.0", "::1/128"]) assert.throws(() => parseAllowedCidr(value));
  for (const value of ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8"]) assert.doesNotThrow(() => parseAllowedCidr(value));
});
