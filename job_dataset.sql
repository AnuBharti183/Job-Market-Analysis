
SELECT *
FROM job_dataset

-------------------------------------------------------------------------------
-- Checking NULL values in the dataset



SELECT
SUM(CASE WHEN job_id IS NULL THEN 1 ELSE 0 END) AS job_id_null,
SUM(CASE WHEN job_title IS NULL THEN 1 ELSE 0 END) AS job_title_null,
SUM(CASE WHEN salary_usd IS NULL THEN 1 ELSE 0 END) AS salary_usd_null,
SUM(CASE WHEN salary_currency IS NULL THEN 1 ELSE 0 END) AS salary_currency_null,
SUM(CASE WHEN experience_level IS NULL THEN 1 ELSE 0 END) AS experience_level_null,
SUM(CASE WHEN employment_type IS NULL THEN 1 ELSE 0 END) AS employment_type_null,
SUM(CASE WHEN company_location IS NULL THEN 1 ELSE 0 END) AS company_location_null,
SUM(CASE WHEN company_size IS NULL THEN 1 ELSE 0 END) AS company_size_null,
SUM(CASE WHEN employee_residence IS NULL THEN 1 ELSE 0 END) AS employee_residence_null,
SUM(CASE WHEN remote_ratio IS NULL THEN 1 ELSE 0 END) AS remote_ratio_null,
SUM(CASE WHEN required_skills IS NULL THEN 1 ELSE 0 END) AS required_skills_null,
SUM(CASE WHEN education_required IS NULL THEN 1 ELSE 0 END) AS education_required_null,
SUM(CASE WHEN years_experience IS NULL THEN 1 ELSE 0 END) AS years_experience_null,
SUM(CASE WHEN industry IS NULL THEN 1 ELSE 0 END) AS industry_null,
SUM(CASE WHEN posting_date IS NULL THEN 1 ELSE 0 END) AS posting_date_null,
SUM(CASE WHEN application_deadline IS NULL THEN 1 ELSE 0 END) AS application_deadline_null,
SUM(CASE WHEN job_description_length IS NULL THEN 1 ELSE 0 END) AS job_description_length_null,
SUM(CASE WHEN benefits_score IS NULL THEN 1 ELSE 0 END) AS benefits_score_null,
SUM(CASE WHEN company_name IS NULL THEN 1 ELSE 0 END) AS company_name_null
FROM job_dataset


-------------------------------------------------------------------------------
-- Normalise Data

CREATE TABLE Separated_skills (
    JobID NVARCHAR(50),
    SkillName NVARCHAR(100) 
)


-- Extracting values
INSERT INTO Separated_skills (JobID, SkillName)
SELECT 
    job_id,
    LTRIM(RTRIM(value)) AS SkillName
FROM job_dataset
CROSS APPLY STRING_SPLIT(required_skills, ',')



CREATE TABLE Skills (
    SkillID INT IDENTITY(1,1) PRIMARY KEY,
    SkillName NVARCHAR(100) UNIQUE
)

INSERT INTO Skills (SkillName)
SELECT DISTINCT SkillName
FROM Separated_skills
WHERE SkillName NOT IN (
    SELECT SkillName FROM Skills
)

SELECT * FROM Skills



CREATE TABLE Job_Skills (
    JobID NVARCHAR(50),
    SkillID INT,
    PRIMARY KEY (JobID, SkillID),
    FOREIGN KEY (JobID) REFERENCES  job_dataset(job_id),
    FOREIGN KEY (SkillID) REFERENCES Skills(SkillID)
)


-- Mapping
INSERT INTO Job_Skills (JobID, SkillID)
SELECT 
    e.JobID,
    s.SkillID
FROM Separated_skills e
JOIN Skills s ON e.SkillName = s.SkillName


-------------------------------------------------------------------------------
-- Dropping unnecessary columns

ALTER TABLE job_dataset
DROP COLUMN required_skills


ALTER TABLE job_dataset
DROP COLUMN job_description_length

-------------------------------------------------------------------------------
--  Convert Other currencies into USD


SELECT DISTINCT(salary_currency)
FROM job_dataset

SELECT salary_currency, salary_usd, FORMAT(ROUND(salary_usd * 1.172127,0),'N0') as converted_salary
FROM job_dataset
WHERE salary_currency = 'EUR'

SELECT salary_currency, salary_usd, ROUND(salary_usd * 1.37,0) as converted_salary
FROM job_dataset
WHERE salary_currency = 'GBP'

ALTER TABLE job_dataset
ADD salary INT

UPDATE job_dataset
SET salary = CASE salary_currency
WHEN 'EUR' THEN ROUND(salary_usd * 1.172127,0)
WHEN 'GBP' THEN ROUND(salary_usd * 1.37,0) 
ELSE salary_usd 
END




-------------------------------------------------------------------------------
-- Change experience level, employement type and company size into full_names

SELECT DISTINCT(experience_level)
FROM job_dataset

ALTER TABLE job_dataset
ADD experiencelevel VARCHAR(15)

UPDATE job_dataset
SET experiencelevel = CASE experience_level
WHEN 'EN' THEN 'Entry'
WHEN 'MI' THEN 'Mid-Level'
WHEN 'SE' THEN 'Senior'
WHEN 'EX' THEN 'Executive'
ELSE 'NULL'
END



SELECT DISTINCT(employment_type)
FROM job_dataset

ALTER TABLE job_dataset
ADD employment_status VARCHAR(15)

UPDATE job_dataset
SET employment_status = CASE employment_type
WHEN 'CT' THEN 'Contract'
WHEN 'PT' THEN 'Part Time'
WHEN 'FL' THEN 'Flex Time'
WHEN 'FT' THEN 'Full Time'
ELSE 'NULL'
END


SELECT DISTINCT(company_size)
FROM job_dataset

ALTER TABLE job_dataset
ADD companysize VARCHAR(10)

UPDATE job_dataset
SET companysize = CASE company_size
WHEN 'S' THEN 'Small'
WHEN 'L' THEN 'Large'
WHEN 'M' THEN 'Medium'
ELSE 'NULL'
END




-------------------------------------------------------------------------------
-- Removing Duplicates
WITH CTE AS (
SELECT job_id,
Rank() OVER(
PARTITION BY job_title, company_location, salary ORDER BY posting_date 
) as rn
FROM 
job_dataset
)


--DELETE FROM Job_Skills 
--WHERE JobID IN (SELECT job_id
--FROM CTE
--WHERE rn > 1)

DELETE FROM job_dataset 
WHERE job_id IN (SELECT job_id
FROM CTE
WHERE rn > 1)


-------------------------------------------------------------------------------
-- Data Quality Assessment

SELECT COUNT(*) - COUNT(DISTINCT(job_id))
FROM job_dataset -- No Duplicates

SELECT COUNT(*)
FROM job_dataset
WHERE salary BETWEEN '32519' AND '425344' -- 95+% within valid range

SELECT COUNT(*) 
FROM job_dataset
WHERE job_title IS NULL OR company_location IS NULL OR required_skills IS NULL
-- Zero records with missing critical data



--------------------------------------------------------------------------------------------
-- ANALYSIS USING SQL

--1. Average salary by Experience Level

SELECT experiencelevel, AVG(salary) as AVG_salary
FROM job_dataset
GROUP BY experiencelevel
ORDER BY AVG_salary

--2. Average salary by company size

WITH CTE AS(
SELECT companysize, AVG(salary) as AVG_salary
FROM job_dataset
GROUP BY companysize
)

SELECT *,
AVG_salary - LAG(AVG_salary) OVER(ORDER BY AVG_salary) as salary_difference
FROM CTE


-- 3. Top skills in demand

ALTER TABLE  Skills
ADD SkillCategory VARCHAR(50)

UPDATE Skills
SET SkillCategory = CASE 
WHEN SkillName IN ('Python', 'R','Scala', 'Java','Hadoop', 'JavaScript', 'SQL') THEN 'Programming Languages'
WHEN SkillName IN ('Machine Learning','MLOps','NLP','Spark', 'Deep Learning', 'TensorFlow', 'PyTorch') THEN 'ML/AI Frameworks'
WHEN SkillName IN ('AWS', 'Azure', 'GCP', 'Docker', 'Kubernetes') THEN 'Cloud & DevOps'
ELSE 'Other'
END

ALTER TABLE job_dataset
DROP COLUMN Frequency 

ALTER TABLE job_dataset
DROP COLUMN Market_penetration 

SELECT * FROM Skills

SELECT s.SkillID, s.SkillCategory, Count(jd.job_id) as Frequency,
CAST(ROUND(COUNT(jd.job_id) * 100.0 / (SELECT COUNT(*) FROM job_dataset), 2)
 AS DECIMAL(5,2)) as Market_penetration
FROM Skills s
JOIN Separated_skills ss
ON ss.SkillName = s.SkillName
JOIN job_dataset jd
ON jd.job_id = ss.JobID
GROUP BY s.SkillID, s.SkillCategory







-- 4. Geographic analysis with remote work breakdown

SELECT company_location,COUNT(job_id) Total_jobs,  AVG(salary) AVG_salary,
SUM(CASE remote_ratio 
WHEN 100 THEN 1 ELSE 0 END) AS Fully_remote,
SUM(CASE remote_ratio 
WHEN 50 THEN 1 ELSE 0 END) AS Hybrid,
SUM(CASE remote_ratio 
WHEN 0 THEN 1 ELSE 0 END) AS 'On-Site'
FROM job_dataset
GROUP BY company_location
ORDER by AVG_salary desc