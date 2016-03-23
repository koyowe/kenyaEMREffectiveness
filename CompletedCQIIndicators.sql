-- =============================================================================================================================================================
--
--	 	||| 					CQI Indicators								|||
-- 
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.1  % of patient in care with 2 or more visits, 3 months apart during the 6 months Review period |||
-- --------------------------------------------------------- Beginning of Query --------------------------------------------------------------------------------

select '1.1' as Indicator, d.cohort_month as Period, n.sixMonthsTotal as Numerator, d.ActiveInCareTotal as Denominator
from
(
	SELECT date_format(e.encounter_datetime, '%Y-%M') as cohort_month,
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
			from obs o
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
) d
inner join (
SELECT date_format(e.encounter_datetime, '%Y-%M') as cohort_month,
	date_sub(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval 6 MONTH) as startDate,
	LAST_DAY(e.encounter_datetime) as endDate,
	(
		select count(distinct ec.patient_id)
		from (select 
			@patient_id :=case -- for every group of a given patient's encounters, compare current encounter date to the previous encounter date
				when (@patient_id = patient_id) and (datediff(date(e.encounter_datetime), @enc_date)) between 85 and 95 then
					1
				else 0
				end as three_m_apart,
			@patient_id :=patient_id as patient_id, -- cache patient_id
			@enc_date :=date(e.encounter_datetime) as enc_date, -- cache encounter date
			e.encounter_datetime, e.voided -- needed for joins & where clause
		from encounter e) ec

		join patient_program pp on pp.patient_id = ec.patient_id and ec.voided = 0 and pp.voided = 0 and pp.program_id=2
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
		and ec.three_m_apart=1 -- two or more encounters satisfy three months apart
		and if(date_died <= endDate,1,0) =0 and if(to_date <= endDate,1,0)=0
	) as sixMonthsTotal
from encounter e
where voided =0
group by year(e.encounter_datetime), month(e.encounter_datetime) 
order by year(e.encounter_datetime), month(e.encounter_datetime)

) n on n.cohort_month = d.cohort_month
order by 1
;




-- =============================================================            End of Query       =================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- =============================================================================================================================================================
--				||| 1.2  % of HIV infected patients in care with at least one CD4 count during the 6 months Review period |||
-- --------------------------------------------------------------Beginning of Query ---------------------------------------------------------------------------

select '1.2' as Indicator, d.cohort_month as Period, n.monthTotal as Numerator, d.ActiveInCareTotal as Denominator
from
(
SELECT date_format(e.encounter_datetime, '%Y-%M') as cohort_month,
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
from obs o
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

) d
inner join (
select
	date_add(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval -6 MONTH) as startDate,
	LAST_DAY(e.encounter_datetime) as endDate,
	date_format(e.encounter_datetime, '%Y-%M') as yearMonth,
	(
select count(distinct patient) from (
select distinct
	o.person_id as patient,
	o.value_numeric as val,
	
	o.obs_datetime as encDate,
	active_status.date_died as date_died,
	active_status.to_date as to_date
from obs o
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
) active_status on active_status.person_id =o.person_id
where o.voided=0 and o.concept_id in (5497, 730) 
group by patient, encDate
) cd4
where cd4.encDate between startDate and endDate and (cd4.date_died is null or cd4.date_died='' or cd4.date_died > endDate)
and (cd4.to_date is null or cd4.to_date='' or cd4.to_date > endDate) -- date_died must be after reporting period
) as monthTotal
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)

) n on n.yearMonth = d.cohort_month
order by 1
;




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


select '1.4' as Indicator, d.cohort_month as Period, n.monthTotal as Numerator, d.ActiveOnARTTotal as Denominator
from
(
SELECT date_format(e.encounter_datetime, '%Y-%M') as cohort_month,
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
from obs o
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

) d
inner join (
select
	date_add(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval -1 YEAR) as startDate,
	LAST_DAY(e.encounter_datetime) as endDate,
	date_format(e.encounter_datetime, '%Y-%M') as yearMonth,
	(
select count(distinct patient) from (
select distinct
	o.person_id as patient,
	o.value_numeric as val,
	o.obs_datetime as encDate,
	active_status.date_died as date_died,
	active_status.to_date as to_date
from obs o
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
) active_status on active_status.person_id =o.person_id
where o.voided=0 and o.concept_id = 856 
group by patient, encDate
) vl
where vl.encDate between startDate and endDate and (vl.date_died is null or vl.date_died='' or vl.date_died > endDate)
and (vl.to_date is null or vl.to_date='' or vl.to_date > endDate) -- date_died must be after reporting period
) as monthTotal
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)

) n on n.yearMonth = d.cohort_month
order by 1
;



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
select '1.12' as Indicator, n.cohort_month as period, n.patients_monthly as patients_monthly, n.startDate as startDate,  n.endDate as endDate, n.sixMonthsTotal as num_sixMonthsTotal, d.sixMonthsTotal as denom_sixMonthsTotal
from
(
SELECT date_format(e.encounter_datetime, '%Y-%M') as cohort_month,
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
		and if(o.concept_id=5272, if(o.value_coded =(1066),1,0),0) = 0 -- non-pregnant
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
) d
join
(SELECT date_format(e.encounter_datetime, '%Y-%M') as cohort_month,
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
) n on n.cohort_month = d.cohort_month
order by 1
-- =============================================================================================================================================================
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
