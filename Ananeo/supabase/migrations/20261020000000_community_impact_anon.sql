-- The Welcome screen shows everyone's totals before sign-in, so the community aggregate is readable
-- signed out. It returns two numbers and no row data, which is why this one function is safe for anon.
-- Personal impact and everything else stay behind sign-in.

grant execute on function public.community_impact() to anon;
