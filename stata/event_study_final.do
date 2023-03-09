/*******************************************************************************
********************************************************************************
* THIS FILE IS DESIGNED TO RUN AN EVENT STUDY ANALYSIS
********************************************************************************
*******************************************************************************/
* THIS CODE IS OWNED BY AIDDATA. PLEASE DO NOT SHARE
/*******************************************************************************
THIS SECTION IS FOR THE USER TO DEFINE MACROS SPECIFIC TO THEIR EVENT STUDY
ANALYSIS

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


// DECLARE VARIABLES NEEDED IN EVENT STUDY

//set global to name(s) of dependent/outcome/left-hand-side variable(s) (can be
//one or multiple; if multiple are used, multiple event study analyses will be 
//run)
global outcome ""
//set global to name of continuous numeric variable that designates time of
//treatment for observation (we recommend usage of a year variable, but could be
//another format such as century month code; must be in same unit as
//time_observation variable below)
global time_treatment ""
//set global to label of time_treatment variable desired for output
global time_treatment_label ""
//set global to name of continuous numeric variable that designates time of
//observation (we recommend usage of a year variable, but could be another
//format such as century month code; must be in same unit as time_treatment
//variable above)
global time_observation ""
//set global to label of time_observation variable desired for output
global time_treatment_label ""
//set global to a list of time steps desired for event study (must be in same 
///units as time_treatment and time_observation variables and include 0 for the
///base; should include both negative and positive numbers ordered from lowest
///value to highest value; each step must be separated by a space)
global time_steps ""
//set global to name(s) of control variable(s) (can be empty)
global control ""
//set global to name of temporal fixed effect variable
global fixedeffect_temporal ""
//set global to name of geospatial fixed effect variable
global fixedeffect_geospatial ""
//set global to cluster-level for clustered SEs
global cluster  ""
//set global for sample restriction (should be if statement; if no sample
//restriction, should be empty string)
global sample ""
//set global for weight type (could be aweight, fweight, iweight or pweight;
//leave as an empty string if no weight)
global weight_type ""
//set global for weight variable if weight type is specified
global weight ""

// Example:
// global outcome "conflict protests"
// global time_treatment "project_complete"
// global time_treatment_label "Year Project Completed"
// global time_observation "year"
// global time_observation_label "Year Observed"
// global time_steps "-50 -10 -5 -1 0 1 5 10 50"
// global control "rainfall"
// global fixedeffect_temporal "province_year"
// global fixedeffect_geospatial "project"
// global cluster "project year"
// global sample ""
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

global run_event_study = 1
	global output_tables = 1
	global output_graphs = 1

/*******************************************************************************
FILE SETUP
*******************************************************************************/
clear
capture log close
cd "${logs}"
log using "eventstudy.log", replace
ssc install reghdfe
ssc install outreg2

/*******************************************************************************
EVENT STUDY ANALYSIS
*******************************************************************************/
if ${run_event_study} == 1 {
	
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
	
	//generate time to treatment variable
	gen time_to_treat = ${time_observation} - ${time_treatment}
	label var time_to_treat "${time_observation_label} - ${time_treatment_label}"
	summ time_to_treat
	local step_start = r(min)
	local step_end = r(max)
	
	//generate categorical version of time to treat variable for time steps
	egen time_to_treat_cat = cut(time_to_treat), at(`step_start' ${time_steps} `step_end')
	display "`step_start' ${time_steps} `step_end'"
	tab time_to_treat_cat
	
	//recode categorical version of time to treat variable for time steps
	local steps = wordcount("${time_steps}")
	
	local step_0 = `step_start'
	local temp = word("${time_steps}", 1)
	local step_0_label = "< `temp'"
	local recode_string = "(`step_0' = 0)"
	label define time_to_treat_cat_lbl 0 "`step_0_label'"
	forvalues s = 1/`steps' {
		local r = `s'-1
		local t = `s'+1
		local step_`s' = word("${time_steps}", `s')
		local step_`t' = word("${time_steps}", `t')
		if `s' != `steps' {
			local step_`s'_label = "`step_`s'' to `step_`t''"
			if word("${time_steps}", `s') == "0" {
				local step_base = `s'
			}
			local recode_string = "`recode_string' (`step_`s'' = `s')"
		}
		else {
			local step_`s'_label = "> `step_`s''"
		} 
		label define time_to_treat_cat_lbl `s' "`step_`s'_label'", modify
	}	
	
	display "`recode_string'"
	recode time_to_treat_cat `recode_string'
	label list time_to_treat_cat_lbl
	label values time_to_treat_cat time_to_treat_cat_lbl
	label var time_to_treat_cat "Time to Treatment"
	tab time_to_treat_cat
	
	display "`step_base'"
	
	
	//if there are no fixed effects specified, run event study analysis using
	//regress command
	if "${fixedeffect_temporal}" == "" & "${fixedeffect_geospatial}" == "" {
		//run event study analysis for each outcome/dependent variable using 
		//pre-specified control variables and cluster for SEs
		foreach o of global outcome {
			reg `o' ib`step_base'.time_to_treat_cat ${control} ${sample} ///
				${weight_text},	vce(cluster ${cluster})
			//store regression with outcome suffix
			est store `o'
		}
	}
	//if there are fixed effects specified, run event study analysis using 
	//reghdfe command
	else {
		//run event study analysis for each outcome/dependent variable using 
		//pre-specified control variables, fixed effects, and cluster for SEs
		foreach o of global outcome {
			reghdfe `o' ib`step_base'.time_to_treat_cat ${control} ${sample} ///
				${weight_text},
				absorb(${fixedeffect_temporal} ${fixedeffect_geospatial}) ///
				vce(cluster ${cluster})
			est store `o'	
		}
	}
	
	if ${output_tables} == 1 {
		//output table for each outcome separately
		cd "${tables}"
		foreach o of global outcome {
			outreg2 `o' using "event_study_`o'.${table_type}", replace label ///
				addnote("${output_note}") nocon
		}
	}
	
	if ${output_graphs} == 1 {
		//output coefficient plot for each outcome separately
		cd "${figures}"
		foreach o of global outcome {
			coefplot `o', keep(*.time_to_treat_cat) vertical base ///
				 yline(0) xline(`step_0') ///
				note("${output_note}")
			graph export "event_study_`o'.${graph_type}", replace as(${graph_type})
		}
	}
}

/*******************************************************************************
FILE ClOSE
*******************************************************************************/
capture log close