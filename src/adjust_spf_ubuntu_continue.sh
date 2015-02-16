#!/bin/sh

#Conservation features
#Cost layer (aggregate 25m to 200m)
#targets and target combinations

#Set Folder containing Marxan and data
mfolder=.
input_folder=input
#Move to Marxan folder
#echo $mfolder
#cd $mfolder/

#Make a backup of input data
if [ ! -d "${mfolder}/input_backup" ] ; then
	##mkdir input_backup
	cp -r "${mfolder}/${input_folder}" "${mfolder}/input_backup"
fi

if [ ! -f "${mfolder}/input_backup.dat" ] ; then
	cp "${mfolder}/input.dat" "${mfolder}/input_backup.dat"
fi

#Create a folder for output sumary data
if [ ! -d "${mfolder}/output_sum" ] ; then
	mkdir output_sum
fi

#Create a folder for output sumary data
if [ ! -d "${mfolder}/output" ] ; then
	mkdir output
#else
	#Make sure output folder is empty
#	rm -rf "${mfolder}/output"
#	mkdir "${mfolder}/output"
fi


#rm "${mfolder}/adj.log"

#echo '"Eligible","BLM","Habitat Target","Species Target","Run Number","Score","Cost","Planning Units","available PuCount","AEM extensification PuCount","available Cost","AEM extensification Cost","Connection Strength","Penalty","Shortfall","Missing_Values","MPM"' > ${mfolder}/output_sum/output_sum.csv
#echo '"Eligible","BLM","Habitat Target","Species Target","Feature","Feature Name","Target","Total Amount","Contributing Amount Held","Occurrence Target ","Occurrences Held","Target Met","Target available","Amount Held available","Contributing Amount Held available","Occurrence Target available","Occurrences Held available","Target Met available","Target AEM extensification","Amount Held AEM extensification","Contributing Amount Held AEM extensification","Occurrence Target AEM extensification","Occurrences Held AEM extensification","Target Met AEM extensification","MPM"' > ${mfolder}/output_sum/output_mvbest.csv

for l in all #only_open
do
	#Create relevant initial lockfile
	#echo puid,zoneid > "${mfolder}/${input_folder}/pulock.dat"
	
	#if [ "$l" == "all" ] ; then
	#	r.stats -1 -n --verbose input=PU,SPA_SAC_rel_200m separator="," | sort -n -t "," >> "${mfolder}/${input_folder}/pulock_pre1.dat"
#Natura 2000 areas?
#Lock to open montado areas?
	#else
	#	r.stats -1 -n --verbose input=PU,SPA_SAC_rel_200m separator="," | sort -n -t "," >> "${mfolder}/${input_folder}/pulock_pre1.dat"
	#fi
	
	#Set BLM to different possible alternatives
	for b in 1000000000000 #1000 100000 10000000 #0 0.00001 0.001 0.1 1 10
	do
		
		if [ $b -eq 0 ] ; then
			cat "${mfolder}/input_backup.dat" | sed "s#^BLM.*#BLM $b#" > "${mfolder}/input.dat.pre"
			cat "${mfolder}/input.dat.pre" | sed "s/BOUNDNAME/#BOUNDNAME/" > "${mfolder}/input.dat"
		else
			cat "${mfolder}/input_backup.dat" | sed "s#^BLM.*#BLM $b#" > "${mfolder}/input.dat"
		fi
		
		#Set target level 25%, 50%, 75%, 100% of each feature
		
		#############
		#Define targets
		for ht in 0.10 0.30 0.50 0.70 0.80 
		do
			for st in 0.1 0.3
			do
				if [ -d output_eligible_${l}_BLM${b}_ht${ht}_st${st} ] ; then
					continue
				fi
				#Make sure that only 10 runs are used for adjusting SPF
				cp "${mfolder}/input.dat" "${mfolder}/input.dat.tmp"
				cat "${mfolder}/input.dat.tmp" | sed '/NUMREPS/c\NUMREPS 10' > "${mfolder}/input.dat"
				rm "${mfolder}/input.dat.tmp"
				
				#Write target level to feat.dat
				cat "${mfolder}/input_backup/feat.dat" | head -n 1 > "${mfolder}/${input_folder}/feat.dat"
				cat "${mfolder}/input_backup/feat.dat" | awk -v FS="," -v OFS="," -v T=$ht '{if(NR==2) print $1, T, $3, $4}' >> "${mfolder}/${input_folder}/feat.dat"
				cat "${mfolder}/input_backup/feat.dat" | awk -v FS="," -v OFS="," -v T=$st '{if(NR>=3) print $1, T, $3, $4}' >> "${mfolder}/${input_folder}/feat.dat"
				
				#Create lockfile for target-level where the best run from the previous scenario is locked in
				cp "${mfolder}/input_backup/pulock.dat" "${mfolder}/${input_folder}/pulock.dat"
				#if [ "$ht" == "0.10" ] ; then
					#cat "${mfolder}/${input_folder}\pulock_pre1.dat" | sort -n -t "," -k 1,2 >> "${mfolder}/${input_folder}/pulock.dat"
				#else
					#cat "${mfolder}/${input_folder}\pulock_pre1.dat" > "${mfolder}/${input_folder}/pulock_pre2.dat"
					#r.stats -1 -n --verbose input=pu,scenario_best_tmp separator=" " | awk -v FS="," '{if($2==2) print $0}' >> "${mfolder}/${input_folder}/pulock_pre2.dat"
					#cat "${mfolder}/${input_folder}/pulock_pre2.dat" | sort -n -t "," -k 1,2 | uniq >> "${mfolder}/${input_folder}/pulock.dat"
				#fi
				
				#Initial marzone run (SPF should be set low enough so targets are not met(yet))
				#perl -e 'alarm shift @ARGV; exec @ARGV' 60 ./MarZone_v201_Linux64 &
				cat "${mfolder}/${input_folder}/feat.dat"
				#Run MarZone in the background
				#./MarZone_v201_Linux64 &
				#wait
				
				cp "${mfolder}/${input_folder}/feat.dat" "${mfolder}/${input_folder}/feat.dat.old"
				
				#Adjust SPF per feature
				for factor in 10000000000 10 1 0.1
				do
				
					#Adjust SPF
					targets_missed=20
					i=0
					addition=$(echo $factor | awk '{if($1<=1) print 1}')
					factor1=$(echo $factor | awk '{if($1==1) print 1}')
					if [ "$factor1" ] ; then
						if [ $factor1 -eq 1 ] ; then
							if [ $i -eq 0 ] ; then
								cat "${mfolder}/${input_folder}/feat.dat.old" | cut -f1,3 -d',' | tail -n +2 > "${mfolder}/feat_add.tmp"
							fi
						fi
					fi
					
					#Adjust SPF by given factor if missing targets in more than X (here 2) runs
					while [ $targets_missed -gt 2 ]
					do
						#Distinguish factor > 1 and <= 1
						
						#Set SPF
						echo "id,prop,spf,name" > "${mfolder}/${input_folder}/feat.dat"
						
						#WHAT IF MVBEST does not contain any shortfall?
						for s in $(cat "${mfolder}/input_backup/feat.dat" | cut -f4 -d',' | tail -n +2)
						do
							if [ $i -gt 0 ] ; then
								if [ $(ls output/openmontado_mv0* | wc -l) -gt 0 ] ; then
									number_nonmet=$(grep -e $s output/openmontado_mv0* | awk -v FS=',' -v OFS=',' -v S=$s '{if($2==S && $8=="no") print $0}' | wc -l)
								else
									number_nonmet=999999
								fi
							else
								number_nonmet=999999
							fi
							#create line in factor.tmp
							if [ $number_nonmet -gt 1 -o $i -eq 0 ] ; then
								if [ -z $addition ] ; then
									cat "${mfolder}/${input_folder}/feat.dat.old" | awk -v FS=',' -v OFS=',' -v F=$factor -v S=$s '{if($4==S) print $1, $2, $3 * F, $4}' >> "${mfolder}/${input_folder}/feat.dat"
								else
									cat "${mfolder}/${input_folder}/feat.dat.old" | tail -n +2 > "${mfolder}/${input_folder}/feat_add.dat.old"
									join -j 1 -t ',' "${mfolder}/feat_add.tmp" "${mfolder}/${input_folder}/feat_add.dat.old" | awk -v FS=',' -v OFS=',' -v F=$factor -v S=$s '{if($5==S) print $1, $3, $4 + (F * $2), $5}' >> "${mfolder}/${input_folder}/feat.dat"
								fi
							else
								cat "${mfolder}/${input_folder}/feat.dat.old" | awk -v FS=',' -v OFS=',' -v S=$s '{if($4==S) print $0}' >> "${mfolder}/${input_folder}/feat.dat"
							fi
						done

						echo "eligible is ${l}, habitat target is ${ht}, species target is ${st}, BLM is ${b}, SP-factor is ${factor}"
						echo "cat ${mfolder}/${input_folder}/feat.dat"
						cat "${mfolder}/${input_folder}/feat.dat"
						
						#Remove temporary files
						#rm "${mfolder}/factor.tmp"
						#rm "${mfolder}/feat.tmp"
						
						#Run Marxan (time for killing the MarZone window (which requires user input to close) has to be set individually according to time possibly needed for one run)
						if [ $(cat "${mfolder}/${input_folder}/feat.dat" | wc  -l) -lt 2 ] ; then
							exit 0
						fi
						#Make sure output folder is empty
						#rm -rf "${mfolder}/output/"*
						./MarZone_v201_Linux64 &
						wait
						cp "${mfolder}/${input_folder}/feat.dat" "${mfolder}/feat_eligible_${l}_BLM${b}_ht${ht}_st${st}_factor${factor}_run${i}.dat"
						
						#Check if enough targets are met
						targets_missed=$(cat "${mfolder}/output/openmontado_sum.txt" | awk -v FS="," '{if($12>=1) print 1}' | wc -l)
									
						#Break while loop after 10 iterstions (no convergence)
						i=`expr $i + 1`
						if [ $i -ge 10 ] ; then
							break
						fi
						cp "${mfolder}/${input_folder}/feat.dat" "${mfolder}/${input_folder}/feat.dat.old"
						
					done
					
					#Reduce all spfs by previous factor befor entering new loop
					echo "id,prop,spf,name" > "${mfolder}/${input_folder}/feat.dat.old"
					if [ -z $addition ] ; then
						cat "${mfolder}/${input_folder}/feat.dat" | awk -v FS=',' -v OFS=',' -v F=$factor '{if(NR>=2) print $1, $2, $3 / F, $4}' >> "${mfolder}/${input_folder}/feat.dat.old"
					else
						cat "${mfolder}/${input_folder}/feat.dat" | tail -n +2 > "${mfolder}/${input_folder}/feat_add.dat.old"
						join -j 1 -t ',' "${mfolder}/feat_add.tmp" "${mfolder}/${input_folder}/feat_add.dat.old" | awk -v FS=',' -v OFS=',' -v F=$factor '{print $1, $3, $4 - F * $2, $5}' >> "${mfolder}/${input_folder}/feat.dat.old"
					fi
					echo "cat ${mfolder}/${input_folder}/feat.dat.old"
					cat "${mfolder}/${input_folder}/feat.dat.old"
						
				done
				
				#Make a final scenario with 100 runs
				cp "${mfolder}/input.dat" "${mfolder}/input.dat.tmp"
				cat "${mfolder}/input.dat.tmp" | sed '/NUMREPS/c\NUMREPS 100' > "${mfolder}/input.dat"
				rm "${mfolder}/input.dat.tmp"
				./MarZone_v201_Linux64 &
				wait

				
				# Make backup of output folder with enpough successful runs and used input files
				cp -r output output_eligible_${l}_BLM${b}_ht${ht}_st${st}
				#mkdir input_eligible_${l}_BLM${b}_ht${ht}_st${st}
				cp -r "${mfolder}/${input_folder}" input_eligible_${l}_BLM${b}_ht${ht}_st${st}
				cp "${mfolder}/input.dat" input_eligible_${l}_BLM${b}_ht${ht}_st${st}/input.dat
				# Make maps of best run and selection frequency for every scenario
				cat output/openmontado_best.txt | sort -n -k1 -t',' | awk -v FS="," '{if(NR>=2) print $1, "=", $2}' | r.reclass --o input=PU output=best_output_eligible_${l}_BLM${b}_ht${ht}_st${st} rules=- --o --v
				cat output/openmontado_ssoln.txt | sort -n -k1 -t',' | awk -v FS="," '{if(NR>=2) print $1, "=", $3}' | r.reclass --o input=PU output=ssoln_available_eligible_${l}_BLM${b}_ht${ht}_st${st} rules=- --o --v
				cat output/openmontado_ssoln.txt | sort -n -k1 -t',' | awk -v FS="," '{if(NR>=2) print $1, "=", $4}' | r.reclass --o input=PU output=ssoln_AEM_output_eligible_${l}_BLM${b}_ht${ht}_st${st} rules=- --o --v
				# Merge output_sum from all scenarios (summary across runs and summary of the best run)
				cat output/openmontado_sum.txt | awk -v FS="," -v OFS="," -v E=$l -v B=$b -v HT=$ht -v ST=$st '{if(NR>=2) print E, B, HT, ST, $0}' >> "${mfolder}/output_sum/output_sum.csv"
				cat output/openmontado_mvbest.txt | awk -v FS="," -v OFS="," -v E=$l -v B=$b -v HT=$ht -v ST=$st '{if(NR>=2) print E, B, HT, ST, $0}' >> "${mfolder}/output_sum/output_mvbest.csv"
				
			done
		done
	done
done

