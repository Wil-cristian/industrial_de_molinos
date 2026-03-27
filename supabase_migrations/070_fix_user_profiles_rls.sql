-- ============================================================
-- 070: Fix infinite recursion in user_profiles RLS policies
-- ============================================================
-- Problem: "Admins can view all profiles" and "Admins can manage profiles"
-- policies query user_profiles inside a user_profiles policy → infinite recursion.
-- Solution: Use a SECURITY DEFINER function that bypasses RLS to check admin role.

-- 1. Create helper function (bypasses RLS to check role)
CREATE OR REPLACE FUNCTION is_admin_user()
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE user_id = auth.uid() AND role = 'admin'
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 2. Drop the recursive policies
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can manage profiles" ON user_profiles;

-- 3. Recreate policies using the SECURITY DEFINER function
CREATE POLICY "Admins can view all profiles" ON user_profiles
    FOR SELECT TO authenticated
    USING (is_admin_user());

CREATE POLICY "Admins can manage profiles" ON user_profiles
    FOR ALL TO authenticated
    USING (is_admin_user())
    WITH CHECK (is_admin_user());
