"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// 🇪🇸 NOTA: navegación lateral. usePathname() (solo cliente) nos dice la ruta actual para resaltar
// el item activo. /products e /invoices aún no existen: van como placeholders deshabilitados.
const ENABLED_LINKS = [
  // 🇪🇸 `match` resalta el item también en rutas hijas (p.ej. /company/[id] activa "Companies").
  { href: "/companies", label: "Companies", match: ["/companies", "/company"] },
];

const DISABLED_LINKS = [
  { label: "Products" },
  { label: "Invoices" },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-56 shrink-0 border-r border-gray-200 p-4">
      <nav className="flex flex-col gap-1">
        {ENABLED_LINKS.map((link) => {
          const isActive = link.match.some(
            (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
          );
          return (
            <Link
              key={link.href}
              href={link.href}
              className={`rounded-md px-3 py-2 text-sm font-medium ${
                isActive
                  ? "bg-blue-50 text-blue-700"
                  : "text-gray-700 hover:bg-gray-50"
              }`}
            >
              {link.label}
            </Link>
          );
        })}

        {DISABLED_LINKS.map((link) => (
          <span
            key={link.label}
            aria-disabled="true"
            className="cursor-not-allowed rounded-md px-3 py-2 text-sm font-medium text-gray-400"
          >
            {link.label} <span className="text-xs">(soon)</span>
          </span>
        ))}
      </nav>
    </aside>
  );
}
