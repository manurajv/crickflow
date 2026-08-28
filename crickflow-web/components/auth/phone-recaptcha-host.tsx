"use client";

/** Invisible reCAPTCHA mount point — must exist before Send OTP. */
export function PhoneRecaptchaHost({ id }: { id: string }) {
  return <div id={id} className="min-h-px" aria-hidden="true" />;
}
