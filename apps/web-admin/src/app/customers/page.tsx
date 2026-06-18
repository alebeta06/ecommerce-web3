"use client";

import { useCustomers } from "@/hooks/useCustomers";
import { CustomerList } from "@/components/CustomerList";

export default function CustomersPage() {
  const { customers, isLoading, error } = useCustomers();

  return (
    <main className="mx-auto max-w-3xl p-8">
      <h1 className="text-2xl font-bold">Customers</h1>
      {/* 🇪🇸 Solo lectura: el alta/rename de clientes es acción del propio cliente (msg.sender) y
          vivirá en web-customer. Aquí el admin solo observa: lista + facturas de cada cliente. */}
      <div className="mt-8">
        <CustomerList customers={customers} isLoading={isLoading} error={error} />
      </div>
    </main>
  );
}
