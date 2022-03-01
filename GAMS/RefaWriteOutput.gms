$log Entering file: %system.incName%

# Filnavn: RefaWriteOutput.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til postprocessering af resultater for aktuelt scenarie og udskrivning til Excel.

# ------------------------------------------------------------------------------------------------
# Efterbehandling af resultater for aktuelt scenarie.
# ------------------------------------------------------------------------------------------------

# Tilbageføring til NPV af penalty costs og omkostninger fra ikke-inkluderede anlaeg og braendsler samt gevinst for Ovn3-varme.
PenaltyTotal_bOnU           = Penalty_bOnU * sum(mo, sum(u, bOnU.L(u,mo)));
Penalty_TotalQRgkMiss       = Penalty_QRgkMiss * sum(mo, QRgkMiss.L(mo));
PenaltyTotal_AffaldsGensalg = Penalty_AffaldsGensalg * sum(mo, sum(f $OnF(f,mo), FuelResaleT.L(f,mo)));
Penalty_QInfeasTotal        = Penalty_QInfeas    * sum(dir, sum(mo, QInfeas.L(dir,mo)));
PenaltyTotal_AffTInfeas     = Penalty_AffTInfeas * sum(dir, sum(mo, AffTInfeas.L(dir,mo)));
PenaltyTotal_QFlisK         = Penalty_QFlisK     * sum(ub, sum(mo, Q.L(ub,mo)));
GainTotal_Qaff              = sum(ua, Gain_Qaff(ua) * sum(mo, Q.L(ua,mo)));

# NPV_Total_V er den samlede NPV med tilbageførte penalties.
NPV_Total_V = NPV.L + [Penalty_QInfeasTotal + PenaltyTotal_AffTInfeas]
                    + [PenaltyTotal_bOnU + Penalty_TotalQRgkMiss + PenaltyTotal_AffaldsGensalg + PenaltyTotal_QFlisK]
                    - [GainTotal_Qaff];

# NPV_REFA_V er REFAs andel af NPV med tilbageførte penalties og tilbageførte GSF-omkostninger.
NPV_REFA_V  = NPV_Total_V + sum(mo, CostsTotalOwner.L('gsf',mo));

#--- display PenaltyTotal_bOnU, Penalty_TotalQRgkMiss, NPV.L, NPV_Total_V, NPV_REFA_V;

# ------------------------------------------------------------------------------------------------
# Beregn sammenfattende data til overordnet eftervisning af inputdata.
#+++ FuelConsTsum_V(ua,mo) = sum(fa, FuelConsT.L(ua,fa,mo)); 
#+++ FuelConsPsum_V(mo) = sum(f, FuelConsP.L(fa,mo)); 
#+++ QaffMmax_V(ua,mo)  = EtaQ(ua,mo)     * FuelConsP.L(fa,mo);
#+++ QrgkMax_V(ua,mo)   = EtaRgk(ua,mo)   * FuelConsP.L(fa,mo);
#+++ PbrutMax_V(mo)     = EtaE('Ovn3',mo) * FuelConsP.L(fa,mo);
#+++ 
#+++ StatsMonth('FuelConsT',mo) = max(tiny, sum(ua, FuelConsTsum_V(mo))));
#+++ StatsMonth('FuelConsP',mo) = max(tiny, FuelConsPsum_V(mo)));
#+++ StatsMonth('QaffMmax',mo)  = max(tiny, sum(ua, QaffMmax_V(ua,mo)));
#+++ StatsMonth('QrgkMax',mo)   = max(tiny, sum(ua, QrgkMax_V(ua,mo)));
#+++ StatsMonth('PbrutMax',mo)  = max(tiny, sum(mo, PbrutMax_V(mo)));
#+++ 
#+++ Stats('Diff_FuelConsT') = Stats('FuelConsT') - sum(mo, sum(ua, sum(fa, FuelConstT.L(ua,fa,mo))));
#+++ Stats('Diff_FuelConsP') = Stats('FuelConsP') - sum(mo, sum(fa, FuelConsP.L(fa,mo)));
#+++ Stats('Diff_QaffMmax-Ovn2')  = Stats('QaffMmax')  - sum(mo, sum(ua))
#+++ Stats('Diff_QrgkMax')   = Stats('QrgkMax')   
#+++ Stats('Diff_PbrutMax')  = Stats('PbrutMax')  


# ------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------
# Sammenfat og udskriv resultater til Excel output fil.
# ------------------------------------------------------------------------------------------------

# Tidsstempel for beregningens udfoerelse.

TimeOfWritingMasterResults = jnow;
PerStart = Schedule('dato','firstPeriod');
PerSlut  = Schedule('dato','lastPeriod');
VPO_V(uaggr,mo) = 0.0;
# Sammenfatning af aggregerede resultater.

# Scenarieresultater
Loop (mo $(NOT sameas(mo,'mo0')),
  RefaAffaldModtagelse_V(mo)               = max(tiny, sum(fa $OnF(fa,mo), IncomeAff.L(fa,mo)));
  RefaRgkRabat_V(mo)                       = max(tiny, RgkRabat.L(mo));
  RefaElsalg_V(mo)                         = max(tiny, IncomeElec.L(mo));
  RefaVarmeSalg_V(mo)                      = max(tiny, IncomeHeat.L(mo));
  RefaTotalVarIndkomst_V(mo)               = RefaAffaldModtagelse_V(mo) + RefaRgkRabat_V(mo) + RefaElsalg_V(mo) + RefaVarmeSalg_V(mo);
  OverView('REFA-Affald-Modtagelse',mo)    = max(tiny, RefaAffaldModtagelse_V(mo) );
  OverView('REFA-RGK-Rabat',mo)            = max(tiny, RefaRgkRabat_V(mo) );
  OverView('REFA-Elsalg',mo)               = max(tiny, RefaElsalg_V(mo) );
  OverView('REFA-Varmesalg',mo)            = max(tiny, RefaVarmeSalg_V(mo) );

  RefaAnlaegsVarOmk_V(mo)                  = sum(urefa $OnU(urefa,mo), CostsU.L(urefa,mo));
  RefaBraendselsVarOmk_V(mo)               = sum(frefa, CostsPurchaseF.L(frefa,mo));
  RefaAfgifter_V(mo)                       = TaxAFV.L(mo) + TaxATL.L(mo) + TaxCO2Aff.L(mo) + sum(frefa, TaxNOxF.L(frefa,mo));
  RefaAfgiftAFV_V(mo)                      = TaxAFV.L(mo);
  RefaAfgiftATL_V(mo)                      = TaxATL.L(mo);
  RefaAfgiftCO2_V(mo)                      = TaxCO2Aff.L(mo);
  RefaAfgiftNOx_V(mo)                      = sum(frefa, TaxNOxF.L(frefa,mo));
  RefaKvoteOmk_V(mo)                       = max(tiny, CostsETS.L(mo));  # Kun REFA er kvoteomfattet.
  RefaStoCost_V(mo)                        = sum(s $OnS(s,mo), StoCostAll.L(s,mo));
  RefaTotalVarOmk_V(mo)                    = RefaAnlaegsVarOmk_V(mo) + RefaBraendselsVarOmk_V(mo) + RefaAfgifter_V(mo) + RefaKvoteOmk_V(mo) + RefaStoCost_V(mo);
  RefaDaekningsbidrag_V(mo)                = RefaTotalVarIndkomst_V(mo) - RefaTotalVarOmk_V(mo);
  OverView('REFA-AnlaegsVarOmk',mo)        = max(tiny, RefaAnlaegsVarOmk_V(mo) );
  OverView('REFA-BraendselOmk',mo)         = max(tiny, RefaBraendselsVarOmk_V(mo) );
  OverView('REFA-Afgifter',mo)             = max(tiny, RefaAfgifter_V(mo) );
  OverView('REFA-Affaldvarme-afgift',mo)   = max(tiny, RefaAfgiftAFV_V(mo) );
  OverView('REFA-Tillaegs-Afgift',mo)      = max(tiny, RefaAfgiftATL_V(mo) );
  OverView('REFA-CO2-Afgift',mo)           = max(tiny, RefaAfgiftCO2_V(mo) );
  OverView('REFA-NOx-Afgift',mo)           = max(tiny, RefaAfgiftNOx_V(mo) );
  OverView('REFA-CO2-Kvoteomk',mo)         = max(tiny, RefaKvoteOmk_V(mo) );
  OverView('REFA-Lageromkostning',mo)      = max(tiny, RefaStoCost_V(mo) );
  OverView('REFA-Total-Var-Indkomst',mo)   = max(tiny, RefaTotalVarIndkomst_V(mo) );
  OverView('REFA-Total-Var-Omkostning',mo) = max(tiny, RefaTotalVarOmk_V(mo) );
  OverView('REFA-Daekningsbidrag',mo)      = ifthen(RefaDaekningsbidrag_V(mo) EQ 0.0, tiny, RefaDaekningsbidrag_V(mo));

# TODO: Skal tilrettes ændrede CO2-opgørelser.
  RefaCO2emission_V(mo,typeCO2)            = max(tiny, sum(frefa $OnF(frefa,mo), CO2emisF.L(frefa,mo,typeCO2)) );
  RefaElproduktionBrutto_V(mo)             = max(tiny, Pbrut.L(mo));
  RefaElproduktionNetto_V(mo)              = max(tiny, Pnet.L(mo));
  OverView('REFA-CO2-Emission-afgift',mo)  = RefaCO2emission_V(mo,'afgift');
  OverView('REFA-CO2-Emission-kvote',mo)   = RefaCO2emission_V(mo,'kvote');
  OverView('REFA-El-produktion-Brutto',mo) = RefaElproduktionBrutto_V(mo);
  OverView('REFA-El-produktion-Netto',mo)  = RefaElproduktionNetto_V(mo);

  AffaldAvail_V(mo)     = max(tiny, sum(fa $OnF(fa,mo), FuelBounds(fa,'MaxTonnage',mo)));
  AffaldConsTotal_V(mo) = max(tiny, sum(fa, sum(ua, FuelConsT.L(ua,fa,mo))));
  AffaldUudnyttet_V(mo) = max(tiny, sum(fa, FuelResaleT.L(fa,mo)));
  AffaldLagret_V(mo)    = max(tiny, sum(s, StoLoad.L(s,mo)));
  Overview('REFA-Total-Affald-Raadighed',mo) = AffaldAvail_V(mo);
  Overview('REFA-Affald-anvendt',mo)         = AffaldConsTotal_V(mo);
  Overview('REFA-Affald-Uudnyttet',mo)       = AffaldUudnyttet_V(mo);
  Overview('REFA-Affald-Lagret',mo)          = AffaldLagret_V(mo);


  RefaVarmeProd_V(mo)       = max(tiny, sum(uprefa $OnU(uprefa,mo), Q.L(uprefa,mo)) );
  RefaModtrykProd_V(mo)     = max(tiny, sum(ua $OnU(ua,mo), QAffM.L(ua,mo)) );
  RefaBypassVarme_V(mo)     = max(tiny, Qbypass.L(mo));
  RefaRgkProd_V(mo)         = max(tiny, sum(ua $OnU(ua,mo), Qrgk.L(ua,mo)) );
  RefaRgkShare_V(mo)        = max(tiny, sum(ua $OnU(ua,mo), Qrgk.L(ua,mo)) / sum(ua $OnU(ua,mo), Q.L(ua,mo)) );
  RefaBortkoeletVarme_V(mo) = max(tiny, sum(uv $OnU(uv,mo), Q.L(uv,mo)) );
  RefaVarmeLeveret_V(mo)    = RefaVarmeProd_V(mo) - RefaBortkoeletVarme_V(mo);
  OverView('REFA-Total-Varme-Produktion',mo) = RefaVarmeProd_V(mo);
  OverView('REFA-Leveret-Varme',mo)          = RefaVarmeLeveret_V(mo);
  OverView('REFA-Modtryk-Varme',mo)          = RefaModtrykProd_V(mo);
  OverView('REFA-Bypass-Varme',mo)           = RefaBypassVarme_V(mo);
  OverView('REFA-RGK-Varme',mo)              = RefaRgkProd_V(mo);
  OverView('REFA-RGK-Andel',mo)              = RefaRgkShare_V(mo);
  OverView('REFA-Bortkoelet-Varme',mo)       = RefaBortkoeletVarme_V(mo);

  GsfAnlaegsVarOmk_V(mo)                    = sum(ugsf, CostsU.L(ugsf, mo) );
  GsfBraendselsVarOmk_V(mo)                 = sum(fgsf, CostsPurchaseF.L(fgsf,mo) );
  GsfAfgifter_V(mo)                         = sum(fgsf, TaxCO2Aux.L(mo) + taxNOxF.L(fgsf,mo)) + TaxEnr.L(mo);
  GsfCO2emission_V(mo)                      = sum(fgsf, CO2emisF.L(fgsf,mo,'afgift') );
  GsfTotalVarmeProd_V(mo)                   = sum(ugsf, Q.L(ugsf,mo) );
  GsfTotalVarOmk_V(mo)                      = GsfAnlaegsVarOmk_V(mo) + GsfBraendselsVarOmk_V(mo) + GsfAfgifter_V(mo);
  OverView('GSF-AnlaegsVarOmk',mo)          = max(tiny, GsfAnlaegsVarOmk_V(mo) );
  OverView('GSF-BraendselOmk',mo)           = max(tiny, GsfBraendselsVarOmk_V(mo) );
  OverView('GSF-Afgifter',mo)               = max(tiny, GsfAfgifter_V(mo) );
  OverView('GSF-CO2-Emission',mo)           = max(tiny, GsfCO2emission_V(mo) );
  OverView('GSF-Total-Varme-Produktion',mo) = max(tiny, GsfTotalVarmeProd_V(mo) );
  OverView('GSF-Total-Var-Omkostning',mo)   = max(tiny, GsfTotalVarOmk_V(mo) );

  NsTotalVarmeProd_V(mo)                    = max(tiny, sum(uc, Q.L(uc,mo)) );
  OverView('NS-Total-Varme-Produktion',mo)  = NsTotalVarmeProd_V(mo);

  OverView('Virtuel-Varme-Kilde',mo)          = max(tiny, QInfeas.L('source',mo));
  OverView('Virtuel-Varme-Draen',mo)          = max(tiny, QInfeas.L('drain',mo));
  OverView('Virtuel-Affaldstonnage-Kilde',mo) = max(tiny, AffTInfeas.L('source',mo));
  OverView('Virtuel-Affaldstonnage-Draen',mo) = max(tiny, AffTInfeas.L('drain',mo));

#---  VarmeVarProdOmkTotal_V(mo) = (sum(u $OnGU(u), CostsU.L(u,mo)) + sum(owner, CostsTotalF.L(owner,mo)) - IncomeTotal.L(mo)) / (sum(up, Q.L(up,mo) - sum(uv, Q.L(uv,mo))));
#---  VarmeVarProdOmkRefa_V(mo)  = (sum(urefa, CostsU.L(urefa,mo)) + CostsTotalF.L('refa',mo) - IncomeTotal.L(mo)) / (sum(uprefa, Q.L(uprefa,mo)) - sum(uv, Q.L(uv,mo)));
  VarmeVarProdOmkTotal_V(mo)  = (RefaTotalVarOmk_V(mo) - RefaTotalVarIndkomst_V(mo) + GsfTotalVarOmk_V(mo)) / Qdemand(mo);
  VarmeVarProdOmkRefa_V(mo)   = (RefaTotalVarOmk_V(mo) - RefaTotalVarIndkomst_V(mo)) / (sum(uprefa, Q.L(uprefa,mo)) - sum(uv, Q.L(uv,mo)));
  Overview('FJV-behov',mo)                      = max(tiny, Qdemand(mo));
  OverView('Total-Var-Varmeproduktions-Omk',mo) = ifthen(VarmeVarProdOmkTotal_V(mo) EQ 0.0, tiny, VarmeVarProdOmkTotal_V(mo));
  OverView('REFA-Var-Varmeproduktions-Omk',mo)  = ifthen(VarmeVarProdOmkRefa_V(mo) EQ 0.0,  tiny, VarmeVarProdOmkRefa_V(mo));


  Loop (f,
    FuelDeliv_V(f,mo) = max(tiny, FuelDelivT.L(f,mo)) $OnF(f,mo) - tiny $(NOT OnGF(f));
    IncomeFuel_V(f,mo) = (IncomeAff.L(f,mo) - CostsPurchaseF.L(f,mo)) $OnF(f,mo) - tiny $(NOT OnF(f,mo));
    if (IncomeFuel_V(f,mo) EQ 0.0, IncomeFuel_V(f,mo) = tiny; );
  );

  FuelConsT_V(u,f,mo) = max(tiny, FuelConsT.L(u,f,mo)) $(OnF(f,mo) AND OnU(u,mo) AND u2f(u,f,mo))  - tiny $(OnF(f,mo) AND OnU(u,mo) AND u2f(u,f,mo));
  FuelConsP_V(u,f,mo) = max(tiny, FuelConsT.L(u,f,mo) * LhvMWh(f,mo));

  Loop (f $(OnF(f,mo) AND fa(f) AND fsto(f)),
    StoDLoadF_V(sa,f,mo)  = max(tiny, StoDLoadF.L(sa,f,mo));
    StoLoadF_V(sa,f,mo)   = max(tiny, StoLoadF.L(sa,f,mo));
  );

  StoLoadAll_V(s,mo) = max(tiny, StoLoad.L(s,mo));


  Q_V(u,mo)  = ifthen (Q.L(u,mo) EQ 0.0, tiny, Q.L(u,mo));
  Q_V(uv,mo) = -Q_V(uv,mo);            # Negation aht. afbildning i sheet Overblik.
  Q_V(u,mo) $(NOT OnU(u,mo)) = -tiny;  # Markerer ikke-rÃ¥dige anlæg.
  Loop (u $OnU(u,mo),
    if (Q.L(u,mo) GT 0.0 AND ShareAvailU(u,mo) GT 0.0,
      #--- Usage_V(u,mo) = Q.L(u,mo) / (KapMax(u,mo) * ShareAvailU(u,mo) * Hours(mo));
      Usage_V(u,mo) = Q.L(u,mo) / (KapMax(u,mo) * Hours(mo));
    else
      Usage_V(u,mo) = tiny;
    );
    if (up(u),
      # Realiseret brændværdi.
      tmp1 = sum(f $(OnF(f,mo) AND u2f(u,f,mo)), FuelConsT.L(u,f,mo));
      if (tmp1 GT 0.0,
        LhvCons_V(u,mo) = 3.6 * sum(f $(OnF(f,mo) AND u2f(u,f,mo)), FuelConsT.L(u,f,mo) * LhvMWh(f,mo)) / tmp1;
      );
      # Tonnage indfyret.
      tmp2 = ShareAvailU(u,mo) * Hours(mo);
      if (tmp2 GT 0.0,
        FuelConsumed_V(u,mo) = sum(f $(OnF(f,mo) AND u2f(u,f,mo)), FuelConsT.L(u,f,mo)) / tmp2;
      );
    );
  );

  # VPO_V: Varmeproduktionsomkostning pr. aggregeret anlæg og mÃ¥ned.
  # Affaldsanlæg
  db = RefaAffaldModtagelse_V(mo) + RefaRgkRabat_V(mo) + RefaElsalg_V(mo)
       - sum(ua, CostsU.L(ua,mo))
       - sum(fa, CostsPurchaseF.L(fa,mo))
       - TaxAFV.L(mo) + TaxATL.L(mo) + TaxCO2Aff.L(mo) + sum(fa, TaxNOxF.L(fa,mo))
       - RefaKvoteOmk_V(mo)
       - RefaStoCost_V(mo);
  qdeliv = sum(ua, Q.L(ua,mo)) - sum(uv, Q.L(uv,mo));
  if (qdeliv GT 1E-8, VPO_V('Affald',mo) = -db/qdeliv; );

  # Fliskedel
  db = - sum(ub, CostsU.L(ub,mo))
       - sum(fb, CostsPurchaseF.L(fb,mo))
       - sum(fb, TaxNOxF.L(fb,mo));
   qdeliv = sum(ub, Q.L(ub,mo));
  if (qdeliv GT 1E-8, VPO_V('Fliskedel',mo) = -db/qdeliv; );

  # SR-kedel
  db = - sum(ur, CostsU.L(ur,mo))
       - sum(fr, CostsPurchaseF.L(fr,mo))
       - sum(fr, TaxNOxF.L(fr,mo));
   qdeliv = sum(ur, Q.L(ur,mo));
  if (qdeliv GT 1E-8, VPO_V('SR-kedel',mo) = -db/qdeliv; );
);

DataCtrl_V(labDataCtrl)            = ifthen(DataCtrlRead(labDataCtrl)   EQ 0.0, tiny, DataCtrlRead(labDataCtrl));
DataU_V(u,labDataU)                = ifthen(DataURead(u,labDataU)       EQ 0.0, tiny, DataURead(u,labDataU));
DataU_V(u,'MinLast')               = 0.0;
DataU_V(u,'KapMin')                = 0.0;
DataSto_V(s,labDataSto)            = ifthen(DataStoRead(s,labDataSto)   EQ 0.0, tiny, DataStoRead(s,labDataSto));
DataFuel_V(f,labDataFuel)          = ifthen(DataFuelRead(f,labDataFuel) EQ 0.0, tiny, DataFuelRead(f,labDataFuel));
DataProgn_V(labDataProgn,mo)       = ifthen(DataPrognRead(mo,labDataProgn) EQ 0.0, tiny, DataPrognRead(mo,labDataProgn));
FuelBounds_V(f,fuelItem,mo)        = max(tiny, FuelBounds(f,fuelItem,mo));
DataUFull_V(u,labDataU,mo)         = ifthen(DataU(u,labDataU,mo)       EQ 0.0, tiny, DataU(u,labDataU,mo));
DataStoFull_V(s,labDataSto,mo)     = ifthen(DataSto(s,labDataSto,mo)   EQ 0.0, tiny, DataSto(s,labDataSto,mo));
FuelBounds_V(f,fuelItem,mo)        = ifthen(FuelBounds(f,fuelItem,mo) EQ 0.0, tiny, FuelBounds(f,fuelItem,mo));

# Sikre at kolonne 'mo0' ikke udskrives til Excel.
DataProgn_V(labDataProgn,'mo0') = tiny;  
FuelBounds_V(f,fuelItem,'mo0')  = 0.0;   
FuelDeliv_V(f,'mo0')            = 0.0;   
StoDLoadF_V(s,f,'mo0')          = 0.0;
FuelConsT_V(u,f,'mo0')          = 0.0;

VirtualUsed = VirtualUsed OR sum(dir, sum(mo, QInfeas.L(dir,mo))) GT tiny OR sum(dir, sum(mo, AffTInfeas.L(dir,mo))) GT tiny;

# Overførsel af aktuelt scenaries nøgletal til opsamlings-array.
#--- Scen_TimeStamp(actScen) = mod(TimeOfWritingMasterResults, 1);  # Gemmer kun tidspunktet, men ikke døgnet.

Scen_Q(u,actScen)          = sum(mo, Q_V(u,mo));
Scen_FuelDeliv(f,actScen)  = sum(mo, FuelDeliv_V(f,mo));
Scen_IncomeFuel(f,actScen) = sum(mo, IncomeFuel_V(f,mo));

Scen_Overview('Tidsstempel',actScen) = frac(TimeOfWritingMasterResults);  # Gemmer kun tidspunktet, men ikke døgnet.
Scen_Overview('Total-NPV',actScen) = NPV_Total_V;
Scen_Overview('REFA-NPV', actScen) = NPV_REFA_V;

Loop (topicSummable,
  Scen_Overview(topicSummable,actScen) = sum(mo, OverView(topicSummable,mo));
);
# Følgende topic giver ikke mening som sumtal.
Scen_Overview('REFA-RGK-Andel',actScen) = 0.0;

#TODO Afgrænses til scenarie records for actuelt scenarie.
actScenRecs(scRec) = (ScenRecs(scRec,'ScenId') EQ ord(scen) - 1) AND (ScenRecs(scRec,'Aktiv') NE 0);
Scen_Recs(actScenRecs,labScenRec) = ScenRecs(actScenRecs,labScenRec);
display actScen, actScenRecs;

#--- if (NOT sameas(actScen,'scen0'),
#---   Loop (labPrognScen $(Scen_Progn(actScen,labPrognScen) NE NaN),  #---  AND NOT sameas(labPrognScen,'Aktiv')),
#---     Scen_Progn_Transpose(labPrognScen,actScen) = Scen_Progn(actScen,labPrognScen);
#---   );
#--- );


execute_unload 'REFAoutput.gdx',
TimeOfWritingMasterResults, scen, actScen,
bound, moall, mo, fkind, f, fa, fb, fc, fr, u, up, ua, ub, uc, ur, u2f, s2f, fuelItem,
labDataU, labDataFuel, labSchRow, labSchCol, labDataProgn, taxkind, topic, typeCO2,
Scen_Overview, Scen_Q, Scen_FuelDeliv, Scen_IncomeFuel,
ScenRecs, #--- Scen_Progn, 
Schedule, DataCtrl_V, DataU_V, DataSto_V, DataProgn_V, AvailDaysU, DataFuel_V, FuelBounds_V,
DataUFull_V, DataStoFull_V, FuelBounds_V,
OnGU, OnGF, OnM, OnGS, OnU, OnS, OnF, Hours, ShareAvailU, EtaQ, KapMin, KapQNom, KapRgk, KapMax, Qdemand, LhvMWh,
Pbrut, Pnet, Qbypass,
TaxAfvMWh, TaxAtlMWh, TaxCO2AffTon, TaxCO2peakTon,
EaffGross, QaffMmax, QrgkMax, QaffTotalMax, TaxATLMax, RgkRabatMax,
OverView, NPV_Total_V, NPV_REFA_V, DataProgn_V, FuelDeliv_V, FuelConsT_V, StoLoadF_V, StoDLoadF_V, IncomeFuel_V, Q_V, VPO_V,
PerStart, PerSlut, VirtualUsed,

RefaDaekningsbidrag_V,
RefaTotalVarIndkomst_V,
RefaAffaldModtagelse_V,
RefaRgkRabat_V,
RefaElsalg_V,

RefaTotalVarOmk_V,
RefaAnlaegsVarOmk_V,
RefaBraendselsVarOmk_V,
RefaAfgifter_V,
RefaKvoteOmk_V,
RefaStoCost_V,
RefaCO2emission_V,
RefaElproduktionBrutto_V,
RefaElproduktionNetto_V,

AffaldConsTotal_V,
AffaldAvail_V,
AffaldUudnyttet_V,
AffaldLagret_V,

RefaVarmeProd_V,
RefaVarmeLeveret_V,
RefaModtrykProd_V,
RefaBypassVarme_V,
RefaRgkProd_V,
RefaRgkShare_V,
RefaBortkoeletVarme_V,
VarmeVarProdOmkTotal_V,
VarmeVarProdOmkRefa_V,
RefaLagerBeholdning_V,
StoLoadAll_V,
Usage_V,
LhvCons_V,

GsfTotalVarOmk_V,
GsfAnlaegsVarOmk_V,
GsfBraendselsVarOmk_V,
GsfAfgifter_V,
GsfCO2emission_V,
GsfTotalVarmeProd_V
;

$OnText
* NOTE on using GDXXRW to export GDX results to Excel. McCarl
* Any item to be exported must be unloaded (saved) to a gdx file using the execute_unload stmt (see above).
* 1: By default an item is assumed to be a table (2D) and the first index being the row index.
* 2: By vectors (1D) do specify cdim=0 to obtain a column vector, otherwise a row vector is obtained.
* 3: GDXXRW args options cdim and rdim DataCtrl how a multi-dim item is written to the Excel sheet:
*    a: cdim is the no. of dimensions going into columns.
*    b: rdim is the no. of dimensions going into rows.
*    c: The dimension of the item must equal cdim + rdim.
* 4: Column indices are the rightmost indices of the item (indices are set names).
* 5: The name of the item is not written as a part of export stmt eg var=<varname> rng=<sheetname>!<topleft cell> cdim=... rdim=...
* 6: When cdim=0 the range will hold no header row ie. the range should be addressed to begin one row lower than multidim. items.
* 7: Formulas cannot be written. A text starting with '=' raises a 'Parameter missing for option' error.
* See details and examples in the McCarl article "Rearranging rows and columns" in the GAMS Documentation Center.
$OffText


$onecho > REFAoutput.txt
filter=0

* OBS: Vaerdier udskrives i basale enheder, men formatteres i Excel til visning af fx. tusinder fremfor enere.

*begin Individuelle dataark

* sheet Inputs
par=DataCtrl_V            rng=Inputs!B3         cdim=0  rdim=1
text="Styringsparameter"  rng=Inputs!B2:B2
par=Schedule              rng=Inputs!B15        cdim=1  rdim=1
text="Schedule"           rng=Inputs!B15:B15
par=DataU_V               rng=Inputs!B21        cdim=1  rdim=1
text="DataU"              rng=Inputs!B21:B21
par=DataSto_V             rng=Inputs!B29        cdim=1  rdim=1
text="DataSto"            rng=Inputs!B29:B29
par=DataFuel_V            rng=Inputs!B43        cdim=1  rdim=1
text="DataFuel"           rng=Inputs!B43:B43
par=DataProgn_V           rng=Inputs!T15        cdim=1  rdim=1
text="Prognoser"          rng=Inputs!T15:T15
par=FuelBounds_V          rng=Inputs!T43        cdim=1  rdim=2
text="FuelBounds"         rng=Inputs!T43:T43
* Fuldt tidsafhængige anvendte data (som modificeret af aktuelle scenarie).
par=DataUFull_V           rng=DataU!B10         cdim=1  rdim=2
par=DataStoFull_V         rng=DataSto!B10       cdim=1  rdim=2
par=FuelBounds_V          rng=DataFuel!B10      cdim=1  rdim=2

*end   Individuelle dataark

* Overview is the last sheet to be written hence becomes the actual sheet when opening Excel file.

*begin sheet Overblik
par=TimeOfWritingMasterResults      rng=Overblik!C2:C2
text="Tidsstempel"                  rng=Overblik!A2:A2
par=VirtualUsed                     rng=Overblik!B2:B2
par=PerStart                        rng=Overblik!B3:B3
par=PerSlut                         rng=Overblik!C3:C3
par=NPV_Total_V                     rng=Overblik!B4:B4
text="Total-NPV"                    rng=Overblik!A4:A4
par=NPV_REFA_V                      rng=Overblik!B5:B5
text="REFA-NPV"                     rng=Overblik!A5:A5
par=OverView                        rng=Overblik!C7          cdim=1  rdim=1
text="Overblik"                     rng=Overblik!C7:C7
par=Q_V                             rng=Overblik!C55         cdim=1  rdim=1
text="Varmemængder"                 rng=Overblik!A55:A55
par=FuelDeliv_V                     rng=Overblik!C63         cdim=1  rdim=1
text="Brændselsforbrug"             rng=Overblik!A63:A63
par=IncomeFuel_V                    rng=Overblik!C95         cdim=1  rdim=1
text="Brændselsindkomst"            rng=Overblik!A95:A95
par=Usage_V                         rng=Overblik!C127        cdim=1  rdim=1
text="Kapacitetsudnyttelse ift. KapMax"         rng=Overblik!A127:A127
par=StoLoadAll_V                    rng=Overblik!C136        cdim=1 rdim=1
text="Lagerbeholdning totalt"       rng=Overblik!A136:A136
text="Lager"                        rng=Overblik!C136:C136
par=StoLoadF_V                      rng=Overblik!B144        cdim=1 rdim=2
text="Lagerbeh. pr fraktion"        rng=Overblik!A144:A144
text="Lager"                        rng=Overblik!B144:B144
text="Fraktion"                     rng=Overblik!C144:C144
*end

$offecho

# Write the output Excel file using GDXXRW.
execute "gdxxrw.exe REFAoutput.gdx o=REFAoutput.xlsm trace=1 @REFAoutput.txt";

execute_unload "REFAmain.gdx";

$If not errorfree $exit

# ======================================================================================================================
# Python script to copy the recently saved output files.
embeddedCode Python:
  import os
  import shutil
  import datetime
  import numpy as np
  currentDate = datetime.datetime.today().strftime('%Y-%m-%d %Hh%Mm%Ss')

  actScen = list(gams.get('actScen'))[0]
  actScen = actScen.title()
  gams.printLog('actScen = ' + str(actScen))
  
  #--- actIter = list(gams.get('actIter'))[0]
  #--- per  = 'per' + str(int( list(gams.get('PeriodLast'))[0] ))
  #--- scenId = str(int( list(gams.get('ScenId'))[0] ))
  #--- gams.printLog("per = " + per + ", scenId = " + scenId)

  #--- wkdir = gams.wsWorkingDir  # Does not work.
  wkdir = os.getcwd()
  #--- gams.printLog('wkdir: '+ wkdir)

  pathNew = 'Output\\' + actScen + ' REFAoutput (' + str(currentDate) + ').xlsm'
  gams.printLog('pathNew : ' + pathNew)
  
  # Copy Excel file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAoutput.xlsm')
  fpathNew = os.path.join(wkdir, 'Output\\' + actScen + ' REFAoutput (' + str(currentDate) + ').xlsm')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('Excel file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

  # Copy gdx file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAmain.gdx')
  fpathNew = os.path.join(wkdir, 'Output\\' + actScen + ' REFAmain (' + str(currentDate) + ').gdx')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('GDX file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

endEmbeddedCode
# ======================================================================================================================
