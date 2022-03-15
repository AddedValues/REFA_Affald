$log Entering file: %system.incName%

# Filnavn: RefaInitVars.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til initialisering af variable.


#begin Initialisering af variable.

# Fiksering af ikke-forbundne anlæg+drivmidler, samt af ikke-aktive anlaeg og ikke-aktive drivmidler.
# Først løsnes variable, som kunne være blevet fikseret i forrige scenarie.
if (nScen GE 1,
  bOnU.up(u,moall)              =  1;
  bOnSto.up(s,moall)            =  1;
  bOnRgk.up(ua,moall)           =  1;
  bOnRgkRabat.up(moall)         =  1;
  
  FuelConsT.up(u,f,moall)            = Big $(OnGU(u) AND OnGF(f));
  FuelConsP.up(f,moall)              = Big $(OnGF(f));
  FuelResaleT.up(f,moall)            = Big $(OnGF(f));
  FuelDelivT.up(f,moall)             = Big $(OnGF(f));
  FuelDelivFreeSumT.up(f)            = Big $(OnGF(f));

  StoDLoadF.up(s,f,moall)            = Big $(OnGS(s) AND OnGF(f));
  StoCostAll.up(s,moall)             = Big $(OnGS(s));
  StoCostLoad.up(s,moall)            = Big $(OnGS(s));
  StoCostDLoad.up(s,moall)           = Big $(OnGS(s));
  StoLoad.up(s,moall)                = Big $(OnGS(s));
  StoLoss.up(s,moall)                = Big $(OnGS(s));
  StoLossF.up(s,f,moall)             = Big $(OnGS(s) AND OnGF(f));
  StoDLoad.up(s,moall)               = Big $(OnGS(s));
  StoDLoadAbs.up(s,moall)            = Big $(OnGS(s));
  StoLoadF.up(s,f,moall)             = Big $(OnGS(s) AND OnGF(f));
                                     
  StoDLoadF.lo(s,f,moall)            = -Big $(OnGS(s) AND OnGF(f));
  StoDLoad.lo(s,moall)               = -Big $(OnGS(s));
                                     
  PbrutMax.up(moall)                 = Big $OnGU('Ovn3'); 
  Pbrut.up(moall)                    = Big $OnGU('Ovn3'); 
  Pnet.up(moall)                     = Big $OnGU('Ovn3'); 
  Qbypass.up(moall)                  = Big $OnGU('Ovn3'); 
  Q.up(u,moall)                      = Big $OnGU(u); 
  QaffM.up(ua,moall)                 = Big $(OnGU(ua)); 
  Qrgk.up(ua,moall)                  = Big $(OnGU(ua)); 
  Qafv.up(moall)                     = Big; 
  QRgkMiss.up(moall)                 = Big; 
                                     
  FEBiogen.up(u,moall)               = Big $(OnGU(u) AND ua(u)); 
  FuelHeatAff.up(moall)              = Big; 
  QBiogen.up(u,moall)                = Big $(OnGU(u) AND ua(u)); 
  
  QtotalCool.up(moall)               = Big; 
  QtotalAff.up(moall)                = Big; 
  EtotalAff.up(moall)                = Big; 
  QtotalAfgift.up(phiKind,moall)     = Big; 
  QudenRgk.up(moall)                 = Big; 
  QmedRgk.up(moall)                  = Big; 
  Quden_X_bOnRgkRabat.up(moall)      = Big; 
  Qmed_X_bOnRgkRabat.up(moall)       = Big; 
  
  IncomeTotal.up(moall)              = Big; 
  IncomeElec.up(moall)               = Big; 
  IncomeHeat.up(moall)               = Big; 
  IncomeAff.up(f,moall)              = Big $(OnGF(f)); 
  RgkRabat.up(moall)                 = Big; 
  CostsTotal.up(moall)               = Big; 
  CostsTotalOwner.up(owner,moall)    = Big; 
  CostsU.up(u,moall)                 = Big $(OnGU(u)); 
  CostsPurchaseF.up(f,moall)         = Big $(OnGF(f)); 
                                     
  TaxAFV.up(moall)                   = Big; 
  TaxATL.up(moall)                   = Big; 
  TaxCO2total.up(moall)              = Big; 
  TaxCO2Aff.up(moall)                = Big; 
  TaxCO2Aux.up(moall)                = Big; 
  TaxCO2F.up(f,moall)                = Big $(OnGF(f)); 
  TaxNOxF.up(f,moall)                = Big $(OnGF(f)); 
  TaxEnr.up(moall)                   = Big; 
                                     
  CostsETS.up(moall)                 = Big; 
  CO2emisF.up(f,moall,typeCO2)       = Big $(OnGF(f)); 
  CO2emisAff.up(moall,typeCO2)       = Big; 
  TotalAffEProd.up(moall)            = Big; 
                                     
  QInfeas.up(dir,moall)              = Big; 
  AffTInfeas.up(dir,moall)           = Big; 
);

# Dernæst udføres fikseringer svarende til det aktuelle scenarie.
Loop (u $(NOT OnGU(u)),
  bOnU.fx(u,mo)         = 0.0;
  Q.fx(u,mo)            = 0.0;
  CostsU.fx(u,mo)       = 0.0;
  FuelConsT.fx(u,f,mo)  = 0.0;
);

if (NOT OnGU('Ovn3'),
  Pbrut.fx(mo)   = 0.0;
  Pnet.fx(mo)    = 0.0;
  Qbypass.fx(mo) = 0.0;
);

Loop (s $(NOT OnGS(s)),
  bOnSto.fx(s,mo)      = 0.0;
  StoLoad.fx(s,mo)     = 0.0;
  StoLoss.fx(s,mo)     = 0.0;
  StoDLoad.fx(s,mo)    = 0.0;
  StoDLoadAbs.fx(s,mo) = 0.0;
  StoCostAll.fx(s,mo)  = 0.0;
  StoDLoadF.fx(s,f,mo) = 0.0;
);

Loop (f $(NOT OnGF(f)),
  CostsPurchaseF.fx(f,mo)    = 0.0;
  IncomeAff.fx(f,mo)         = 0.0;
  CO2emisF.fx(f,mo,typeCO2)  = 0.0;
  FuelDelivT.fx(f,mo)        = 0.0;
  FuelConsT.fx(u,f,mo)       = 0.0;
  FuelConsP.fx(f,mo)         = 0.0;
  StoDLoadF.fx(s,f,mo)       = 0.0;
);

# Brændselsomkostning hhv. -indtægt.
CostsPurchaseF.fx(f,mo) $fpospris(f,mo) = 0.0;
IncomeAff.fx(f,mo)      $fnegpris(f,mo) = 0.0;

# Fiksering (betinget) af lagerbeholdning i sidste måned.
$OffOrder
Loop (s $OnGS(s),
  if (DataSto(s,'ResetLast',moFirst) NE 0,
    bOnSto.fx(s,mo)  $(ord(mo) EQ NactiveM) = 0;
    StoLoad.fx(s,mo) $(ord(mo) EQ NactiveM) = 0.0;
  );
);
$OnOrder

# Fiksering af RGK-produktion til nul på ikke-aktive affaldsanlaeg.
Loop (ua $(NOT OnGU(ua)), bOnRgk.fx(ua,mo) = 0.0; );

# Restriktion på bypass.
Loop (mo,
  if (NOT OnBypass(mo),
    Qbypass.fx(mo) = 0.0;
  );
);

#end Initialisering af variable.

