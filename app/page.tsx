import { AndroidIcon } from "@/components/icons/AndroidIcon";
import { AppleIcon } from "@/components/icons/AppleIcon";
import { MeshIcon } from "@/components/icons/MeshIcon";
import { DownloadButton } from "@/components/DownloadButton";
import { PhoneMockup } from "@/components/PhoneMockup";
import { downloads } from "@/lib/downloads";

export default function Home() {
  const android = downloads.find((d) => d.id === "android")!;
  const ios = downloads.find((d) => d.id === "ios")!;

  return (
    <main className="flex min-h-screen items-center bg-white text-ink">
      <div className="mx-auto w-full max-w-5xl px-5 py-5 sm:px-8 sm:py-10 lg:px-12 lg:py-0">
        <div className="grid grid-cols-1 items-center gap-4 sm:gap-10 lg:grid-cols-2 lg:gap-16">
          {/* left column */}
          <div className="flex flex-col items-start">
            <div className="mb-3 flex items-center gap-2 sm:mb-8">
              <span className="flex h-7 w-7 items-center justify-center rounded-md border border-line">
                <MeshIcon className="h-3.5 w-3.5 text-accent" />
              </span>
              <span className="text-[15px] font-medium tracking-tight">
                Bejuco
              </span>
            </div>

            <h1 className="max-w-md text-[36px] font-medium leading-[1.2] tracking-tight text-ink lg:text-[44px] lg:leading-[1.15]">
              Comunicación cuando la red cae.
            </h1>

            <p className="mt-4 max-w-sm text-[15px] leading-relaxed text-muted">
              Detecta sismos con datos del USGS y transmite tu ubicación por
              malla Bluetooth cuando no hay señal ni internet.
            </p>

            <div className="mt-4 flex w-full max-w-[280px] flex-col gap-3 sm:mt-8">
              <DownloadButton platform={android} icon={<AndroidIcon className="h-5 w-5" />} />
              <DownloadButton platform={ios} icon={<AppleIcon className="h-5 w-5" />} />
            </div>

            <p className="mt-3 text-[12px] text-muted sm:mt-6">
              v1.0 · Android 10+ · iOS 17+
            </p>
          </div>

          {/* right column */}
          <div className="flex justify-center lg:justify-end">
            <PhoneMockup />
          </div>
        </div>
      </div>
    </main>
  );
}
