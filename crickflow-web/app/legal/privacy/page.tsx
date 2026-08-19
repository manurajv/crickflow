export default function PrivacyPage() {
  return (
    <article className="prose prose-invert max-w-3xl">
      <h1 className="text-3xl font-bold">Privacy</h1>
      <p className="mt-4 text-muted-foreground">
        CrickFlow Web uses the same Firebase project as the mobile app. See the published privacy policy at{" "}
        <a className="text-primary" href="https://crickflow.app/privacy">
          crickflow.app/privacy
        </a>
        .
      </p>
    </article>
  );
}
