/*******************************************************************************
********************************************************************************
* THIS FILE IS DESIGNED TO RUN A DIFFERENCE-IN-DIFFERENCE ANALYSIS
* THIS FILE IS FOR USE IN A SCENARIO WHERE THERE ARE MULTIPLE TREATMENT PERIODS
* AND OBSERVATIONS ARE PART OF BOTH THE TREATMENT AND CONTROL GROUP DEPENDING
* ON THE TIME OF OBSERVATION
********************************************************************************
*******************************************************************************/
* THIS CODE IS OWNED BY AIDDATA. PLEASE DO NOT SHARE
/*******************************************************************************
THIS SECTION IS FOR THE USER TO DEFINE MACROS SPECIFIC TO THEIR DIFFERENCE-IN-
DIFFERENCE ANALYSIS

THESE MACROS ARE NEEDED TO MAKE THE DO-FILE RUN
*******************************************************************************/

// DECLARE FILE PATHS

//set file path for folder storing data needed for difference-in-difference
global data ""
//set file path for data file stored in data folder (should be fully cleaned and
//in dta format)
global datafile ""
//set file path for folder storing log files from this do-file
global logs ""
//set file path for folder storing tables outputed from this do-file
global tables ""
//set file path for folder storing figures outputed from this do-file
global figures ""

// Example:
// global data "C:\Users\username\projectname\data\"
// global datafile "dataset_clean.dta"
// global logs "C:\Users\username\projectname\logs\"
// global tables "C:\Users\username\projectname\output\tables\"
// global figures "C:\Users\username\projectname\output\figures\"


// DECLARE VARIABLES NEEDED IN DIFFERENCE-IN-DIFFERENCE

//set global to name(s) of dependent/outcome/left-hand-side variable(s) (can be
//one or multiple; if multiple are used, multiple difference-in-difference
//analyses will be run)
global outcome ""
//set global to name of binary variable indidcating whether an observation has
//been treated at the time of observation 
global treated ""
//set global to label of binary treated variable desired for output
global treated_label ""
//set global to name(s) of control variable(s) (can be empty)
global control ""
//set global to name of temporal fixed effect variable (should not be empty)
global fixedeffect_temporal ""
//set global to name of geospatial fixed effect variable (should not be empty)
global fixedeffect_geospatial ""
//set global to cluster-level for clustered SEs
global cluster ""
//set global for sample restriction (should be if statement; if no sample
//restriction, should be empty string)
global sample ""
//set global for weight type (could be aweight, fweight, iweight or pweight;
//leave as an empty string if no weight)
global weight_type ""
//set global for weight variable if weight type is specified
global weight ""

// Example:
// global outcome "ndvi builtup"
// global treated "post_treatment"
// global treated_label "Observed After Nearest Project Site Completed"
// global control "rainfall"
// global fixedeffect_temporal "year"
// global fixedeffect_geospatial "gridcell"
// global cluster "gridcell year"
// global sample "if distance_project < 0.1"
// global weight_type ""
// global weight ""

// DECLARE OPTIONS FOR TABLES AND FIGURES

//set table output type (doc, xlsx, tex)
global table_type ""
//set graph output type (png, svg, pdf, jpg)
global graph_type ""
//set output note
global output_note ""

// Example:
// global table_type "doc"
// global graph_type "pdf"
// global output_note "Sample includes children under 5 years of age living within 10 km of a project. SEs clustered two-way by project site and cohort. * p<0.1, ** p<0.05, *** p<0.01"

/*******************************************************************************
THIS SECTION IS FOR THE USER TO CHOOSE WHICH PARTS OF THE DO-FILE TO RUN

TO RUN A CERTAIN PART, SET THAT GLOBAL EQUAL TO 1. OTHERWISE, SET TO 0.
*******************************************************************************/

global run_did_regressions = 1
	global output_tables = 1
	global output_graphs = 1

/*******************************************************************************
FILE SETUP
*******************************************************************************/
clear
capture log close
cd "${logs}"
log using "difference_in_difference.log", replace
ssc install reghdfe
ssc install outreg2

/*******************************************************************************
DIFFERENCE-IN-DIFFERENCE REGRESSION
*******************************************************************************/
if ${run_did_regressions} == 1 {
	
	//load data
	cd "${data}"
	use "${datafile}", clear	
	
	//generate weight text
	if "${weight_type}" != "" {
		global weight_text = "[${weight_type}=${weight}]"
	}
	else {
		global weight_text = ""
	}
	
	//if there are no fixed effects specified, run difference-in-difference
	//regression using regress command
	if "${fixedeffect_temporal}" == "" & "${fixedeffect_geospatial}" == "" {
		//run difference-in-data for each outcome/dependent variable using 
		//pre-specified independent variables, control variables, and cluster
		//for SEs
		foreach o of global outcome {
			reg `o' ${treated} ${control} ${sample}, vce(cluster ${cluster})
			//store regression with outcome suffix
			est store `o'
			// output table for each outcome separately
			cd "${tables}"
			if ${output_tables} == 1 {
				outreg2 using "did_`o'.${table_type}", replace label ///
					addnote("${output_note}") drop(${control})
			}

		//output coefficient plot for each outcome separately
			cd "${figures}"
			if ${output_graphs} == 1 {
				foreach o of global outcome {
					coefplot, note("${output_note}") drop(_cons ${control}) ///
						xline(0) xlabel(0,add)
					graph export "did_`o'.${graph_type}", replace as(${graph_type}) 
				}
			}
		}
	}
	
	//if there are fixed effects specified, run difference-in-difference
	//regression using reghdfe command
	else {
		//run difference-in-data for each outcome/dependent variable using 
		//pre-specified independent variables, control variables, fixed effects,
		//and cluster for SEs
		foreach o of global outcome {
			reghdfe `o' ${treated} ${control} ${sample}, ///
				absorb(${fixedeffect_temporal} ${fixedeffect_geospatial}) ///
				vce(cluster ${cluster})
		//store regression with outcome suffix		
		est store `o'	
		// output table for each outcome separately 
		cd "${tables}"
		if ${output_tables} == 1 {
				outreg2 `o' using "did_`o'.${table_type}", replace label ///
				addnote("${output_note}") nocon drop(${control})
		}
		//output coefficient plot for each outcome separately
		cd "${figures}"
		if ${output_graphs} == 1 {
		foreach o of global outcome {
			coefplot `o', note("${output_note}") drop(_cons ${control}) ///
				xline(0) xlabel(0,add)
			graph export "did_`o'.${graph_type}", replace as(${graph_type})
				}
			}
		}
   }
	
}	

/*******************************************************************************
FILE CLOSE
*******************************************************************************/
capture log close