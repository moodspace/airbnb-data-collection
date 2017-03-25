CREATE OR REPLACE VIEW city_survey AS
SELECT sa.name AS city,
       max(s.survey_id) AS newer,
       min(s.survey_id) AS older
FROM survey AS s
JOIN search_area AS sa ON s.search_area_id = sa.search_area_id
GROUP BY city
HAVING count(*) > 1 ;


CREATE OR REPLACE FUNCTION survey_room (IN integer) RETURNS TABLE (room_id integer, host_id integer, room_type varchar(255),
                                                                                                               country varchar(255),
                                                                                                                       city varchar(255),
                                                                                                                            neighborhood varchar(255),
                                                                                                                                         address varchar(1023),
                                                                                                                                                 reviews integer, overall_satisfaction double precision, accommodates integer, bedrooms decimal(5,2),
                                                                                                                                                                                                                                        bathrooms decimal(5,2),
                                                                                                                                                                                                                                                  price double precision, deleted integer, minstay integer, last_modified TIMESTAMP,
                                                                                                                                                                                                                                                                                                                          latitude numeric(30,6),
                                                                                                                                                                                                                                                                                                                                   longitude numeric(30,6),
                                                                                                                                                                                                                                                                                                                                             survey_id integer) AS $BODY$
  select room_id, host_id, room_type,
    country, city, neighborhood, address, reviews,
    overall_satisfaction, accommodates, bedrooms,
    bathrooms, price, deleted, minstay, last_modified,
    latitude, longitude, survey_id
    from room as r
    where r.survey_id = $1
    and price is not null
    and deleted = 0;
$BODY$ LANGUAGE SQL ;


DROP FUNCTION IF EXISTS survey_host(int);


CREATE FUNCTION survey_host(IN integer) RETURNS TABLE ( host_id int, rooms bigint, multilister smallint, review_count bigint, addresses bigint, rating numeric(4,2),
                                                                                                                                                       income1 double precision, income2 double precision) AS $BODY$
  select
    host_id,
    count(*) as rooms,
    cast((case when count(*) > 1 then 1 else 0 end) as smallint) as multilister,
    sum(reviews) as review_count,
    count(distinct address) as addresses,
    cast(sum(overall_satisfaction*reviews)/sum(reviews) as numeric(4,2)) as rating,
    sum(reviews*price) as income1,
    sum(reviews*price*minstay) as income2
    from survey_room($1)
    where reviews > 0 and minstay is not null
    group by host_id;
$BODY$ LANGUAGE SQL ;


CREATE OR REPLACE FUNCTION add_survey(IN varchar(255)) RETURNS VOID AS $BODY$
  insert into survey( survey_description, search_area_id )
    select(name || ' (' || current_date || ')') as survey_description,
      search_area_id
      from search_area
      where name = $1;
$BODY$ LANGUAGE SQL ;


CREATE OR REPLACE FUNCTION new_room(IN old_survey_id integer, IN new_survey_id integer) RETURNS TABLE ("room_id" integer) AS $BODY$
  select "room_id"
    from
  (select "room_id" from "survey_room"(new_survey_id)
  except
  select "room_id" from "survey_room"(old_survey_id))
  as "t"
$BODY$ LANGUAGE SQL
