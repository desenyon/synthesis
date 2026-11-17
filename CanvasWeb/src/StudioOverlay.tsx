import { Cursor as MousePointer2, Hand, Plus, IdentificationCard as ContactRound, Note as StickyNote, Image as ImageIcon, GitBranch, BoundingBox as Frame, Pencil, Square, Minus, CornersOut as Scan, ArrowCounterClockwise as Undo2, ArrowClockwise as Redo2, ArrowUpRight, At as AtSign, X, SlidersHorizontal, Books as Library, FilePlus as FilePlus2, FileText, Graph, User, Flag, MapPin, Lightning, Sparkle, CalendarBlank, Lightbulb, type Icon as PhosphorIcon } from '@phosphor-icons/react';
import { CaptureUpdateAction, newElementWith } from '@excalidraw/excalidraw';
import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { isCard, kindLabel, stateName, type RecordInfo, type RelationInfo } from './cards';
import { cardFrame, visibleFrame, drawingStyleContext } from './sceneRules';
import { palette, displayPalette, categoryColor, categoryKey, type Theme } from './palette';
type Props = {
    api: any;
    theme: Theme;
    assisted: boolean;
    records: () => Map<string, RecordInfo>;
    relations: () => RelationInfo[];
    post: (message: Record<string, unknown>) => void;
};
const icons: Record<string, PhosphorIcon> = { select: MousePointer2, hand: Hand, plus: Plus, entity: ContactRound,
    note: StickyNote, image: ImageIcon, connect: GitBranch, frame: Frame, draw: Pencil, shape: Square,
    minus: Minus, fit: Scan, arrange: Graph, undo: Undo2, redo: Redo2, open: ArrowUpRight, reference: AtSign,
    close: X, settings: SlidersHorizontal, library: Library, capture: FilePlus2 };
function Icon({ name }: { name: string }) {
    const Glyph = icons[name] ?? FileText;
    return <Glyph size={17} weight="regular" aria-hidden="true"/>;
}
function Tool({ label, icon, active = false, disabled = false, action }: {
    label: string;
    icon: string;
    active?: boolean;
    disabled?: boolean;
    action: () => void;
}) {
    return <button type="button" className={`studio-tool ${active ? 'is-active' : ''}`} title={label} aria-label={label} aria-pressed={active} disabled={disabled} onClick={action}><Icon name={icon}/><span className="studio-tooltip">{label}</span></button>;
}
const categoryIcons: Record<string, PhosphorIcon> = { characters: User, factions: Flag, places: MapPin, 'power systems': Lightning, cosmology: Sparkle, events: CalendarBlank, ideas: Lightbulb };
/** Rich cards are a presentation of engine elements, never a second board model.
 * Pointer-transparent bodies preserve Excalidraw drag, selection, resize and undo.
 * Only explicit record actions and connection ports intercept the pointer. */
export function StudioOverlay({ api, theme, assisted, records, relations, post }: Props) {
    const [view, setView] = useState<any>(null);
    const [connecting, setConnecting] = useState<string | null>(null);
    const [styles, setStyles] = useState(false);
    const frame = useRef(0);
    useEffect(() => {
        const refresh = () => { cancelAnimationFrame(frame.current); frame.current = requestAnimationFrame(() => setView({ state: api.getAppState(), elements: api.getSceneElements(), files: api.getFiles(), records: new Map(records()) })); };
        const unsubscribe = api.onChange(refresh);
        refresh();
        return () => { unsubscribe(); cancelAnimationFrame(frame.current); };
    }, [api, records]);
    useEffect(() => { const cancel = (e: KeyboardEvent) => { if (e.key === 'Escape') {
        setConnecting(null);
        setStyles(false);
    } }; window.addEventListener('keydown', cancel); return () => window.removeEventListener('keydown', cancel); }, []);
    useEffect(() => {
        if (connecting && view && !view.elements.some((element:any) => isCard(element) && element.customData.recordID === connecting)) setConnecting(null);
    }, [connecting, view]);
    useEffect(() => {
        const dismiss = (event:PointerEvent) => {
            if (!(event.target as HTMLElement)?.closest('.record-port, .studio-connect-hint')) setConnecting(null);
        };
        window.addEventListener('pointerdown',dismiss);
        return () => window.removeEventListener('pointerdown',dismiss);
    }, []);

    if (!view)
        return null;
    const { state, elements, files } = view;
    const cards = elements.filter(isCard);
    const recordMap: Map<string, RecordInfo> = view.records;
    const chosen = cards.filter((c: any) => state.selectedElementIds[c.id]);
    const selectedIDs = new Set<string>(chosen.map((c: any) => c.customData.recordID));
    const neighbours = new Set(selectedIDs);
    for (const relation of relations()) {
        if (selectedIDs.has(relation.sourceID))
            neighbours.add(relation.targetID);
        if (selectedIDs.has(relation.targetID))
            neighbours.add(relation.sourceID);
    }
    const artByGroup = new Map<string, any>();
    for (const element of elements)
        if (element.type === 'image' && element.customData?.role === 'art' && element.groupIds?.[0])
            artByGroup.set(element.groupIds[0], element);
    const chooseTool = (type: string) => { setConnecting(null); api.setActiveTool({ type }); };
    const command = (name: string) => (window as any).synthesis?.command(name);
    const active = state.activeTool?.type;
    const styleContext = drawingStyleContext<any>(elements, state.selectedElementIds, active);
    const selectedDrawing = styleContext.targets;
    const note = selectedDrawing.length === 1 && selectedDrawing[0].type === 'text' ? selectedDrawing[0] : null;
    const selectedRelation = elements.find((e:any) => state.selectedElementIds[e.id] && e.customData?.synthesis === 'relation');
    const storedRelation = relations().find(r => r.id === selectedRelation?.customData.relationID);
    const style = (property: string, value: unknown) => {
      const key = 'currentItem' + property[0].toUpperCase() + property.slice(1);
      api.updateScene({ elements: elements.map((e:any) => selectedDrawing.includes(e) ? newElementWith(e, {[property]:value}) : e),
        appState:{[key]:value}, captureUpdate:CaptureUpdateAction.IMMEDIATELY });
    };
    const connect = (id: string) => {
        if (!connecting) {
            setConnecting(id);
            return;
        }
        if (connecting === id) {
            setConnecting(null);
            return;
        }
        post({ type: 'connect', arrowID: `ports:${crypto.randomUUID()}`, source: connecting, target: id, label: '' });
        setConnecting(null);
    };
    const material = displayPalette(theme);
    const lightMaterial = theme === 'light' ? {
        '--glass': material.surface, '--line': material.border, '--quiet': material.secondary,
        '--ink': material.text, '--muted': material.muted, '--positive': material.positive,
        '--focus': material.accent,
    } as CSSProperties : undefined;
    return <div className={`studio-overlay ${theme}`} style={lightMaterial}>
   <div className="studio-relationship-layer">
     {elements.filter((e:any) => e.customData?.synthesis === 'relation' && !e.isDeleted).map((edge:any) => {
       const labelID = edge.boundElements?.find((b:any) => b.type === 'text')?.id;
       const label = elements.find((e:any) => e.id === labelID);
       const relation = relations().find(r => r.id === edge.customData.relationID);
       if (!label || !relation) return null;
       const bounds = cardFrame(label, state);
       return <button key={edge.id} className="studio-relationship-hit"
         style={{left:bounds.x-8,top:bounds.y-6,width:Math.max(30,bounds.width+16),height:Math.max(26,bounds.height+12)}}
         aria-label={`${recordMap.get(relation.sourceID)?.title} ${relation.label} ${recordMap.get(relation.targetID)?.title}`}
         title="Inspect relationship" onClick={() => post({type:'inspectRelation',relationID:relation.id})}/>;
     })}
   </div>
   <div className="studio-card-layer" aria-label="World records on this board">
     {cards.map((card: any) => {
            const bounds = cardFrame(card, state);
            if (!visibleFrame(bounds, state.width, state.height))
                return null;
            const record = recordMap.get(card.customData.recordID);
            const selected = !!state.selectedElementIds[card.id];
            const group = card.groupIds?.[0];
            const art = artByGroup.get(group);
            const artURL = art && files[art.fileId]?.dataURL;
            const related = chosen.length === 0 || neighbours.has(card.customData.recordID);
            const color = categoryColor(displayPalette(theme), record?.category ?? '');
            const CategoryIcon = categoryIcons[categoryKey(record?.category ?? '')] ?? FileText;
            const connections = relations().filter(r => r.sourceID === record?.id || r.targetID === record?.id).length;
            return <article key={card.id} className={`studio-record ${selected ? 'is-selected' : ''} ${related ? '' : 'is-unrelated'} ${artURL ? 'has-art' : ''}`} style={{ '--record-accent': color, left: bounds.x + (bounds.width - card.width) / 2, top: bounds.y + (bounds.height - card.height) / 2, width: card.width, height: card.height, transform: `scale(${bounds.zoom}) rotate(${card.angle ?? 0}rad)` } as CSSProperties}>
         <div className="record-kicker"><CategoryIcon size={13} weight="regular" aria-hidden="true"/>{record ? kindLabel(record) : 'Archived record'}</div>
         {artURL && <img className="record-art" src={artURL} alt="" style={{ height: Math.min(art.height, card.height - 90) }} draggable={false}/>}
         <div className="record-copy"><h2>{record?.title ?? 'Archived record'}</h2><p>{record?.body || 'Open this record to begin writing.'}</p></div>
         <footer><span>{connections} {connections === 1 ? 'connection' : 'connections'}</span><span className={`record-state ${record?.state === 'canon' ? 'is-canon' : ''}`}><i />{record ? stateName(record) : 'Archived'}</span></footer>
         <div className="record-actions"><Tool label="Open record" icon="open" action={() => post({ type: 'openRecord', id: card.customData.recordID })}/></div>
         {record?.kind === 'entity' && ['in', 'out'].map(side => <button key={side} type="button" className={`record-port ${side} ${connecting === record.id ? 'connecting' : ''}`} title={connecting ? 'Connect to this entity' : 'Connect this entity'} aria-label={`${connecting ? 'Connect to' : 'Connect from'} ${record.title}`} onClick={() => connect(record.id)}/>)}
       </article>;
        })}
   </div>
   <div className="studio-add-bar glass" role="toolbar" aria-label="Worldbuilding tools">
     <Tool label="Add entity" icon="entity" action={() => post({ type: 'request', action: 'entity' })}/>
     <Tool label="Add from library" icon="library" action={() => post({ type: 'request', action: 'library' })}/>
     <span className="tool-separator"/>
     <Tool label="Capture an idea in Library" icon="note" action={() => post({type:'request',action:'note'})}/>
     <Tool label="Add image" icon="image" action={() => post({ type: 'request', action: 'image' })}/>
   </div>
   <div className="studio-drawing-bar glass" role="toolbar" aria-label="Canvas tools">
     <Tool label="Select · V" icon="select" active={active === 'selection'} action={() => chooseTool('selection')}/>
     <Tool label="Pan · H" icon="hand" active={active === 'hand'} action={() => chooseTool('hand')}/>
     <span className="tool-separator"/>
     <Tool label="Connect · A" icon="connect" active={active === 'arrow'} action={() => chooseTool('arrow')}/>
     <Tool label="Shape · R" icon="shape" active={active === 'rectangle'} action={() => chooseTool('rectangle')}/>
     <Tool label="Board text · T" icon="note" active={active === 'text'} action={() => chooseTool('text')}/><Tool label="Draw · P" icon="draw" active={active === 'freedraw'} action={() => chooseTool('freedraw')}/>
     <Tool label="Group in a frame · F" icon="frame" active={active === 'frame'} action={() => chooseTool('frame')}/>
     <span className="tool-separator"/>
     <Tool label="Drawing style" icon="settings" active={styles && styleContext.available} disabled={!styleContext.available} action={() => setStyles(v => !v)}/>
   </div>
   <div className="studio-viewport glass" role="toolbar" aria-label="Canvas viewport">
     <Tool label="Undo · ⌘Z" icon="undo" action={() => command('undo')}/><Tool label="Redo · ⇧⌘Z" icon="redo" action={() => command('redo')}/>
     <span className="tool-separator"/><Tool label="Zoom out" icon="minus" action={() => command('zoomOut')}/>
     <button className="zoom-label" title="Reset zoom to 100%" onClick={() => command('resetZoom')}>{Math.round(state.zoom.value * 100)}%</button>
     <Tool label="Zoom in" icon="plus" action={() => command('zoomIn')}/><Tool label="Fit to content" icon="fit" action={() => command('fit')}/><Tool label="Arrange linked records · undoable" icon="arrange" disabled={cards.length < 2} action={() => command('arrange')}/>
   </div>
   {styles && styleContext.available && <section className="studio-style glass" aria-label="Drawing appearance"><header>Drawing appearance<Tool label="Close appearance" icon="close" action={() => setStyles(false)}/></header>
     {chosen.length > 0 && <p>Styles apply to the selected drawings. Record cards keep their world identity.</p>}
       <span>{styleContext.text ? 'Text color' : 'Stroke'}</span><div className="style-options">{[palette(theme).text,palette(theme).accent,palette(theme).positive,palette(theme).categories.characters].map((color,i) => <button key={color} title={['Neutral','Blue','Green','Warm'][i]} aria-label={['Neutral stroke','Blue stroke','Green stroke','Warm stroke'][i]} style={{background:theme!=='light'?['#eff0f2','#aec7ef','#8fc3a6','#d7b899'][i]:color}} onClick={()=>style('strokeColor',color)}/>)}</div>
       {styleContext.shapes && <><span>Weight</span><div className="style-options">{[1,2,4].map(w=><button key={w} onClick={()=>style('strokeWidth',w)}>{w}px</button>)}</div>
       <span>Line</span><div className="style-options">{['solid','dashed','dotted'].map(v=><button key={v} onClick={()=>style('strokeStyle',v)}>{v}</button>)}</div>
       <span>Fill</span><div className="style-options"><button onClick={()=>style('backgroundColor','transparent')}>None</button><button onClick={()=>style('backgroundColor',palette(theme).surface)}>Surface</button></div>
       </>}
   </section>}
   {note && <div className="studio-selection glass"><span>Board text · not in Library</span><button className="text-action" onClick={()=>post({type:'captureText',elementID:note.id,body:note.originalText ?? note.text})}>Save as idea <Icon name="capture"/></button></div>}
   {storedRelation && <div className="studio-selection glass"><span>{recordMap.get(storedRelation.sourceID)?.title} → {recordMap.get(storedRelation.targetID)?.title}</span><button className="text-action" onClick={()=>post({type:'inspectRelation',relationID:storedRelation.id})}>{storedRelation.label}<Icon name="open"/></button></div>}
   {connecting && <div className="studio-connect-hint glass" role="status"><span className="signal-dot"/>Choose another entity’s port to describe the relationship<Tool icon="close" label="Cancel connection · Escape" action={() => setConnecting(null)}/></div>}
   {chosen.length > 0 && !connecting && <div className="studio-selection glass"><span>{chosen.length === 1 ? recordMap.get(chosen[0].customData.recordID)?.title : `${chosen.length} records`}</span>{assisted && <Tool label="Reference in conversation" icon="reference" action={() => post({ type: 'request', action: 'reference' })}/>}{chosen.length === 1 && <Tool label="Attach artwork" icon="image" action={() => post({ type: 'request', action: 'artwork' })}/>}</div>}
   {cards.length === 0 && elements.length === 0 && <div className="studio-empty"><span className="empty-orbit"><Frame size={34} strokeWidth={1}/></span><h1>Room for a universe.</h1><p>Place your first record. Follow the connections.</p><button onClick={() => post({ type: 'request', action: 'entity' })}>Create an entity <ArrowUpRight size={16}/></button></div>}
 </div>;
}
