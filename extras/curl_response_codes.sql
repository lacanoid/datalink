CREATE OR REPLACE FUNCTION datalink.html_tidy_text(text)
 RETURNS text
 LANGUAGE plperlu
 STRICT
AS $function$
use HTML::Tidy;

my $tidy = HTML::Tidy->new( {
 doctype=>'omit', output_xhtml=>1,
 clean=>1, bare=>1, indent=>1,
 'drop-empty-paras'=>1, 'drop-proprietary-attributes'=>1,
 'punctuation-wrap'=>1, 'show-body-only'=>1, 'hide-comments'=>1,
});
$tidy->ignore( type => TIDY_WARNING );
my $xml = $tidy->clean($_[0]);

# for my $message ( $tidy->messages ) { elog(NOTICE,$message->as_string); }

return $xml;

$function$
;

CREATE OR REPLACE FUNCTION datalink.html_tidy(text)
 RETURNS xml
 LANGUAGE sql
 STRICT
AS $function$
 select xmlparse(content datalink.html_tidy_text($1))
$function$
;

CREATE OR REPLACE FUNCTION datalink.html_tidy(datalink)
 RETURNS xml
 LANGUAGE sql
 STRICT
AS $function$
 select xmlparse(content datalink.html_tidy_text(substr($1)))
$function$
;

create view datalink.curl_response_codes as 
with 
e as (
    select datalink.html_tidy(substr(
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
