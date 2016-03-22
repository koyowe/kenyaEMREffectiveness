-- =============================================================================================================================================================
--
--	 	||| 					Please let us add paired indicators 								|||
-- 
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.1  % of patient in care with 2 or more visits, 3 months apart during the 6 months Review period |||
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------





-- =============================================================================================================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.2  % of HIV infected patients in care with at least one CD4 count during the 6 months Review period |||
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------





-- =============================================================================================================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.3  % eligible patients initiated on ART |||
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------





-- =============================================================================================================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.4  % of patients on ART with at least one VL results during the last 12 months |||
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------





-- =============================================================================================================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.5  % of patients on ART for at least 6 months with VL suppression |||
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------





-- =============================================================================================================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.6  % of patients screened for TB using ICF card at last clinic visit |||
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------

select '1.6' as Indicator, d.yearMonth as Period, n.monthlyCount as Numerator, d.monthlyCount as Denominator
from
(
select
	date_add(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval -6 MONTH) as startDate,
	LAST_DAY(e.encounter_datetime) as endDate,
	date_format(e.encounter_datetime, '%Y-%M') as yearMonth,
	(
select count(distinct patient) from (
select
x.patient,
x.encDate,
x.encounter_id,
x.encounter_type,
x.dob,
max(x.dateEnrolledInHiv) as dateEnrolledInHiv,
x.dateEnrolledInTB,
x.date_died,
x.to_date
from (
select distinct
e.patient_id as patient,
date(e.encounter_datetime) as encDate,
e.encounter_type,
e.encounter_id,
p.birthdate as dob,
hiv.dateEnrolledInCare as dateEnrolledInHiv,
tb.dateEnrolledInTB as dateEnrolledInTB,
a_s.date_died as date_died,
a_s.to_date as to_date
from encounter e
inner join (
select 
	e.patient_id, 
	date(min(e.encounter_datetime)) as dateEnrolledInCare
from encounter e 
where e.encounter_type=3 and e.voided=0 group by e.patient_id
) hiv on e.patient_id = hiv.patient_id
left outer join (
select 
	o.person_id,
	min(date(o.value_datetime)) as dateEnrolledInTB
from obs o
where o.concept_id = 1113 and o.voided=0
group by 1
) tb on tb.person_id=e.patient_id
left outer join (
-- subquery to transfer out and death status
select 
o.person_id,
ifnull(max(if(o.concept_id=1543, o.value_datetime,null)), '') as date_died,
ifnull(max(if(o.concept_id=160649, o.value_datetime,null)), '') as to_date,
ifnull(max(if(o.concept_id=161555, o.value_coded,null)), '') as dis_reason
from obs o
where o.concept_id in (1543, 161555, 160649) and o.voided = 0 -- concepts for date_died, date_transferred out and discontinuation reason
group by person_id
) a_s on a_s.person_id =e.patient_id
inner join person p on e.patient_id=p.person_id and p.voided=0
where e.encounter_type in(3,7) and e.voided=0
group by e.patient_id, e.encounter_id ) x
group by x.patient,x.encounter_id
) m 
where m.encDate between startDate and endDate 
	and m.dateEnrolledInHiv <= endDate 
	and (m.dateEnrolledInTB is null or m.dateEnrolledInTB <= endDate)
	and (datediff(endDate, dob) / 365.25)>=15 
	and (m.date_died is null or m.date_died='' or m.date_died > endDate)
and (m.to_date is null or m.to_date='' or m.to_date > endDate) -- date_died must be after reporting period
) as monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)

) d
inner join (
select
	date_add(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval -6 MONTH) as startDate,
	LAST_DAY(e.encounter_datetime) as endDate,
	date_format(e.encounter_datetime, '%Y-%M') as yearMonth,
	(
select count(*) from (
select 
x.patient,
x.dob,
max(concat(x.eDate,x.status_checked,x.suspected_concept_filled, x.diagnosis_done, x.no_signs_present)) as lastEnc,
left(max(concat(x.eDate,x.status_checked,x.suspected_concept_filled, x.diagnosis_done, x.no_signs_present)),10) as lastEncDate,
substring(max(concat(x.eDate,x.status_checked,x.suspected_concept_filled, x.diagnosis_done, x.no_signs_present)),11,1) as status_checked,
substring(max(concat(x.eDate,x.status_checked,x.suspected_concept_filled, x.diagnosis_done, x.no_signs_present)),12,1) as suspected_concept_filled,
substring(max(concat(x.eDate,x.status_checked,x.suspected_concept_filled, x.diagnosis_done, x.no_signs_present)),13,1) as diagnosis_done,
substring(max(concat(x.eDate,x.status_checked,x.suspected_concept_filled, x.diagnosis_done, x.no_signs_present)),14,1) as no_signs_present
from 
(
select
	e.patient_id as patient,
	p.birthdate as dob,
	date(e.encounter_datetime) as eDate,
	max(if(o.concept_id=1659 and o.value_coded is not null,1, 0)) as status_checked,
	max(if(o.concept_id=142177 and o.value_boolean is not null,1, 0)) as suspected_concept_filled,
	max(if(o.concept_id=1661 and o.value_boolean is not null,1, 0)) as diagnosis_done,
	max(if(o.concept_id=1660 and o.value_boolean is not null,1, 0)) as no_signs_present
from encounter e
inner join person p on e.patient_id=p.person_id and p.voided=0
left outer join obs o on e.encounter_id = o.encounter_id and o.concept_id in (1659, 142177, 1661, 1660) and o.voided=0
where e.encounter_type =11 -- and e.patient_id=12
group by e.patient_id, e.encounter_id  
order by e.patient_id, e.encounter_datetime) x
group by x.patient
) n
where n.lastEncDate between startDate and endDate and (datediff(endDate, dob) / 365.25)>=15 and (status_checked=1 or suspected_concept_filled=1 or diagnosis_done=1 or no_signs_present=1)
) as monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)

) n on n.yearMonth = d.yearMonth
order by 1
;




-- =============================================================================================================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.8  % of patients with Nutritional assessment at the last clinic visit |||
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------

select '1.8' as Indicator, d.yearMonth as Period, nm.monthlyCount as Numerator, d.monthlyCount as Denominator
from
(
select
	date_add(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval -6 MONTH) as startDate,
	LAST_DAY(e.encounter_datetime) as endDate,
	date_format(e.encounter_datetime, '%Y-%M') as yearMonth,
	(
select count(*) from (
select 
x.patient,
x.dob,
max(concat(x.eDate,x.weight,x.height)) as lastEnc,
left(max(concat(x.eDate,x.weight,x.height)),10) as lastEncDate,
substring(max(concat(x.eDate,x.weight,x.height)),11,1) as lastWeight,
substring(max(concat(x.eDate,x.weight,x.height)),12,1) as lastHeight
from 
(
select
	e.patient_id as patient,
	p.birthdate as dob,
	date(e.encounter_datetime) as eDate,
	max(if(o.concept_id=5089 and o.value_numeric is not null,1, 0)) as weight,
	max(if(o.concept_id=5090 and o.value_numeric is not null,1, 0)) as height
	-- max(if(o.concept_id=1343 and o.value_numeric is not null,1, 0)) as muac
from encounter e
inner join person p on e.patient_id=p.person_id and p.voided=0
left outer join obs o on e.encounter_id = o.encounter_id and o.concept_id in (5089, 5090) and o.voided=0
where e.encounter_type in (7) -- and e.patient_id=12
group by e.patient_id, e.encounter_id  
order by e.patient_id, e.encounter_datetime) x
-- where x.eDate between startDate and endDate -- x.weight =0 and x.height =0 -- and x.eDate <= '2011-05-17';
group by x.patient
) n
where n.lastEncDate  between startDate and endDate and (datediff(endDate, dob) / 365.25)>=15
) as monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
) d
inner join (
select
	date_add(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval -6 MONTH) as startDate,
	LAST_DAY(e.encounter_datetime) as endDate,
	date_format(e.encounter_datetime, '%Y-%M') as yearMonth,
	(
select count(*) from (
select 
x.patient,
x.dob,
max(concat(x.eDate,x.weight,x.height)) as lastEnc,
left(max(concat(x.eDate,x.weight,x.height)),10) as lastEncDate,
substring(max(concat(x.eDate,x.weight,x.height)),11,1) as lastWeight,
substring(max(concat(x.eDate,x.weight,x.height)),12,1) as lastHeight
from 
(
select
	e.patient_id as patient,
	p.birthdate as dob,
	date(e.encounter_datetime) as eDate,
	max(if(o.concept_id=5089 and o.value_numeric is not null,1, 0)) as weight,
	max(if(o.concept_id=5090 and o.value_numeric is not null,1, 0)) as height
from encounter e
inner join person p on e.patient_id=p.person_id and p.voided=0
left outer join obs o on e.encounter_id = o.encounter_id and o.concept_id in (5089, 5090) and o.voided=0
where e.encounter_type in (7) 
group by e.patient_id, e.encounter_id  
order by e.patient_id, e.encounter_datetime) x
group by x.patient
) n
where n.lastEncDate  between startDate and endDate and lastWeight=1 and lastHeight=1 and (datediff(endDate, dob) / 365.25)>=15
) as monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)

) nm on nm.yearMonth = d.yearMonth
order by 1
;



-- =============================================================================================================================================================

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.12  % non-pregnant women patients who are on modern contraceptive methods During the review period |||
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------





-- =============================================================================================================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
