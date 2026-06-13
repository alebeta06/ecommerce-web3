"use client";

import { useCompanies } from "@/hooks/useCompanies";
import { CompanyForm } from "@/components/CompanyForm";
import { CompanyList } from "@/components/CompanyList";

export default function CompaniesPage() {
  const { companies, isLoading, error, refetch } = useCompanies();

  return (
    <main className="mx-auto max-w-3xl p-8">
      <h1 className="text-2xl font-bold">Companies</h1>
      <div className="mt-6">
        <CompanyForm onRegistered={refetch} />
      </div>
      <div className="mt-8">
        <CompanyList companies={companies} isLoading={isLoading} error={error} />
      </div>
    </main>
  );
}
