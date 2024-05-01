/* this is real life data */
/* First - get the dataset. In this case it is originally from	Our World in Data (https://ourworldindata.org/) and provided by Alex the Analyst */
/* The video (Alex) also explains how to obtain the data from the website. */
/* Note - in my case, using "Microsoft OLE DB Provider for SQL Server" for Destination works */

/* SELECT some rows and see if the tables working */
SELECT TOP(3) *
FROM dbo.CovidDeaths_mod as d
ORDER BY d.location, d.date;

SELECT TOP(3) *
FROM dbo.CovidVaccn_mod as v
ORDER BY v.location, v.date;

--SELECT the parts we are going to work with
SELECT d.location, d.date, d.total_cases, d.new_cases, d.total_deaths, d.population
FROM dbo.CovidDeaths_mod as d
ORDER BY 1, 2;

--View all the locations covered
SELECT DISTINCT(d.location) as Locations
FROM dbo.CovidDeaths_mod as d
ORDER BY Locations DESC;

--Looking at Total Cases vs Total Deaths in the US
/* ~1.78% as of 21-04-30 */
/* https://stackoverflow.com/questions/441600/write-a-number-with-two-decimal-places-sql-server */
SELECT d.location, 
	d.date, 
	d.population, 
	d.total_cases, 
	d.total_deaths, 
	CONVERT(DECIMAL(10, 2), ((d.total_deaths / d.total_cases) * 100)) as Death_percent
FROM dbo.CovidDeaths_mod as d
WHERE d.location = 'United States'
ORDER BY d.location, d.date;

--Looking at Total Cases vs Population in US
/* ~9.88% as of 21-04-30 */
SELECT d.location, 
	d.date, 
	d.population, 
	d.total_cases, 
	CONVERT(DECIMAL(10, 2), ((d.total_cases / d.population) * 100)) as Infec_percent
FROM dbo.CovidDeaths_mod as d
WHERE d.location = 'United States'
ORDER BY d.location, d.date;

--Looking at locations with the Highest Infection Rate compared to population
SELECT d.location, 
	d.population, 
	MAX(d.total_cases) as Highest_infection_count, 
	MAX(CONVERT(DECIMAL(10, 2), ((d.total_cases / d.population) * 100))) as Highest_infec_percent
FROM dbo.CovidDeaths_mod as d
GROUP BY d.location, d.population /* these two variables can be individually aggregated */
ORDER BY Highest_infec_percent DESC;

--Looking at locations (countries) with the Highest Death Count per population
/* in this case, location is a continent when 'continent' is NULL */
SELECT TOP(3) *
FROM dbo.CovidDeaths_mod as d
ORDER BY d.continent;

/* note the data type issue with certain variable - solved by CAST */
SELECT d.location, 
	d.population, 
	MAX(CAST(d.total_deaths as int)) as Total_death_count, 
	(MAX(CAST(d.total_deaths as int)) / d.population) * 100 as Death_rate_population
FROM dbo.CovidDeaths_mod as d
WHERE d.continent is not NULL
GROUP BY d.location, d.population
ORDER BY Total_death_count DESC;

/* we can do the same thing but GROUP BY 'continent'; however, in this case continent is included in 'location' as well and 
only the continent info in 'location' gives proper results*/
SELECT d.location, 
	d.population, 
	MAX(CAST(d.total_deaths as int)) as Total_death_count, 
	(MAX(CAST(d.total_deaths as int)) / d.population) * 100 as Death_rate_population
FROM dbo.CovidDeaths_mod as d
WHERE d.continent is NULL
GROUP BY d.location, d.population
ORDER BY Total_death_count DESC;

--Global numbers
/* SUM of daily new cases at global scale */
SELECT d.date, SUM(d.new_cases) as Daily_global_cases, 
	SUM(CAST(d.new_deaths as int)) as Daily_global_deaths,
	STR(SUM(CAST(d.new_deaths as int)) / SUM(d.new_cases) * 100, 10, 2) as Daily_global_death_rates
FROM dbo.CovidDeaths_mod as d
WHERE d.continent is not NULL
GROUP BY d.date
ORDER BY 1, 2;

/* total cases at global scale */
SELECT SUM(d.new_cases) as Global_cases, 
	SUM(CAST(d.new_deaths as int)) as Global_deaths,
	STR(SUM(CAST(d.new_deaths as int)) / SUM(d.new_cases) * 100, 10, 2) as Global_death_rates
FROM dbo.CovidDeaths_mod as d
WHERE d.continent is not NULL;

/* CREATE VIEW for the output of SUM of daily new cases at global scale */
/* a VIEW can be exported to PowerBI (tested), entering YUT\SQLEXPRESS in this case */
/* a VIEW is the data source that we will use for the visualisation */
CREATE VIEW Cases_global
AS
SELECT d.date, SUM(d.new_cases) as Daily_global_cases, 
	SUM(CAST(d.new_deaths as int)) as Daily_global_deaths,
	STR(SUM(CAST(d.new_deaths as int)) / SUM(d.new_cases) * 100, 10, 2) as Daily_global_death_rates
FROM dbo.CovidDeaths_mod as d
WHERE d.continent is not NULL
GROUP BY d.date;

-- Looking at Total population vs New vaccinations
/* note how CONVERT is used as CAST */
SELECT d.continent, 
	d.location, 
	d.date, 
	d.population, 
	v.new_vaccinations, 
	SUM(CONVERT(int, v.new_vaccinations)) OVER (PARTITION BY d.location) as Total_vac_by_location
FROM dbo.CovidDeaths_mod as d
INNER JOIN dbo.CovidVaccn_mod as v
	ON d.location = v.location AND d.date = v.date
WHERE d.continent is not NULL
ORDER BY 2, 3;

-- Looking at Total population vs New vaccinations (above) but vaccination added up by date
SELECT d.continent, 
	d.location, 
	d.date, 
	d.population, 
	v.new_vaccinations, 
	SUM(CONVERT(int, v.new_vaccinations)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) as Rolling_count_by_location
FROM dbo.CovidDeaths_mod as d
INNER JOIN dbo.CovidVaccn_mod as v
	ON d.location = v.location AND d.date = v.date
WHERE d.continent is not NULL
ORDER BY 2, 3;

-- If we want it to be in a temp table ()
DROP TABLE IF EXISTS #Rolling_vac_count_table;
/* do this first so you can modify the table */

CREATE TABLE #Rolling_vac_count_table
(
Continent nvarchar(255), 
Location nvarchar(255), 
Date datetime, 
Population numeric, 
New_vaccinations numeric, 
Rolling_count_by_location numeric,
)

INSERT INTO #Rolling_vac_count_table
SELECT d.continent, 
	d.location, 
	d.date, 
	d.population, 
	v.new_vaccinations, 
	SUM(CONVERT(int, v.new_vaccinations)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) as Rolling_count_by_location
FROM dbo.CovidDeaths_mod as d
INNER JOIN dbo.CovidVaccn_mod as v
	ON d.location = v.location AND d.date = v.date
WHERE d.continent is not NULL;

/* test the temp table */
SELECT *
FROM #Rolling_vac_count_table as r
WHERE r.Location = 'New Zealand';


--Now we are interested in the rolling vaccination rate by location, i.e., 'Rolling_count_by_location' / population * 100
/* however, we need to do a CTE for this to happen */
/* remember to select the whole thing for it to work */
/* we can also CREATE VIEW for this */

DROP VIEW IF EXISTS Rolling_vac_count;
/* do this first so you can modify the VIEW */

CREATE VIEW Rolling_vac_count
AS
WITH tmp AS
(
SELECT d.continent, 
	d.location, 
	d.date, 
	d.population, 
	v.new_vaccinations, 
	SUM(CONVERT(int, v.new_vaccinations)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) as Rolling_count_by_location
FROM dbo.CovidDeaths_mod as d
INNER JOIN dbo.CovidVaccn_mod as v
	ON d.location = v.location AND d.date = v.date
WHERE d.continent is not NULL
)
SELECT *, 
	CONVERT(DECIMAL(10, 2), (Rolling_count_by_location / t.population) * 100) as Rolling_vac_rate_by_location
FROM tmp as t
WHERE t.location IN ('Canada', 'China', 'New Zealand');

/* test the VIEW */
SELECT *
FROM Rolling_vac_count as rv
WHERE rv.Location = 'Canada';