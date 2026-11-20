const MAVIXAS_HOME_URL = "https://mavixas.com";

export function PoweredByMavixas({ className }: { className?: string }) {
  return (
    <p className={className}>
      Powered by{" "}
      <a
        href={MAVIXAS_HOME_URL}
        target="_blank"
        rel="noreferrer"
        className="underline underline-offset-2 hover:text-white"
      >
        Mavixas
      </a>{" "}
      <span aria-hidden="true">🇱🇰</span>
      <span className="sr-only">Sri Lanka</span>
    </p>
  );
}
