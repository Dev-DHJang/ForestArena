import { randomUUID } from "node:crypto";

export type CharacterId = "ja-hyun" | "myo-ryung";
export type QueueEntry = {
  id: string;
  playerId: string;
  status: "waiting" | "matched";
  matchId?: string;
  slot?: 1 | 2;
  characterId?: CharacterId;
};

export type MatchPair = {
  matchId: string;
  first: QueueEntry & { status: "matched"; slot: 1; characterId: "ja-hyun" };
  second: QueueEntry & { status: "matched"; slot: 2; characterId: "myo-ryung" };
};

export class Matchmaker {
  private entries = new Map<string, QueueEntry>();
  private playerEntries = new Map<string, string>();
  private waitingId: string | undefined;
  private activeMatchId: string | undefined;

  join(playerId: string): { entry: QueueEntry; pair?: MatchPair } {
    const existingId = this.playerEntries.get(playerId);
    if (existingId) return { entry: this.mustGet(existingId) };
    if (this.activeMatchId) throw new Error("game_server_busy");

    const entry: QueueEntry = { id: randomUUID(), playerId, status: "waiting" };
    this.entries.set(entry.id, entry);
    this.playerEntries.set(playerId, entry.id);
    if (!this.waitingId) {
      this.waitingId = entry.id;
      return { entry };
    }

    const firstWaiting = this.mustGet(this.waitingId);
    const matchId = randomUUID();
    const first: MatchPair["first"] = { ...firstWaiting, status: "matched", matchId, slot: 1, characterId: "ja-hyun" };
    const second: MatchPair["second"] = { ...entry, status: "matched", matchId, slot: 2, characterId: "myo-ryung" };
    this.entries.set(first.id, first);
    this.entries.set(second.id, second);
    this.waitingId = undefined;
    this.activeMatchId = matchId;
    return { entry: second, pair: { matchId, first, second } };
  }

  get(entryId: string, playerId: string): QueueEntry | undefined {
    const entry = this.entries.get(entryId);
    return entry?.playerId === playerId ? entry : undefined;
  }

  cancel(entryId: string, playerId: string): boolean {
    const entry = this.get(entryId, playerId);
    if (!entry || entry.status !== "waiting") return false;
    this.entries.delete(entryId);
    this.playerEntries.delete(playerId);
    if (this.waitingId === entryId) this.waitingId = undefined;
    return true;
  }

  complete(matchId: string): void {
    if (this.activeMatchId !== matchId) return;
    this.activeMatchId = undefined;
    for (const [id, entry] of this.entries) {
      if (entry.matchId === matchId) {
        this.entries.delete(id);
        this.playerEntries.delete(entry.playerId);
      }
    }
  }

  fail(matchId: string): void {
    this.complete(matchId);
  }

  private mustGet(id: string): QueueEntry {
    const entry = this.entries.get(id);
    if (!entry) throw new Error("queue_entry_missing");
    return entry;
  }
}
