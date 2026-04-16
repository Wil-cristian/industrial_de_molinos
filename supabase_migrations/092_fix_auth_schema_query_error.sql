-- ============================================================
-- 092: Fix auth "Database error querying schema" on login
-- ============================================================
-- Root cause:
-- Recursive RLS policies on user_profiles query user_profiles again,
-- which can break auth/schema introspection paths.
--
-- This migration makes admin checks non-recursive through a
-- SECURITY DEFINER helper and rebuilds policies safely.
-- ============================================================

-- 1) Helper function used by policies (bypasses RLS safely)
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_profiles
    WHERE user_id = auth.uid()
      AND role = 'admin'
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin_user() TO authenticated;

-- 2) Drop potentially recursive policies
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Admins can manage profiles" ON public.user_profiles;

-- 3) Recreate non-recursive policies
CREATE POLICY "Admins can view all profiles"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (public.is_admin_user());

CREATE POLICY "Admins can manage profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (public.is_admin_user())
WITH CHECK (public.is_admin_user());

-- 4) Ensure users can still read their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.user_profiles;
CREATE POLICY "Users can view own profile"
ON public.user_profiles
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- 5) Force PostgREST schema cache refresh
NOTIFY pgrst, 'reload schema';
