/** Restore existing linked cards only. Never add cards, move the viewport, or select archived lore. */
export function restoredCardSelection(elements: readonly any[], requested: readonly string[], live: ReadonlySet<string>) {
  const wanted = new Set(requested.filter(id => live.has(id)));
  const cards = elements.filter(e => !e.isDeleted && e.customData?.synthesis === "card" && wanted.has(e.customData.recordID));
  const ids = new Set(cards.map(e => e.id));
  const groups = new Set(cards.flatMap(e => (e.groupIds ?? []).slice(0, 1)));
  return Object.fromEntries(elements.filter(e => !e.isDeleted &&
    (ids.has(e.id) || (e.customData?.synthesis === "part" && (e.groupIds ?? []).some((id: string) => groups.has(id)))))
    .map(e => [e.id, true])) as Record<string, true>;
}
