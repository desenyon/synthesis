// Excalidraw keeps pictures looking natural in its dark theme by drawing them through
// `context.filter`, which cancels the theme's inversion. WebKit's 2D canvas does not implement
// `filter`, so inside the application every picture would appear as a negative. This supplies
// the one behaviour Excalidraw relies on: when a filter containing `invert` is set, images are
// drawn from a cached, pre-inverted copy.

const proto = CanvasRenderingContext2D.prototype as any;

if (!("filter" in proto)) {
  const filters = new WeakMap<object, string>();
  const stacks = new WeakMap<object, string[]>();
  const copies = new WeakMap<object, HTMLCanvasElement>();

  Object.defineProperty(proto, "filter", {
    configurable: true,
    get() {
      return filters.get(this) ?? "none";
    },
    set(value: string) {
      filters.set(this, value);
    },
  });

  const save = proto.save;
  const restore = proto.restore;
  proto.save = function () {
    const stack = stacks.get(this) ?? [];
    stack.push(filters.get(this) ?? "none");
    stacks.set(this, stack);
    return save.call(this);
  };
  proto.restore = function () {
    const previous = stacks.get(this)?.pop();
    if (previous !== undefined) filters.set(this, previous);
    return restore.call(this);
  };

  // invert(100%) → hue-rotate(180deg) → saturate(1.25), as one pass over the pixels.
  const hue = [
    [-0.574, 1.43, 0.144],
    [0.426, 0.43, 0.144],
    [0.426, 1.43, -0.856],
  ];
  const s = 1.25;
  const sat = [
    [0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s],
    [0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s],
    [0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s],
  ];
  const inverted = (image: any): CanvasImageSource => {
    const width = image.naturalWidth ?? image.width;
    const height = image.naturalHeight ?? image.height;
    if (!width || !height) return image;
    const cached = copies.get(image);
    if (cached) return cached;
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d")!;
    drawImage.call(ctx, image, 0, 0, width, height);
    try {
      const data = ctx.getImageData(0, 0, width, height);
      const px = data.data;
      for (let i = 0; i < px.length; i += 4) {
        const r = 255 - px[i];
        const g = 255 - px[i + 1];
        const b = 255 - px[i + 2];
        const hr = hue[0][0] * r + hue[0][1] * g + hue[0][2] * b;
        const hg = hue[1][0] * r + hue[1][1] * g + hue[1][2] * b;
        const hb = hue[2][0] * r + hue[2][1] * g + hue[2][2] * b;
        px[i] = sat[0][0] * hr + sat[0][1] * hg + sat[0][2] * hb;
        px[i + 1] = sat[1][0] * hr + sat[1][1] * hg + sat[1][2] * hb;
        px[i + 2] = sat[2][0] * hr + sat[2][1] * hg + sat[2][2] * hb;
      }
      ctx.putImageData(data, 0, 0);
    } catch {
      return image;
    }
    copies.set(image, canvas);
    return canvas;
  };

  const drawImage = proto.drawImage;
  proto.drawImage = function (image: any, ...rest: any[]) {
    const filter = filters.get(this);
    const source = filter && filter.includes("invert") && image instanceof HTMLImageElement ? inverted(image) : image;
    return drawImage.call(this, source, ...rest);
  };
}

export {};
