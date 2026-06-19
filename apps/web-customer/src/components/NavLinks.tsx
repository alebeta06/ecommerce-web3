"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

// 🇪🇸 NOTA: navegación del header. usePathname() (cliente) marca el link activo. "/" es exacto
// (catálogo); /cart y /orders activan por prefijo. /cart y /orders existen pero son placeholders.
const LINKS = [
  { href: "/", label: "Products" },
  { href: "/cart", label: "Cart" },
  { href: "/orders", label: "Orders" },
];

export function NavLinks() {
  const pathname = usePathname();

  return (
    <nav className="flex items-center gap-6">
      {LINKS.map((link) => {
        const isActive =
          link.href === "/" ? pathname === "/" : pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            className={`text-sm font-medium ${
              isActive ? "text-accent" : "text-muted hover:text-fg"
            }`}
          >
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
