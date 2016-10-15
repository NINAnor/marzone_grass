v.category --verbose input=planning_units@g64 output=planning_units_bound type=boundary layer=2
v.db.addtable --verbose map=planning_units_bound layer=2 columns=cat integer, left integer, right integer
v.to.db --verbose map=planning_units_bound@g64 type=boundary layer=2 qlayer=2 option=sides units=meters columns=left,right

v.overlay --overwrite --verbose ainput=planning_units@g64 binput=priority_restoration@g64 output=PU_restoration olayer=1,1,1
echo "ALTER TABLE PU_restoration ADD COLUMN area_m2 double" | db.execute
v.to.db map=PU_restoration@g64 option=area units=meters columns=area_m2

echo "UPDATE PU_restoration SET a_cat = (SELECT max(a_cat)+1 FROM PU_restoration)WHERE a_cat IS NULL" | db.execute

