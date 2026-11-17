import { graphlib, layout } from '@dagrejs/dagre';

export type LayoutCard = {id: string; recordID: string; x: number; y: number; width: number; height: number};
/** Pure layout; applying it is an explicit, undoable creator action. */
export function arrangeCards(cards: LayoutCard[], relations: {sourceID: string; targetID: string}[], landscape = true) {
  const graph = new graphlib.Graph({multigraph: true});
  graph.setGraph({rankdir: landscape ? 'LR' : 'TB', nodesep: 64, ranksep: 120, edgesep: 32});
  graph.setDefaultEdgeLabel(() => ({}));
  const byRecord = new Map(cards.map(card => [card.recordID, card.id]));
  for (const card of cards) graph.setNode(card.id, {width: card.width, height: card.height});
  relations.forEach((relation, index) => {
    const a = byRecord.get(relation.sourceID), b = byRecord.get(relation.targetID);
    if (a && b) graph.setEdge(a, b, {}, String(index));
  });
  layout(graph);
  return new Map(cards.map(card => {
    const node = graph.node(card.id);
    return [card.id, {x: node.x - card.width / 2, y: node.y - card.height / 2}];
  }));
}
