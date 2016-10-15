#:Start Grass

#:Set data directory

#:Create location and mapset (copy CRS information from layer)

###################################:
#:Prepare GIS data
###################################:

#:Path C:\data\Prosjekter\Policymix\Workshop_Oslo\Portugal should be replaced in document with something else
mkdir "C:/data/Prosjekter/Portugal/input"
mkdir "C:/data/Prosjekter/Portugal/output"
wd="C:/data/Prosjekter/Portugal"
input_dir="C:/data/Prosjekter/Portugal/input"
output_dir="C:/data/Prosjekter/Portugal/output"

#:Import data
#File -> Import raster data -> Common import formats (use directory mode)
#File -> Import vector data -> Common import formats (use directory mode)


Set region to 25m resolution:
g.region -p rast=DEM_25m@PERMANENT zoom=DEM_25m@PERMANENT save=SE_Portugal_25m
v.to.rast input="SPA@PERMANENT" layer="1" type="point,line,area" output="SPA" use="val" value=1 rows=4096
v.to.rast input="SAC@PERMANENT" layer="1" type="point,line,area" output="SAC" use="val" value=1 rows=4096

r.reclass input=land_cover@PERMANENT output=land_cover_montados_types rules=C:\data\Prosjekter\Policymix\Workshop_Oslo\Portugal\elegible_areas.txt
r.reclass --overwrite input=montado_distribution@PERMANENT output=montado_types rules=C:\data\Prosjekter\Policymix\Workshop_Oslo\Portugal\elegible_areas.txt
r.reclass --overwrite --verbose input=land_cover@PERMANENT output=land_cover_costs_ext rules="C:\data\Prosjekter\Portugal\AEM_ext_costs.txt"

#single layer for open montado:
r.mapcalc "open_montado=if(montado_types==1,1,null())"
single layer for dense montado:
r.mapcalc "dense_montado=if(montado_types==2,1,null())"


#eligible areas:
r.reclass input=land_cover@PERMANENT output=land_cover_eligible_ext rules=C:\data\portugal\AEM_ext_eligible.txt
"110 thru 135 = 4
126 thru 240 = 3
241 thru 324 = 1
325 thru 523 = 2
* = NULL"

##Identify flat areas
#r.reclass input=Slope_25m_perc output=Flat_areas rules=C:\data\grassdata/Portugal/ninsbl/.tmp/16828.1
#"0 thru 10 = 1
#11 thru 9999 = NULL"

#defining eligible areas:
#r.mapcalc "elegible_areas=if(Local_area,if(elegible_land_cover==1,if((isnull(Flat_areas) && isnull(montado_types)), null(),1),null()),null())"
r.mapcalc "expression=elegible_areas_all=if(Local_area,if(land_cover_eligible_ext==1, 1, null()),null())" --o
r.mapcalc "expression=elegible_areas_open_montado=if(Local_area,if(land_cover_eligible_ext==1 && montado_types ==1, 1, null()),null())" --o
r.mapcalc "expression=elegible_areas_all_SPA=if(Local_area,if(land_cover_eligible_ext==1 && (!isnull(SPA) ||| !isnull(SAC)), 1, null()),null())" --o


###################################:
####Aggregate to 200m cell resolution in order to reduce number of PUs
###################################:

###Set region to 200m resolution
g.region -p --verbose rast=DEM_25m res=200 e=e+100 save=PU_200m
r.resamp.stats --overwrite --verbose input=elegible_areas_all output=elegible_areas_all_200m method=mode
r.resamp.stats --overwrite --verbose input=elegible_areas_open_montado output=elegible_areas_open_montado_200m method=mode
r.resamp.stats --overwrite --verbose input=elegible_areas_all_SPA output=elegible_areas_all_SPA_200m method=mode
r.resamp.stats --overwrite --verbose input=land_cover_eligible_ext output=land_cover_eligible_ext_200m method=max
r.resamp.stats --overwrite --verbose input=land_cover_costs_ext output=land_cover_costs_ext_200m method=sum
r.null map=land_cover_costs_ext_200m@ninsbl null=0

#resampling the elegible land_cover (either natural or urban/semi-natural areas):
#r.resamp.stats --overwrite --verbose input=elegible_land_cover output=elegible_land_cover_200m method=maximum

#r.resamp.stats --overwrite --verbose input=Local_area output=Local_area_200m method=mode

#elegible areas either montado or steeps:
#r.mapcalc "elegible_areas_200m=int(if(elegible_land_cover_200m==1,elegible_areas_200m_pre,null()))"

#relevant costs (summing up the costs within the 200m cells):
#g.region -p --verbose rast=land_cover_slope_soil_costs_reclass
#r.resamp.stats --overwrite --verbose input=elegible_areas output=elegible_areas_50m_pre method=mode
#r.resamp.stats --overwrite --verbose input=elegible_land_cover output=elegible_land_cover_50m method=maximum
r.resamp.stats --overwrite --verbose input=Local_area output=Local_area_200m method=mode
#r.mapcalc "elegible_areas_50m=int(if(elegible_land_cover_50m==1,elegible_areas_50m_pre,null()))"
#r.mapcalc "land_cover_slope_soil_costs_reclass_rel=if(elegible_areas_50m,land_cover_slope_soil_costs_reclass,null())"
#g.region -p region=PU_200m
#r.resamp.stats --overwrite --verbose input=land_cover_slope_soil_costs_reclass_rel output=area_costs_200m method=sum
#r.resamp.stats --overwrite --verbose input=land_cover_slope_soil_costs_reclass output=area_costs_200m_all method=sum

#Resample the first three essential conservation features (also in order to assign possible zones to the PUs)
r.resamp.stats --overwrite --verbose input=open_montado output=open_montado_200m method=sum
#r.resamp.stats --overwrite --verbose input=dense_montado output=dense_montado_200m method=sum
#r.resamp.stats --overwrite --verbose input=Flat_areas output=Flat_areas_200m method=sum




#Create planning unit map
#Temporary file for the PU with 100m resolution:
r.stats -1 -g -n --verbose input=elegible_areas_all_200m | gawk '{print $1 ";" $2 ";" NR}' > "${input_dir}\pu.tmp"

#To import the PU map into GIS by creating a raster map:
r.in.xyz --verbose input="${input_dir}\pu.tmp" output=PU_200m_pre method=min type=CELL separator=";" --o
#(result: PU=45255)

#to remove the temporary file:
rm "${input_dir}\pu.tmp"

#to select/replaces PU files to 200m (limits all the local area with 50m resolution - 1: elegible areas; 2: the other areas):
r.mapcalc expression="PU=int(if(Local_area_200m,if(isnull(PU_200m_pre),5-land_cover_eligible_ext_200m,3+PU_200m_pre),null()))" --o
#(map: PU with 45258 PUs in total)




#:Create planning unit input file
#header:
echo id,land_value > "${input_dir}\pu.dat"
echo 1,0 >> "${input_dir}\pu.dat"
echo 2,0 >> "${input_dir}\pu.dat"
echo 3,0 >> "${input_dir}\pu.dat"
r.stats -1 -n --verbose input="PU,land_cover_costs_ext_200m" separator="," | gawk  -v FS=',' '{if($1>=4) print $1, $2}' | tr ' ' ',' >> "${input_dir}\pu.dat"
#unix2dos "${input_dir}\pu.dat"

#r.mapcalc expression="feat_area=if(PU,isnull(open_montado_200m)+isnull(cerambyx_rel_200m)+isnull(felis_rel_200m)+isnull(aquila_rel_200m)+isnull(hieraaetus_rel_200m)+isnull(asio_rel_200m)+isnull(lulluba_rel_200m)+isnull(milvus_rel_200m)+isnull(milvus_2_rel_200m)+isnull(circaetus_rel_200m)+isnull(hieraaetus_2_rel_200m)+isnull(bubo_rel_200m),null())" --o



#######:Conservation features########
g.region -p region=SE_Portugal_25m

#: 4: BATS data:
v.to.rast input=Bats@PERMANENT output=bats use=val
#all areas are relevant to the bats:
r.mapcalc "bats_rel=if(elegible_areas,bats,null())"
#(map: bats_rel)

#: 5: Cerambyx_cerdo data:
v.to.rast input=Cerambyx_cerdo@PERMANENT output=cerambyx use=val
#to mask out areas that are not so relevant to the bats:
r.mapcalc "cerambyx_rel=if(isnull(steeps),if(elegible_areas,cerambyx,null()),null())"
#(map: cerambyx_rel)

#: 6: wild_cat data:
v.to.rast input=Wildcat@PERMANENT output=felis use=val
#to mask out areas that are not so relevant to the bats:
r.mapcalc "felis_rel=if(montado_types==2,felis,null())"
#(map: felis_rel)

#: 7: genet data:
v.to.rast input=Genet@PERMANENT output=genet use=val
#to mask out areas that are not so relevant to the genet (here we are going to consider that only the dense montado are imp for the genet conservation, leaving out all the others occurence):
r.mapcalc "genet_rel=if(montado_types==2,genet,null())"
#(map: genet_rel)

#: 8: rabbit:
v.to.rast input=Rabbit@PERMANENT output=oryctolagus use=val
#all areas are relevant to the rabbits:
r.mapcalc "oryctolagus_rel=if(elegible_areas,oryctolagus,null())"
#(map: oryctolagus_rel)

#: 9: phoenicurus - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="phoenicurus integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=phoenicurus value=PHOPHOE
#the amount of phoenicurus in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=phoenicurus use=attr column=phoenicurus 
#(map: phoenicurus)
#to eliminate all the zeros in the dataset:
r.null map=phoenicurus@PERMANENT setnull=0
#to mask out areas that are not so relevant to the phoenicurus:
r.mapcalc "phoenicurus_rel=if(elegible_areas,phoenicurus,null())"
#(map: phoenicurus_rel)

#: 10: phylloscopus - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="phylloscopus integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=phylloscopus value=PHYBREH
#the amount of phylloscopus in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=phylloscopus use=attr column=phylloscopus 
#(map: phylloscopus)
#to eliminate all the zeros in the dataset:
r.null map=phylloscopus@PERMANENT setnull=0
#to mask out areas that are not so relevant to the phylloscopus:
r.mapcalc "phylloscopus_rel=if(elegible_areas,phylloscopus,null())"
#(map: phylloscopus_rel)

#: 11: tetrax - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="tetrax integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=tetrax value=TETTETR
#the amount of tetrax in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=tetrax use=attr column=tetrax 
#(map: tetrax)
#to eliminate all the zeros in the dataset:
r.null map=tetrax@PERMANENT setnull=0
#to mask out areas that are not so relevant to the tetrax:
r.mapcalc "tetrax_rel=if(elegible_areas,tetrax,null())"
#(map: tetrax_rel)

#: 12: pernis - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="pernis integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=pernis value=PERAPIV
#the amount of pernis in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=pernis use=attr column=pernis 
#(map: pernis)
#to eliminate all the zeros in the dataset:
r.null map=pernis@PERMANENT setnull=0
#to mask out areas that are not so relevant to the pernis:
r.mapcalc "pernis_rel=if(elegible_areas,pernis,null())"
#(map: pernis_rel)

#: 13: circus - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="circus integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=circus value=CIRPYGA
#the amount of circus in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=circus use=attr column=circus 
#(map: circus)
#to eliminate all the zeros in the dataset:
r.null map=circus@PERMANENT setnull=0
#to mask out areas that are not so relevant to circus:
r.mapcalc "circus_rel=if(elegible_areas,circus,null())"
#(map: circus_rel)

# 14: elanus - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="elanus integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=elanus value=ELACAER
#the amount of circus in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=elanus use=attr column=elanus 
#(map: elanus)
#to eliminate all the zeros in the dataset:
r.null map=elanus@PERMANENT setnull=0
#to mask out areas that are not so relevant to elanus:
r.mapcalc "elanus_rel=if(elegible_areas,elanus,null())"
#(map: elanus_rel)

#: 15: aquila - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="aquila integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=aquila value=AQUCHRY
#the amount of aquila in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=aquila use=attr column=aquila 
#(map: aquila)
#to eliminate all the zeros in the dataset:
r.null map=aquila@PERMANENT setnull=0
#to mask out areas that are not so relevant to aquila:
r.mapcalc "aquila_rel=if(elegible_areas,aquila,null())"
#(map: aquila_rel)

#: 16: falco - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="falco integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=falco value=FALNAUM
#the amount of falco in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=falco use=attr column=falco 
#(map: falco)
#to eliminate all the zeros in the dataset:
r.null map=falco@PERMANENT setnull=0
#to mask out areas that are not so relevant to falco:
r.mapcalc "falco_rel=if(elegible_areas,falco,null())"
#(map: falco_rel)

#: 17: falco_2 - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="falco_2 integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=falco_2 value=FALSUBB
#the amount of falco_2 in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=falco_2 use=attr column=falco_2 
#(map: falco_2)
#to eliminate all the zeros in the dataset:
r.null map=falco_2@PERMANENT setnull=0
#to mask out areas that are not so relevant to falco_2:
r.mapcalc "falco_2_rel=if(elegible_areas,falco_2,null())"
#(map: falco_2_rel)

#: 18: hieraaetus - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="hieraaetus integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=hieraaetus value=HIEFASC
#the amount of hieraaetus in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=hieraaetus use=attr column=hieraaetus 
#(map: hieraaetus)
#to eliminate all the zeros in the dataset:
r.null map=hieraaetus@PERMANENT setnull=0
#to mask out areas that are not so relevant to hieraaetus:
r.mapcalc "hieraaetus_rel=if(elegible_areas,hieraaetus,null())"
#(map: hieraaetus_rel)

#: 19: otis - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="otis integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=otis value=OTITARD
#the amount of otis in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=otis use=attr column=otis 
#(map: otis)
#to eliminate all the zeros in the dataset:
r.null map=otis@PERMANENT setnull=0
#to mask out areas that are not so relevant to otis:
r.mapcalc "otis_rel=if(elegible_areas,otis,null())"
#(map: otis_rel)

#: 20: alectoris - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="alectoris integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=alectoris value=ALERUFA
#the amount of alectoris in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=alectoris use=attr column=alectoris 
#(map: alectoris)
#to eliminate all the zeros in the dataset:
r.null map=alectoris@PERMANENT setnull=0
#to mask out areas that are not so relevant to alectoris:
r.mapcalc "alectoris_rel=if(elegible_areas,alectoris,null())"
#(map: alectoris_rel)

#: 21: asio - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="asio integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=asio value=ASIOTUS
#the amount of asio in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=asio use=attr column=asio 
#(map: asio)
#to eliminate all the zeros in the dataset:
r.null map=asio@PERMANENT setnull=0
#to mask out areas that are not so relevant to asio:
r.mapcalc "asio_rel=if(elegible_areas,asio,null())"
#(map: asio_rel)

#: 22: caprimulgus - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="caprimulgus integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=caprimulgus value=CAPEURO
#the amount of caprimulgus in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=caprimulgus use=attr column=caprimulgus 
#(map: caprimulgus)
#to eliminate all the zeros in the dataset:
r.null map=caprimulgus@PERMANENT setnull=0
#to mask out areas that are not so relevant to caprimulgus:
r.mapcalc "caprimulgus_rel=if(elegible_areas,caprimulgus,null())"
#(map: caprimulgus_rel)

#: 23: pterocles - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="pterocles integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=pterocles value=PTEORIE
#the amount of pterocles in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=pterocles use=attr column=pterocles 
#(map: pterocles)
#to eliminate all the zeros in the dataset:
r.null map=pterocles@PERMANENT setnull=0
#to mask out areas that are not so relevant to pterocles:
r.mapcalc "pterocles_rel=if(elegible_areas,pterocles,null())"
#(map: pterocles_rel)

#: 25: lulluba - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="lulluba integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=lulluba value=LULARBO
#the amount of lulluba in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=lulluba use=attr column=lulluba 
#(map: lulluba)
#to eliminate all the zeros in the dataset:
r.null map=lulluba@PERMANENT setnull=0
#to mask out areas that are not so relevant to lulluba:
r.mapcalc "lulluba_rel=if(elegible_areas,lulluba,null())"
#(map: lulluba_rel)

#: 26: milvus - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="milvus integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=milvus value=MILMIGR
#the amount of milvus in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=milvus use=attr column=milvus 
#(map: milvus)
#to eliminate all the zeros in the dataset:
r.null map=milvus@PERMANENT setnull=0
#to mask out areas that are not so relevant to milvus:
r.mapcalc "milvus_rel=if(elegible_areas,milvus,null())"
#(map: milvus_rel)

#: 27: cicconia - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="cicconia integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=cicconia value=CICCICO
#the amount of cicconia in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=cicconia use=attr column=cicconia 
#(map: cicconia)
#to eliminate all the zeros in the dataset:
r.null map=cicconia@PERMANENT setnull=0
#to mask out areas that are not so relevant to cicconia:
r.mapcalc "cicconia_rel=if(elegible_areas,cicconia,null())"
#(map: cicconia_rel)

#: 28: Bonelli_eagle:
#to create a buffer zone around the points (5000m):
v.buffer input=Bonelli_eagle@PERMANENT output=bonelli_eagle_buffer distance=5000
vector to raster:
v.to.rast input=bonelli_eagle_buffer@PERMANENT output=bonelli_eagle use=val
#to mask out areas that are not so relevant to the bonelli:
r.mapcalc "bonelli_eagle_rel=if(isnull(dense_montado),if(elegible_areas,bonelli_eagle,null()),null())"
#(map: bonelli_eagle_rel)

#: 29: milvus_2 - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="milvus_2 integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=milvus_2 value=MILMILV
#the amount of milvus_2 in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=milvus_2 use=attr column=milvus_2 
#(map: milvus_2)
#to eliminate all the zeros in the dataset:
r.null map=milvus_2@PERMANENT setnull=0
#to mask out areas that are not so relevant to milvus_2:
r.mapcalc "milvus_2_rel=if(elegible_areas,milvus_2,null())"
#(map: milvus_2_rel)

#: 30: circaetus - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="circaetus integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=circaetus value=CIRGALL
#the amount of circaetus in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=circaetus use=attr column=circaetus 
#(map: circaetus)
#to eliminate all the zeros in the dataset:
r.null map=circaetus@PERMANENT setnull=0
#to mask out areas that are not so relevant to circaetus:
r.mapcalc "circaetus_rel=if(elegible_areas,circaetus,null())"
#(map: circaetus_rel)

#: 31: hieraaetus_2 - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds2@PERMANENT columns="hieraaetus_2 integer"
v.db.update map=Atlas_of_birds2@PERMANENT column=hieraaetus_2 value=HIEPENN
#the amount of hieraaetus_2 in the different areas:
v.to.rast --verbose input=Atlas_of_birds2@PERMANENT output=hieraaetus_2 use=attr column=hieraaetus_2 
#(map: hieraaetus_2)
#to eliminate all the zeros in the dataset:
r.null map=hieraaetus_2@PERMANENT setnull=0
#to mask out areas that are not so relevant to hieraaetus_2:
r.mapcalc "hieraaetus_2_rel=if(elegible_areas,hieraaetus_2,null())"
#(map: hieraaetus_2_rel)

#: 32: bubo - Atlas of birds in text (should be in number format) - to convert it to number (integer):
v.db.addcol map=Atlas_of_birds1@PERMANENT columns="bubo integer"
v.db.update map=Atlas_of_birds1@PERMANENT column=bubo value=BUBBUBO
#the amount of bubo in the different areas:
v.to.rast --verbose input=Atlas_of_birds1@PERMANENT output=bubo use=attr column=bubo 
#(map: bubo)
#to eliminate all the zeros in the dataset:
r.null map=bubo@PERMANENT setnull=0
#to mask out areas that are not so relevant to bubo:
r.mapcalc "bubo_rel=if(elegible_areas,bubo,null())"
#(map: bubo_rel)

#: 33: ecological corridor (EEM) data:
v.to.rast input=EEM@PERMANENT output=EEM use=val
#all areas are relevant to EEM:
r.mapcalc "EEM_rel=if(elegible_areas,EEM,null())"
#(map: EEM_rel)

#: 34: SPA_SAC data:
v.to.rast --overwrite input=SPA_SAC@PERMANENT output=SPA_SAC use=val
#all areas are relevant to SPA_SAC:
r.mapcalc "SPA_SAC_rel=if(elegible_areas,SPA_SAC,null())"
#(map: SPA_SAC_rel)

#: 35: tourism data:



g.region -p region=PU_200m

r.resamp.stats --overwrite input=bats_rel output=bats_rel_200m
r.resamp.stats --overwrite input=cerambyx_rel output=cerambyx_rel_200m
r.resamp.stats --overwrite input=felis_rel output=felis_rel_200m
r.resamp.stats --overwrite input=genet_rel output=genet_rel_200m
r.resamp.stats --overwrite input=oryctolagus_rel output=oryctolagus_rel_200m
r.resamp.stats --overwrite input=phoenicurus_rel output=phoenicurus_rel_200m
r.resamp.stats --overwrite input=phylloscopus_rel output=phylloscopus_rel_200m
r.resamp.stats --overwrite input=tetrax_rel output=tetrax_rel_200m
r.resamp.stats --overwrite input=pernis_rel output=pernis_rel_200m
r.resamp.stats --overwrite input=circus_rel output=circus_rel_200m
r.resamp.stats --overwrite input=elanus_rel output=elanus_rel_200m
r.resamp.stats --overwrite input=aquila_rel output=aquila_rel_200m
r.resamp.stats --overwrite input=falco_rel output=falco_rel_200m
r.resamp.stats --overwrite input=falco_2_rel output=falco_2_rel_200m
r.resamp.stats --overwrite input=hieraaetus_rel output=hieraaetus_rel_200m
r.resamp.stats --overwrite input=otis_rel output=otis_rel_200m
r.resamp.stats --overwrite input=alectoris_rel output=alectoris_rel_200m
r.resamp.stats --overwrite input=asio_rel output=asio_rel_200m
r.resamp.stats --overwrite input=caprimulgus_rel output=caprimulgus_rel_200m
r.resamp.stats --overwrite input=pterocles_rel output=pterocles_rel_200m
r.resamp.stats --overwrite input=lulluba_rel output=lulluba_rel_200m
r.resamp.stats --overwrite input=milvus_rel output=milvus_rel_200m
r.resamp.stats --overwrite input=cicconia_rel output=cicconia_rel_200m
r.resamp.stats --overwrite input=bonelli_eagle_rel output=bonelli_eagle_rel_200m
r.resamp.stats --overwrite input=milvus_2_rel output=milvus_2_rel_200m
r.resamp.stats --overwrite input=circaetus_rel output=circaetus_rel_200m
r.resamp.stats --overwrite input=hieraaetus_2_rel output=hieraaetus_2_rel_200m
r.resamp.stats --overwrite input=bubo_rel output=bubo_rel_200m
r.resamp.stats --overwrite input=EEM_rel output=EEM_rel_200m
r.resamp.stats --overwrite input=SPA_SAC_rel output=SPA_SAC_rel_200m


###Create planning unit versus feature input file(s)
#writes featureid, puid, amount into a text file (just the header):
echo featureid,puid,amount > "${input_dir}\puvfeat.dat"

#determines the amount of cells that have these conservation feautures (open montado=1; dense montado=2; steeps=3) within each PU:
r.stats -cn1 --verbose input="PU,open_montado_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 1, $1, $2}' > "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,dense_montado_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 2, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,Flat_areas_200m_rel" | gawk -v OFS=',' '{if($1>3&&$2>0) print 3, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,bats_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 4, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,cerambyx_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 5, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,felis_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 6, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,genet_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 7, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,oryctolagus_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 8, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,phylloscopus_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 10, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,pernis_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 12, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,elanus_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 14, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,aquila_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 15, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,falco_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 16, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,falco_2_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 17, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,hieraaetus_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 18, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,alectoris_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 20, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,asio_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 21, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,caprimulgus_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 22, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,lulluba_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 25, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,milvus_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 26, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,cicconia_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 27, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,bonelli_eagle_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 28, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,milvus_2_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 29, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,circaetus_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 30, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,hieraaetus_2_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 31, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
r.stats -cn1 --verbose input="PU,bubo_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 32, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,EEM_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 33, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#r.stats -cn1 --verbose input="PU,SPA_SAC_rel_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 34, $1, $2}' >> "${input_dir}\puvfeat.dat.tmp"
#...more conservation features

#takes the temporary files created by the raster commands and sorts it in a numerical order treats the comma as the delimitor - added to the PUvsFEAT data final:
cat "${input_dir}\puvfeat.dat.tmp" | sort -n -k 2 -k 1 -t ',' >> "${input_dir}\puvfeat.dat"
#unix2dos "${input_dir}\puvfeat.dat"

#to remove the temporary file:
rm "${input_dir}\puvfeat.dat.tmp"


###################################:
#:Create boundary file - 200m resolution
#################

#:Direct neighbours: to calculate direct neighbours in maps (comparison of PU map with PUn):
g.region region=PU

r.mapcalc --o expression="PU_n_200m=if(isnull(PU[-1,0]),PU,if(PU!=PU[-1,0],PU[-1,0],null()))"
r.stats -nc --verbose input=PU,PU_n_200m | gawk '{print $1 "," $2 "," $3 * 200}' > "${input_dir}\bound.dat.tmp"

r.mapcalc --o expression="PU_e_200m=if(isnull(PU[0,1]),PU,if(PU!=PU[0,1],PU[0,1],null()))"
r.stats -nc --verbose input=PU,PU_e_200m | gawk '{print $1 "," $2 "," $3 * 200}' >> "${input_dir}\bound.dat.tmp"

#r.mapcalc --o expression="PU_s_200m=if(isnull(PU[1,0]),PU,if(PU!=PU[1,0],PU[1,0],null()))"
r.mapcalc --o expression="PU_s_200m=if(isnull(PU[1,0]),PU,null())"
r.stats -nc --verbose input=PU,PU_s_200m | gawk '{print $1 "," $2 "," $3 * 200}' >> "${input_dir}\bound.dat.tmp"

r.mapcalc --o expression="PU_w_200m=if(isnull(PU[0,-1]),PU,null())"
r.stats -nc --verbose input=PU,PU_w_200m | gawk '{print $1 "," $2 "," $3 * 200}' >> "${input_dir}\bound.dat.tmp"

###Diagonal neighbours
r.mapcalc --o expression="PU_se_200m=if(isnull(PU[1,1]),PU,if(PU!=PU[1,1],PU[1,1],null()))"
r.stats -nc --verbose input=PU,PU_se_200m | gawk '{print $1 "," $2 "," $3 * 200}' >> "${input_dir}\bound.dat.tmp"

r.mapcalc --o expression="PU_sw_200m=if(isnull(PU[1,-1]),PU,if(PU!=PU[1,-1],PU[1,-1],null()))"
r.stats -nc --verbose input=PU,PU_sw_200m | gawk '{print $1 "," $2 "," $3 * 200}' >> "${input_dir}\bound.dat.tmp"

r.mapcalc --o expression="PU_ne_200m=if(isnull(PU[-1,1]),PU,null())"
r.stats -nc --verbose input=PU,PU_ne_200m | gawk '{print $1 "," $2 "," $3 * 200}' >> "${input_dir}\bound.dat.tmp"

r.mapcalc --o expression="PU_nw_200m=if(isnull(PU[-1,-1]),PU,null())"
r.stats -nc --verbose input=PU,PU_nw_200m | gawk '{print $1 "," $2 "," $3 * 200}' >> "${input_dir}\bound.dat.tmp"

###Order bound.dat entries first by PU1 then by PU2
echo id1,id2,boundary > "${input_dir}\bound.dat"

cat "${input_dir}\bound.dat.tmp" | gawk -v FS=',' '{if($1<=$2) print $1 "_" $2, $3}' > "${input_dir}\bound.dat.tmp2"
cat "${input_dir}\bound.dat.tmp" | gawk -v FS=',' '{if($1>$2) print $2 "_" $1, $3}' >> "${input_dir}\bound.dat.tmp2"
cat "${input_dir}\bound.dat.tmp2" | sort -n -t_ -k1 -k2 > "${input_dir}\bound.dat.tmp3"
cat "${input_dir}\bound.dat.tmp3"| gawk 'BEGIN{FS=" "} {a[$1]++;b[$1]=b[$1]+$2}END{for (i in a) printf("%s %d\n", i, b[i])}' | tr '_' ' ' | sort -n -k1 -k2 | tr ' ' ',' > "${input_dir}\bound.dat.tmp4"
cat "${input_dir}\bound.dat.tmp3" | sed 's/$//g' | sort -n -k1 -k2 -t ',' > "${input_dir}\bound.dat.tmp"
rm  "${input_dir}\bound.dat.tmp2"
rm  "${input_dir}\bound.dat.tmp3"

cat "${input_dir}\bound.dat.tmp4" | grep , | sort -n -t "," -k 1 -k2 -k3 >> "${input_dir}\bound.dat"
rm "${input_dir}\bound.dat.tmp"
#unix2dos "${input_dir}\bound.dat"

###################################:
#Create planning unit lock input file for a 4 zone scenario
echo puid,zoneid > "${input_dir}\pulock.dat"
echo 1,4 >> "${input_dir}\pulock.dat"
echo 2,3 >> "${input_dir}\pulock.dat"
echo 3,1 >> "${input_dir}\pulock.dat"

r.mapcalc --o expression="all_vs_om_SPA=if(PU,if(isnull(SPA_SAC_rel_200m)&&isnull(open_montado_200m),0,1),null())"
all_vs_om_SPA

echo puid,zoneid > "${input_dir}\pulock_om_pa.dat"
echo 1,1 >> "${input_dir}\pulock_om_pa.dat"
echo 2,1 >> "${input_dir}\pulock_om_pa.dat"
echo 3,1 >> "${input_dir}\pulock_om_pa.dat"
r.stats -n1 --verbose input="PU,all_vs_om_SPA" | awk '{if($1>=4 && $2 == 0) print $1 " 1"}' | sort -n -k 1,2 | tr ' ' ',' >> "${input_dir}\pulock_om_pa.dat"

r.stats -N1 --verbose input="PU,open_montado_200m,elegible_areas_all_200m,elegible_areas_all_SPA" | sort -n | uniq | awk '{if($1 != "*" && $1>=5) print $0}' > "${input_dir}\pulock.dat.tmp"
#Lock out everything but open monatado
cp "${input_dir}\pulock.dat" "${input_dir}\pulock_open_montado.dat"
cat "${input_dir}\pulock.dat.tmp" | awk '{if($2 == "*") print $1 ",1"}' >> "${input_dir}\pulock_open_montado.dat"
#Lock out everything but protected areas
cp "${input_dir}\pulock.dat" "${input_dir}\pulock_PA.dat"
cat "${input_dir}\pulock.dat.tmp" | awk '{if($4 == "*") print $1 ",1"}' >> "${input_dir}\pulock_PA.dat"

cat "${input_dir}\pulock.dat.tmp" | awk '{if($1 != "*" && $1>=5) print $0}' 
r.stats -1 -n --verbose input=pu,conservation_areas_200m fs="," | sort -n -t "," >> "${input_dir}\pulock.dat"

unix2dos "${input_dir}\pulock.dat"

r.stats -in --verbose input="PU,land_cover_eligible_ext_200m" | sort -n -k1,2 | uniq | gawk -v OFS=',' '{if($2==2) print $1, 3}' >> "${input_dir}\pulock.dat.tmp"
# 
r.stats -in --verbose input="PU,land_cover_eligible_ext_200m" | sort -n -k1,2 | uniq | gawk -v OFS=',' '{if($2==3) print $1, 4}' >> "${input_dir}\pulock.dat.tmp"
# 
r.stats -in --verbose input="PU,land_cover_eligible_ext_200m" | sort -n -k1,2 | uniq | gawk -v OFS=',' '{if($2==4) print $1, 5}' >> "${input_dir}\pulock.dat.tmp"

r.stats -cn1 --verbose input="PU,open_montado_200m,elegible_areas_all_200m" | gawk -v OFS=',' '{if($1>3&&$2>0) print 1, $1, $2}' > "${input_dir}\puvfeat.dat.tmp"
elegible_areas_all_200m

###################################:
#Create planning unit lock input file for a 2 zone scenario
echo puid,zoneid > "${input_dir}\pulock.dat"
echo 1,1 >> "${input_dir}\pulock.dat"
echo 2,1 >> "${input_dir}\pulock.dat"
echo 3,1 >> "${input_dir}\pulock.dat"
unix2dos "${input_dir}\pulock.dat"


##############Create puzone.dat - 200m resolution
#header:
echo puid,zoneid > "${input_dir}\puzone.dat"
rm "${input_dir}\puzone.dat.tmp"
# all PU can go to the available zone:
r.stats -n --verbose input="PU" | gawk -v OFS=',' '{print $1, 1}' > "${input_dir}\puzone.dat.tmp"
# identifying PU containing eligible areas (writen in a temporary file) delimitating the areas that can receive each measure:
r.stats -1n --verbose input="PU,elegible_areas_all_200m,land_cover_eligible_ext_200m" | gawk -v OFS=',' '{if($3 <= 2) print $1, 2}' >> "${input_dir}\puzone.dat.tmp"
#r.stats -1n --verbose input="PU,elegible_areas_all_200m,land_cover_eligible_ext_200m" | gawk -v OFS=',' '{if($3 <= 2) print $1, 1}' >> "${input_dir}\puzone.dat.tmp"
# 
#r.stats -1n --verbose input="PU,land_cover_eligible_ext_200m" | sort -n -k1,2 | uniq | gawk -v OFS=',' '{if($2==2) print $1, 1}' >> "${input_dir}\puzone.dat.tmp"
# 
r.stats -1n --verbose input="PU,land_cover_eligible_ext_200m" | sort -n -k1,2 | uniq | gawk -v OFS=',' '{if($2==3) print $1, 3}' >> "${input_dir}\puzone.dat.tmp"
# 
r.stats -1n --verbose input="PU,land_cover_eligible_ext_200m" | sort -n -k1,2 | uniq | gawk -v OFS=',' '{if($2==4) print $1, 4}' >> "${input_dir}\puzone.dat.tmp"


# identifying PU containing dense montado:
# # r.stats -n --verbose input="PU,dense_montado_200m" | gawk -v OFS=',' "{if($1>2) print $1, 3}" >> "${input_dir}\puzone.dat.tmp"
# identifying PU containing flat areas wich either can recieve measure 3 or 4 (Measures for flat areas can not overlapp with montados):
# # r.mapcalc "Flat_areas_200m_rel=if(isnull(open_montado_200m)&&isnull(dense_montado_200m),Flat_areas_200m,null())"
# # r.stats -n --verbose input="PU,Flat_areas_200m_rel" | gawk -v OFS=',' "{if($1>2) print $1, 4}" >> "${input_dir}\puzone.dat.tmp"
# # r.stats -n --verbose input="PU,Flat_areas_200m_rel" | gawk -v OFS=',' "{if($1>2) print $1, 5}" >> "${input_dir}\puzone.dat.tmp"

cat "${input_dir}\puzone.dat.tmp" | sort -n -k 1 -k 2 -t ',' >> "${input_dir}\puzone.dat"
unix2dos "${input_dir}\puzone.dat"
# # rm "${input_dir}\puzone.dat.tmp"
r.stats -n --verbose input="PU,elegible_areas_all_200m" | gawk -v OFS=',' '{print $1, 1}' > "${input_dir}\puzone.dat.tmp"

#Import Marxan results:

#marxan_output_folder="C:\data\Prosjekter\Policymix\Workshop_Oslo\Portugal\output\"

runs=$(ls $marxan_output_folder | grep _r)

for r in $runs
do
r_name=$(basename $r | cut -f1 -d'.')
cat ${output_dir}"\openmontado_best.txt" | gawk 'FS="," {if(NR!=1) print $1 " = " $2}' | r.reclass --overwrite --verbose input=PU output=openmontado_best rules=-
rm ${marxan_output_folder}rc.tmp
done



Marxan results reading (- test_scenario run: 08-03-2013):
g.region -p rast=PU
r.reclass input=PU output=best_run rules=C:\data\Prosjekter\Policymix\Workshop_Oslo\Portugal\output\marxan_4_zones_10perc_best_rc.txt
import to GRASS (Raster - change values and categories - reclassify with the output_best_rc file)



Thing to improve - test_scenario run:
pu.dat : add features 1 (semi-natural) and 2 (urban) with costs 0 (already loched on pulock.dat)
adjust feature penalty factor (spf) : to reduce the importance of conservation features to see where the balance is (between costs and conservation features)
check/adjust zone-target and zone-contribution : 
create puzones.dat file : 
create bound.dat file and zoneboundcost.dat











##:Marxan Run###
best solution: run=4

g.region -p rast=PU@PERMANENT





#:Order bound.dat entries first by PU1 then by PU2
echo id1,id2,bound > "C:\data\Prosjekter\Policymix\Workshop_Oslo\Portugal\marxan_4_measures\input\bound.dat"
cat "D:\marxan\test_scenario\input\tmp" | grep , | sort -n -t "," -k 1 -k2 -k3 >> "C:\data\Prosjekter\Policymix\Workshop_Oslo\Portugal\marxan_4_measures\input\bound.dat"
rm "C:\data\Prosjekter\Policymix\Workshop_Oslo\Portugal\marxan_4_measures\input\tmp"



rasterize soil types:
v.to.rast input=clip_soil_classes_local_area_buffer@PERMANENT output=soil_classes_local_area_buffer use=attr column=CODUSO labelcolumn=CLASSE

crossing slope
r.cross input=land_cover@PERMANENT,Slope_classes_mode_5_3@PERMANENT,soil_classes_local_area_buffer@PERMANENT output=land_cover_slope_soil

r.stats - including the r.cross map, land_cover, soil_types, Slope_5_3
r.stats -l -N input=land_cover_slope_soil@PERMANENT,land_cover@PERMANENT,Slope_classes_mode_5_3@PERMANENT,soil_classes_local_area_buffer@PERMANENT fs=;
r.stats -l -N input=land_cover_slope_soil@PERMANENT,land_cover@PERMANENT,Slope_classes_mode_5_3@PERMANENT,soil_classes_local_area_buffer@PERMANENT fs=;

#:send to excel to calculate unique costs for category#:
r.reclass input=land_cover_slope_soil@PERMANENT output=land_cover_slope_soil_costs rules=C:\Users\rute\Desktop\opportunity costs.txt





||||||FINAL||||||| 10-04-2013
crossing slope:
r.cross --overwrite input=land_cover@PERMANENT,Slope_25m_perc_max_5@PERMANENT,soil_classes_local_area_buffer@PERMANENT output=land_cover_slope_soil

r.stats - including the r.cross map, land_cover, soil_types, Slope:
r.stats -l -N input=land_cover@PERMANENT,Slope_25m_perc_max_5@PERMANENT,soil_classes_local_area_buffer@PERMANENT,land_cover_slope_soil@PERMANENT fs=;

#:send to excel to calculate unique costs for category#:
r.reclass --overwrite input=land_cover_slope_soil@PERMANENT output=land_cover_slope_soil_costs rules=C:\Users\rute\Desktop\opportunity_costs_final_10042013.txt


r.stats input=land_cover_slope_soil@PERMANENT
r.reclass --overwrite input=land_cover_slope_soil@PERMANENT output=land_cover_slope_soil_costs rules=C:\Users\rute\Desktop\costs_final.txt

(Fri Apr 12 14:05:44 2013)                                                      
r.mapcalc land_cover_slope_soil_costs_reclass = land_cover_slope_soil_costs@PERMANENT/100.0





###Fill data gaps / nodata areas with nearest neighbor values
#:r.grow.distance --overwrite --verbose input=opportunity_costs value=opportunity_costs_filled

###################################:
###Rasterize elegible areas in order to be able to mask out unrelevant area
v.to.rast --overwrite --verbose input=land_cover output=land_cover use=val

###################################:
#:Rasterize existing conservation areas (!!!Pay attention to Zone IDs!!!)
#in this case all conservation areas are of zone type 2 (zone ID 2 = nature conservation, zone ID 1 = "unprotected")
v.to.rast --overwrite --verbose input=conservation_areas output=conservation_areas use=val value=2

###################################:
#:Rasterize conservation feature maps  (!!!Pay attention to feature IDs!!!)
##For polygons and lines
v.to.rast --overwrite --verbose input=land_cover output=land_cover use=attr XXX

##For point data (count points in cells for point features)
v.to.db -p --quiet map=endemic_species option=coor | sed "s/|/ /g" | gawk '{print $2 ";" $3 ";1"}' > C:\marxan\scenario_threezones\input\tmp
r.in.xyz --verbose --overwrite -i input="C:\marxan\scenario_threezones\input\tmp" output=endemic_species method=sum type=CELL fs=";"
rm C:\marxan\scenario_threezones\input\tmp
r.null --verbose map=endemic_species setnull=0

###################################:
###Rasterize ESS layers (cell value reflects the amount of each feature at a given location)

#:Rainfall areas
v.to.rast --overwrite --verbose input=important_rainfall_areas output=important_rainfall_areas use=val

#:Groundwater ressources
v.to.rast --overwrite --verbose input=important_groundwater_resources output=important_groundwater_resources use=val

#:Wells (point data)
v.to.rast --overwrite --verbose input=wells output=wells use=val
r.neighbors -c --overwrite --verbose input=wells output=well_neighbors method=sum size=11

#:Sum all layers representing ESS "water provision"
r.mapcalc "ess_water_provision=if(isnull(well_neighbors),0,well_neighbors)+if(isnull(important_groundwater_resources),0,important_groundwater_resources)+if(isnull(important_rainfall_areas),0,important_rainfall_areas)"
r.null --verbose map=ess_water_provision setnull=0

#:Wildfire risk areas
v.to.rast --overwrite --verbose input=wildfire_risk_areas output=wildfire_risk_areas use=val

###################################:
###Prepare map of habitat types

#:Rasterize ecoregions
v.to.rast --overwrite --verbose input=ecoregions output=ecoregions use=attr column=class_nr labelcolumn=DESCRIP

#:Rasterize land cover map
v.to.rast --overwrite --verbose input=landcover output=landcover use=attr column=class_id labelcolumn=class_name

#:Create a mask with relevant land use classes
#:Deactivate old mask
g.rename --verbose rast=MASK,nicoya_mask

#:Rules file LU_rc.txt prepared with excel
r.reclass --overwrite --verbose input=landcover output=MASK rules=C:\marxan\CR_GIS_data\LU_rc.txt

#:Cross Land use and ecoregions
r.cross -z --overwrite --verbose input="landcover,ecoregions" output=relevant_habitat_types
r.null --verbose map=relevant_habitat_types setnull=0

#:Deactivate mask
g.rename --verbose rast=MASK,feature_mask


###################################:
#:Generate ESS carbon sequestration layer (!!!use commandline interface!!!)
r.mapcalc "ess_carbon_sequestration=if(isnull(wildfire_risk_areas)&&&feature_mask==1,1,null())"


###################################:
#:Aggregation likely not necessary

###################################:
####Aggregate to 200m cell resolution
###################################:

###Set region to 200m resolution
#:g.region -p --verbose res=200 n=n+150 e=e+100 save=nicoya_200m

###Rasterize mask with 200m resolution
#:v.to.rast --overwrite --verbose input=mask output=MASK use=val

###################################:
###Rasterize conservation areas with 200m resolution (!!!Pay attention to Zone IDs!!!)
##:in this case all conservation areas are of zone type 2 (zone ID 2) (=nature conservation, zone type 1 is "unprotected")
#:v.to.rast --overwrite --verbose input=conservation_areas output=conservation_areas_200m use=val value=2

###Endemic species
#:r.resamp.stats --overwrite --verbose input=endemic_species output=endemic_species_200m method=sum
###r.mapcalc "endemic_species_200m_int=int(endemic_species_200m)"

###Opportunity costs
#:r.resamp.stats --overwrite --verbose input=opportunity_costs_filled output=opportunity_costs_200m method=sum
###r.mapcalc "opportunity_costs_200m_int=int(opportunity_costs_200m*200*200)"

###ESS water provision
#:r.resamp.stats --overwrite --verbose input=ess_water_provision output=ess_water_provision_200m method=sum

###ESS carbon sequestration
#:r.resamp.stats --overwrite --verbose input=ess_carbon_sequestration output=ess_carbon_sequestration_200m method=sum



###################################:
##Create Planning Units
#:For UNIX PCs: r.stats -1 -g -n --verbose input=MASK | gawk '{print $1 ";" $2 ";" NR}' | r.in.xyz --verbose input="-" output=PU_1 method=min type=CELL fs=";"
r.stats -1 -g -n --verbose input=MASK | gawk '{print $1 ";" $2 ";" NR}' > C:\marxan\scenario_threezones\input\tmp
r.in.xyz --verbose --overwrite input="C:\marxan\scenario_threezones\input\tmp" output=pu method=min type=CELL fs=";"
rm C:\marxan\scenario_threezones\input\tmp


###################################:
#:Export to Marxan input files for a scenario with three zones (1 = available, 2 = nature conservation, and 3 = water protection)
###################################:

###Display protection status of the relevant habitat types
#:r.stats -a -l -N --verbose input="relevant_habitat_types,conservation_areas" output="C:\marxan\scenario_threezones\input\habitat_types.csv" fs=tab

###Strip non alphanumeric characters from conservation feature names (they are not supported in Marxan) 
#:cat C:\marxan\scenario_threezones\input\habitat_types.csv | sed "s/[<;, \*>]//g" | sed "s/[<Ã¡\*>]/a/g"| sed "s/[<Ã­\*>]/i/g" | sed "s/[<Ã±\*>]/n/g" > C:\marxan\scenario_threezones\input\habitat_types_alpha.csv

###################################:
#:Create planning unit input file
echo id,costs > C:\marxan\scenario_threezones\input\pu.dat
r.stats -1 -n --verbose input="pu,opportunity_costs_200m" fs="," | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t ',' >> C:\marxan\scenario_threezones\input\pu.dat


###################################:
#:Create planning unit vs. feature input file  (!!!Pay attention to feature IDs!!!)
#:g.region -p --verbose region=nicoya_50m
r.stats -c -n --verbose input="pu,montado" | gawk '{print $2 "," $1 "," $3}' > C:\marxan\scenario_threezones\input\tmp
#:g.region -p --verbose region=nicoya_200m

r.stats -1 -n --verbose input="pu,steeps" | gawk '{print "32," $1 "," $2}' >> C:\marxan\scenario_threezones\input\tmp
r.stats -1 -n --verbose input="pu,bird_1" | gawk '{print "33," $1 "," $2}' >> C:\marxan\scenario_threezones\input\tmp
r.stats -1 -n --verbose input="pu,bird_2" | gawk '{print "34," $1 "," $2}' >> C:\marxan\scenario_threezones\input\tmp

#:Order puvfeat.dat entries first by PU then by feature
echo featureid,puid,amount > C:\marxan\scenario_threezones\input\puvsp.dat
cat C:\marxan\scenario_threezones\input\tmp | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t "," -k2 -k1 -k3 >> C:\marxan\scenario_threezones\input\puvsp.dat
rm C:\marxan\scenario_threezones\input\tmp


#:For checking the occurence of conservation features:
#cat C:\marxan\scenario_threezones\input\puvfeat.dat | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t "," -k 1 -u

###################################:
#:Create boundary file
#################r.stats -1 -n --verbose input=pu,pu_n | gawk '{if($1==$2){print $1 "," $2 "," "200"}else{print "test"}}'' > c:\tmp
######echo "id1,id2,boundary" > C:\marxan\scenario_threezones\input\bound.dat

#:Direct neighbours
r.mapcalc "PU_n=if(isnull(PU[-1,0]),PU,PU[-1,0])"
r.stats -1 -n --verbose input=pu,pu_n | gawk '{print $1 "," $2 "," "200"}' > C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_e=if(isnull(PU[0,1]),PU,PU[0,1])"
r.stats -1 -n --verbose input=pu,pu_e | gawk '{print $1 "," $2 "," "200"}' >> C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_s=if(isnull(PU[1,0]),PU[1,0],null())"
r.stats -1 -n --verbose input=pu,pu_s | gawk '{print $1 "," $2 "," "200"}' >> C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_w=if(isnull(PU[0,-1]),PU[0,-1],null())"
r.stats -1 -n --verbose input=pu,pu_w | gawk '{print $1 "," $2 "," "200"}' >> C:\marxan\scenario_threezones\input\tmp


###Diagonal neighbours
r.mapcalc "PU_se=if(isnull(PU[1,1]),PU,PU[1,1])"
r.stats -1 -n --verbose input=pu,pu_se | gawk '{print $1 "," $2 "," "100"}' >> C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_sw=if(isnull(PU[1,-1]),PU,PU[1,-1])"
r.stats -1 -n --verbose input=pu,pu_sw | gawk '{print $1 "," $2 "," "100"}' >> C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_ne=if(isnull(PU[-1,1]),PU[-1,1],null())"
r.stats -1 -n --verbose input=pu,pu_ne | gawk '{print $1 "," $2 "," "100"}' >> C:\marxan\scenario_threezones\input\tmp

r.mapcalc "PU_nw=if(isnull(PU[-1,-1]),PU[-1,-1],null())"
r.stats -1 -n --verbose input=pu,pu_nw | gawk '{print $1 "," $2 "," "100"}' >> C:\marxan\scenario_threezones\input\tmp


#Order bound.dat entries first by PU1 then by PU2
echo id1,id2,bound > C:\marxan\scenario_threezones\input\bound.dat
cat C:\marxan\scenario_threezones\input\tmp | grep , | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t "," -k 1 -k2 -k3 >> C:\marxan\scenario_threezones\input\bound.dat
rm C:\marxan\scenario_threezones\input\tmp

###################################:
#Create planning unit lock input file
echo puid,zoneid > C:\marxan\scenario_threezones\input\pulock.dat
r.stats -1 -n --verbose input=pu,conservation_areas_200m fs="," | C:\PROGRA~1\QUANTU~2\apps\msys\bin\sort -n -t "," >> C:\marxan\scenario_threezones\input\pulock.dat

#Lock in results from earlier runs:
echo puid,zoneid > C:\marxan\scenario_threezones\input\pulock.dat
r.stats -1 -n --verbose input=pu,scenario_best fs=" " | gawk -v OFS="," '{if($2==2) print $0}' | sort -n -t "," >> C:\marxan\scenario_threezones\input\pulock.dat

r.mapcalc --o expression="zero_cost_areas=if(PU,if(land_cover_costs_ext_200m==0,0,1),null())"

echo "feat,zone,sum_feat" >  "${input_dir}\featvszerocost.dat"
r.univar -t map=open_montado_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2) print "open_montado", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"
r.univar -t map=cerambyx_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "cerambyx", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat" #
r.univar -t map=felis_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "felis", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat" #
r.univar -t map=aquila_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "aquila", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat" #
r.univar -t map=hieraaetus_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "hieraaetus", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"
r.univar -t map=hieraaetus_2_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "hieraaetus_2", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"
r.univar -t map=asio_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "asio", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"
r.univar -t map=lulluba_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "lulluba", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"
r.univar -t map=milvus_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "milvus", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"
r.univar -t map=milvus_2_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "milvus_2", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"
r.univar -t map=circaetus_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "circaetus", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"
r.univar -t map=bubo_rel_200m@ninsbl zones=all_vs_om_SPA@ninsbl separator=space | gawk '{if(NR>=2)print "bubo", $1, $13}' | tr ' ' ',' >>  "${input_dir}\featvszerocost.dat"

