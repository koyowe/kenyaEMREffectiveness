-- =================================================================================================================================================
-- 					||||||| completed report metadata query ||||||||||||||||
-- =================================================================================================================================================
select 
	(select value_reference from location_attribute where location_id = (select property_value from global_property where property = 'kenyaemr.defaultLocation')) as MFL_CODE,
	(select name from location where location_id = (select property_value from global_property where property = 'kenyaemr.defaultLocation')) as Facility_Name,
	date(rr.request_datetime) as date_requested,
	so.name as report_type, 
	u.username as requested_by,
	timediff(rr.evaluation_complete_datetime, rr.evaluation_start_datetime) as duration
from 
	reporting_report_request rr 
	inner join serialized_object so on rr.report_definition_uuid = so.uuid
	inner join users u on u.user_id=rr.requested_by
where rr.request_datetime between date_sub(curdate(), interval 3 DAY) AND curdate()
order by requested_by desc;



-- =================================================================================================================================================
-- 					||||||| completed query for patient initial enrollment report ||||||||
-- =================================================================================================================================================

select distinct
	(select value_reference from location_attribute where location_id = (select property_value from global_property where property = 'kenyaemr.defaultLocation')) as MFL_CODE,
	(select name from location where location_id = (select property_value from global_property where property = 'kenyaemr.defaultLocation')) as Facility_Name,
	f.name as Form_type,
	e.date_created as form_creation_time,
	e.date_changed as last_saving_time,
	u.username as creatorLogin,
	urole.roles as roles,
	date(e.encounter_datetime) as Enrollment_Date,
	if(ov.Date_first_enrolled_in_care=1,'Yes','No') as Date_first_enrolled_in_care,
	if(ov.date_started_on_art_at_transfering_facility=1,'Yes','No') as date_started_on_art_at_transfering_facility,
	if(ov.date_confirmed_Hiv_positive=1,'Yes','No') as date_confirmed_Hiv_positive
from encounter e 
	inner join users u on u.user_id=e.creator
	inner join user_role ur on ur.user_id=e.creator
	inner join encounter_type et on et.encounter_type_id = e.encounter_type
	inner join form f on e.form_id = f.form_id
	inner join (select user_id, group_concat(role) as roles from user_role group by user_id) urole on urole.user_id = e.creator
	left outer join (
	select 
	o.encounter_id,
	max(if(o.concept_id = 160555 and o.value_datetime is not null, 1, 0)) as Date_first_enrolled_in_care,
	max(if(o.concept_id = 159599 and o.value_datetime is not null, 1, 0)) as date_started_on_art_at_transfering_facility,
	max(if(o.concept_id = 160554 and o.value_datetime is not null, 1, 0)) as date_confirmed_Hiv_positive
from obs o 
where o.concept_id in (160555,159599,160554) and o.voided=0
group by o.encounter_id
) ov on ov.encounter_id = e.encounter_id
where e.encounter_type = 5 and e.voided =0 
order by e.encounter_datetime;


-- =====================================================================================================================================================
-- 		|||||| Completed query for patient encounter/visit information |||||||||||
-- =====================================================================================================================================================

-- Facility name	patient_ID 	Form_type	form_creation_time	last_saving_time	ID person doing data entry	Level person doing data entry	Start date and time	visit_date	weight_taken	height_taken	temperature_taken	cd4_result	CD4%_result	VL_result	HIV DNA PCR_result	vl_collection_date	Hemoglobin_result	hemoglobin_collection_date	drug_prescribed	drug_duration
-- weight	5089 ,Pressure	5085, Height	5090, Temperature	5088, Viral Load	856, PCR	5497 ,CD4%	730, CD4 count	5497

select distinct
	(select value_reference from location_attribute where location_id = (select property_value from global_property where property = 'kenyaemr.defaultLocation')) as MFL_CODE,
	(select name from location where location_id = (select property_value from global_property where property = 'kenyaemr.defaultLocation')) as Facility_Name,
	f.name as Form_type,
	e.patient_id,
	e.encounter_id,
	date(e.encounter_datetime) as visitDate,
	e.date_created as form_creation_time,
	u.username as creatorLogin,
	urole.roles as roles,
	if(ov.Weight=1,'Yes','No') as Weight,
	if(ov.Height=1,'Yes','No') as Height,
	if(ov.Temperature=1,'Yes','No') as Temperature,
	if(ov.CD4=1,'Yes','No') as CD4,
	if(ov.CD4_percent=1,'Yes','No') as CD4_percent,
	if(ov.ViralLoad=1,'Yes','No') as ViralLoad,
	if(ov.PCR=1,'Yes','No') as Hiv_DNA_PCR,
	if(ov.Hemoglobin=1,'Yes','No') as Hemoglobin
from encounter e 
	-- inner join obs o on o.encounter_id=e.encounter_id and o.voided=0
	inner join users u on u.user_id=e.creator
	inner join user_role ur on ur.user_id=e.creator
	inner join encounter_type et on et.encounter_type_id = e.encounter_type and et.retired =0
	inner join form f on e.form_id = f.form_id
	inner join (select user_id, group_concat(role) as roles from user_role group by user_id) urole on urole.user_id = e.creator
	left outer join (
	select 
	o.encounter_id,
	max(if(o.concept_id = 5089 and o.value_numeric is not null, 1, 0)) as Weight,
	max(if(o.concept_id = 5085 and o.value_numeric is not null, 1, 0)) as Pressure,
	max(if(o.concept_id = 5090 and o.value_numeric is not null, 1, 0)) as Height,
	max(if(o.concept_id = 5088 and o.value_numeric is not null, 1, 0)) as Temperature,
	max(if(o.concept_id = 5497 and o.value_numeric is not null, 1, 0)) as CD4,
	max(if(o.concept_id = 730 and o.value_numeric is not null, 1, 0)) as CD4_percent,
	max(if(o.concept_id = 856 and o.value_numeric is not null, 1, 0)) as ViralLoad,
	max(if(o.concept_id = 1030 and o.value_coded is not null, 1, 0)) as PCR,
	max(if(o.concept_id = 21 and o.value_numeric is not null, 1, 0)) as Hemoglobin
from obs o 
where o.concept_id in (21,1030,856,730,5497,5088,5090,5085,5089) and o.voided=0
group by o.encounter_id
) ov on ov.encounter_id = e.encounter_id
where e.voided =0 
order by encounter_datetime;


-- =====================================================================================================================================================
--  		||||||| completed query for patients with nutritional assessment in their last visit ||||||||||||||
-- =====================================================================================================================================================
-- getting encounters grouped by year and month
-- final query for patients who had nutrititional assessment in their last visits within a given period
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
where n.lastEncDate  between startDate and endDate and lastWeight=1 and lastHeight=1 and (datediff(endDate, dob) / 365.25)>=15
) as monthTotal
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)


-- ======================================================================================================================================================
-- 		||||||||| completed query for patients who had hiv visits during a given period |||||||||
-- ======================================================================================================================================================

-- getting encounters grouped by year and month
-- final query for patients who had hiv visits within a given period
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
) as monthTotal
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)


-- ======================================================================================================================================================
-- 		||||||||| Completed query for patients with at least one cd4 result/test within reporting period ||||||||
-- ======================================================================================================================================================
select
	date_add(date_add(LAST_DAY(o.obs_datetime),interval 1 DAY),interval -6 MONTH) as startDate,
	LAST_DAY(o.obs_datetime) as endDate,
	date_format(o.obs_datetime, '%Y-%M') as yearMonth,
	count( distinct o.person_id) as patients,
	(select sum(x.patients) as total from
		(select
		count( distinct o.person_id) as patients,
		month(o.obs_datetime) as cd4Month,
		year(o.obs_datetime) as cd4Year,
		date(o.obs_datetime) as cd4Date,
		date_format(o.obs_datetime, '%Y-%M') as yearMonth
		from obs o
		where o.voided=0 and o.concept_id in (5497, 730)
	group by year(o.obs_datetime), month(o.obs_datetime)) x
	where x.cd4Date between startDate and endDate) as sixMonthPeriodPatients

from obs o
where o.voided=0 and o.concept_id in (5497, 730)
group by year(o.obs_datetime), month(o.obs_datetime)




-- =====================================================================================================================================================
-- 		||||||| Completed query for patients screened with icf card
-- =====================================================================================================================================================

-- patients screened for TB using ICF card on their last visit within a period of time
--  11 | TB Screening               | ed6dacc9-0827-4c82-86be-53c0d8c449be |
-- these are patients >=15 with encounter_type_id=11 and has 
-- any of the following obs TUBERCULOSIS_DISEASE_STATUS:1659(Coded), DISEASE_SUSPECTED:142177(Boolean), DISEASE_DIAGNOSED:1661(Boolean), NO_SIGNS_OR_SYMPTOMS:1660(Boolean)
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
-- obs TUBERCULOSIS_DISEASE_STATUS:1659(Coded), DISEASE_SUSPECTED:142177(Boolean), DISEASE_DIAGNOSED:1661(Boolean), NO_SIGNS_OR_SYMPTOMS:1660(Boolean)
left outer join obs o on e.encounter_id = o.encounter_id and o.concept_id in (1659, 142177, 1661, 1660) and o.voided=0
where e.encounter_type =11 -- and e.patient_id=12
group by e.patient_id, e.encounter_id  
order by e.patient_id, e.encounter_datetime) x
-- where x.eDate between startDate and endDate -- x.weight =0 and x.height =0 -- and x.eDate <= '2011-05-17';
group by x.patient
) n
where n.lastEncDate between startDate and endDate and (datediff(endDate, dob) / 365.25)>=15 and (status_checked=1 or suspected_concept_filled=1 or diagnosis_done=1 or no_signs_present=1)
) as monthTotal
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
;



-- ---------------------------------------------------------------------------------------------------------------------------------------------------------
-- 		||||| Current on care/art query			||||||||
-- =========================================================================================================================================================
SELECT date_format(e.encounter_datetime, '%Y-%m') as cohort_month,
-- DATE(CONCAT(YEAR(e.encounter_datetime),'-', 1 + 3*(QUARTER(e.encounter_datetime)-1),'-01')) AS quarter_beginning,
COUNT(distinct e.patient_id) AS patients_monthly,
date_sub(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval 6 MONTH) as startDate,
LAST_DAY(e.encounter_datetime) as endDate,
(
-- query to get active patients in specified duration
select count(distinct ec.patient_id)
from encounter ec 
join person p on p.person_id = ec.patient_id and p.voided=0 -- and p.dead = 0 -- filter dead
join patient_program pp on pp.patient_id = ec.patient_id and pp.voided = 0 and pp.program_id=2
left outer join (
select person_id, mid(max(concat(tca, visit_date)),11) as visit_date,
left(max(concat(tca, visit_date)),10) as tca
from (
select person_id, date(mid(max(concat(obs_datetime,value_datetime)),20)) as tca,
date(left(max(concat(obs_datetime,value_datetime)),19)) as visit_date
from obs 
where voided =0 and concept_id = 5096
group by person_id, date(obs_datetime))x
group by person_id 
)lft on lft.person_id = ec.patient_id and lft.visit_date<=GREATEST(LAST_DAY((select max(ec.encounter_datetime))),0)
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
) active_status on active_status.person_id =ec.patient_id
where ec.encounter_datetime between startDate and endDate
and if(date_died <= endDate,1,0) =0 and if(to_date <= endDate,1,0)=0
 -- and if(datediff(lft.tca, endDate) <= 90, 0,1) = 0
) as ActiveInCareTotal,
(
-- query to get active on ART patients in specified duration
select count(distinct ec.patient_id)
from encounter ec 
join person p on p.person_id = ec.patient_id and p.voided=0 -- and p.dead = 0 -- filter dead
join patient_program pp on pp.patient_id = ec.patient_id and pp.voided = 0 and pp.program_id=2
left outer join (
select person_id, mid(max(concat(tca, visit_date)),11) as visit_date,
left(max(concat(tca, visit_date)),10) as tca
from (
select person_id, date(mid(max(concat(obs_datetime,value_datetime)),20)) as tca,
date(left(max(concat(obs_datetime,value_datetime)),19)) as visit_date
from obs 
where voided =0 and concept_id = 5096
group by person_id, date(obs_datetime))x
group by person_id 
)lft on lft.person_id = ec.patient_id and lft.visit_date<=GREATEST(LAST_DAY((select max(ec.encounter_datetime))),0)
left outer join (
-- art status
select patient_id, min(start_date) as start_date
from (
select patient_id, group_concat(cn.name) as reg, start_date, discontinued, o.discontinued_reason
from orders o
join concept_name cn on cn.concept_id=o.concept_id and cn.voided=0 and cn.concept_name_type='SHORT'
where o.voided =0
group by patient_id, date(start_date)
) art
group by patient_id
) art_status on art_status.patient_id = ec.patient_id
left outer join (
-- subquery to transfer out and death status
select 
o.person_id,
ifnull(max(if(o.concept_id=1543, o.value_datetime,null)), '') as date_died,
ifnull(max(if(o.concept_id=160649, o.value_datetime,null)), '') as to_date,
ifnull(max(if(o.concept_id=161555, o.value_coded,null)), '') as dis_reason
from obs operson_attribute_type
where o.concept_id in (1543, 161555, 160649) and o.voided = 0 -- concepts for date_died, date_transferred out and discontinuation reason
group by person_id
) active_status on active_status.person_id =ec.patient_id
where ec.encounter_datetime between startDate and endDate
and if(date_died <= endDate,1,0) =0 and if(to_date <= endDate,1,0)=0
and if(start_date <= endDate,1,0) =1
) as ActiveOnARTTotal
from encounter e
where voided =0
group by year(e.encounter_datetime), month(e.encounter_datetime) 
order by year(e.encounter_datetime), month(e.encounter_datetime) 

-- -------------------------------------------------------------------------------------------------------------------------------------------------------
-- 		|||||||||||||||| Query for patients with at least one hiv visit, in hiv program and not on tb during review period |||
-- =========================================================================================================================================================
-- denominator for patients screened using ICF card
-- hiv infected: patient enrolled in hiv program: hiv enrollment encounter = 3
-- patient not on tb treatment: encounter_type=6, tb treatment start date: 1113
-- patient has at least one hiv visit in the six months review period: encounter_type in (3,7)
-- visit date within the period, date enrolled in tb is null or less than enddate
-- final query for patients in hiv program, have at least an hiv visit and are not on TB treatment

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
x.dateEnrolledInTB
from (
select distinct
e.patient_id as patient,
date(e.encounter_datetime) as encDate,
e.encounter_type,
e.encounter_id,
p.birthdate as dob,
hiv.dateEnrolledInCare as dateEnrolledInHiv,
tb.dateEnrolledInTB as dateEnrolledInTB
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
inner join person p on e.patient_id=p.person_id and p.voided=0
where e.encounter_type in(3,7) and e.voided=0
group by e.patient_id, e.encounter_id ) x
-- where x.encDate between '2011-05-15' and '2011-05-30' 
	 -- and x.dateEnrolledInHiv <= '2011-05-30' 
	 -- and (x.dateEnrolledInTB is null or x.dateEnrolledInTB <= '2011-05-30')
group by x.patient,x.encounter_id
) m 
where m.encDate between startDate and endDate 
	and m.dateEnrolledInHiv <= endDate 
	and (m.dateEnrolledInTB is null or m.dateEnrolledInTB <= endDate)
	and (datediff(endDate, dob) / 365.25)>=15 
) as monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
;


-- =======================================================================================================================================================
--		 		||| patients with at least one vl result in the last 12 months |||
-- =	===================================================================================================================================================
-- patients with at least one viral load result in the last 12 months
select
	date_add(date_add(LAST_DAY(o.obs_datetime),interval 1 DAY),interval -12 MONTH) as startDate,
	LAST_DAY(o.obs_datetime) as endDate,
	date_format(o.obs_datetime, '%Y-%M') as yearMonth,
	count( distinct o.person_id) as patients,
	(select sum(x.patients) as total from
		(select
		count( distinct o.person_id) as patients,
		month(o.obs_datetime) as cd4Month,
		year(o.obs_datetime) as cd4Year,
		date(o.obs_datetime) as vlDate,
		date_format(o.obs_datetime, '%Y-%M') as yearMonth
		from obs o
		where o.voided=0 and o.concept_id in (856)
	group by year(o.obs_datetime), month(o.obs_datetime)) x
	where x.vlDate between startDate and endDate) as sixMonthPeriodPatients

from obs o
where o.voided=0 and o.concept_id in (856)
group by year(o.obs_datetime), month(o.obs_datetime)


-- ============================================================================================================================================================
                            -- non-pregnant women patients who are on modern contraceptive methods within the six months review period
-- ============================================================================================================================================================
SELECT date_format(e.encounter_datetime, '%Y-%m') as cohort_month,
	COUNT(distinct e.patient_id) AS patients_monthly,
	date_sub(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval 6 MONTH) as startDate,
	LAST_DAY(e.encounter_datetime) as endDate,
	(
		-- 
		select count(distinct ec.patient_id)
		from encounter ec
		join person p on p.person_id = ec.patient_id
		and p.voided = 0 and ec.voided = 0 
		and p.gender = 'F' -- female

		join patient pa on pa.patient_id = ec.patient_id
		and pa.voided = 0

		join obs o on o.person_id = ec.patient_id
		and o.concept_id in (374,5272) -- family planning, pregnancy
		and if(o.concept_id=374, if(o.value_coded not in(5277, 159524, 1107, 1175, 5622),1,0),0) = 1 -- only modern contraceptive
		and if(o.concept_id=5272, if(o.value_coded =(1066),1,0),0) = 0 -- not pregnant
		and o.voided = 0
		join patient_program pp on pp.patient_id = ec.patient_id and pp.voided = 0 and pp.program_id=2
		left outer join 
		(
			select person_id, mid(max(concat(tca, visit_date)),11) as visit_date,
			left(max(concat(tca, visit_date)),10) as tca
			from (
			select person_id, date(mid(max(concat(obs_datetime,value_datetime)),20)) as tca,
			date(left(max(concat(obs_datetime,value_datetime)),19)) as visit_date
			from obs 
			where voided =0 and concept_id = 5096
			group by person_id, date(obs_datetime))x
			group by person_id 
		)lft on lft.person_id = ec.patient_id and lft.visit_date<=GREATEST(LAST_DAY((select max(ec.encounter_datetime))),0)
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
		) active_status on active_status.person_id =ec.patient_id
		where ec.encounter_datetime between startDate and endDate
		and if(date_died <= endDate,1,0) =0 and if(to_date <= endDate,1,0)=0
	) as sixMonthsTotal
from encounter e
where voided =0
group by year(e.encounter_datetime), month(e.encounter_datetime) 
order by year(e.encounter_datetime), month(e.encounter_datetime)


