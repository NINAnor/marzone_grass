:::Start Grass

:::Set data directory

:::Create location and mapset (copy CRS information from layer)




:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Prepare GIS data
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


mkdir C:\marxan\scenario_threezones\input
mkdir C:\marxan\scenario_threezones\output


:::Import data
::File -> Import raster data -> Common import formats (use directory mode)
::File -> Import vector data -> Common import formats (use directory mode)

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Set region
g.region -p vect=mask align=opportunity_costs save=nicoya_50m


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::Rasterize mask
v.to.rast --overwrite --verbose input=mask output=MASK use=val


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Fill data gaps / nodata areas with nearest neighbor values
r.grow.distance --overwrite --verbose input=opportunity_costs value=opportunity_costs_filled


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Rasterize conservation areas (!!!Pay attention to Zone IDs!!!)
::in this case all conservation areas are of zone type 2 (zone ID 2) (=nature conservation, zone type 1 is "unprotected")
v.to.rast --overwrite --verbose input=conservation_areas output=conservation_areas use=val value=2

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Rasterize species (count points in cells for point features)
v.to.db -p --quiet map=endemic_species option=coor | sed "s/|/ /g" | gawk '{print $2 ";" $3 ";1"}' > C:\marxan\scenario_threezones\input\tmp
r.in.xyz --verbose --overwrite -i input="C:\marxan\scenario_threezones\input\tmp" output=endemic_species method=sum type=CELL fs=";"
rm C:\marxan\scenario_threezones\input\tmp
r.null --verbose map=endemic_species setnull=0

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::Rasterize ESS layers (cell value reflects the amount of each feature at a given location)

:::Rainfall areas
v.to.rast --overwrite --verbose input=important_rainfall_areas output=important_rainfall_areas use=val

:::Groundwater ressources
v.to.rast --overwrite --verbose input=important_groundwater_resources output=important_groundwater_resources use=val

:::Wells (point data)
v.to.rast --overwrite --verbose input=wells output=wells use=val
r.neighbors -c --overwrite --verbose input=wells output=well_neighbors method=sum size=11

:::Sum all layers representing ESS "water provision"
r.mapcalc "ess_water_provision=if(isnull(well_neighbors),0,well_neighbors)+if(isnull(important_groundwater_resources),0,important_groundwater_resources)+if(isnull(important_rainfall_areas),0,important_rainfall_areas)"
r.null --verbose map=ess_water_provision setnull=0

:::Wildfire risk areas
v.to.rast --overwrite --verbose input=wildfire_risk_areas output=wildfire_risk_areas use=val

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::Prepare map of habitat types

:::Rasterize ecoregions
v.to.rast --overwrite --verbose input=ecoregions output=ecoregions use=attr column=class_nr labelcolumn=DESCRIP

:::Rasterize land cover map
v.to.rast --overwrite --verbose input=landcover output=landcover use=attr column=class_id labelcolumn=class_name

:::Create a mask with relevant land use classes
:::Deactivate old mask
g.rename --verbose rast=MASK,nicoya_mask

:::Rules file LU_rc.txt prepared with excel
r.reclass --overwrite --verbose input=landcover output=MASK rules=C:\marxan\CR_GIS_data\LU_rc.txt

:::Cross Land use and ecoregions
r.cross -z --overwrite --verbose input="landcover,ecoregions" output=relevant_habitat_types
r.null --verbose map=relevant_habitat_types setnull=0

:::Deactivate mask
g.rename --verbose rast=MASK,feature_mask


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Generate ESS carbon sequestration layer (!!!use commandline interface!!!)
r.mapcalc "ess_carbon_sequestration=if(isnull(wildfire_risk_areas)&&&feature_mask==1,1,null())"



:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::::::Aggregate to 200m cell resolution
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:::Set region to 200m resolution
g.region -p --verbose res=200 n=n+150 e=e+100 save=nicoya_200m

::::::Rasterize mask with 200m resolution
v.to.rast --overwrite --verbose input=mask output=MASK use=val

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Rasterize conservation areas with 200m resolution (!!!Pay attention to Zone IDs!!!)
::in this case all conservation areas are of zone type 2 (zone ID 2) (=nature conservation, zone type 1 is "unprotected")
v.to.rast --overwrite --verbose input=conservation_areas output=conservation_areas_200m use=val value=2

:::Endemic species
r.resamp.stats --overwrite --verbose input=endemic_species output=endemic_species_200m method=sum
:::r.mapcalc "endemic_species_200m_int=int(endemic_species_200m)"

:::Opportunity costs
r.resamp.stats --overwrite --verbose input=opportunity_costs_filled output=opportunity_costs_200m method=sum
:::r.mapcalc "opportunity_costs_200m_int=int(opportunity_costs_200m*200*200)"

:::ESS water provision
r.resamp.stats --overwrite --verbose input=ess_water_provision output=ess_water_provision_200m method=sum

:::ESS carbon sequestration
r.resamp.stats --overwrite --verbose input=ess_carbon_sequestration output=ess_carbon_sequestration_200m method=sum


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::::Create Planning Units
:::For UNIX PCs: r.stats -1 -g -n --verbose input=MASK | gawk '{print $1 ";" $2 ";" NR}' | r.in.xyz --verbose input="-" output=PU_1 method=min type=CELL fs=";"
r.stats -1 -g -n --verbose input=MASK | gawk '{print $1 ";" $2 ";" NR}' > C:\marxan\scenario_threezones\input\tmp
r.in.xyz --verbose --overwrite input="C:\marxan\scenario_threezones\input\tmp" output=pu method=min type=CELL fs=";"
rm C:\marxan\scenario_threezones\input\tmp




:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Export to Marxan input files for a scenario with three zones (1 = available, 2 = nature conservation, and 3 = water protection)
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:::Display protection status of the relevant habitat types
r.stats -a -l -N --verbose input="relevant_habitat_types,conservation_areas" output="C:\marxan\scenario_threezones\input\habitat_types.csv" fs=tab

:::Strip non alphanumeric characters from conservation feature names (they are not supported in Marxan) 
cat C:\marxan\scenario_threezones\input\habitat_types.csv | sed "s/[<;, \*>]//g" | sed "s/[<á\*>]/a/g"| sed "s/[<í\*>]/i/g" | sed "s/[<ñ\*>]/n/g" > C:\marxan\scenario_threezones\input\habitat_types_alpha.csv

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Create planning unit input file
echo id,OPPCOSTS > C:\marxan\scenario_threezones\input\pu.dat
r.stats -1 -n --verbose input="pu,opportunity_costs_200m" fs="," | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t ',' >> C:\marxan\scenario_threezones\input\pu.dat


:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Create planning unit vs. feature input file  (!!!Pay attention to feature IDs!!!)
g.region -p --verbose region=nicoya_50m
r.stats -c -n --verbose input="pu,relevant_habitat_types" | gawk '{print $2 "," $1 "," $3}' > C:\marxan\scenario_threezones\input\tmp
g.region -p --verbose region=nicoya_200m

r.stats -1 -n --verbose input="pu,endemic_species_200m" | gawk '{print "32," $1 "," $2}' >> C:\marxan\scenario_threezones\input\tmp
r.stats -1 -n --verbose input="pu,ess_water_provision_200m" | gawk '{print "33," $1 "," $2}' >> C:\marxan\scenario_threezones\input\tmp
r.stats -1 -n --verbose input="pu,ess_carbon_sequestration_200m" | gawk '{print "34," $1 "," $2}' >> C:\marxan\scenario_threezones\input\tmp


echo featureid,puid,amount > C:\marxan\scenario_threezones\input\puvsp.dat
cat C:\marxan\scenario_threezones\input\tmp | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t "," -k 2 -k1 -k3 >> C:\marxan\scenario_threezones\input\puvsp.dat
rm C:\marxan\scenario_threezones\input\tmp


:::For checking the occurence of conservation features:
::cat C:\marxan\scenario_threezones\input\puvfeat.dat | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t "," -k 1 -u

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Create boundary file
::::::::::::::::::::::::::::::::::r.stats -1 -n --verbose input=pu,pu_n | gawk '{if($1==$2){print $1 "," $2 "," "200"}else{print "test"}}'' > c:\tmp
::::::::::::echo "id1,id2,boundary" > C:\marxan\scenario_threezones\input\bound.dat

:::Direct neighbours
r.mapcalc "PU_n=if(isnull(PU[-1,0]),PU,PU[-1,0])"
r.stats -1 -n --verbose input=pu,pu_n | gawk '{print $1 "," $2 "," "200"}' > C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_e=if(isnull(PU[0,1]),PU,PU[0,1])"
r.stats -1 -n --verbose input=pu,pu_e | gawk '{print $1 "," $2 "," "200"}' >> C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_s=if(isnull(PU[1,0]),PU[1,0],null())"
r.stats -1 -n --verbose input=pu,pu_s | gawk '{print $1 "," $2 "," "200"}' >> C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_w=if(isnull(PU[0,-1]),PU[0,-1],null())"
r.stats -1 -n --verbose input=pu,pu_w | gawk '{print $1 "," $2 "," "200"}' >> C:\marxan\scenario_threezones\input\tmp


::::::Diagonal neighbours
:::r.mapcalc "PU_se=if(isnull(PU[1,1]),PU,PU[1,1])"
:::r.stats -1 -n --verbose input=pu,pu_se | gawk '{print $1 "," $2 "," "100"}' >> C:\marxan\scenario_threezones\input\tmp

:::r.mapcalc "PU_sw=if(isnull(PU[1,-1]),PU,PU[1,-1])"
:::r.stats -1 -n --verbose input=pu,pu_sw | gawk '{print $1 "," $2 "," "100"}' >> C:\marxan\scenario_threezones\input\tmp

:::r.mapcalc "PU_ne=if(isnull(PU[-1,1]),PU[-1,1],null())"
:::r.stats -1 -n --verbose input=pu,pu_ne | gawk '{print $1 "," $2 "," "100"}' >> C:\marxan\scenario_threezones\input\tmp

:::r.mapcalc "PU_nw=if(isnull(PU[-1,-1]),PU[-1,-1],null())"
:::r.stats -1 -n --verbose input=pu,pu_nw | gawk '{print $1 "," $2 "," "100"}' >> C:\marxan\scenario_threezones\input\tmp



echo id1,id2,bound > C:\marxan\scenario_threezones\input\bound.dat
cat C:\marxan\scenario_threezones\input\tmp | grep , | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t "," -k 1 -k2 -k3 >> C:\marxan\scenario_threezones\input\bound.dat
rm C:\marxan\scenario_threezones\input\tmp

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Create planning unit lock input file
echo puid,zoneid > C:\marxan\scenario_threezones\input\pulock.dat
r.stats -1 -n --verbose input=pu,conservation_areas_200m fs="," | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t "," >> C:\marxan\scenario_threezones\input\pulock.dat



:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:::Export to Marxan input files for a scenario with two zones (available and protected, where ESS are taken into account as negative costs)
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
mkdir C:\marxan\scenario_twozones\input\
mkdir C:\marxan\scenario_twozones\output\

cp C:\marxan\scenario_threezones\input\pulock.dat C:\marxan\scenario_twozones\input\pulock.dat
cp C:\marxan\scenario_threezones\input\bound.dat C:\marxan\scenario_twozones\input\bound.dat
