import Foundation

/// Shared by the additive migration and imports of older world files.
/// Only known revisions and labeled saved states are reconstructed; missing past edits are not invented.
enum ActivityHistoryMigration {
  static func backfill(_ db: Database, worldID: String? = nil) throws {
    for query in queries {
      let scope = worldID == nil ? "" : " WHERE change_world=?"
      try db.execute(
        "INSERT INTO world_activity SELECT * FROM (\(query))\(scope)",
        worldID.map { [$0] } ?? [])
    }
  }
  private static let queries = [
    """
    SELECT synthesis_uuid(),n.world_id AS change_world,n.record_id,'record',
      CASE WHEN n.legacy=1 THEN 'recorded'
        WHEN (CASE WHEN json_valid(n.snapshot) THEN json_extract(n.snapshot,'$.state') ELSE '' END)='canon' THEN 'approved'
        WHEN n.version=1 THEN 'created' ELSE 'updated' END,
      CASE WHEN json_valid(n.snapshot) THEN COALESCE(json_extract(n.snapshot,'$.title'),'Record revision') ELSE 'Record revision' END,
      'Saved revision ' || n.version,n.created_at,n.version,NULL,1
    FROM (
      SELECT world_id,record_id,version,snapshot,created_at,rowid AS original_order,0 AS legacy FROM native_revisions
      UNION ALL
      SELECT r.world_id,r.record_id,r.version,r.snapshot,r.created_at,r.rowid,1 FROM revisions r
        WHERE NOT EXISTS(SELECT 1 FROM native_revisions n WHERE n.record_id=r.record_id AND n.version=r.version)
    ) n ORDER BY n.created_at,n.version,n.original_order
    """,
    """
    SELECT synthesis_uuid(),r.world_id AS change_world,r.id,'record','recorded',r.title,
      'Saved record before activity tracking',r.updated_at,r.version,NULL,1
    FROM records r WHERE NOT EXISTS(SELECT 1 FROM native_revisions n WHERE n.record_id=r.id)
    """,
    """
    SELECT synthesis_uuid(),h.world_id AS change_world,h.relationship_id,'relationship','recorded',
      a.title || ' → ' || b.title,'Recorded ' || h.action || ' · previous label: ' || h.label,
      h.created_at,NULL,NULL,1
    FROM relationship_history h JOIN records a ON a.id=h.source_id JOIN records b ON b.id=h.target_id
    ORDER BY h.created_at,h.rowid
    """,
    """
    SELECT synthesis_uuid(),h.world_id AS change_world,r.system_id,'record','recorded',
      CASE WHEN json_valid(h.snapshot) THEN COALESCE(json_extract(h.snapshot,'$.title'),r.title) ELSE r.title END,
      'Saved rule snapshot',h.created_at,NULL,NULL,1
    FROM rule_history h JOIN rules r ON r.id=h.rule_id ORDER BY h.created_at,h.rowid
    """,
    """
    SELECT synthesis_uuid(),id AS change_world,id,'world','recorded',name,'World saved before activity tracking',updated_at,NULL,NULL,1 FROM worlds
    """,
    """
    SELECT synthesis_uuid(),world_id AS change_world,id,'relationship','recorded',label,'Relationship saved before activity tracking',updated_at,NULL,NULL,1 FROM relationships
    """,
    """
    SELECT synthesis_uuid(),world_id AS change_world,id,'event','recorded',title,'History event saved before activity tracking',updated_at,NULL,NULL,1 FROM events
    """,
    """
    SELECT synthesis_uuid(),world_id AS change_world,id,'board','recorded',name,'Workspace saved before activity tracking',updated_at,NULL,kind,1 FROM boards WHERE kind IN ('atlas','canvas')
    """,
    """
    SELECT synthesis_uuid(),world_id AS change_world,id,'proposal','recorded',reason,'Review state saved before activity tracking',updated_at,NULL,NULL,1 FROM proposals
    """,
    """
    SELECT synthesis_uuid(),world_id AS change_world,id,'lane','recorded',name,'History branch or period saved before activity tracking',updated_at,NULL,NULL,1 FROM chronology_lanes
    """,
    """
    SELECT synthesis_uuid(),world_id AS change_world,id,'conversation','recorded',title,'Conversation saved before activity tracking',updated_at,NULL,NULL,1 FROM conversations
    """,
    """
    SELECT synthesis_uuid(),world_id AS change_world,system_id,'record','recorded',title,'Rule saved before activity tracking',updated_at,NULL,NULL,1 FROM rules
    """,
    """
    SELECT synthesis_uuid(),world_id AS change_world,system_id,'record','recorded',title,'Scenario saved before activity tracking',updated_at,NULL,NULL,1 FROM rule_scenarios
    """,
  ]
}
