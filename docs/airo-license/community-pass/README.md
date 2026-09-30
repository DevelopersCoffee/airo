# Community pass (function-first)

Copy `supabase/` into the **private license** Supabase project (`airo-pro` / license backend). Do not wire this into public Play OSS.

Unknown users pay through the RevenueCat paywall (monthly / yearly / lifetime, store-localized prices). Friends and family redeem a hashed access pass. Play promo campaigns are not the coupon system.

## Deploy

1. Apply `supabase/migrations/20260930_coupons.sql`.
2. `supabase secrets set REV_CAT_SECRET=…` (RevenueCat **secret** API key, never the public SDK key).
3. `supabase functions deploy redeem-coupon`
4. Dashboard: rate-limit this function. `verify_jwt` is already `false` for accountless clients.
5. Generate codes **offline**:

   `python3 scripts/generate_coupons.py --out-dir ./out`

   Apply `out/insert_coupons.sql`. Keep `out/distribution_list.txt` off git and off devices you do not trust.

## Smoke test

```bash
curl -sS -X POST "$FUNCTIONS_URL/redeem-coupon" \
  -H 'Content-Type: application/json' \
  -d '{"code":"AIKA-…","app_user_id":"<Purchases.appUserID>"}'
```

Expect `200` then the subscriber shows promotional `aika_stream_premium`. A second redeem of the same code must be `403`.

## Client (overlay)

`COUPON_REDEEM_URL` is a dart-define on the Pro TV/phone build (see overlay `scripts/build-tv.sh`). Settings shows **Redeem access pass** only when that URL is set. The Flutter client posts `{code, app_user_id}` and then calls `Purchases.invalidateCustomerInfoCache()`. No secret, no coupon list, no “skip the store” copy.

The grant is bound to the anonymous RevenueCat user. Uninstall wipes it; issue a replacement pass.
