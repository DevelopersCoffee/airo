-- Community pass codes for Aika Stream (RevenueCat promotional entitlements).
-- Copy this migration into the private license Supabase project — not a public Play client.
-- service_role bypasses RLS; anon/authenticated have no policies.

CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code_hash VARCHAR(64) NOT NULL UNIQUE,
    duration VARCHAR(20) NOT NULL CHECK (duration IN ('monthly', 'yearly', 'lifetime')),
    is_redeemed BOOLEAN DEFAULT FALSE NOT NULL,
    redeemed_by_user_id TEXT,
    redeemed_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_coupons_lookup
    ON public.coupons (code_hash)
    WHERE is_redeemed = FALSE;

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- Atomic claim: unused + unexpired. Avoids PostgREST timestamp .or() filters.
CREATE OR REPLACE FUNCTION public.claim_coupon(
    p_code_hash TEXT,
    p_app_user_id TEXT
)
RETURNS TABLE (
    id UUID,
    duration VARCHAR(20)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    UPDATE public.coupons AS c
    SET
        is_redeemed = TRUE,
        redeemed_by_user_id = p_app_user_id,
        redeemed_at = now()
    WHERE c.code_hash = p_code_hash
      AND c.is_redeemed = FALSE
      AND (c.expires_at IS NULL OR c.expires_at > now())
    RETURNING c.id, c.duration;
END;
$$;

CREATE OR REPLACE FUNCTION public.unclaim_coupon(p_coupon_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.coupons
    SET
        is_redeemed = FALSE,
        redeemed_by_user_id = NULL,
        redeemed_at = NULL
    WHERE id = p_coupon_id
      AND is_redeemed = TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_coupon(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.claim_coupon(TEXT, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_coupon(TEXT, TEXT) TO service_role;

REVOKE ALL ON FUNCTION public.unclaim_coupon(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.unclaim_coupon(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.unclaim_coupon(UUID) TO service_role;
