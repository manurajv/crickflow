# Firebase Storage CORS (Admin web images)

Flutter web (CanvasKit) loads Storage images via byte fetch. Without bucket CORS, Chrome reports:

`NetworkImageLoadException … statusCode: 0`

## Apply CORS

Bucket for project `crickflow-b06bc` is typically:

`gs://crickflow-b06bc.firebasestorage.app`

(or legacy `gs://crickflow-b06bc.appspot.com` — check Firebase Console → Storage)

`config/storage-cors.json` allows `GET`/`HEAD` from any origin (`*`) so localhost and Hosting domains work with Flutter web CanvasKit.

```powershell
# Requires Google Cloud SDK (gsutil) authenticated to the project
gsutil cors set config\storage-cors.json gs://crickflow-b06bc.firebasestorage.app
gsutil cors get gs://crickflow-b06bc.firebasestorage.app
```

If the first bucket name fails, try:

```powershell
gsutil cors set config\storage-cors.json gs://crickflow-b06bc.appspot.com
```

## App-side mitigation

`CfNetworkImage` / `CfAvatar` use `WebHtmlElementStrategy.prefer` on web so `<img>` can display download URLs even when CORS byte fetch fails, and `errorBuilder` avoids red-screen noise.

CORS should still be set for production reliability (and any code that needs image bytes).
