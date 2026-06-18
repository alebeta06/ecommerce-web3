import { NextResponse } from "next/server";

// 🇪🇸 NOTA: PRIMERA API route del app (hasta ahora todo era client-side). Existe SOLO para
// mantener PINATA_JWT en el servidor: ese secreto NO lleva prefijo NEXT_PUBLIC_, así que nunca
// llega al bundle del navegador. El browser sube el archivo a ESTE endpoint; el endpoint lo
// reenvía a Pinata firmando con el JWT. El cliente nunca ve la credencial.

// 🇪🇸 La respuesta de Pinata v3 /v3/files tiene forma { data: { cid: "..." } }. Tipamos solo lo
// que consumimos (sin `any`); el resto de campos (id, size, mime_type…) se ignoran.
interface PinataV3Response {
  data?: { cid?: string };
}

export async function POST(req: Request): Promise<NextResponse> {
  // 🇪🇸 Validación en el boundary: sin JWT no podemos firmar contra Pinata. No se puede validar
  // "al arrancar" en un route handler (no hay fase de boot), así que lo chequeamos al entrar.
  const pinataJwt = process.env.PINATA_JWT;
  if (pinataJwt === undefined || pinataJwt.trim() === "") {
    return NextResponse.json(
      { error: "Server is missing PINATA_JWT. See apps/web-admin/.env.example." },
      { status: 500 },
    );
  }

  // 🇪🇸 El form entrante trae el campo "file". get() devuelve File | string | null; exigimos File.
  const form = await req.formData();
  const file = form.get("file");
  if (!(file instanceof File)) {
    return NextResponse.json({ error: "No file provided." }, { status: 400 });
  }

  // 🇪🇸 Reconstruimos un FormData nuevo (file + network=public) en vez de reenviar el body crudo:
  // network=public garantiza que el CID se sirva desde el gateway PÚBLICO (gateway.pinata.cloud),
  // que es lo que la app usa para mostrar la imagen. No fijamos Content-Type a mano: fetch pone
  // el boundary multipart automáticamente a partir del FormData.
  const pinataForm = new FormData();
  pinataForm.append("file", file);
  pinataForm.append("network", "public");

  let res: Response;
  try {
    res = await fetch("https://uploads.pinata.cloud/v3/files", {
      method: "POST",
      headers: { Authorization: `Bearer ${pinataJwt}` },
      body: pinataForm,
    });
  } catch {
    // 🇪🇸 Falla de red al hablar con Pinata (502 Bad Gateway: el upstream no respondió).
    return NextResponse.json({ error: "Could not reach IPFS provider." }, { status: 502 });
  }

  if (!res.ok) {
    return NextResponse.json({ error: "IPFS upload failed." }, { status: 502 });
  }

  const json = (await res.json()) as PinataV3Response;
  const cid = json.data?.cid;
  if (cid === undefined || cid === "") {
    return NextResponse.json({ error: "IPFS provider returned no CID." }, { status: 502 });
  }

  return NextResponse.json({ cid });
}
