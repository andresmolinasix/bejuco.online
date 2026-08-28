import type { ReactNode } from "react";
import type { DownloadPlatform } from "@/lib/downloads";

const BASE =
  "group flex w-full items-center gap-3 rounded-lg border px-4 py-3 transition-colors";

export function DownloadButton({
  platform,
  icon,
}: {
  platform: DownloadPlatform;
  icon: ReactNode;
}) {
  const variant =
    platform.id === "android"
      ? "border-ink bg-ink text-white hover:bg-[#1c1c1c]"
      : "border-line bg-white text-ink hover:border-[#c9c9c9]";

  const content = (
    <>
      <span className="shrink-0">{icon}</span>
      <span className="flex flex-1 flex-col items-start leading-tight">
        <span className="text-[15px] font-medium">{platform.label}</span>
        <span
          className={
            platform.id === "android"
              ? "text-[12px] text-white/60"
              : "text-[12px] text-muted"
          }
        >
          {platform.available ? platform.sublabel : "Coming soon"}
        </span>
      </span>
    </>
  );

  if (!platform.available) {
    return (
      <span
        aria-disabled="true"
        className={`${BASE} ${variant} cursor-not-allowed opacity-40`}
      >
        {content}
      </span>
    );
  }

  return (
    <a
      href={platform.href}
      className={`${BASE} ${variant} focus-visible:outline-offset-2`}
      rel="noopener noreferrer"
    >
      {content}
    </a>
  );
}
