#!/bin/bash -xe


#the pipeline run rule is list of condition as following :
#	output_rate >< value # output rate must be member of the following  'output_rates list'
#	
#	the output_rate conditions are separated with ',' or ';' symbols to create simple condtionals
# 	
#	
#	IE : 
#	n_bases>40;n_under_200>6,proportion_n<30;
#	means continue pipeline if n_base > 40 OR if n_under_200 > 6 AND proportion_n < 30
#	
#	
#	
#		
#	

export output_rates=(n_seqs smallest largest n_bases mean_len n_under_200 n_over_1k n_over_10k n_with_orf mean_orf_percent n90 n70 n50 n30 n10 gc bases_n proportion_n fragments fragments_mapped p_fragments_mapped good_mappings p_good_mapping bad_mappings potential_bridges bases_uncovered p_bases_uncovered contigs_uncovbase p_contigs_uncovbase contigs_uncovered p_contigs_uncovered contigs_lowcovered p_contigs_lowcovered contigs_segmented p_contigs_segmented score optimal_score cutoff weighted)

store_rr(){
	#extract the list of rules
	IFS=';' read -ra rule_list <<< "$(ss-get run_rule)"
	for rule in "${rule_list[@]}"
	do
                IFS=',' read -ra cl <<< "$rule"
                unset error     
                for condition in "${cl[@]}"
                do
                        col="${condition%%[<>]*}"

                        if [[ ${output_rates[@]} =~ (^|[[:space:]])$col($|[[:space:]]) ]]
                        then
                                value="${condition##*[<>]}"
                                if [[ ! "${value}" =~ [+-]?[0-9]+\.?[0-9]* ]]
                                then
                                        error="error in condition $condition value is not a number( $value )"
                                fi
                        else
                                error="error in condition $condition $col must be in list of output_rates"
                        fi
                done
                if [[ ${error:=noerror} == "noerror" ]];then
                        echo $rule >> ${CWL_DATA_DIR}/run.rules
                else
                        echo "invalid condition $condition $error  "
                fi
        done
}	

check_rr(){
	#read rule one by one and extract 
	while read rule; do
		errors=""
		IFS=',' read -ra subrule_list <<< "$rule"
		for subrule in ${subrule_list[@]}
		do
			# for each subrule 
			#1. extract colname opérator valueo
			col="${subrule%%[<>]*}"
			thresold="${subrule##*[<>]}"
			[[ "$subrule" =~ (<|>) ]] && operator=$BASH_REMATCH
			#2. search it in $1
			real_value=$(csvcut -d, -c $col $1 |csvformat -K 1)
			#3. ensure correctness
			if [[ $(echo "${real_value}${operator}${thresold}" | bc ) -eq 0  ]]
                        then
                                error="${error:-}assembly thresold incorectness (rule $subrule  and $col value $real_value \n"
		       	fi
	 	done
		if [[ "${errors:-}" == "" ]];
		then
			valid_rules="${valid_rules:-}${valid_rules:+;}$rule"
		fi
	done < ${CWL_DATA_DIR}/run.rules
	if [[ "${error:-}" != "" ]]; then
                printf "${error:-}" > ${outdir}/assemblies.errors
        fi
	if [[ "${valid_rules:-}" == "" ]];then
		return 1
	fi

}

_run(){
	#load env vars
	SC_DIR_ABS_PATH="$( realpath $( dirname ${BASH_SOURCE[0]}))"
	. /etc/profile.d/$COMPONENT_NAME-env.sh

	C_DATA_DIR="${COMPONENT_NAME^^}_DATA_DIR"
	C_LOCAL_DIR="${COMPONENT_NAME^^}_LOCAL_DIR"

	export CWL_LOCAL_DIR=${!C_LOCAL_DIR}		
	export CWL_DATA_DIR=${!C_DATA_DIR}

	store_rr
	pl_counter=0
	IFS=';' read -ra plu_list <<< "$(ss-get data_urls)"
	for plu in "${plu_list[@]}"
	do
		IFS="," read -ra url_list <<< "$plu"
		if [[ "${#url_list[@]}" -eq 2 ]];then

			export left_file=${url_list[0]##*/}
			export right_file=${url_list[1]##*/}

			mkdir -p ${CWL_DATA_DIR}/datasets/

			#download 
			cd ${CWL_DATA_DIR}/datasets/
			curl ${url_list[0]} --output $left_file
			curl ${url_list[1]} --output $right_file
			
			#prepare the outputs dirs and TA PE config
			outdir=${CWL_DATA_DIR}/outputs/$pl_counter
			mkdir -p ${outdir}
			template_file="${SC_DIR_ABS_PATH}/../config/TA-PE-template.yaml"
			ta_config="${outdir}/TA-PE.yaml"
			envsubst '$CWL_DATA_DIR,$left_file,$right_file' < "${template_file}" > "${ta_config}"
			config_file=${outdir}/TA-PE.yaml
			wf_file=${CWL_LOCAL_DIR}/workflows/TranscriptomeAssembly-wf.paired-end.cwl
		
		#elif length= 1 RUN SE 
		#else FAILURE GO NEXT
		fi
		echo "command :	cwltool --outdir ${outdir} --basedir ${CWL_DATA_DIR} ${wf_file} ${config_file}" > ${outdir}/wf.info
		cwltool --outdir ${outdir} --basedir ${CWL_DATA_DIR} ${wf_file} ${config_file} > ${outdir}/cwl_stdout.json
                assembly_data_path=$( cat ${outdir}/cwl_stdout.json | jq -r '.transrate_output_dir.basename'/assemblies.csv )
                part_1_result=$(check_rr $assembly_data_path)
                if [[ "$(part_1_result)" -eq 0 ]];then
                        continue
                fi

		pl_counter=$((pl_counter + 1))
		
	done

}

_run

