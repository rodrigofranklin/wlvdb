Summary

Open Science project to develop, implement and improve methodologies to obtain values (marxian, sraffian ...) and categorical concepts estimates based on world - level public available information such as World Input Output matrices, KLEMS, cepal io data. Further extensions to include EXIOBASE, better estimates available for more countries.

When using the data, please cite:

FRANKLIN, R.;BORGES, R,; SÁNCHEZ, C.; MONTIBELER, E. Skilled labour and the reduction problem: questioning the exploitation rate equalization hypoyhesis. _World Review of Political Economy_ (in press), 2022.



Also included preliminary estimates on:
- Unequal Exchange;
- Exploitation rates;
- Profit rates;
- different approximation to values - direct prices, sraffian prices

Available by region, country and sector from 1995 to 2014, or from 1990 to 2024 , depending of source' s 




# current stage of the project

Four data sources already included:

- World Input Output Database release 2013 (WIOD13)
- World Input Output Database release 2016 (WIOD16)
- EXIOBASE (v 3.8.2, v. 3.7, v.3.8.1)*
- EORA26*

 *work in progress

## Autostart and main function

When the project is opened, it automatically:

- detects which packages are not installed, installs them silently;
- sources R/main.R script, which loads the function **get_wlv**
- Provides a Welcome message

### get_wlv function

get_wlv is a function that wraps all calculations and outputs files to the results folder with all variables, and arrays with Country and Sector Socio-Economic Accounts(SEAs).


For example, to calculate the current standard procedure with WIOD16 data, one only needs to call get_wlv("WIOD13").

The function accepts the following arguments:

* methods - a string or a character vector like c("WIOD13","WIOD16") for the methods to be calculated. Defaults to "WIOD13"
* repeat_pp - boolean to indicate if full download and preparation of source data should be performed . Defaults to FALSE
* papern - number of the paper to eventually trigger further tables and/or graphs that compare different methods, cross-sectional and longitudinal indicators, any custom analysis to be included in the paper referred to by the same number.
* prepaper - wether to actually trigger the preparation of such custom analysis (calls corresponding script from papers/ folder)


 ## Repository Folder Structure
 1) source_data - to be downloaded separatedly from gitlab -  [link here](https://cloud.worldlabourvalues.org/s/wjMfkBXDnptADXF)

Folder with data downloaded from primary input-output tables sources.

The data in this folder is also formatted to keep a tractable structure from different sources to the virtually same processing 

Data is also formatted to


 2) parameters
 
 Folder with few parameters, organized in subfolders,
global parameters (common_ground subfolder) and general parameters for each of primary IO sources.
For each source, eg. WIOD13:


* _source_assumptions.csv - indicates how to deal to estimate important (and missing from source) info,currently mainly Rest of the World and China info on labour
* _source_matrices.csv - indicates how to deal mainly to infer Kapital and Depreciation Matrices
* _source_solutions.csv - indicates variables to be calculated and corresponding procedure for the estimate



 
These parameters are  to be used if no different specific definition is provided in any one method that uses the source

 3) methods
 
 The first and reference paper shows how the same source can be subject to different methods. In that case, different methods to convent from concrete to abstract labour time.
 
 One of the features of the World Labour Values Database is the ease to create, apply and compare different methods for estimating categories. As such, it provides subsidiary complement to theoretical discussions.
 
The subfolders in methods refer to a specific method. Their structure is similar to parameters:


* _method_assumptions.csv - indicates how to deal to estimate important (and missing from source) info,currently mainly Rest of the World and China info on labour
* _method_matrices.csv - indicates how to deal mainly to infer Kapital and Depreciation Matrices
* _method_solutions.csv - indicates variables to be calculated and corresponding procedure for the estimate
 
 Additionaly, there is a sectors.csv file indicating which sectors should be considered productive an unproductive.
 
 
 
 4) results - to be downloaded separatedly if one wants to check results already arrived by our team - [ink here](https://coletiva.imperialismoedependencia.org/s/NMMDyMxL8fWxfjq)
 
 The results of calculations get saved as files in subfolders named by the method that generated them.
 
 The variables are either saved in:
 
 m_io files (in values, for ex), if sectorial , m_countries, if national 
 SEA_countries and SEA_sectors arrays
 
 
 5) papers
A number would be suggested to be linked to a specific analysis for, say, a paper
From results, one can filter some indicators, regions, and produce new calculus - for example in reference paper, we estimate all distance measures from market prices and direct prices



6) R

Folder with  scripts

- lib
- modules
  - assumptions
  - matrices
  - reduced_matrices
  - variables
-utils

each subfolder will be structured in common and source or method specific scripts.