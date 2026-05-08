create index idx_body_measurements_user_id on public.body_measurements(user_id);
create index idx_clothing_items_user_category on public.clothing_items(user_id, category);
create index idx_clothing_sizes_item_id on public.clothing_sizes(clothing_item_id);
create index idx_reference_clothing_user_active on public.reference_clothing(user_id, is_active);
create index idx_reference_clothing_user_category on public.reference_clothing(user_id, category);
create index idx_external_products_user_category on public.external_products(user_id, category);
create index idx_external_product_sizes_product_id on public.external_product_sizes(external_product_id);
create index idx_fit_results_user_created_at on public.fit_analysis_results(user_id, created_at desc);
create index idx_feedback_user_id on public.user_feedback(user_id);
create index idx_recommendation_logs_user_created_at on public.recommendation_logs(user_id, created_at desc);

