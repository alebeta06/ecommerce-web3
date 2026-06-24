import { loadStripe } from "@stripe/stripe-js";
import { env } from "@/lib/env";

// 🇪🇸 NOTA: loadStripe carga el script de Stripe.js y devuelve una Promise del SDK. La resolvemos a
// nivel de módulo (singleton) para no recargar Stripe en cada render del <Elements> provider.
export const stripePromise = loadStripe(env.stripePublishableKey);
