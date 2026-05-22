-- Rename lower-body length measurements from inseam to outseam for Fit Engine v1.2.
-- Existing inseam 데이터를 outseam으로 마이그레이션할지 여부는 실제 운영 데이터 존재 여부에 따라 결정.

alter table public.body_measurements
  rename column inseam to outseam;

alter table public.clothing_sizes
  rename column inseam to outseam;

alter table public.external_product_sizes
  rename column inseam to outseam;
