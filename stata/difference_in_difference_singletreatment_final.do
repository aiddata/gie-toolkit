/*******************************************************************************
********************************************************************************
* THIS FILE IS DESIGNED TO RUN A DIFFERENCE-IN-DIFFERENCE ANALYSIS
* THIS FILE IS FOR USE IN A SCENARIO WHERE THERE IS A SINGLE TREATMENT PERIOD
* AND A CLEARLY DEFINED TREATMENT AND CONTROL GROUP
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
//set global to name of temporal binary variable (usually designates an
//observation occurs after treatment)
global after ""
//set global to label of temporal binary variable desired for output
global after_label ""
//set global to name of treatment group binary variable (usually designates an
//observation is in the treatment group)
global treatmentgroup ""
//set global to label of treatment group binary variable desired for output
global treatmentgroup_label ""
//set global to name(s) of control variable(s) (can be empty)
global control ""
//set global to name of temporal fixed effect variable (can be empty if no
//temporal fixed effect is desired)
global fixedeffect_temporal ""
//set global to name of geospatial fixed effect variable (can be empty if no
//geospatial fixed effect is desired)
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
// global outcome "child_stunting child_wasting anemia"
// global after "after_project"
// global after_label "After Project Completion"
// global treatmentgroup "near_project"
// global treatmentgroup_label "Lives Close to Project Site"
// global control "rainfall"
// global fixedeffect_temporal "province_year"
// global fixedeffect_geospatial "project_id"
// global cluster "project dob_year"
// global sample "if distance_project < 0.1 & age < 5"
// global weight_type "pweight"
// global weight "sampleweight"

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
	
	//generate and label independent variables for difference-in-difference
	//regression
	label var ${after} "${after_label}"
	label var ${treatmentgroup} "${treatmentgroup_label}"
	gen after_treated = ${after}*${treatmentgroup}
	label var after_treated "${treatmentgroup_label} * ${after_label}"
	
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
		//run difference-in-difference for each outcome/dependent variable using 
		//pre-specified independent variables, control variables, and cluster
		//for SEs
		foreach o of global outcome {
			reg `o' ${after} ${treatmentgroup} after_treated ${control} ///
				${sample} ${weight_text}, vce(cluster ${cluster})
			//store regression with outcome suffix
			est store `o'
		}
	}
	//if there are fixed effects specified, run difference-in-difference
	//regression using reghdfe command
	else {
		//run difference-in-difference for each outcome/dependent variable using 
		//pre-specified independent variables, control variables, fixed effects,
		//and cluster for SEs
		foreach o of global outcome {
			reghdfe `o' ${after} ${treatmentgroup} after_treated ${control} ///
				${sample} ${weight_text}, ///
				absorb(${fixedeffects_temporal} ${fixedeffect_geospatial}) ///
				vce(cluster ${cluster})
			est store `o'	
		}
	}
	
	if ${output_tables} == 1 {
		//output table for each outcome separately
		cd "${tables}"
		foreach o of global outcome {
			outreg2 `o' using "did_`o'.${table_type}", replace label ///
				addnote("${output_note}") nocon drop(${control}) 
		}
	}
	
	if ${output_graphs} == 1 {
		//output coefficient plot for each outcome separately
		cd "${figures}"
		foreach o of global outcome {
			coefplot `o', note("${output_note}") drop(_cons ${control}) ///
				xline(0) xlabel(0,add)
			graph export "did_`o'.${graph_type}", replace as(${graph_type})
		}
	}
}

/*******************************************************************************
FILE CLOSE
*******************************************************************************/
capture log close