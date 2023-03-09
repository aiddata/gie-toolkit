/*******************************************************************************
********************************************************************************
* THIS FILE IS DESIGNED TO RUN A PRE-TREND TEST FOR A DIFFERENCE-IN-DIFFERENCE
* ANALYSIS. THIS FILE WILL CONSIDER THE PARALLEL TRENDS ASSUMPTION. THIS FILE
* IS DESIGNED FOR USE IN DIFFERENCE-IN-DIFFERENCE ANALYSIS WITH ONE TREATMENT
* PERIOD AND A DISTINCT TREATMENT AND CONTROL GROUP.
********************************************************************************
*******************************************************************************/
* THIS CODE IS OWNED BY AIDDATA. PLEASE DO NOT SHARE
/*******************************************************************************
THIS SECTION IS FOR THE USER TO DEFINE MACROS SPECIFIC TO THEIR PRE-TREND TEST

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
//set global to name of temporal variable (we recommend usage of a year
///variable, but could be another format such as century month code)
global time ""
//set global to value of time variable for which treatment occurred
global time_treatment ""
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
// global outcome "anemia diarrhea fever_cough"
// global time "year"
// global time_treatment "2013"
// global treatmentgroup "near_project"
// global treatmentgroup_label "Lives Close to Project Site"
// global control "rainfall"
// global fixedeffect_temporal "province_year"
// global fixedeffect_geospatial "project_id"
// global cluster "project year"
// global sample "if distance_project < 0.1 & age < 5"
// global weight_type "pweight"
// global weight "sampleweight"

// DECLARE OPTIONS FOR TABLES AND FIGURES

//set table output type (doc, xlsx, tex)
global table_type ""
//set graph output type (png, svg, pdf, jpeg)
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

global run_pretrend_graph = 1
	global output_graphs = 1

/*******************************************************************************
FILE SETUP
*******************************************************************************/
clear
capture log close
cd "${logs}"
log using "pre_trends.log", replace
ssc install reghdfe
ssc install outreg2

/*******************************************************************************
PRE-TRENDS GRAPH
*******************************************************************************/
if ${run_pretrend_graph} == 1 {
	
	//load data
	cd "${data}"
	use "${datafile}", clear	

	//create different sample restrictions for treatment and control group
	//pre-trends
	if "${sample}" == "" {
		local sample_control = "if ${treatmentgroup} == 0"
		local sample_treatment = "if ${treatmentgroup} == 1"
	}
	else {
		local sample_control = "${sample} & ${treatmentgroup} == 0"
		local sample_treatment = "${sample} & ${treatmentgroup} == 1"
	}
	
	//generate weight text
	if "${weight_type}" != "" {
		global weight_text = "[${weight_type}=${weight}]"
	}
	else {
		global weight_text = ""
	}
	
	//rough pre-trends with no fixed effects or controls
	foreach o of global outcome {	
		preserve
		local outcome_lbl: variable label `o'
		local time_lbl: variable label ${time}
		collapse (mean) `o' ${sample} ${weight_text}, by(${time} ///
			${treatmentgroup})
		drop if ${time} >= ${time_treatment}
		separate `o', by(${treatmentgroup})
		twoway (connected `o'0 ${time}) (connected `o'1 ${time}), ///
		legend(order(1 "Control Group" 2 "Treatment Group")) ///
		ytitle("`outcome_lbl'") xtitle("`time_lbl'")
		//output graph
		if ${output_graphs} == 1 {
			cd ${figures}
			graph export "`o'_basicpretrend.${graph_type}", replace as(${graph_type})
		}
		restore
	}
	
	//identify first year observed during/after treatment for base
	levelsof ${time}, local(time_lvls)
	local base_time = -99
	local count = 0
	foreach l of local time_lvls {
		if `base_time' == -99 & ${time_treatment} <= `l' {
			local base_time = `l'
			local base_step = `count'
		}
		local count = `count' + 1
	}
	
	//if there are no fixed effects specified, run pre-trends regression using
	//regress command
	if "${fixedeffect_temporal}" == "" & "${fixedeffect_geospatial}" == "" {
		//find time trend for each outcome/dependent variable using control 
		//variables, and cluster for SEs
		foreach o of global outcome {
			reg `o' ib`base_time'.${time} ${control} `sample_control' ///
				${weight_text}, vce(cluster ${cluster})
			//store regression with outcome suffix
			est store `o'0
			reg `o' ib`base_time'.${time} ${control} `sample_treatment' ///
				${weight_text}, vce(cluster ${cluster})
			//store regression with outcome suffix
			est store `o'1
		}
	}
	
	//if there are fixed effects specified, run pre-trends regression using
	//reghdfe command
	else {
		//find time trend for each outcome/dependent variable using control 
		//variables, fixed effects, and cluster for SEs
		foreach o of global outcome {
			reghdfe `o' ib`base_time'.${time} ${control} `sample_control' ///
				${weight_text}, ///
				absorb(${fixedeffect_temporal} ${fixedeffect_geospatial}) ///
				vce(cluster ${cluster})
			est store `o'0	
			reghdfe `o' ib`base_time'.${time} ${control} `sample_treatment' ///
				${weight_text}, ///
				absorb(${fixedeffect_temporal} ${fixedeffect_geospatial}) ///
				vce(cluster ${cluster})
			est store `o'1	
		}
	}
	
	//output graph
	if ${output_graphs} == 1 {
		foreach o of global outcome {
			coefplot (`o'1, recast(connected)) (`o'0, recast(connected)), keep(*.${time}) vert base omitted nooffsets plotlabels("Treatment Group" "Control Group") xline(`base_step')
			if ${output_graphs} == 1 {
			cd ${figures}
			graph export "`o'_pretrend.${graph_type}", replace as(${graph_type})
		}
		}
	}
	
	
}

/*******************************************************************************
FILE ClOSE
*******************************************************************************/
capture log close