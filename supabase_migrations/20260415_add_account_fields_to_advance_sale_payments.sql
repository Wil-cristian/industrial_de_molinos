alter table public.advance_sale_payments
  add column if not exists account_id uuid references public.accounts(id),
  add column if not exists account_name text;

create index if not exists idx_advance_sale_payments_account_id
  on public.advance_sale_payments(account_id);

update public.advance_sale_payments
set account_name = coalesce(
  account_name,
  case
    when method = 'cash' then 'Caja'
    else 'Cuenta no especificada'
  end
)
where account_name is null;
