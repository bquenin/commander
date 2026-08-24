# Stock Kane's Wrath skirmish AI — reference

What the shipped EA/Petroglyph skirmish AI data looks like and how its pieces
fit together. Source: `Kanes Wrath/Xml/SkirmishAI/` and
`Kanes Wrath/Schemas/SkirmishAI/` in EA's public
[CnC_Modding_Support](https://github.com/electronicarts/CnC_Modding_Support)
release. Counts were extracted programmatically. Where a knob's meaning is
not documented by the KW XSD, this says so; the Tiberium Wars-era EA
comments preserved in this repo's [`archive`](../../../tree/archive) branch
(`Mods/Commander/data/AI/GDICommander.xml`) are used as a secondary source and
marked `[TW]`.

Commander is built by declaring new assets of these same types on top of the
stock data, so this is the vocabulary we work in.

## 1. File map

| Path | Asset type(s) | Count |
|---|---|---|
| `ArmyDef<Faction>.xml` | `ArmyDefinition` | 9 (one per faction / sub-faction) |
| `OpeningMoves/*.xml` | `SkirmishOpeningMove` | 45 per-faction-tier files + `TestMove.xml` (aggregator) |
| `Personalities/*.xml` | `AIPersonalityDefinition` | 45 faction-tier files (9 factions × 5 tiers) + `DefaultPersonality`, `HuntPersonality`, `GDITest`, `PersonalityList` (aggregator), `RandomPersonalities` |
| `Personalities/Campaign/*.xml` | `AIPersonalityDefinition` | 6, commented out of the include chain — dead |
| `States/AIStates.xml` | `AIStrategicStateDefinition`, `AIBudgetStateDefinition` | shared library: 113 strategic + 14 budget states |
| `States/<Faction><Tier>States.xml` | same | 44 files, 4–11 strategic + 3–7 budget each |
| `Targets/AITargetHeuristics.xml` | `AITargetingHeuristic` | 59 heuristics |
| `KC_AIP/`, `KC_AIS/` | personalities / states | 9 + 9, Kane's Challenge only (§7) |
| `SkirmishAIIncludes.xml` | include root | loaded from `Static.xml` |

### Include graph

`Static.xml` → `SkirmishAI/SkirmishAIIncludes.xml`, which pulls in, in
order: the 9 `ArmyDef*.xml`, `States/AIStates.xml`,
`Targets/AITargetHeuristics.xml`, `OpeningMoves/TestMove.xml` (which includes
all 45 `*OpeningMoves.xml`), and `Personalities/PersonalityList.xml` (which
includes the 45 faction-tier personalities, `DefaultPersonality`,
`HuntPersonality`, `RandomPersonalities`, the 9 `KC_AIP_*` files and ~25
campaign-mission AI files under `DATA:maps\official\...`).

**Asset ids are global, not file-scoped.** Every asset is referenced by its
bare `id` string, resolved across the whole loaded pool. Consequences:

- `BlackHandOptimal.xml` references `BlackHandMegaUnitRush`, which is defined
  in `BlackHandOverlordOpeningMoves.xml` — personalities borrow moves across
  tiers freely.
- `OptimalEarlyGameBudget` / `OptimalMidGameBudget` / `OptimalLateGameBudget`
  are referenced by all nine factions' `*Optimal` personalities but defined
  only in `GDIOptimalStates.xml` / `SteelTalonsOptimalStates.xml` /
  `ZOCOMOptimalStates.xml` (identical copies). Every other faction resolves
  to GDI's numbers. There is no faction-scoped shadowing.
- For Commander this means **our ids must be unique** (`GDICommander`,
  `6RandomCommander`, `Commander*State`) and that we can reuse any stock
  state / opening move / heuristic by name.

### Concrete end-to-end graph: BlackHand → Optimal → BRUTAL

```
SkirmishAIIncludes.xml
 ├─ ArmyDefBlackHand.xml          ArmyDefinition id=BlackHandArmy Side=BlackHand
 ├─ Personalities/PersonalityList.xml
 │   └─ Personalities/BlackHandOptimal.xml
 │        AIPersonalityDefinition id=1BlackHandOptimal PersonalityUIName="Personality:Optimal"
 │        <Side>BlackHand</Side>
 │        OpeningMove refs (by difficulty):
 │          EASY   → BlackHand_EASY
 │          MED/HRD→ BlackHandStandard/Standard2/StandardCrane, BlackHandMegaUnitRush, BlackHandRush
 │          BRUTAL → BlackHandBrutalCrane
 │        States refs: BlackHandOptimalDirectAttack1/2, …Siege, …AirHarassment, …Engineer
 │          + shared: Garrison, ExpansionDefense, BeaconHelp, CratePickup, BlackHandUnitPreferences
 │        BudgetStates refs: OpeningMoveBudget, FullInvestmentBudget(+variants),
 │          InvestmentFinishBudget, TechByMoneyBudget, TechByNeed*Budget, TechFinishBudget,
 │          OptimalEarly/Mid/LateGameBudget, BlackHandOptimalTechByTimeBudget(+_EASY/_MEDIUM)
 └─ each AIStrategicStateDefinition, e.g. BlackHandOptimalDirectAttack1:
      TargetHeuristic ref → SafestToGroundStructureHeuristic
      Tactic Tactic="DefenseAvoidanceAttack" TargetType="FocusedTarget"
        TeamTemplate MinUnits=7 IncludeKindOf=CAN_ATTACK ExcludeKindOf=AIRCRAFT
```

## 2. ArmyDefinition knobs

`AssetTypeArmyDefinition.xsd` has no annotations. All 9 files declare the
same attribute set; only template names, `Side`/`id`, and one numeric knob
differ.

| Attribute | XSD default | Value | Differs? |
|---|---|---|---|
| `StructureRebuildPriorityModifier` | 50 | 50 | no |
| `DefaultUnitPriority` | 100.0 | 100.0 | no |
| `FortressRebuildPriority` | 1950.0 | 1950.0 | no |
| `LowUnitPriorityModifier` | 100.0 | 100.0 | no |
| `EconomyBuilderMinFarmsOwned` | 5 | **1** for GDI/SteelTalons/ZOCOM, **5** for the rest | **yes** |
| `EconomyBuilderMinMoney` | 150 | 150 | no |
| `EconomyBuilderPerFarmValue` | 70 | 70 | no |
| `EconomyBuilderPerSecPriorityIncreaseBase` | 5.0 | 5.0 | no |
| `UpgradeSciencePriorityNormalLow/High` | 100/200 | 100/200 | no |
| `UpgradeSciencePriorityImportantLow/High` | 250/350 | 250/350 | no |
| `UnitUpgradePriorityLow/High` | 100/200 | 100/200 | no |
| `MaxThreatForOpportunityTargets` | 10.0 | 10.0 | no |
| `ValueToSetForMaxOnDefenseTeam` | 10 | 10 | no |
| `CombatChainSearchDepthForTeamRecruits_{Attack,Defense,Explore}Teams` | 2/7/7 | 2/7/7 | no |
| `UnboundedProductionEconomyStructure` | — | faction Power Plant | per faction |
| `LimitedProductionEconomyStructure` | — | faction Refinery | per faction |
| `WorkerGathererTemplate` / `MCVTemplate` | — | faction Harvester / MCV | per faction |

`TechStructure` lists (6 per faction, SteelTalons 5): GDI = CommandPost,
Armory, MedicalBay, SpaceCommandUplink, IonCannonControl, MG_ReclamatorHub.

## 2b. AIPersonalityDefinition knobs

The KW XSD documents exactly one attribute: `PersonalityUIName` ("what is
shown in the UI"). **Every attribute is identical across all 9 factions within
a tier** — stock tuning is a function of tier, not faction.

| Attribute | Meaning | Defensive | Guerilla | Offensive | Optimal | Overlord |
|---|---|---|---|---|---|---|
| `SecondsTillTargetsCanExpire` | `[TW]` time before AI re-picks a tactical target | 15 | 15 | 15 | 15 | 15 |
| `ChanceForTargetToExpire` | `[TW]` % chance target expires after that | 100 | 100 | 100 | 100 | 100 |
| `MaxBuildingsToBeDefensiveTarget_*`, `ChanceForUnitsToUpgrade`, `ChanceToUseAllUnitsForDefenseTarget_*` | `[TW: unused]` | — | — | — | — | — |
| `DesiredExcessPowerBuffer` | `[TW]` power surplus to maintain | 40 | 10 | 20 | 20 | 10 |
| `BaseCompactness` | `[TW]` 0–1 base packing; only 0.5–1 work | 0.65 | 1.00 | 0.85 | 0.75 | 0.65 |
| `DefaultThreatFindRadius` | `[TW: deprecated]` | 0 | 0 | 0 | 0 | 0 |
| `UnitBuilderCostEffectivenessWeight` | `[TW]` weight of power/cost in unit choice | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| `UnitBuilderMoneyVersusTimePreference` | `[TW: effectively unused]` | 0.5 | 0.5 | 0.5 | 0.5 | 0.5 |
| `UnitBuilderOverallOffensivePreference` | `[TW]` weigh damage over armour | 100% | 110% | 110% | 100% | 100% |
| `UnitBuilderOverallDefensivePreference` | `[TW]` weigh armour over damage | 110% | 100% | 100% | 100% | 110% |
| `Expansion_TiberiumSearchRadius` | `[TW]` min distance from a base for a field to count as expansion | 1000 | 1000 | 1000 | 1000 | 1000 |
| `Expansion_MaxTiberiumRemaining` | `[TW]` expand once tiberium near bases drops below this | 999999 | 22000 | 22000 | 22000 | 999999 |
| `ReactiveDefenseRadius` | `[TW]` radius the `ReactiveDefense` tactic defends | 1000 | 1000 | 1000 | 1000 | 1000 |
| `RepairBuildingsAtDifficulty` | | MEDIUM HARD BRUTAL (all tiers) |
| `EmergencyManagerHandleNo{Power,Income,Conyard}AtDifficulty` | | MED+ / all / all (all tiers) |
| `StructureSaveChanceEasy/Medium/Hard` | `[TW]` chance to sell before an engineer captures | 0.0 / 0.01 / 1.0 (all tiers) |

KW-only attributes with no documentation anywhere: `UnitBuilderEnemyTowerWeight`
(default 100%), `MinHarvesters` (default 0), `TimeToBeConsideredIdle` (1.0) —
none set by any stock file. `BuildDelayRange`,
`UnitBuilderUnitChoiceStrategy[Adaptive]`, `UnitBuilderEvaluationDelayRange`
match the TW comments structurally.

**The income cheat lives here:** `<ResourceMultiplierCheat Percentage="200%"
Difficulty="BRUTAL"/>` in 46 of 50 skirmish personalities — Brutal only.
Easy/Medium/Hard get no multiplier, which is why Hard is the fair baseline.
Kane's Challenge personalities use 150% at all difficulties.

## 3. Opening moves

A `SkirmishOpeningMove` is a flat script of `Order` elements: either
`Build="<template>"` or a budget earmark (`Time`, `Account`, `Deposit`).

Per-tier move ids (same pattern for every faction, `<F>` = prefix):

| Tier | Move ids | Difficulty |
|---|---|---|
| Defensive | `<F>SuperweaponRush`, `<F>DualBarracks` | MEDIUM/HARD/BRUTAL |
| Guerilla | 3 unit rushes (GDI: `OrcaRush`, `HammerheadRush`, `PitbullRush`) | MEDIUM/HARD/BRUTAL |
| Offensive | `<F>FastRush`, `<F>DualFactoryRush`, `<F>TriFactoryRush`, `<F>BrutalTankRush`, + `MammothRush`/`AvatarRush`/`TripodRush` | MEDIUM/HARD |
| Optimal | `<F>_EASY`, `<F>Standard`, `<F>Standard2`, `<F>StandardCrane`, `<F>BrutalCrane` | EASY / MEDIUM+HARD / BRUTAL |
| Overlord | `ZoneTrooperRush`/`FanaticRush`/`ShockTrooperRush`, `<F>MegaUnitRush`, `<F>BrutalInfantryRush`, `<F>BrutalMixedRush` | MEDIUM/HARD |

**GDIStandard** (Optimal, MEDIUM/HARD, weight 11%):

```
Build=GDIPowerPlant
Build=GDIBarracks
Build=GDIRifleSoldierSquad ×2
Build=GDIRefinery ×2
Build=GDIWarfactory
Time=73s Account=PRODUCTION Deposit=3000
Build=GDIRefinery ×2
Time=113s   (close-out)
```

### `Deposit` is a budget earmark, not free money

`Account` is an `AIBankAccountType` (`AIBank.xsd`): `INVESTMENT`,
`SPECIAL_OPERATIONS`, `PRODUCTION`, `DEFENSE`, `TECHNOLOGY`, `SLUSH_FUND` —
spending categories that partition the AI's *own* income according to the
active budget state's `AccountShare` percentages. A `Deposit` order moves up
to N of the AI's own credits into that account. All 108 stock deposits are on
`PRODUCTION`; `Deposit="999999"` on the `*Rush` moves means "everything into
combat units". Schedule for the GDI lineage (GDI / SteelTalons / ZOCOM share
it):

| Move | Time | Deposit |
|---|---|---|
| `<F>BrutalCrane` | 58s | 999,999 |
| `<F>*Rush` (all six) | 0s | 999,999 |
| `<F>Standard2` | 33s | 6,500 |
| `<F>SuperweaponRush` | 53s | 6,000 |
| `<F>DualBarracks` | 0s | 4,000 |
| `<F>Standard` | 73s | 3,000 |
| `<F>StandardCrane` | 90s | 2,000 |

## 4. Strategic state machine

478 strategic + 159 budget states in total. Every state has a `<Heuristic>`
block: a `ConstantHeuristic Weight` sets the base score and the other
heuristics act as gates. Among eligible states of a category the engine picks
the highest score. Example weight ladder (`GDIOptimalStates.xml`):

| Budget state | Weight | Gate |
|---|---|---|
| `OptimalEarlyGameBudget` | 0.3 | `OpeningMoveHeuristic Complete="true"` |
| `OptimalMidGameBudget` | 0.5 | + `MiddleGameHeuristic` |
| `OptimalLateGameBudget` | 0.7 | + `LateGameHeuristic` |

### Heuristic vocabulary (`AssetTypeAIStateDefinition.xsd`)

| Element | Parameters (default) | Uses | Meaning |
|---|---|---|---|
| `IntervalHeuristic` | `IntervalTime` 60s, `ActiveTime` 30s | 342 | duty-cycle gate |
| `ConstantHeuristic` | `Weight` 1.0 | 336 | base score |
| `PathToTargetHeuristic` | `PathExists` true | 246 | reachability |
| `OpeningMoveHeuristic` | `Complete` true | 174 | opening move finished |
| `TimerHeuristic` | `StartTime` 0s, `EndTime` 20s | 120 | absolute clock window |
| `SiegeThresholdHeuristic` | `SiegeMode`, `Threshold` 1.0 | 106 | siege posture |
| `LateGameHeuristic` / `MiddleGameHeuristic` | — | 94 / 18 | engine phase flags |
| `FocusedThresholdHeuristic` | `AttackerKindOf`, `DefenderKindOf` | 51 | focused attack |
| `SuperweaponHeuristic` | — | 9 | superweapon ready |
| `EnemyNearbyHeuristic` | `Distance` 1000, KindOf filters | 9 | proximity |
| `CounterattackHeuristic` | `Threshold` 1.0 | 9 | attack in progress against us |
| `ResourceSqueezeHeuristic` / `ProductionHaltHeuristic` | composite | 9 / 9 | economic / production pressure |
| `OpponentPowerThresholdHeuristic` | — | 9 | opponent power state |
| `OverrunEarly/Middle/LateHeuristic` | composite | 9 each | phase-gated overwhelm |
| `HarvesterCapHeuristic` | `MaxHarvesters` 5 | 5 | harvester count gate |
| `SpreadThresholdHeuristic` | KindOf filters | 2 | spread attack |
| `AntiGarrisonTechHeuristic` | `EnemyGarrisons` 4 | 2 | garrison count |
| `FullInvestmentHeuristic` / `FullTechHeuristic` | `Threshold` 1000 | 1 / 1 | uncommitted account balance |
| `MoneyHeuristic` | `Money` 1000, `Above` | 1 | bank balance |

Declared but unused by stock data: `ProductionAdvantageHeuristic`,
`BridgeExistsHeuristic`, `ScriptedFlagHeuristic`, `AlliedBeaconExistsHeuristic`,
`OverpowerHeuristic`, `BaseCrackHeuristic`, `PowerCutHeuristic`,
`EmergencyHeuristic`, `LinearCombinationHeuristic`.

### Budget states

Each `AIBudgetStateDefinition` has one `AccountShare` per account, summing to
100%:

| Budget state | INVEST | SPEC_OPS | PROD | DEF | TECH | SLUSH |
|---|---|---|---|---|---|---|
| `OpeningMoveBudget` | 0 | 0 | 0 | 0 | 0 | 100 |
| `OpeningMoveRushBudget` | 0 | 0 | 100 | 0 | 0 | 0 |
| `FullInvestmentBudget` (+ EASY/MEDIUM variants by `MaxHarvesters`) | 90 | 0 | 0 | 0 | 0 | 10 |
| `TechBy*Budget`, `TechFinishBudget`, `AntiGarrisonTechBudget` | 0 | 0 | 0 | 0 | 90 | 10 |
| `OptimalEarly/Mid/LateGameBudget` | 0 | 0→15→20 | 70→55→50 | 10 | 0 | rest |

### Tactics and team templates

`Tactics` enum and stock usage: `DefenseAvoidanceAttack` 228, `SimpleAttack`
124, `Engineer` / `SimpleExpansion` / `SimpleSiege` 27 each, `StaticDefense`
25, `Superweapon` / `ReactiveDefense` 9 each, `Hunt` / `GarrisonBuilding` 2.
Declared but unused: `FlankAttack`, `SiegeGates`, `BasePenetrationTroops`,
`SimpleDefense`, `FarmKill`, `RoamingDefense`, `StructureCreep`.

A `Tactic` has up to 4 `TeamTemplate`s (`MinUnits`/`MaxUnits`,
`IncludeKindOf`/`ExcludeKindOf`, `AlwaysRecruit`/`AlwaysRelease`/`AutoReinforce`),
each with up to 7 `CreateUnits` (`UnitName`, `MinUnits`/`MaxUnits`,
`ExperienceLevel`). Example:

```xml
<Tactic Tactic="SimpleSiege" TargetType="SiegeTarget">
  <TeamTemplate MinUnits="3" MaxUnits="3" IncludeKindOf="CAN_ATTACK" ExcludeKindOf="AIRCRAFT">
    <CreateUnits UnitName="BlackHandBeamCannon"/>
    <CreateUnits UnitName="BlackHandBeamCannon"/>
    <CreateUnits UnitName="BlackHandBeamCannon"/>
  </TeamTemplate>
  <TeamTemplate MinUnits="8" MaxUnits="12" IncludeKindOf="CAN_ATTACK" ExcludeKindOf="AIRCRAFT"/>
</Tactic>
```

`UnitModifierByName` / `UnitModifierByKind` (`UnitBonus` default 10,
`UnitPreferenceOffensiveModifier` / `DefensiveModifier` default 100%) steer
what the unit builder produces. `BlackHandUnitPreferences` in `AIStates.xml`
is an always-on state (`ConstantHeuristic Weight="999"`) that exists only to
carry such modifiers — e.g. BeamCannon 250%/100%, StealthTank 100%/400%,
Venom 10%/10%. **This is the main composition lever for a data-mod AI.**

## 5. Targeting heuristics

`Targets/AITargetHeuristics.xml`: 59 `AITargetingHeuristic`s.
`TargetingHeuristicType` (all 13 used): `BaseDefense`, `EnemyStructure`,
`FriendlyStructure`, `EnemyUnit`, `FriendlyUnit`, `Expansion`, `Prioritized`,
`TechBuilding`, `Bridge`, `NeutralGarrison`, `AntiGarrison`, `Beacon`, `Crate`.
`AITargetSortType`: `Distance` (default), `ThreatToGround`, `ThreatToAir`,
`Random` (unused).

Most useful for us:

| id | Type | Returns | Sort | Vital / Prioritized KindOf |
|---|---|---|---|---|
| `ClosestStructureHeuristic` | EnemyStructure | Structure | Distance | STRUCTURE (walls, tech, civ excluded) |
| `SafestToGroundStructureHeuristic` / `SafestToAir…` | EnemyStructure | Structure | ThreatToGround / ThreatToAir | STRUCTURE |
| `SafestToAirPowerPlantHeuristic` | EnemyStructure | Structure | ThreatToAir | STRUCTURE FS_POWER |
| `ClosestHarvesterHeuristic` / `SafestToGroundHarvesterHeuristic` / `EconomyKillHeuristic` | EnemyUnit | Unit | Distance / ThreatToGround | HARVESTER |
| `PowerKillHeuristic` | Prioritized | Structure | | FS_POWER, CONSTRUCTION_YARD |
| `ProductionKillHeuristic` / `ProductionHaltHeuristic` | Prioritized | Structure | | FS_WAR_FACTORY, FS_BARRACKS, FS_AIR_FIELD |
| `ConstructionKillHeuristic` | Prioritized | Structure | | CONSTRUCTION_YARD |
| `ResourceSqueezeHeuristic` | Prioritized | Structure | | SUPPLY_GATHERING_CENTER, FS_MONEY_STORAGE |
| `EngineerHeuristic` / `CommandoHeuristic` | Prioritized | Engineer | | CONYARD, WF, AIRFIELD, TECH, RADAR, BARRACKS |
| `ExpansionHeuristic` | Expansion | Expansion | | — |
| `ClosestNeutralTechHeuristic` | TechBuilding | CaptureTech | | SearchRange 150000 |
| `OutsideAAHeuristic` | EnemyStructure | Airstrike | | — |
| `ClosestFriendlyHarvesterHeuristic` / `…ConyardHeuristic` | Friendly* | Defensive | | HARVESTER / CONSTRUCTION_YARD |

## 6. What the engine computes for the AI

Implied by the schema: per-candidate ground/air threat scores
(`ThreatToGround`/`ThreatToAir`), priority-bucket-then-distance targeting,
live harvester count, game-phase classification, reachability, KindOf-filtered
proximity, superweapon readiness, six bank accounts, balance-of-power /
penetrability / vulnerability comparisons, opponent funds and power state,
counter-attack detection, siege/focused/spread posture, remaining tiberium
around bases, target-expiry timers, and combat-chain recruitment depth.

## 7. Kane's Challenge (`KC_AIP` / `KC_AIS`)

One personality + state file per mission, `SkirmishPersonality="false"` (never
in the lobby list), 150% resource cheat at all difficulties, and things like a
hard `UnitBuilderSimpleUnitCap="28"`. Out of scope for skirmish.
