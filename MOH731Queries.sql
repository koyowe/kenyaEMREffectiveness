-- =============================================================================================================================================================
-- 				|||	Completed query for HIV Exposed Infant (within 2 months) 

-- 				|||	Q:CHILDS CURRENT HIV STATUS 5303 A: Exposure to HIV (822) 
-- =============================================================================================================================================================

select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
extract(YEAR_MONTH from o.obs_datetime) as yearMonth,
o.obs_datetime as encDate,
p.birthdate,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.concept_id,
o.value_coded
from person p
inner join obs o on o.person_id = p.person_id and o.voided = 0 and o.concept_id = 5303 and o.value_coded=822
-- group by 1
-- having ageInDays <=60 and extract(YEAR_MONTH from o.obs_datetime) = '201403'
) x
where x.ageInDays <=60 and extract(YEAR_MONTH from x.encDate) = period
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period

;
-- eligible within two months and eligible for ctx
-- ctx dispensed:162229 , YES: 1065
select 
p.person_id,
p.dead as dead,
extract(YEAR_MONTH from o.obs_datetime) as yearMonth,
o.obs_datetime as encDate,
max(if(o.concept_id = 5303 and o.value_coded=822, 1, 0)) as exposed,
max(if(o.concept_id=162229 and o.value_coded=1065, 1, 0)) as ctxDispensed,
max(if(o.concept_id=1282 and o.value_coded=105281,1,0)) as sulfaOrder,-- MEDICATION_ORDERS = "1282: SULFAMETHOXAZOLE_TRIMETHOPRIM = 105281
p.birthdate,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.concept_id
from person p
inner join obs o on o.person_id = p.person_id and o.voided = 0 and o.concept_id in(162229, 5303, 1282)
group by 1
-- having ageInDays <=60  and exposed =0 and (ctxDispensed=1 or sulfaOrder =1)
having ageInDays <=60 and exposed=1 and ctxDispensed=0 and extract(YEAR_MONTH from o.obs_datetime) = '201403'
;

-- ----------------------------------------------------------------------------------------------------------------------------------------------------------
-- 			||| completed query for HIV Exposed Infant (Eligible for CTX at 2 months) |||
-- ==========================================================================================================================================================
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.dead as dead,
extract(YEAR_MONTH from o.obs_datetime) as yearMonth,
o.obs_datetime as encDate,
max(if(o.concept_id = 5303 and o.value_coded=822, 1, 0)) as exposed,
max(if(o.concept_id=162229 and o.value_coded=1065, 1, 0)) as ctxDispensed,
max(if(o.concept_id=1282 and o.value_coded=105281,1,0)) as sulfaOrder,-- MEDICATION_ORDERS = "1282: SULFAMETHOXAZOLE_TRIMETHOPRIM = 105281
p.birthdate,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.concept_id
from person p
inner join obs o on o.person_id = p.person_id and o.voided = 0 and o.concept_id in(162229, 5303, 1282)
group by 1
-- having ageInDays <=60 and extract(YEAR_MONTH from o.obs_datetime) = '201403'
) x
where x.ageInDays <=60 and x.exposed=1 and extract(YEAR_MONTH from x.encDate) = period and (x.ctxDispensed=1 or x.sulfaOrder =1)
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- =============================================================================================================================================================
--		 					||| Hiv  Visits Females 18+ |||
-- +-----------------------------------+---------+
-- | name                              | form_id |
-- +-----------------------------------+---------+
-- | Clinical Encounter - HIV addendum |      15 |
-- +-----------------------------------+---------+
-- +-----------------------+---------+
-- | MOH 257 Visit Summary |      11 |
-- +-----------------------+---------+
--						select all encounters where form id in (11,15)
-- =============================================================================================================================================================
-- full query
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
extract(year_month from e.encounter_datetime) as period,
(select count(distinct patientId) from (
select 
p.person_id as patientId,
p.birthdate as dob,
p.gender,
datediff(e.encounter_datetime, p.birthdate) div 365.25 as age,
e.encounter_datetime as encDate,
extract(YEAR_MONTH from e.encounter_datetime) as yearMonth,
e.form_id as form
from person p
inner join encounter e on p.person_id = e.patient_id and e.form_id in (11,15) and e.voided =0
where p.voided=0 and gender='F'--  and extract(YEAR_MONTH from e.encounter_datetime) = '201403'
having age >= 18
) x
where extract(YEAR_MONTH from x.encDate) = period
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- =============================================================================================================================================================
--							|||| scheduled visits ||||
-- =============================================================================================================================================================
select 
e.patient_id as patientId,
e.visit_id as visit,
e.encounter_datetime as encDate,
if(o.concept_id = 1246, o.value_coded, '') as scheduledVisitConcept,
tca.encDate as tcaEncDate,
tca.tca as tca,
tca.patient,
extract(YEAR_MONTH from e.encounter_datetime) as yearMonth,
e.form_id as form
from encounter e 
left outer join obs o on o.encounter_id = e.encounter_id and o.voided=0 and o.concept_id =1246
left outer join (
select 
o.person_id as patient,
date(o.obs_datetime) as encDate,
o.value_datetime as tca
from obs o
where o.concept_id = 5096 and o.voided=0
) tca on e.patient_id = tca.patient and e.encounter_datetime = tca.tca
where e.form_id in (11,15) and e.voided =0 and extract(YEAR_MONTH from e.encounter_datetime) = '201403' 
having (scheduledVisitConcept=1 or tca is not null)

-- ===============================================================================================================================================================
--						|||| completed query for non-scheduled visits ||||
-- ===============================================================================================================================================================
-- completed query for monthly non-scheduled visits

select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
e.patient_id as patientId,
e.visit_id as visit,
e.encounter_datetime as encDate,
if(o.concept_id = 1246, o.value_coded, '') as scheduledVisitConcept,
tca.encDate as tcaEncDate,
tca.tca as tca,
tca.patient,
extract(YEAR_MONTH from e.encounter_datetime) as yearMonth,
e.form_id as form
from encounter e 
left outer join obs o on o.encounter_id = e.encounter_id and o.voided=0 and o.concept_id =1246
left outer join (
select 
o.person_id as patient,
date(o.obs_datetime) as encDate,
o.value_datetime as tca
from obs o
where o.concept_id = 5096 and o.voided=0
) tca on e.patient_id = tca.patient and e.encounter_datetime = tca.tca
where e.form_id in (11,15) and e.voided =0 
having ((scheduledVisitConcept = '' or scheduledVisitConcept is null) and tca is null)
) x
where extract(YEAR_MONTH from x.encDate) = period
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- ==========================================================================================================================================================
--				|||		completed query for patients on modern contraceptives 			|||
-- ==========================================================================================================================================================

select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select distinct
p.person_id as patient,
o.obs_datetime as encDate,
(
case o.value_coded
when 5277 or 159524 or 1107 or 1175 or 5622 then 0
else 1
end
) as onModernFP 
from person p
inner join obs o using(person_id)
where p.voided=0 and o.concept_id = 374 and o.voided =0 and o.value_coded is not null 
) x
where x.onModernFP=1 and extract(YEAR_MONTH from x.encDate) = period
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;


-- ============================================================================================================================================================
--				|||		completed query for patients provided with condoms			|||
-- ============================================================================================================================================================
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
extract(year_month from e.encounter_datetime) as period,
(select count(distinct x.patient) from (
select distinct
o.person_id as patient,
o.obs_datetime as encDate,
(case o.value_coded when 1065 then 1 else 0 end) as condomProvided
from obs o
where o.concept_id = 159777 and o.voided = 0
) x
where x.condomProvided=1 and extract(YEAR_MONTH from x.encDate) = period
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;


-- =============================================================================================================================================================
-- 				|||		Completed query for infants tested for pcr within two months of age |||
-- =============================================================================================================================================================
-- Infants given pcr within 2 months
-- Q: TEXT_CONTEXT_STATUS = 162084 A: TEST_STATUS_INITIAL = 162080

/*
*		Concept pcrTest = 844
		Concept detected = 1301
		Concept equivocal = 1300
		Concept inhibitory = 1303
		Concept poorSampleQuality = 1304
		return commonCohorts.hasObs(pcrTest,detected,equivocal,inhibitory,poorSampleQuality);
*/

select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 162084 and o.value_coded= 162080, 1, 0)) as pcrIntitialTest,
max(if(o.concept_id = 844 and o.value_coded in (1300,1301,1303,1304), 1, 0)) as pcrTest
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (162084, 844)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.pcrIntitialTest=1 and x.pcrTest = 1 and x.ageInDays <= 62
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- =============================================================================================================================================================
-- 				|||		Completed query for infants tested for pcr between 3 and 8 months old |||
-- =============================================================================================================================================================

select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 162084 and o.value_coded= 162080, 1, 0)) as pcrIntitialTest,
max(if(o.concept_id = 844 and o.value_coded in (1300,1301,1303,1304), 1, 0)) as pcrTest
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (162084, 844)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.pcrIntitialTest=1 and x.pcrTest = 1 and x.ageInDays between 90 and 252
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;


-- =============================================================================================================================================================
-- 				|||		Completed query for infants tested for pcr between 8 and 12 months old |||
-- =============================================================================================================================================================

select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 162084 and o.value_coded= 162080, 1, 0)) as pcrIntitialTest,
max(if(o.concept_id = 844 and o.value_coded in (1300,1301,1303,1304), 1, 0)) as pcrTest
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (162084, 844)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.pcrIntitialTest=1 and x.pcrTest = 1 and x.ageInDays between 270 and 366
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;


-- ===============================================================================================================================================================
--				|||		completed query for infants between 9 and 12 with serology test  |||
-- ===============================================================================================================================================================


select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInMonths,
o.obs_datetime encDate,
o.concept_id,
o.value_coded,
max(if(o.value_coded in (664,1304,703), 1, 0)) as serologyTest
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id = 1040
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.serologyTest=1 and x.ageInMonths between 270 and 366
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;


-- =============================================================================================================================================================
-- 				|||		Completed query for infants with positive pcr test within two months of age |||
-- =============================================================================================================================================================


select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 162084 and o.value_coded= 162082, 1, 0)) as pcrPositiveTest,
max(if(o.concept_id = 844 and o.value_coded in (1300,1301,1303,1304), 1, 0)) as pcrTest
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (162084, 844)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.pcrPositiveTest=1 and x.pcrTest = 1 and ageInDays <= 62
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;


-- =============================================================================================================================================================
-- 				|||		Completed query for infants between 3 and 8 with positive pcr test  |||
-- =============================================================================================================================================================


select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 162084 and o.value_coded= 162082, 1, 0)) as pcrPositiveTest,
max(if(o.concept_id = 844 and o.value_coded in (1300,1301,1303,1304), 1, 0)) as pcrTest
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (162084, 844)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.pcrPositiveTest=1 and x.pcrTest = 1 and x.ageInDays between 90 and 252
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;


-- =============================================================================================================================================================
-- 				|||		Completed query for infants between 9 and 12 with positive pcr test  |||
-- =============================================================================================================================================================


select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 162084 and o.value_coded= 162082, 1, 0)) as pcrPositiveTest,
max(if(o.concept_id = 844 and o.value_coded in (1300,1301,1303,1304), 1, 0)) as pcrTest
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (162084, 844)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.pcrPositiveTest=1 and x.pcrTest = 1 and x.ageInDays between 270 and 366
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- ==========================================================================================================================================================
-- 2.8 Infant Feeding
-- infants on exclusive breastfeeding
/**
	Concept infantFeedingMethod = 1151
	Concept exclusiveBreastFeeding = 5526
	return commonCohorts.hasObs(infantFeedingMethod,exclusiveBreastFeeding);
*/
-- =========================================================================================================================================================


select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 1151 and o.value_coded= 5526, 1, 0)) as exclusiveFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (1151)
group by p.person_id, extract(year_month from o.obs_datetime)

;
-- completed query
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 1151 and o.value_coded= 5526, 1, 0)) as exclusiveFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (1151)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.exclusiveFeeding=1 and ageInDays between 179 and 215
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- =======================================================================================================================================================
-- infants on exclusive replacement breast feeding at 6 months
/**
	Concept infantFeedingMethod = 1151
	Concept exclusiveReplacement = 1595
	return commonCohorts.hasObs(infantFeedingMethod,exclusiveReplacement);
*/
-- =======================================================================================================================================================

select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 1151 and o.value_coded= 1595, 1, 0)) as exclusiveReplacementFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (1151)
group by p.person_id, extract(year_month from o.obs_datetime)

;
-- completed query
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 1151 and o.value_coded= 1595, 1, 0)) as exclusiveReplacementFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (1151)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.exclusiveReplacementFeeding=1 and ageInDays between 179 and 215
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

--==============================================================================================================================================================
-- infants on exclusive mixed breast feeding at 6 months
/**
	Concept infantFeedingMethod = 1151
	Concept exclusiveReplacement = 6046
	return commonCohorts.hasObs(infantFeedingMethod,exclusiveReplacement);
*/
--==============================================================================================================================================================

select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 1151 and o.value_coded= 6046, 1, 0)) as mixedFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (1151)
group by p.person_id, extract(year_month from o.obs_datetime)

;
-- completed query
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 1151 and o.value_coded= 6046, 1, 0)) as mixedFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (1151)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.mixedFeeding=1 and ageInDays between 179 and 215
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- =========================================================================================================================================================
                                        -- completed query for total HEI patients feeding aged 6 between
-- =========================================================================================================================================================

select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 1151 and o.value_coded= 5526, 1, 0)) as exclusiveBreastFeeding,
max(if(o.concept_id = 1151 and o.value_coded= 1595, 1, 0)) as exclusiveReplacementFeeding,
max(if(o.concept_id = 1151 and o.value_coded= 6046, 1, 0)) as mixedFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (1151)
group by p.person_id, extract(year_month from o.obs_datetime)
) x
where extract(YEAR_MONTH from x.encDate) = period and x.exclusiveBreastFeeding=1 and x.exclusiveReplacementFeeding=1 and x.mixedFeeding=1 and ageInDays between 179 and 215
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- =========================================================================================================================================================
/**
	 * Mothers who are on treatment and breast feeding between ${onOrAfter} and ${onOrBefore}
	 * @return  the cohort definition
	 
	public CohortDefinition motherOnTreatmentAndBreastFeeding() {
		Concept motherOnTreatmentAndBreatFeeding = 159941
		Concept breastfeeding = 1065
		return commonCohorts.hasObs(motherOnTreatmentAndBreatFeeding,breastfeeding);
	}
*/
-- ========================================================================================================================================================

select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 159941 and o.value_coded= 1065, 1, 0)) as pregnant$BreastFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (159941)
group by p.person_id, extract(year_month from o.obs_datetime)

;
-- completed query
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) div 365.25 as ageInyears,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 159941 and o.value_coded= 1065, 1, 0)) as pregnantBreastFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (159941)
group by p.person_id, extract(year_month from o.obs_datetime)

) x
where extract(YEAR_MONTH from x.encDate) = period and x.pregnantBreastFeeding=1 and x.ageInyears =1 
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- ==========================================================================================================================================================
                                -- Mothers who are on treatment and NOT breast feeding 
-- ----------------------------------------------------------------------------------------------------------------------------------------------------------


select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 159941 and o.value_coded= 1066, 1, 0)) as pregnant$BreastFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (159941)
group by p.person_id, extract(year_month from o.obs_datetime)

;
-- completed query
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) div 365.25 as ageInyears,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 159941 and o.value_coded= 1066, 1, 0)) as pregnantBreastFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (159941)
group by p.person_id, extract(year_month from o.obs_datetime)

) x
where extract(YEAR_MONTH from x.encDate) = period and x.pregnantBreastFeeding=1 and x.ageInyears =1 
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;

-- ==============================================================================================================================================================
                         -- Mothers who are on treatment and never know if they are breastfeeding between
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------

select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) as ageInDays,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 159941 and o.value_coded= 1067, 1, 0)) as pregnant$BreastFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (159941)
group by p.person_id, extract(year_month from o.obs_datetime)

;
-- completed query
select
date_format(e.encounter_datetime, '%Y-%M') as fPeriod,
last_day(e.encounter_datetime) as lastDay,
extract(year_month from e.encounter_datetime) as period,
(select count(*) from (
select 
p.person_id,
p.birthdate as dob,
datediff(o.obs_datetime, p.birthdate) div 365.25 as ageInyears,
o.obs_datetime as encDate,
o.concept_id,
o.value_coded,
max(if(o.concept_id = 159941 and o.value_coded= 1067, 1, 0)) as pregnantBreastFeeding
from person p
inner join obs o on o.person_id = p.person_id and o.concept_id in (159941)
group by p.person_id, extract(year_month from o.obs_datetime)

) x
where extract(YEAR_MONTH from x.encDate) = period and x.pregnantBreastFeeding=1 and x.ageInyears =1 
) monthlyCount
from encounter e
where e.voided =0 and e.encounter_datetime between '1980-01-01' and curdate()
group by year(e.encounter_datetime), month(e.encounter_datetime)
order by period
;



-- ========================================================================================================================================================
--                                    Net Cohort and on Therapy Query
-- ---------------------------------------------------------------------------------------------------------------------------------------------------------

select trial_1.visit_month_, count(distinct cohort.patient_id) as net_cohort,
count(distinct if((coalesce(cohort.to_date,cohort.date_died) > trial_1.endDate or coalesce(cohort.to_date,cohort.date_died) is null), cohort.patient_id,null)) as on_therapy
from (
select patient_id, min(start_date) as art_startDate, p.gender, p.birthdate,
date_format(min(o.start_date), '%Y-%m') as art_start_month,
active_status.*
from orders o
join person p on person_id = o.patient_id and p.voided =0
left outer join (
-- subquery to transfer out and death status
select 
o.person_id,
max(if(o.concept_id=1543, o.value_datetime,null)) as date_died,
max(if(o.concept_id=160649, o.value_datetime,null)) as to_date,
max(if(o.concept_id=161555, o.value_coded,null)) as dis_reason,
min(if(o.concept_id=159599, o.value_datetime,null)) as ti_art_startDate,
min(if(o.concept_id=160534, o.value_datetime,null)) as ti_Date
from obs o
where o.concept_id in (1543, 161555, 160649, 159599, 160534) and o.voided = 0 -- concepts for date_died, date_transferred out and discontinuation reason
group by person_id
) active_status on active_status.person_id =o.patient_id
group by patient_id
)as cohort
left outer join (
select date_sub(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval 1 MONTH) as startDate,
LAST_DAY(e.encounter_datetime) as endDate,
date_sub(date_sub(date_add(LAST_DAY(e.encounter_datetime),interval 1 DAY),interval 1 MONTH),interval 1 year) as startDate_,
date_sub(LAST_DAY(e.encounter_datetime),interval 1 year) as  endDate_,
date_format(e.encounter_datetime, '%Y-%m') as visit_month,
date_format(date_sub(e.encounter_datetime,interval 1 year), '%Y-%m') as visit_month_
from encounter e
where voided =0
group by year(e.encounter_datetime), month(e.encounter_datetime) 
order by year(e.encounter_datetime), month(e.encounter_datetime)
) as trial_1 on trial_1.visit_month_=cohort.art_start_month
group by trial_1.visit_month_;



-- ==============================================================================================================================================================


