# Return to the same part of a map

Atlas remembers each map's zoom, geographic center, visible marker/region layers and selected region or record. Open a linked document, switch tools or maps, then return through the sidebar or Back (⌘[). Forward (⌘]) returns to the later visit. A saved workspace layout includes the map view at the time it was saved.

The view is local to this device and universe. It is saved when leaving or saving Atlas and on normal quit, and restored when reopening that map. It does not rewrite the map image, markers, regions, source documents or canon. Moving the viewport alone does not create lore activity.

Resizing the window or opening a second editor preserves the image-relative center and zoom. **Fit** recenters the image at 100% without changing layer visibility or the selection. Replacing the image intentionally fits the new image.

Removed selections clear while the rest of the view survives. An archived map is not resurrected by navigation. Unreadable saved view preferences fall back to the default view; the original preference is preserved, with a recovery copy made before a later changed view replaces it. The map itself is untouched.

This is map-view restoration, not a claim of full application-session restoration (#33). An in-progress polygon or uncommitted reshape is not replayed as a navigation state. Imported world files do not carry device-local view preferences.
