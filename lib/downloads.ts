export type DownloadPlatform = {
  id: "android" | "ios";
  label: string;
  sublabel: string;
  href: string;
  available: boolean;
};

// TODO: reemplazar con los enlaces reales antes de publicar.
export const downloads: DownloadPlatform[] = [
  {
    id: "android",
    label: "Android",
    sublabel: "Download APK",
    href: "#",
    available: true,
  },
  {
    id: "ios",
    label: "iOS",
    sublabel: "App Store",
    href: "#",
    available: false,
  },
];
