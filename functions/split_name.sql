CREATE OR REPLACE FUNCTION split_name(IN fullname TEXT, OUT name_parts TEXT[]) AS
$$
BEGIN

-- SPLITS A FULL NAME IN ONE STRING INTO THE FIRST NAME AND THE REMAINDER OF THE NAME AS A TWO PART ARRAY

name_parts[1] := initcap(split_part(fullname, ' ', 1)); -- name_first 

name_parts[2] := initcap(right(fullname, -(1+length(split_part(fullname, ' ', 1))))); -- name_last(s)

END;
$$
LANGUAGE plpgsql
;

select 
	(split_name('alex Theodore'))[1]
,	(split_name('alex Theodore'))[2]
,	split_name('alex Theodore')
,	split_name('Mildred S. Dresselhaus')
;