-- Speed up society-scoped finance reads as payment/ledger volume grows.
create index if not exists idx_maintenance_charges_society_id
  on public.maintenance_charges using btree (society_id);

create index if not exists idx_maintenance_payments_charge_id
  on public.maintenance_payments using btree (charge_id);

create index if not exists idx_maintenance_payments_charge_status
  on public.maintenance_payments using btree (charge_id, payment_status);

create index if not exists idx_expenses_group_id
  on public.expenses using btree (group_id);

create index if not exists idx_expenses_group_status_category
  on public.expenses using btree (group_id, record_status, expense_category);

create index if not exists idx_expense_splits_expense_id
  on public.expense_splits using btree (expense_id);

create index if not exists idx_members_flat_id_primary
  on public.members using btree (flat_id)
  where (is_primary = true);

create index if not exists idx_resident_users_flat_id
  on public.resident_users using btree (flat_id);

create index if not exists idx_expense_groups_society_kind
  on public.expense_groups using btree (society_id, group_kind);
