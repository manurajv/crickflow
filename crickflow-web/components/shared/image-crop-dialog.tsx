"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

export type ImageCropMode = "document" | "avatar" | "cover";

const PRESETS: Array<{ id: string; label: string; ratio: number | null }> = [
  { id: "free", label: "Free", ratio: null },
  { id: "1:1", label: "1:1", ratio: 1 },
  { id: "4:3", label: "4:3", ratio: 4 / 3 },
  { id: "3:2", label: "3:2", ratio: 3 / 2 },
  { id: "16:9", label: "16:9", ratio: 16 / 9 },
];

type CropBox = { x: number; y: number; w: number; h: number };

function applyRatio(box: CropBox, ratio: number | null, maxW: number, maxH: number): CropBox {
  if (!ratio) {
    return {
      x: Math.max(0, box.x),
      y: Math.max(0, box.y),
      w: Math.min(box.w, maxW - Math.max(0, box.x)),
      h: Math.min(box.h, maxH - Math.max(0, box.y)),
    };
  }
  const maxByWidth = maxW / ratio;
  let w = Math.min(box.w, maxW);
  let h = w / ratio;
  if (h > maxH) {
    h = maxH;
    w = h * ratio;
  }
  if (maxByWidth < maxH && w > maxW) {
    w = maxW;
    h = w / ratio;
  }
  return {
    x: Math.min(Math.max(0, box.x), Math.max(0, maxW - w)),
    y: Math.min(Math.max(0, box.y), Math.max(0, maxH - h)),
    w,
    h,
  };
}

function defaultBox(width: number, height: number, ratio: number | null): CropBox {
  if (!ratio) {
    return { x: 0, y: 0, w: width, h: height };
  }
  const imgRatio = width / height;
  if (imgRatio > ratio) {
    const h = height;
    const w = h * ratio;
    return { x: (width - w) / 2, y: 0, w, h };
  }
  const w = width;
  const h = w / ratio;
  return { x: 0, y: (height - h) / 2, w, h };
}

export function ImageCropDialog({
  file,
  mode,
  title,
  onCancel,
  onConfirm,
}: {
  file: File;
  mode: ImageCropMode;
  title: string;
  onCancel: () => void;
  onConfirm: (file: File) => void;
}) {
  const imgRef = useRef<HTMLImageElement | null>(null);
  const [url, setUrl] = useState("");
  const [natural, setNatural] = useState({ w: 0, h: 0 });
  const [box, setBox] = useState<CropBox>({ x: 0, y: 0, w: 0, h: 0 });
  const lockedRatio = mode === "avatar" ? 1 : mode === "cover" ? 16 / 9 : null;
  const [ratio, setRatio] = useState<number | null>(lockedRatio);
  const drag = useRef<{ kind: "move" | "resize"; sx: number; sy: number; start: CropBox } | null>(null);

  useEffect(() => {
    const next = URL.createObjectURL(file);
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [file]);

  const display = useMemo(() => {
    if (!natural.w || !natural.h) return { w: 0, h: 0, scale: 1 };
    const maxW = 320;
    const maxH = 420;
    const scale = Math.min(maxW / natural.w, maxH / natural.h, 1);
    return { w: natural.w * scale, h: natural.h * scale, scale };
  }, [natural]);

  function onImageLoad(img: HTMLImageElement) {
    const w = img.naturalWidth;
    const h = img.naturalHeight;
    setNatural({ w, h });
    setBox(defaultBox(w, h, ratio));
  }

  function selectPreset(next: number | null) {
    if (lockedRatio != null) return;
    setRatio(next);
    if (natural.w) setBox(defaultBox(natural.w, natural.h, next));
  }

  function onPointerDown(kind: "move" | "resize", e: React.PointerEvent) {
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    drag.current = { kind, sx: e.clientX, sy: e.clientY, start: box };
  }

  function onPointerMove(e: React.PointerEvent) {
    if (!drag.current || !display.scale) return;
    const dx = (e.clientX - drag.current.sx) / display.scale;
    const dy = (e.clientY - drag.current.sy) / display.scale;
    const start = drag.current.start;
    if (drag.current.kind === "move") {
      setBox(applyRatio({ ...start, x: start.x + dx, y: start.y + dy }, ratio, natural.w, natural.h));
    } else {
      setBox(
        applyRatio(
          { ...start, w: Math.max(32, start.w + dx), h: Math.max(32, start.h + dy) },
          ratio,
          natural.w,
          natural.h,
        ),
      );
    }
  }

  function onPointerUp() {
    drag.current = null;
  }

  async function confirm() {
    const img = imgRef.current;
    if (!img || !box.w || !box.h) return;
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(box.w);
    canvas.height = Math.round(box.h);
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.drawImage(img, box.x, box.y, box.w, box.h, 0, 0, canvas.width, canvas.height);
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.9));
    if (!blob) return;
    const name = file.name.replace(/\.[^.]+$/, "") + "-cropped.jpg";
    onConfirm(new File([blob], name, { type: "image/jpeg" }));
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <Card className="w-full max-w-md space-y-3 p-4">
        <h2 className="text-lg font-bold">{title}</h2>
        {lockedRatio == null ? (
          <div className="flex flex-wrap gap-2">
            {PRESETS.map((p) => (
              <Button
                key={p.id}
                type="button"
                size="sm"
                variant={ratio === p.ratio ? "default" : "outline"}
                onClick={() => selectPreset(p.ratio)}
              >
                {p.label}
              </Button>
            ))}
          </div>
        ) : null}
        <div className="flex justify-center">
          {url ? (
            <div
              className="relative overflow-hidden bg-muted"
              style={{ width: display.w || "auto", height: display.h || "auto" }}
              onPointerMove={onPointerMove}
              onPointerUp={onPointerUp}
              onPointerCancel={onPointerUp}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                ref={imgRef}
                src={url}
                alt=""
                className="block max-h-[420px] max-w-[320px]"
                onLoad={(e) => onImageLoad(e.currentTarget)}
                draggable={false}
              />
              {display.scale && box.w ? (
                <div
                  className="absolute cursor-move border-2 border-white shadow-[0_0_0_9999px_rgba(0,0,0,0.45)]"
                  style={{
                    left: box.x * display.scale,
                    top: box.y * display.scale,
                    width: box.w * display.scale,
                    height: box.h * display.scale,
                  }}
                  onPointerDown={(e) => onPointerDown("move", e)}
                >
                  <button
                    type="button"
                    aria-label="Resize crop"
                    className="absolute -bottom-1.5 -right-1.5 h-4 w-4 cursor-nwse-resize rounded-sm bg-white"
                    onPointerDown={(e) => onPointerDown("resize", e)}
                  />
                </div>
              ) : null}
            </div>
          ) : null}
        </div>
        <p className="text-xs text-muted-foreground">
          {lockedRatio == null
            ? "Drag the frame to crop. Use Free or a preset, then resize from the corner."
            : "Drag the frame to crop this photo."}
        </p>
        <div className="flex justify-end gap-2">
          <Button type="button" variant="outline" onClick={onCancel}>
            Cancel
          </Button>
          <Button type="button" onClick={confirm} disabled={!box.w}>
            Use photo
          </Button>
        </div>
      </Card>
    </div>
  );
}
