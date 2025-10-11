create view datalink.curl_response_codes as 
with 
e as (
    select atom.html_tidy(substr(
      dlvalue('https://curl.se/libcurl/c/libcurl-errors.html')))::xml
    as entry
),
f as (
select 
  unnest(xpath('//span[@class=''nroffip'']/text()',entry))::text as error
 from e
),
g as (
select row_number() over() as n,
       regexp_matches(error,'([A-Z0-9_]+)\s+\((\d+)\)') as m
  from f
)
select m[2]::int as rc, m[1] as label
  from g
 where n<99;
