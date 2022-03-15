$log Entering file: %system.incName%

# Filnavn: RefaWriteScenarios.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til postprocessering af resultater for alle scenarier og udskrivning til Excel.



# Sammenfattende nÃ¸gletal for alle scenarier

if (RunScenarios,
  TimeOfWritingMasterResults = jnow;

  execute_unload 'REFAscens.gdx',
  TimeOfWritingMasterResults,
  scen, actScen,
  bound, moall, mo, fkind, f, fa, fb, fc, fr, u, up, ua, ub, uc, ur, u2f, s2f, fuelItem,
  labDataU, labDataFuel, labSchRow, labSchCol, labDataProgn, taxkind, topic, typeCO2,
  PerStart, PerSlut, nScen, NScenSpec, VirtualUsed, 
  Scen_Recs, #--- Scen_Progn, Scen_Progn_Transpose,
  Scen_Overview, Scen_Q, Scen_FuelDeliv, Scen_IncomeFuel;

  #TODO: Udskriv til Excel-fil REFAOutputScens.xlsm


$onecho > REFAscens.txt
filter=0

* OBS: Vaerdier udskrives i basale enheder, men formatteres i Excel til visning af fx. tusinder fremfor enere.

*begin sheet Overblik
par=Scen_Recs                       rng=ScenInput!AT5         cdim=1 rdim=1
par=TimeOfWritingMasterResults      rng=Overblik!C1:C1
par=VirtualUsed                     rng=Overblik!B1:B1
par=PerStart                        rng=Overblik!B2:B2
par=PerSlut                         rng=Overblik!C2:C2
par=Scen_Overview                   rng=Overblik!C4          cdim=1  rdim=1
text="Nøgletal"                     rng=Overblik!C4:C4
par=Scen_Q                          rng=Overblik!C61         cdim=1  rdim=1
text="Varmemængder"                 rng=Overblik!C61:C61
par=Scen_FuelDeliv                  rng=Overblik!C69         cdim=1  rdim=1
text="Brændselsforbrug"             rng=Overblik!C69:C69
par=Scen_IncomeFuel                 rng=Overblik!C101        cdim=1  rdim=1
text="Brændselsindkomst"            rng=Overblik!C101:C101
*end

$offecho

# Write the output Excel file using GDXXRW.
execute "gdxxrw.exe REFAscens.gdx o=REFAscens.xlsm trace=1 @REFAscens.txt";

$If not errorfree $exit

# ======================================================================================================================
# Python script to copy the recently saved output files.
embeddedCode Python:
  import os
  import shutil
  import datetime
  currentDate = datetime.datetime.today().strftime('%Y-%m-%d %Hh%Mm%Ss')

  #--- actIter = list(gams.get('actIter'))[0]
  #--- per  = 'per' + str(int( list(gams.get('PeriodLast'))[0] ))
  #--- scenId = str(int( list(gams.get('ScenId'))[0] ))
  #--- gams.printLog("per = " + per + ", scenId = " + scenId)

  wkdir = os.getcwd()

  # Copy Excel file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAscens.xlsm')
  fpathNew = os.path.join(wkdir, r'Output\REFAscens (' + str(currentDate) + ').xlsm')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('Excel file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

  # Copy gdx file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAscens.gdx')
  fpathNew = os.path.join(wkdir, r'Output\REFAscens (' + str(currentDate) + ').gdx')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('GDX file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

endEmbeddedCode
# ======================================================================================================================

);

