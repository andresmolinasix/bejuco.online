export function AndroidIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
    >
      <path d="M8 6.2 6.6 3.7" />
      <path d="M16 6.2l1.4-2.5" />
      <path d="M5 12a7 7 0 0 1 14 0" fill="none" />
      <rect x="5" y="11" width="14" height="8.2" rx="2" />
      <circle cx="9" cy="14.3" r="0.55" fill="currentColor" stroke="none" />
      <circle cx="15" cy="14.3" r="0.55" fill="currentColor" stroke="none" />
      <path d="M5 12.5H3" />
      <path d="M19 12.5h2" />
      <path d="M8 19.2v1.8" />
      <path d="M16 19.2v1.8" />
    </svg>
  );
}
