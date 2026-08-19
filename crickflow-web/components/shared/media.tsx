export function PhotoPicker({
  files,
  onChange,
  max = 4,
  label = "Photos (optional, JPEG)",
}: {
  files: File[];
  onChange: (files: File[]) => void;
  max?: number;
  label?: string;
}) {
  return (
    <div>
      <label className="text-xs text-muted-foreground">{label}</label>
      <input
        type="file"
        accept="image/*"
        multiple={max > 1}
        className="mt-1 block w-full text-sm"
        onChange={(e) => {
          const extra = Array.from(e.target.files ?? []);
          onChange([...files, ...extra].slice(0, max));
          e.target.value = "";
        }}
      />
      {files.length ? (
        <p className="mt-1 text-xs text-muted-foreground">
          {files.length} of {max} selected
        </p>
      ) : null}
    </div>
  );
}

export function MediaGallery({
  items,
}: {
  items?: { url: string; type?: string }[] | string[];
}) {
  const media = (items ?? [])
    .map((item) =>
      typeof item === "string" ? { url: item, type: "image" } : { url: item.url, type: item.type || "image" },
    )
    .filter((item) => item.url.trim());
  if (!media.length) return null;
  return (
    <div className="mt-4 grid gap-2">
      {media.map((item) =>
        item.type === "video" ? (
          <video
            key={item.url}
            src={item.url}
            controls
            className="max-h-96 w-full rounded-xl bg-black"
          />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            key={item.url}
            src={item.url}
            alt=""
            className="max-h-96 w-full rounded-xl object-cover"
          />
        ),
      )}
    </div>
  );
}
