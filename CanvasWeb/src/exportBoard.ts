import { exportToCanvas, getCommonBounds } from '@excalidraw/excalidraw';
import { isCard, kindLabel, stateName, type RecordInfo, type RelationInfo } from './cards';
import { displayColor, displayPalette, categoryColor, type Theme } from './palette';

/** The engine's drawing plus the actual Synthesis card presentation. No scene mutation. */
export async function exportBoard(elements: readonly any[], appState: any, files: any,
  records: Map<string, RecordInfo>, relations: RelationInfo[], theme: Theme): Promise<Blob> {
  if (!elements.length) throw new Error('Add something to the board before exporting an image.');
  await document.fonts.load('600 17px Inter');
  await document.fonts.load('400 14px Inter');
  const [minX, minY] = getCommonBounds(elements);
  let scale = 1;
  const canvas = await exportToCanvas({
    elements: elements.map(e => ({...e,
      opacity: ['card', 'part'].includes(e.customData?.synthesis) ? 0 : e.opacity,
      strokeColor: displayColor(e.strokeColor, theme), backgroundColor: displayColor(e.backgroundColor, theme)})),
    appState: {...appState, exportBackground: true, exportWithDarkMode: false,
      viewBackgroundColor: displayPalette(theme).background},
    files, exportPadding: 32,
    getDimensions: (width, height) => {
      scale = Math.min(2, 4096 / width, 4096 / height);
      return {width: width * scale, height: height * scale, scale};
    },
  });
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('The board image could not be rendered.');
  ctx.filter = 'none';
  const p = displayPalette(theme);
  for (const card of elements.filter(isCard)) {
    const record = records.get(card.customData.recordID);
    const tint = categoryColor(p, record?.category ?? '');
    ctx.save();
    ctx.setTransform(scale, 0, 0, scale, 0, 0);
    ctx.translate(card.x - minX + 32 + card.width / 2, card.y - minY + 32 + card.height / 2);
    ctx.rotate(card.angle ?? 0);
    ctx.translate(-card.width / 2, -card.height / 2);
    ctx.beginPath(); ctx.roundRect(0, 0, card.width, card.height, 12);
    ctx.fillStyle = p.surface; ctx.fill(); ctx.strokeStyle = p.border; ctx.lineWidth = 1; ctx.stroke();
    ctx.clip(); ctx.textBaseline = 'top';
    ctx.fillStyle = tint; ctx.beginPath(); ctx.arc(18, 19, 2.5, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = p.secondary; ctx.font = '400 12px Inter';
    ctx.fillText(record ? kindLabel(record) : 'Archived record', 29, 12, card.width - 48);
    ctx.beginPath(); ctx.moveTo(14, 38); ctx.lineTo(card.width - 14, 38); ctx.stroke();
    let copyY = 50;
    const art = elements.find(e => !e.isDeleted && e.type === 'image' && e.customData?.role === 'art'
      && e.groupIds?.[0] === card.groupIds?.[0]);
    const url = art && files[art.fileId]?.dataURL;
    if (url && /^data:image\//.test(url)) {
      const image = await new Promise<HTMLImageElement>((resolve, reject) => {
        const img = new Image(); img.onload = () => resolve(img);
        img.onerror = () => reject(new Error('An attached image could not be exported.'));
        img.src = url;
      });
      const height = Math.min(art.height, card.height - 90), width = card.width - 12;
      const ratio = Math.max(width / image.width, height / image.height);
      ctx.save(); ctx.beginPath(); ctx.roundRect(6, 44, width, height, 11); ctx.clip();
      ctx.drawImage(image, 6 + (width - image.width * ratio) / 2, 44 + (height - image.height * ratio) / 2,
        image.width * ratio, image.height * ratio); ctx.restore();
      copyY = 56 + height;
    }
    ctx.save(); ctx.beginPath(); ctx.rect(0, copyY, card.width, Math.max(0, card.height - 42 - copyY)); ctx.clip();
    ctx.font = '600 17px Inter'; ctx.fillStyle = p.text;
    const title = lines(ctx, record?.title ?? 'Archived record', card.width - 30, 2);
    title.forEach((line, i) => ctx.fillText(line, 15, copyY + i * 21.25));
    copyY += title.length * 21.25 + 7;
    ctx.font = '400 14px Inter'; ctx.fillStyle = p.secondary;
    lines(ctx, record?.body || 'Open this record to begin writing.', card.width - 30, art ? 3 : 5)
      .forEach((line, i) => ctx.fillText(line, 15, copyY + i * 21));
    ctx.restore();
    ctx.fillStyle = p.surface; ctx.fillRect(1, card.height - 34, card.width - 2, 33);
    ctx.strokeStyle = p.border; ctx.beginPath(); ctx.moveTo(0, card.height - 34); ctx.lineTo(card.width, card.height - 34); ctx.stroke();
    const count = relations.filter(r => r.sourceID === record?.id || r.targetID === record?.id).length;
    ctx.font = '400 12px Inter'; ctx.fillStyle = p.secondary;
    ctx.fillText(`${count} ${count === 1 ? 'connection' : 'connections'}`, 14, card.height - 23);
    const status = record ? stateName(record) : 'Archived';
    const statusX = card.width - 14 - ctx.measureText(status).width;
    ctx.fillText(status, statusX, card.height - 23);
    ctx.fillStyle = record?.state === 'canon' ? p.positive : p.muted;
    ctx.beginPath(); ctx.arc(statusX - 9, card.height - 17, 2.5, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
  }
  return new Promise((resolve, reject) => canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error('The exported image was empty.')), 'image/png'));
}

function lines(ctx: CanvasRenderingContext2D, text: string, width: number, limit: number): string[] {
  const result: string[] = [];
  for (const paragraph of text.split('\n')) {
    let line = '';
    for (const word of paragraph.split(/\s+/)) {
      const next = line ? `${line} ${word}` : word;
      if (ctx.measureText(next).width > width && line) { result.push(line); line = word; }
      else line = next;
    }
    result.push(line);
  }
  const visible = result.slice(0, limit);
  if (result.length > limit) visible[limit - 1] += '…';
  return visible.map(line => {
    if (ctx.measureText(line).width <= width) return line;
    while (line.length && ctx.measureText(`${line}…`).width > width) line = line.slice(0, -1);
    return `${line}…`;
  });
}
