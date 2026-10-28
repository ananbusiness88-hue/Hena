-- Allow authenticated users to create their own profile.
-- The profile id must always match auth.uid().

create policy "Users can create own profile"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);
