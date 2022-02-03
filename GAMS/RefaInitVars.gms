$log Entering file: %system.incName%

# Filnavn: RefaInitVars.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til initialisering af variable.


#begin Initialisering af variable.

# Fiksering af ikke-forbundne anlæg+drivmidler, samt af ikke-aktive anlaeg og ikke-aktive drivmidler.
# Først løsnes variable, som kunne være blevet fikseret i forrige scenarie.
if (nScen GE 2,
  bOnU.up(u,moall)              =  1;
  bOnSto.up(s,moall)            =  1;
  bOnRgk.up(ua,moall)           =  1;
  bOnRgkRabat.up(moall)         =  1;
  IncomeAff.up(f,moall)         = Big;
  CostsPurchaseF.up(f,moall)    = Big;
  CostsU.up(u,moall)            = Big;
  Pbrut.up(moall)               = Big;
  Pnet.up(moall)                = Big;
  Q.up(u,moall)                 = Big;
  Qbypass.up(moall)             = Big;
  StoLoad.up(s,moall)           = Big;
  StoLoss.up(s,moall)           = Big;
  StoDLoad.up(s,moall)          = Big;
  StoDLoadAbs.up(s,moall)       = Big;
  StoCostAll.up(s,moall)        = Big;
  StoDLoadF.up(s,f,moall)       = Big;
  CO2emisF.up(f,moall,typeCO2)  = Big;
  FuelDelivT.up(f,moall)        = Big;
  FuelConsT.up(u,f,moall)       = Big;
  FuelConsP.up(f,moall)         = Big;
  StoDLoadF.up(s,f,moall)       = Big;
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

