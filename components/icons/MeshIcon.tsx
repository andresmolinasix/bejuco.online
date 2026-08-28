export function MeshIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.4}
      strokeLinecap="round"
      className={className}
      aria-hidden="true"
    >
      <path d="M6 18 12 7l6 11" />
      <path d="M6 18h12" />
      <circle cx="12" cy="7" r="1.4" fill="currentColor" stroke="none" />
      <circle cx="6" cy="18" r="1.4" fill="currentColor" stroke="none" />
      <circle cx="18" cy="18" r="1.4" fill="currentColor" stroke="none" />
    </svg>
  );
}
