CREATE DATABASE ENERGYDB2;
USE ENERGYDB2;

-- 1. country table
CREATE TABLE country (
    CID VARCHAR(10) PRIMARY KEY ,
    Country VARCHAR(100) UNIQUE
);

SELECT * FROM COUNTRY;
select count(CID) from country;


-- 2. emission_3 table
CREATE TABLE emission_3 (
    country VARCHAR(100),
    energy_type VARCHAR(50),
    year INT,
    emission DOUBLE,
    per_capita_emission DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
    on update cascade
    on delete cascade
);

SELECT * FROM EMISSION_3;
select distinct energy_type ,count(*)
from emission_3
group by energy_type;


-- 3. population table
CREATE TABLE population (
    countries VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (countries) REFERENCES country(Country)
    on update cascade
    on delete cascade
);

SELECT * FROM POPULATION;

-- 4. production table
CREATE TABLE production (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    production DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
    on update cascade
    on delete cascade
);


SELECT * FROM PRODUCTION;

-- 5. gdp_3 table

CREATE TABLE gdp_3 (
    Country VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (Country) REFERENCES country(Country)
    on update cascade 
    on delete  cascade
);

SELECT * FROM GDP_3;

-- 6. consumption table
CREATE TABLE consumption (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    consumption DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
    on update cascade
    on delete cascade
);

SELECT * FROM CONSUMPTION;


# General & Comparative Analysis

-- 1. What is the total emission per country for the most recent year available?

SELECT COUNTRY,SUM(EMISSION) AS TOTAL_EMISSION
FROM EMISSION_3
WHERE YEAR=(SELECT MAX(YEAR) FROM EMISSION_3)
AND ENERGY_TYPE <> 'CO2 emissions (MMtonnes CO2)'
GROUP BY COUNTRY;

/* Identifies the largest global contributors to non-CO2 emissions in the latest year, 
highlighting which nations have the most significant alternative environmental impacts.*/

select distinct(ENERGY_TYPE) from EMISSION_3;


-- 2.What are the top 5 countries by GDP in the most recent year?

SELECT country,value,RANK() OVER(ORDER BY VALUE DESC) AS GDP_RANKS
FROM GDP_3
WHERE YEAR=(SELECT MAX(YEAR) FROM GDP_3) # STATIC-ENTER YEAR=2024,DYNAMIC-USE SUBQUERY
ORDER BY VALUE DESC
LIMIT 5;

/*Pinpoints the current top global economic powers by ranking the five highest GDPs, establishing a baseline for macroeconomic comparisons.*/

-- 3.Compare energy production and consumption by country and year. 

SELECT P.COUNTRY,P.YEAR,P.PROD,C.CONSUM
FROM(SELECT COUNTRY,YEAR,SUM(PRODUCTION) AS PROD
FROM PRODUCTION
GROUP BY COUNTRY,YEAR) AS P
LEFT JOIN
(SELECT COUNTRY,YEAR,SUM(CONSUMPTION) AS CONSUM
FROM CONSUMPTION
GROUP BY COUNTRY,YEAR) AS C
ON P.COUNTRY=C.COUNTRY AND P.YEAR=C.YEAR
UNION
SELECT P.COUNTRY,P.YEAR,P.PROD,C.CONSUM
FROM(SELECT COUNTRY,YEAR,SUM(PRODUCTION) AS PROD
FROM PRODUCTION
GROUP BY COUNTRY,YEAR) AS P
RIGHT JOIN
(SELECT COUNTRY,YEAR,SUM(CONSUMPTION) AS CONSUM
FROM CONSUMPTION
GROUP BY COUNTRY,YEAR) AS C
ON P.COUNTRY=C.COUNTRY AND P.YEAR=C.YEAR;

/* Production vs Consumption: Reveals energy independence by contrasting production against consumption,
 identifying which countries run an energy surplus versus a deficit.*/
 
-- 4.Which energy types contribute most to emissions across all countries?

SELECT ENERGY_TYPE,SUM(EMISSION) AS TOTAL_CONTRIBUTION
FROM EMISSION_3
GROUP BY ENERGY_TYPE
HAVING ENERGY_TYPE <> 'CO2 emissions (MMtonnes CO2)'
ORDER BY TOTAL_CONTRIBUTION DESC;

/*  Isolates the specific energy types driving non-CO2 emissions, pointing to exactly which fuel sources require the most urgent regulatory attention. */

SELECT COUNT(*) FROM EMISSION_3;

#  Trend Analysis Over Time

-- 5.How have global emissions changed year over year?

select year,
		emission_over_year,
        emission_over_year-lag(emission_over_year) over(order by year) as trend_emission
from(SELECT YEAR,SUM(EMISSION) AS EMISSION_OVER_YEAR 
FROM EMISSION_3
where ENERGY_TYPE <> 'CO2 emissions (MMtonnes CO2)'
GROUP BY YEAR) as f;

/*  Global Emission Trend: Tracks the year-over-year global trend in non-CO2 emissions, showing whether global sustainability efforts are yielding actual reductions. */

-- 6.What is the trend in GDP for each country over the given years?

select country,year,value,value-lag(value) over(partition by country order by year) as trend_gdp
from( SELECT *
FROM GDP_3
order by country asc) as g;

/*  GDP Trend by Country: Maps the economic trajectory of individual countries by calculating year-over-year GDP growth or contraction. */

-- 7.How has population growth affected total emissions in each country?

WITH Pop_Agg AS (
    SELECT countries AS country, year, SUM(value) AS total_pop
    FROM population
    GROUP BY countries, year
),
Emi_Agg AS (
    SELECT country, year, SUM(emission) AS total_emi
    FROM emission_3
    WHERE energy_type = 'CO2 emissions (MMtonnes CO2)'
    GROUP BY country, year
)

SELECT 
    p.country,
    p.year,
    
    p.total_pop,
    ((p.total_pop / NULLIF(LAG(p.total_pop) OVER(PARTITION BY p.country ORDER BY p.year), 0)) - 1) * 100 AS pop_growth_pct,
    
    e.total_emi,
    ((e.total_emi / NULLIF(LAG(e.total_emi) OVER(PARTITION BY p.country ORDER BY p.year), 0)) - 1) * 100 AS emission_growth_pct

FROM Pop_Agg p
LEFT JOIN Emi_Agg e 
    ON p.country = e.country AND p.year = e.year
ORDER BY p.country, p.year;

/*  Population Growth vs Emissions: Correlates population shifts with CO2 emission changes, 
uncovering whether demographic growth strictly dictates a country's environmental footprint. */

-- 8.Has energy consumption increased or decreased over the years for major economies?
SELECT
    country,
    year,
    SUM(consumption) AS total_consumption,
    SUM(consumption) -
        LAG(SUM(consumption)) OVER (
            PARTITION BY country
            ORDER BY year
        ) AS yearly_change
FROM consumption
WHERE country IN ('United States', 'China', 'India', 'Japan', 'Germany')
GROUP BY country, year
ORDER BY country, year;

/*  Energy Consumption Trend: Tracks the shifting energy demands of major economic powers (US, China, India, Japan, Germany) 
to see whose industrial footprint is expanding or shrinking. */

-- 9.What is the average yearly change in emissions per capita for each country?

WITH data AS (
    SELECT
        e.country,
        e.year,
        e.emission / p.value AS emission_per_capita,
        LAG(e.emission / p.value) OVER (
            PARTITION BY e.country
            ORDER BY e.year
        ) AS previous_per_capita
    FROM emission_3 e
    JOIN population p
        ON e.country = p.countries
        AND e.year = p.year
)

SELECT
    country,
    AVG(emission_per_capita - previous_per_capita) AS avg_yearly_change
FROM data
WHERE previous_per_capita IS NOT NULL
GROUP BY country
ORDER BY avg_yearly_change DESC;

/*  Average Yearly Change in Emissions per Capita: Normalizes environmental impact by population, 
revealing the average annual change in the carbon footprint of an individual citizen in each country. */

-- Ratio & Per Capita Analysis 

-- 10.What is the emission-to-GDP ratio for each country by year? 

SELECT
    e.country,
    e.year,
    SUM(e.emission) / g.value AS emission_to_gdp_ratio
FROM emission_3 e
LEFT JOIN gdp_3 g
    ON e.country = g.country
    AND e.year = g.year
WHERE e.energy_type = 'CO2 emissions (MMtonnes CO2)'
GROUP BY e.country, e.year, g.value
ORDER BY e.country, e.year;

/*  Emission-to-GDP Ratio: Measures economic carbon efficiency, showing which countries generate the most wealth per unit of CO2 emitted. */

-- 11.What is the energy consumption per capita for each country over the last decade? 

SELECT c.country,c.year,
SUM(c.consumption) AS total_consumption,
p.Value AS population,
SUM(c.consumption) / p.Value AS consumption_per_capita
FROM consumption c
JOIN population p ON c.country = p.countries AND c.year = p.year
WHERE c.year >= YEAR (CURDATE()) - 10
GROUP BY c.country, c.year, p.Value
ORDER BY c.country, c.year;

/*  Energy Consumption per Capita: Normalizes energy usage by population over a decade, allowing for fair consumption comparisons between massively different nations. */

-- 12. How does energy production per capita vary across countries? 
 
WITH prod_table AS (
    SELECT country,year,SUM(production) AS total_production
    FROM production
    GROUP BY country, year
)
select
    p.country,p.year,p.total_production,
    pop.Value AS population,p.total_production / pop.Value AS production_per_capita
FROM prod_table p
JOIN 
population pop
ON p.country = pop.countries AND p.year = pop.year
ORDER BY production_per_capita desc;
# identifies how the production per capita(per person) looks like



-- 13.Which countries have the highest energy consumption relative to GDP?
SELECT country, SUM(consumption) AS total_consumption
FROM consumption
-- WHERE year = (SELECT MAX(year) FROM consumption)
GROUP BY country;
WITH consum AS (
    SELECT country, SUM(consumption) AS total_consumption
    FROM consumption
    WHERE year = (SELECT MAX(year) FROM consumption)
    GROUP BY country
)
SELECT c.country,
       c.total_consumption,
       g.value AS GDP,   
       c.total_consumption / g.value AS ratio
FROM consum c
JOIN gdp_3 g
  ON c.country = g.country
 AND g.year = (SELECT MAX(year) FROM gdp_3)
ORDER BY ratio DESC
LIMIT 10;

/*  Energy Consumption Relative to GDP: Identifies the most energy-intensive economies 
by calculating which top 10 countries consume the most energy relative to their economic output. */

-- 14. What is the correlation between GDP growth and energy production growth? 
WITH data AS (
    SELECT
        p.country,
        p.year,
        SUM(p.production) AS production,
        g.value AS gdp
    FROM production p
    JOIN gdp_3 g
        ON p.country = g.country
        AND p.year = g.year
    GROUP BY p.country, p.year, g.value
),

growth AS (
    SELECT
        country,
        year,
        production / LAG(production) OVER (
            PARTITION BY country ORDER BY year
        ) - 1 AS prod_growth,
        gdp / LAG(gdp) OVER (
            PARTITION BY country ORDER BY year
        ) - 1 AS gdp_growth
    FROM data
)

SELECT
    country,
    (
        COUNT(*) * SUM(prod_growth * gdp_growth)
        - SUM(prod_growth) * SUM(gdp_growth)
    )
    /
    SQRT(
        (COUNT(*) * SUM(prod_growth * prod_growth)
         - POW(SUM(prod_growth), 2))
        *
        (COUNT(*) * SUM(gdp_growth * gdp_growth)
         - POW(SUM(gdp_growth), 2))
    ) AS correlation
FROM growth
WHERE prod_growth IS NOT NULL
  AND gdp_growth IS NOT NULL
GROUP BY country;

/*  GDP Growth vs Energy Production Growth: Calculates the Pearson correlation between GDP growth and energy production,
 proving statistically how tightly a country's economic growth is bound to its energy generation. */

-- Global Comparisons 

-- 15.What are the top 10 countries by population and how do their emissions compare? 

WITH top_population AS (
    SELECT
        countries,
        value AS population,
        year
    FROM population
    WHERE year = (
        SELECT MAX(year)
        FROM population
        WHERE year IN (SELECT year FROM emission_3)
    )
    ORDER BY value DESC
    LIMIT 10
)

SELECT
    p.countries,
    p.population,
    COALESCE(SUM(e.emission), 0) AS total_emission
FROM top_population p
LEFT JOIN emission_3 e
    ON p.countries = e.country
    AND p.year = e.year
GROUP BY p.countries, p.population
ORDER BY p.population DESC;

/*  Top 10 Countries by Population: Contrasts the world's 10 most populous nations against their total emissions, 
evaluating if sheer population size is the primary driver of environmental impact. */

-- 16.Which countries have improved (reduced) their per capita emissions the most over the last decade? 
WITH emission AS (
    SELECT country, year, SUM(emission) AS total_emission
    FROM emission_3
    WHERE energy_type <> 'CO2 emissions (MMtonnes CO2)'
    GROUP BY country, year
),
per_cap AS (
    SELECT e.country,
           e.year,
           e.total_emission / p.value AS emission_per_capita
    FROM emission e
    JOIN population p
      ON e.country = p.countries
     AND e.year = p.year
),
change_in_emi AS (
    SELECT country,
           year,
           emission_per_capita,
           emission_per_capita -
           LAG(emission_per_capita)
           OVER (PARTITION BY country ORDER BY year) AS yearly_change
    FROM per_cap
)
SELECT country,
       AVG(yearly_change) AS avg_yearly_change
FROM change_in_emi
GROUP BY country
ORDER BY avg_yearly_change;

/* Countries with Reduced Per-Capita Emissions: Highlights the most successfully improving nations by finding who has reduced their per-capita emissions the most, 
showcasing effective sustainability policies. */


-- 17. What is the global share (%) of emissions by country? 

select country,(sum(emission)/(select sum(emission) from emission_3))*100 as percentage
from emission_3
group by country
order by percentage desc;

/*  Global Share of Emissions: Determines the global distribution of emissions,
 pinpointing exactly what percentage of the world's pollution is owned by each nation. */


-- 18.What is the global average GDP, emission, and population by year?
 
 WITH population_avg AS (
    SELECT year, AVG(value) AS avg_p
    FROM population
    GROUP BY year
),

gdp_avg AS (
    SELECT year, AVG(value) AS avg_g
    FROM gdp_3
    GROUP BY year
),

emission_avg AS (
    SELECT year, AVG(emission) AS avg_e
    FROM emission_3
    WHERE energy_type <> 'CO2 emissions (MMtonnes CO2)'
    GROUP BY year
)

SELECT
    p.year,
    p.avg_p,
    g.avg_g,
    e.avg_e
FROM population_avg p
LEFT JOIN gdp_avg g
    ON p.year = g.year
LEFT JOIN emission_avg e
    ON p.year = e.year
ORDER BY p.year;


/*  Global Average GDP, Emission & Population: Provides a macro-level macroeconomic and environmental summary by averaging
 global GDP, emissions, and population over time to track worldwide baseline shifts. */
