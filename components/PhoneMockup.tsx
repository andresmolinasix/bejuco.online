import { MeshIcon } from "@/components/icons/MeshIcon";

function PacketRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between">
      <span className="text-[10px] text-muted">{label}</span>
      <span className="text-[12px] font-medium tabular-nums text-ink">
        {value}
      </span>
    </div>
  );
}

export function PhoneMockup() {
  return (
    <div className="relative mx-auto w-[228px] sm:w-[244px] lg:w-[260px]">
      <div className="rounded-[34px] border border-line bg-white p-2 shadow-[0_1px_2px_rgba(0,0,0,0.04)]">
        <div className="flex h-[368px] flex-col overflow-hidden rounded-[26px] border border-line sm:h-[396px] lg:h-[428px]">
          {/* status bar */}
          <div className="flex items-center justify-between px-4 pb-2 pt-3 text-[11px] font-medium text-muted">
            <span>9:41</span>
            <span className="flex items-center gap-1 text-accent">
              <MeshIcon className="h-3 w-3" />
              Malla · 3 nodos
            </span>
          </div>

          <div className="border-t border-line" />

          {/* distress packet header */}
          <div className="flex items-center justify-between border-b border-line px-4 py-3">
            <div className="flex items-center gap-2">
              <span className="h-1.5 w-1.5 rounded-full bg-accent" />
              <div className="leading-tight">
                <p className="text-[13px] font-medium text-ink">
                  Necesito ayuda
                </p>
                <p className="text-[10px] text-muted">DISTRESS · 2 min</p>
              </div>
            </div>
            <span className="rounded-full border border-line px-2 py-1 text-[10px] text-muted">
              uploading
            </span>
          </div>

          {/* emitted distress packet */}
          <div className="flex min-h-0 flex-1 flex-col justify-center gap-3 bg-[#FAFAFA] px-4 py-4">
            <p className="text-[10px] uppercase tracking-wide text-muted">
              Resumen
            </p>
            <div className="flex flex-col gap-2 rounded-md border border-line bg-white p-3">
              <PacketRow label="Saltos" value="0 / 20" />
              <PacketRow label="Firma" value="Válida" />
              <PacketRow label="Latitud" value="4.6097" />
              <PacketRow label="Longitud" value="-74.0817" />
              <PacketRow label="Nombre" value="Camila Torres" />
              <PacketRow label="Teléfono" value="+57 300 ••• 45" />
            </div>
          </div>

          {/* relay route */}
          <div className="flex items-center gap-2 border-t border-line bg-white px-4 py-2.5">
            <svg
              viewBox="0 0 40 10"
              className="h-2.5 w-10 text-line"
              aria-hidden="true"
            >
              <path
                d="M2 8 L20 2 L38 8"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.2"
              />
              <circle cx="2" cy="8" r="1.6" className="fill-ink" />
              <circle cx="20" cy="2" r="1.6" className="fill-accent" />
              <circle cx="38" cy="8" r="1.6" className="fill-ink" />
            </svg>
            <p className="text-[10px] text-muted">
              Tú → Nodo 214 → Estación con señal
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
