-- FIX: Infinite recursion in user_profiles RLS policies
-- Run this in Supabase SQL Editor

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
