# Atlas maps

The Atlas title is a map selector. **New map** creates a named, saved map; **Map details** can rename it, link it to an entity and choose a parent map. The entity can be any custom category. Parent links organize world, region and local maps without claiming that their imagery is geometrically aligned.

Choose an image or an optional bundled sample illustration for each map. **Place marker** selects an existing record, then a click places it. A marker's context menu opens its record, moves it with another click, or removes it with Undo. Image replacement also offers Undo. Each map keeps independent imagery and markers.

Zoom buttons preserve the place at the viewport centre, including after panning. Pinch and Command-scroll preserve the point beneath the pointer. Both use the same bounded transform (50–500%); **Fit** restores the whole map. The decoded image is retained while navigating the map, so panning and zooming do not repeatedly decode its base64 payload.

A parent link appears in the workspace bar. Maps with children offer a **Local maps** menu. A linked place opens its lore from the map; a record's action menu lists maps that describe or contain it. Removing a map archives it with Undo. Move or remove child maps before archiving their parent.

Save and Undo compare the exact loaded map name/content in a transaction. They cannot overwrite a newer save or target another map after switching. Unsaved conflicts keep their local changes; **Reload saved map** explicitly confirms discarding them. A failed load leaves stored content untouched and allows navigation away.

Assistant context identifies the active Atlas map, place, parent, image availability and record placements without transmitting image bytes. A reviewed `create_map` proposal can create a named empty map and its links. Existing `place_marker` proposals require a map with an image. The assistant cannot silently generate artwork, move established geography or accept canon. Manual mode retains the same map tools.

Optional `placeID` and `parentMapID` fields live in the existing world-scoped board document. They round-trip through `.synthesis` v6 with fresh IDs. Core validation rejects foreign-world links, cyclic map ancestry, invalid coordinates and duplicate markers.

This is a linked image-map workspace. Editable terrain geometry, aligned regional crops, layers, drag handles, automatic lore-driven geography and subscription image generation remain future work. Creation, parenting and marker editing do not imply those capabilities.
