# Dataset:  https://www.kaggle.com/datasets/prasad22/healthcare-dataset/data
# Note that there was a step I did at the start before loading the csv file onto MySQl
# The first variable 'name' had a capitilisation problem where names were like 'AnDrEW JaCKsoN' 
# It was easier to change the csv file directly using = PROPER() on Excel, as fixing the upper/lowercases like this on SQL for names with two words is more difficult
# Even though I realise this hurts reproducibility, this is only a step done now since I would like to use SQL only for the data cleaning part of this project for practice, but typically I would use Python and would clean all data there, meaning better reproducibility

SELECT * 
FROM healthcare_dataset;

# First thing we want to do is create a copy table. This is the one we will work in and clean the data in. We want a table with the original raw data in case something happens
CREATE TABLE healthdata_copy
LIKE healthcare_dataset;

INSERT healthdata_copy
SELECT * FROM healthcare_dataset;

-- Now when we are data cleaning we usually follow a few steps:
-- 1. check for duplicates and remove any
-- 2. standardise data and fix errors
-- 3. Look at null values and deal with them
-- 4. remove any columns and rows that are not necessary 

SELECT *
FROM healthdata_copy
;

# First I have to drop the old column of names whch I renamed 'Namee'. The new fixed names column I named 'Name' (I did this manually on Excel - not advised as mentioned earlier)
ALTER TABLE healthcare_dataset
DROP COLUMN Namee;


# 1.Let us remove duplicates

SELECT *,
		ROW_NUMBER() OVER (
			PARTITION BY `Name`, Age, Gender, `Blood Type`, `Medical Condition`, `Date of Admission`, Doctor, Hospital, `Insurance Provider`, `Billing Amount`, `Room Number`, `Admission Type`, `Discharge Date`, Medication, `Test Results`) AS row_num
	FROM 
		healthdata_copy;
# for SQL syntax the double-word columns must be surrounded by backticks


SELECT *
FROM (
	SELECT *,
		ROW_NUMBER() OVER (
			PARTITION BY `Name`, Age, Gender, `Blood Type`, `Medical Condition`, `Date of Admission`, Doctor, Hospital, `Insurance Provider`, `Billing Amount`, `Room Number`, `Admission Type`, `Discharge Date`, Medication, `Test Results`
			) AS row_num
	FROM 
		healthdata_copy
) duplicates
WHERE 
	row_num > 1;
    
# No rows returned, fantastic, means no duplicates

# 2. Standardise and fix errors
# I will be inspecting mostly only the categorical variables below

SELECT *
FROM healthdata_copy
;

# do distinct viewing of the columns so that we can see if some of them have two labels (e.g. USA and United States of America), have spaces before and after, etc


# let us look at the Name variable
# Note that in machine learning models I would typically remove 'name' and 'hospital' from my main analysis as they are not very useful for us, especially 'name' since they are unique and do not give us much predictive ability/patterns
# but for this analysis in MySQL it might be useful to keep 'Hospital' because it can help with finding some group-level trends (like average stay per hospital). The 'name' variable is not useful even here on MySQL but I still cleaned it in this sql file to practice my data cleaning.

SELECT DISTINCT `Name`
FROM healthdata_copy
ORDER BY `Name`;
# We must remove the titles in the names: Dr., Mr., Mrs.


UPDATE healthdata_copy
SET Name = TRIM(
    REPLACE(
        REPLACE(
            REPLACE(
                REPLACE(Name, 'Mr. ', ''),
                'Mrs. ', ''
            ),
            'Dr. ', ''
        ),
        'Ms. ', ''
    )
)
WHERE Name LIKE 'Mr.%' OR Name LIKE 'Mrs.%' OR Name LIKE 'Dr.%' OR Name LIKE 'Ms.%';

# Perfect


SELECT * 
FROM healthdata_copy;
# Looks good!


SELECT Name, SOUNDEX(Name) AS sound
FROM healthdata_copy
ORDER BY sound;
# This is not essential but it can help find similar sounding names, helps me in my search for same names that might be written twice in slightly different ways

# Before inspecting date variable let us convert to correct format:

-- we can use str to date to update this field
UPDATE healthdata_copy
SET `Date of Admission` = STR_TO_DATE(`Date of Admission`, '%m/%d/%Y');
# '%m/%d/%Y' is the current format that we wish to convert to the MySQL internal DATE format


UPDATE healthdata_copy
SET `Discharge Date` = STR_TO_DATE(`Discharge Date`, '%m/%d/%Y');


SELECT DISTINCT `Date of Admission`
FROM healthdata_copy
ORDER BY `Date of Admission`;
# Look good

SELECT DISTINCT `Discharge Date`
FROM healthdata_copy
ORDER BY `Discharge Date`;
# Look good

ALTER TABLE healthdata_copy
MODIFY COLUMN `Date of Admission` DATE;
# Convert it to DATE type

ALTER TABLE healthdata_copy
MODIFY COLUMN `Discharge Date` DATE;


# Let us inspect Gender

SELECT DISTINCT Gender
FROM healthdata_copy
ORDER BY Gender;
# no problems

SELECT DISTINCT `Medical Condition`
FROM healthdata_copy
ORDER BY `Medical Condition`;
# no problems

SELECT DISTINCT Doctor
FROM healthdata_copy
ORDER BY Doctor;
# Again some of the names have Mr., Dr., and Mrs. and even some have MD at the end



UPDATE healthdata_copy
SET Doctor = TRIM(
    REPLACE(
        REPLACE(
            REPLACE(Doctor, 'Mr. ', ''),
            'Mrs. ', ''
        ),
        'Dr. ', ''
    )
)
WHERE Doctor LIKE 'Mr.%' OR Doctor LIKE 'Mrs.%' OR Doctor LIKE 'Dr.%';

-- Since we only want to remove MD if it is at the end and not mid sentence, it is better to use REGEXP to remove MD
UPDATE healthdata_copy
SET Doctor = TRIM(
    REGEXP_REPLACE(Doctor, 'MD$', '')
)
WHERE Doctor LIKE '%MD';
# Now looks good!



SELECT DISTINCT Hospital
FROM healthdata_copy
ORDER BY Hospital;
# There is an issue here. The problem is that when moving the data to a csv file, some of the hospital names in the rows begin with 'and' e.g. 'and Carter Sons'. We must remove the 'and'


UPDATE healthdata_copy
SET Hospital = TRIM(
    TRAILING ',' FROM
    IF(LEFT(Hospital, 4) = 'and ', SUBSTRING(Hospital, 5), Hospital)
)
WHERE Hospital LIKE 'and %' OR Hospital LIKE '%,';
# Hospital variable is difficult to analyse. This is because not does it consist of many different possible values and so hard to detect patterms for, but it also is hard to understand
# what the names of the hospitals actually begin and end, for instance Anderson and Medina, Sullivan .


SELECT DISTINCT `Insurance Provider`
FROM healthdata_copy
ORDER BY `Insurance Provider`;
# Looks good.

SELECT DISTINCT `Admission Type`
FROM healthdata_copy
ORDER BY `Admission Type`;
# Looks good.
# The hospital offers 3 types of admission: Emergency, Elective, Transfer


SELECT DISTINCT Medication
FROM healthdata_copy
ORDER BY Medication;
# Looks good.

SELECT DISTINCT `Test Results`
FROM healthdata_copy
ORDER BY `Test Results`;
# Looks good.

# 3. Let us check null values

SELECT *
FROM healthdata_copy
;

SELECT *
FROM healthdata_copy
WHERE `Name` IS NULL
    OR Age IS NULL
    OR Gender IS NULL
    OR `Blood Type` IS NULL
    OR `Medical Condition` IS NULL
    OR `Date of Admission` IS NULL
    OR Doctor IS NULL
    OR Hospital IS NULL
    OR `Insurance Provider` IS NULL
    OR `Billing Amount` IS NULL
    OR `Room Number` IS NULL
    OR `Admission Type` IS NULL
    OR `Discharge Date` IS NULL
    OR Medication IS NULL
    OR `Test Results` IS NULL;
# No nulls. 

-- 4. remove any columns and rows that are not necessary

# It does not seem like there are any unecessary data 


# Now let us move on to EDA:


# Describe() and summary() functions otside of MySQL show statistical summaries, here I will try to replicate them on MySQL
# EDA for the numerical variables (note that this can also help us identify even more points of data cleaning, such as a negative minimum age):

# 1) Age analysis:

SELECT  
  COUNT(AGE) AS count,
  MIN(AGE) AS min,
  MAX(AGE) AS max,
  AVG(AGE) AS mean,
  STDDEV(AGE) AS std_dev,
  VARIANCE(AGE) AS variance
FROM healthdata_copy;
# minimum in dataset is 18 years old, max 85, average ~51

# 2) Billing amount analysis:

SELECT  
  COUNT(`Billing Amount`) AS count,
  MIN(`Billing Amount`) AS min,
  MAX(`Billing Amount`) AS max,
  AVG(`Billing Amount`) AS mean,
  STDDEV(`Billing Amount`) AS std_dev,
  VARIANCE(`Billing Amount`) AS variance
FROM healthdata_copy;
# There are negative amounts. obviously wrong as these are costs

SELECT *
FROM healthdata_copy
WHERE `Billing Amount` <0;
# 2 rows like this. We must remove them

DELETE FROM healthdata_copy
WHERE `Billing Amount` < 0;

# Now again:
SELECT  
  COUNT(`Billing Amount`) AS count,
  MIN(`Billing Amount`) AS min,
  MAX(`Billing Amount`) AS max,
  AVG(`Billing Amount`) AS mean,
  STDDEV(`Billing Amount`) AS std_dev,
  VARIANCE(`Billing Amount`) AS variance
FROM healthdata_copy;
# Minimum billing amount is ~43 $
# Avergae billing amount is ~25150 $
# Max is 51600 $

# 3) Temporal analysis:

SELECT  
  COUNT(`Date of Admission`) AS count,
  MIN(`Date of Admission`) AS min,
  MAX(`Date of Admission`) AS max,
  AVG(`Date of Admission`) AS mean,
  STDDEV(`Date of Admission`) AS std_dev,
  VARIANCE(`Date of Admission`) AS variance
FROM healthdata_copy;
# Data spans 5 years from 2019 to 2024
SELECT  
  COUNT(`Discharge Date`) AS count,
  MIN(`Discharge Date`) AS min,
  MAX(`Discharge Date`) AS max,
  AVG(`Discharge Date`) AS mean,
  STDDEV(`Discharge Date`) AS std_dev,
  VARIANCE(`Discharge Date`) AS variance
FROM healthdata_copy;
# Data spans 5 years from 2019 to 2024

# 4) Accomodation analysis:

SELECT  
  COUNT(`Room Number`) AS count,
  MIN(`Room Number`) AS min,
  MAX(`Room Number`) AS max,
  AVG(`Room Number`) AS mean,
  STDDEV(`Room Number`) AS std_dev,
  VARIANCE(`Room Number`) AS variance
FROM healthdata_copy;
# The hospital provides rooms from 101 to 500, menaing a wide range of rooms to accomodate a high number of patients at a time

# 5) Doctor analysis
# for the cateogorical variables, I will do a different type of analysis using Count:

SELECT Doctor, COUNT(*) AS patient_count
FROM healthdata_copy
GROUP BY Doctor
ORDER BY patient_count DESC
LIMIT 1;
# John Smith has the most visits by patients

SELECT Doctor, COUNT(*) AS patient_count
FROM healthdata_copy
GROUP BY Doctor
ORDER BY patient_count ASC
LIMIT 1;
# Matthew Smith the least

# 6) Blood type analysis:

SELECT `Blood Type`, COUNT(*) AS Blood_type_count
FROM healthdata_copy
GROUP BY `Blood Type`
ORDER BY Blood_type_count DESC
LIMIT 1;
# Most common is O+  

SELECT `Blood Type`, COUNT(*) AS Blood_type_count
FROM healthdata_copy
GROUP BY `Blood Type`
ORDER BY Blood_type_count ASC
LIMIT 1;
# Least common O-alter

# 7) Hospital Analysis:

SELECT Hospital, COUNT(*) AS Hospital_count
FROM healthdata_copy
GROUP BY Hospital
ORDER BY Hospital_count DESC
LIMIT 1;
# Hospital with most patients is Group Thompson

SELECT Hospital, COUNT(*) AS Hospital_count
FROM healthdata_copy
GROUP BY Hospital
ORDER BY Hospital_count ASC
LIMIT 1;
# Least is Sons and Miller

# 8) Condition analysis:

SELECT `Medical Condition`, COUNT(*) AS Condition_count
FROM healthdata_copy
GROUP BY `Medical Condition`
ORDER BY Condition_count DESC
LIMIT 1;
# Most frequent is arthritis

SELECT `Medical Condition`, COUNT(*) AS Condition_count
FROM healthdata_copy
GROUP BY `Medical Condition`
ORDER BY Condition_count ASC
LIMIT 1;
# Least frequent is obesity

# 9) Insurance Provider analysis

SELECT `Insurance Provider`, COUNT(*) AS Insurance_count
FROM healthdata_copy
GROUP BY `Insurance Provider`
ORDER BY Insurance_count DESC
LIMIT 1;
# Cigna is the most frequent

SELECT `Insurance Provider`, COUNT(*) AS Insurance_count
FROM healthdata_copy
GROUP BY `Insurance Provider`
ORDER BY Insurance_count  ASC
LIMIT 1;
# UNitedHealthcare is the least frequent

# 10) Medication analysis 

SELECT Medication, COUNT(*) AS Medication_count
FROM healthdata_copy
GROUP BY  Medication
ORDER BY Medication_count DESC
LIMIT 1;
# Ibuprofen is the most frequent

SELECT Medication, COUNT(*) AS Medication_count
FROM healthdata_copy
GROUP BY  Medication
ORDER BY Medication_count ASC
LIMIT 1;
# Aspirin is the least frequent

# 11) Test Results analysis 

SELECT `Test Results`, COUNT(*) AS Results_count
FROM healthdata_copy
GROUP BY  `Test Results`
ORDER BY Results_count DESC
LIMIT 1;
# Abnormal is the most frequent

SELECT `Test Results`, COUNT(*) AS Results_count
FROM healthdata_copy
GROUP BY  `Test Results`
ORDER BY Results_count ASC
LIMIT 1;
# Inconclusive is the least frequent

# What more EDA can  we do:

SELECT *
FROM healthdata_copy
;

# 12) Let us do average time between admission and discharge
SELECT AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS avg_length_of_stay
FROM healthdata_copy;
# DATEDIFF function can help u shere
# Patient stays ~ 16 days on average

# Let us group by doctor
SELECT AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS avg_length_of_stay,
Doctor
FROM healthdata_copy
GROUP BY Doctor
ORDER BY avg_length_of_stay ASC;
# Connie Boyds, Matthew Carter and Misty Garcia among many doctors with only 1 average day of patient stay

SELECT AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS avg_length_of_stay,
Doctor
FROM healthdata_copy
GROUP BY Doctor
ORDER BY avg_length_of_stay DESC;
# Kevin Wells, Heather Day, and James Tucker among many with 30 days of stay

# Let us group by Blood Type
SELECT AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS avg_length_of_stay,
`Blood Type`
FROM healthdata_copy
GROUP BY `Blood Type`
ORDER BY avg_length_of_stay DESC;
# AB- spend most time on average in hospital

SELECT AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS avg_length_of_stay,
`Blood Type`
FROM healthdata_copy
GROUP BY `Blood Type`
ORDER BY avg_length_of_stay ASC;
# B+ least amount of stay on average

# This is enough for the SQL analysis, the rest will be done in stage 2 - ML using Python (Jupyter Notebook)
# I will exporrt his cleaned data and use it for stage 2.
# Note that the hospital column is not fixed yet, but since it requires a lot of cleaning that deals with many assumptions (such as that the name ends when the ', and' appears in the hospital name), I will wait until I do correlation analysis in Python to see if it is even worth taking these assumptions
# Meaning that when I predict the Test Results which is the goal, maybe the hospital has a small correlation with it an dis therefore not that useful as a predictive feature and so we needn't waste time on it
# Area of focus: I must focus on CTE's and using them more often on SQL. They were not essential in this project, but for future use I must keep that in mind.

# Exporting CSV using Table Wizard Export with Comma field separator and rest of choices the default option was picked
























































