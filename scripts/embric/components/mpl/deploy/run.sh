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
	C_DATA_DIR="${COMPONENT_NAME}_DATA_DIR"
	data_dir=${!C_DATA_DIR}
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
                        echo $rule >> $data_dir/run.rules
                else
                        echo "invalid condition $condition $error  "
                fi
        done
}	


_run(){
	#load env vars
	. /etc/profile.d/$COMPONENT_NAME

	C_DATA_DIR="${COMPONENT_NAME}_DATA_DIR"
	C_LOCAL_DIR="${COMPONENT_NAME}_LOCAL_DIR"
	
	CWL_LOCAL_DIR=${!C_LOCAL_DIR}
	CWL_DATA_DIR=${!C_DATA_DIR}
	IFS=';' read -ra plu_list <<< "$(ss-get data_urls)"
	for plu in "${plu_list[@]}"
	do
		IFS="," read -ra url_list <<< "$plu"
		if [[ "${#url_list[@]}" -eq 2 ]];then

			left_file=${url_list[0]##*/}
			right_file=${url_list[1]##*/}

			mkdir -p ${CWL_DATA_DIR}/datasets/

			#download 
			cd ${CWL_DATA_DIR}/datasets/
			curl ${url_list[0]} --output=$left_file
			curl ${url_list[1]} --output=$right_file
			
			#prepare the outputs dirs and TA PE config
			outdir=${CWL_DATA_DIR}/outputs/$pl_counter
			mkdir -p ${outdir}

			# build the Transcriptome Assembly wf pair ended yaml file
			SC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
			envsubst '${CWL_DATA_DIR},${left_file},${right_file}' <$SC_DIR/../config/TA-PE-template.yaml >${outdir}/TA-PE.yaml
			config_file=${outdir}/TA-PE.yaml
			wf_file=${CWL_LOCAL_DIR}/workflows/TranscriptomeAssembly-wf.paired-end.cwl

		#elif length= 1 RUN SE 
		#else FAILURE GO NEXT
		fi
		echo "command :	cwltool --outdir ${outdir} --basedir ${CWL_DATA_DIR} ${wf_file} ${config_file}" > ${outdir}/wf.info
		cwltool --outdir ${outdir} --basedir ${CWL_DATA_DIR} ${wf_file} ${config_file} > ${outdir}/cwl_stdout.json
		((pl_counter++))
	done

}

_run

