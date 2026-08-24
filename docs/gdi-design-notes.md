# GDI design notes

What competitive Kane's Wrath play looks like, and which of it a data-mod AI
can actually express. This is the input to the Commander GDI personality.
Sources: GameReplays.org strategy guides (linked inline), public pro replays
from the GameReplays replay archive (top-ranked GDI players, 1.02 ladder maps),
and the stock AI data described in [`stock-skirmish-ai-reference.md`](stock-skirmish-ai-reference.md).

Constraint that shapes everything: **no cheats.** No `ResourceMultiplierCheat`
at any difficulty. Stock *Hard* is the honest baseline to beat; Brutal wins
by 2× income and is not a reference for anything.

## 1. What the meta says

### Economy first, harvesters are the target

- Economy is the foundation, not a dimension: no money → no production → no
  army. Pro play treats **killing harvesters as the primary offensive goal**.
  A harvester kill removes a recurring income stream; a unit kill removes a
  one-off cost. Trading a $600 unit for a $1,400 harvester *and* its income is
  the best trade in the game.
  ([GameReplays economy guide](https://www.gamereplays.org/kaneswrath/portals.php?name=economy-guide&show=page))
- Refineries go **as close to the field as possible**; harvester travel time is
  income latency.
- **Low power halves production speed globally.** Power is a continuous
  constraint, not a one-time check; pros power-down non-critical buildings
  before adding load. Any build order that lets power dip is strictly worse.
- The 50% sell refund plus the free units every faction's structures eject on
  sale ("sell-trick") is a real economic tool for humans — GDI gets a Rifleman
  Squad + Engineer from a sold Conyard-class structure. Pros cycle cheap
  structures (Barracks, Watchtowers) through this deliberately.

### Openers — mined from 390 GDI 1v1 games

`Tools/mine_openers.py` parsed the command streams of ~1,100 public
GameReplays 1.02 ladder replays (Tournament Rift / Decision / Dustbowl
mostly, top players including the #1 ranked GDI player with 114 games).
Full report: [`mined-openers-gdi.md`](mined-openers-gdi.md). The picture is
remarkably uniform:

| Step | Median time | Games |
|---|---|---|
| Power Plant | 0:08 | 386/390 |
| Barracks | 0:15 | 366 |
| Watchtower — **sell-trick, not a defence**: 95% of early Watchtowers are sold within 8 s of placement (median 0.6 s, i.e. still under construction) to eject free infantry; a 2nd at 0:28, 2–4 sells per game before 2:00 | 0:17 | 384 |
| Refinery | 0:46 | 390 |
| War Factory | 1:09 | 375 |
| 2nd Refinery | 1:46 | 353 |
| 2nd Power Plant | 2:07 | 356 |
| 3rd Refinery | 3:27 | 276 |
| Airfield | 3:50 | 189 |
| Command Post | 3:52 | 308 |
| 2nd War Factory | 4:00 | 147 |
| Tech Center | 5:17 | 100 |

Units by 2:00 (average per game): **4.6 Harvesters, 2.9 Pitbulls, 1.6
Engineers**, 0.8 Predators, 0.7 Orcas. The top player runs the same order
but harder on economy: 6.6 Harvesters and 3.7 Pitbulls by 2:00, Airfield at
2:58. First-minute production is Engineers (1–2, for Tiberium Spike
captures) and Riflemen; minute two is Harvesters + Pitbulls; Predators arrive
in minute three; APCs and Missile Squads dominate minutes four to six.

Upgrades by 6:00: **Power Plant upgrade** in 278/390 games (median 4:02) —
the meta's answer to the power problem instead of a third plant — and **AP
Ammo** in 206 games (median 4:23). Surveyor/Outpost expansion within six
minutes is rare on ladder maps (1%); MCVs are queued in 43 games.

Stock `GDIStandard` (`PowerPlant → Barracks → 2 Riflemen → 2 Refinery →
WarFactory → 2 Refinery`) is close in shape but has no Watchtower, no
Pitbulls, no harvester mass, and no upgrades. A single large-map pro game
(GDI vs Nod, Abandoned Subway) shows the same opener extended into an
expansion-heavy mid game:

```
0:00  Power Plant → Barracks (→ 2nd Barracks, sold once Engineers are out)
      Watchtower at the base entrance
      Refinery, Refinery
0:45  War Factory (queue Engineers from Barracks meanwhile)
1:00  2nd Power Plant, 2nd Refinery, mass-queue Harvesters at the WF
      power-down the Conyard while the 2nd PP builds
2:00  Surveyor → Outpost at the first expansion; Barracks + WF at the outpost
3:00  Pitbulls in response to a scouted bike rush; 2 more Refineries at the outpost
4:00  Command Post → Airfield; AP Ammo + Composite Armor upgrades
5:00+ Further Outposts (4, then 6, then 7 bases), Armories, Watchtower/Guardian
      Cannon clusters at each, continuous Barracks + Rifleman/Engineer production
```

Key properties: **two refineries before the War Factory**, a defensive
structure at the chokepoint from the start, harvesters mass-queued the moment
the WF is up, expansion by Outpost from minute two, and tech (Command Post →
Airfield → upgrades) only once the economy is established.

- On **small 2-player maps** (Tournament Arena, Tournament Rift) the opener is
  all-infantry: infantry scouts, harasses and captures, and an early
  anti-infantry defence at the choke counters the mirror. Refineries come
  later because the game is often decided by 3–4 minutes. Don't read an early
  turret there as turtling.

### Composition and counters (GDI)

| Threat | Answer (best first) | Source |
|---|---|---|
| Militants / basic infantry | Hammerhead (very asymmetric), APC, Riflemen, Grenadiers; Watchtower at the base | pro replays |
| Rocket infantry | Sniper (once Armory is up), AP-ammo APCs, Riflemen/Grenadiers; Hammerhead only if AA is thin | pro replays |
| Fanatics | Hammerhead (they have no AA), APCs with AP ammo; never Pitbulls/Predators | pro replays |
| Attack Bikes | Pitbulls (2 per bike in a volley), Predators for the counter-push, Missile Squads as the Barracks-speed fallback | [ToTW #75](https://www.gamereplays.org/kaneswrath/portals.php?name=kanes-wrath-tip-of-the-week-75-countering-nod-attack-bike-rush-spam&show=page) |
| Scorpion spam | Predators lead, infantry behind the tanks, Hammerheads in groups of 3+ | [scorpion-spam guide](https://www.gamereplays.org/kaneswrath/portals.php?name=scorp_spam&show=page) |
| Raider Buggies | Pitbulls to match speed, Predators to kill, APCs screening infantry | guides |
| Flame Tanks | Predators / Missile Squads at range; never infantry blobs | guides |
| Stealth Tanks | Pitbull (detector) first, then Predators | guides |
| Venoms / air | massed Pitbulls (cheapest AA), Slingshots, Firehawks; AA Battery for the base | GDI AA guide |
| Tank lines generally | Zone Troopers (jump walls, kill tanks), Predators | counter matrix |

Rock-paper-scissors underneath: anti-infantry beats infantry and loses to
tanks/air; anti-vehicle beats tanks and loses to infantry swarms; AA units
(Pitbull, Slingshot) beat air and lose to ground armour; artillery
(Juggernaut) beats static targets and loses to fast units; air beats anything
without AA.

GDI-specific facts: Pitbull is scout + detector + AA; Predator is weak vs
infantry; Slingshot has **no ground attack**; Mammoth has AA; Hammerhead
carries infantry; Firehawk switches AV/AA loadouts; Zone Troopers need the
Armory; Juggernaut is the siege piece.

## 2. What a data-mod AI can and cannot do

The stock `SkirmishAI` is a scored state machine over scripted openers. It
cannot micro. Concretely:

| Meta behaviour | Lever in the data | Feasible? |
|---|---|---|
| Fixed strong opener | `SkirmishOpeningMove` (`Build` orders + `PRODUCTION` earmarks) | **yes** — this is the biggest single lever |
| Harvester-first economy | opener order + `EconomyBuilder*` knobs + `HarvesterCapHeuristic` / `FullInvestmentBudget` | yes |
| Expand early by Outpost | `SimpleExpansion` tactic + `Expansion_MaxTiberiumRemaining` / `Expansion_TiberiumSearchRadius` + `INVESTMENT` share | yes |
| Refinery next to the field | engine placement; `BaseCompactness` only | partial |
| Target harvesters | states using `ClosestHarvesterHeuristic` / `EconomyKillHeuristic` / `SafestToGroundHarvesterHeuristic`, `ResourceSqueezeHeuristic` | yes |
| Composition by matchup | `UnitBuilderUnitChoiceStrategyAdaptive` + always-on `UnitModifierByName` state (à la `GDIUnitPreferences`) | yes, coarse |
| Don't let power dip | `DesiredExcessPowerBuffer` | yes |
| Power-down micro, sell-trick, harvester patch micro, kiting, focus fire | none | **no** |
| Chokepoint defence early | `StaticDefense` tactic + `DEFENSE` budget share; opener can `Build` a Watchtower | yes |
| Tech timing (CP → Airfield → upgrades at ~4:00) | `TechByTimeBudget` / `TechByMoneyBudget` with `TimerHeuristic` / `MoneyHeuristic`; `TECHNOLOGY` share | yes |
| Scouting-driven pivots | `EnemyNearbyHeuristic`, `CounterattackHeuristic`, `BalanceOfPower*` composites | crude |
| Air harass on undefended targets | `SafestToAirStructureHeuristic` / `SafestToAirPowerPlantHeuristic` with Orca/Hammerhead `CreateUnits` | yes |

So the edge has to come from **plan quality**: a pro-grade opener with no
wasted seconds, an economy that expands earlier and harder than stock Hard,
composition preferences that match the counter table, and attack states that
go for harvesters and power rather than the nearest building.

## 3. Design direction for `GDICommander`

Ordered by expected impact:

1. **Opening move** — encode the mined ladder opener as
   `GDICommanderOpening`: PP → Barracks → Watchtower → Refinery (0:46) →
   War Factory (1:09) → Refinery (1:46) → PP (2:07) → Refinery (3:27), with
   Engineers + Riflemen first, then Harvesters (target 5–6 by 2:00) and
   Pitbulls (3 by 2:00), Predators from 3:00; Power Plant upgrade and AP Ammo
   at ~4:00, Command Post + Airfield at ~3:50. **Leave the early Watchtowers
   out**: in the corpus they are sell-trick pumps sold the moment they are
   placed, which a data-mod AI cannot do, so copying them would cost 600
   credits at 0:17 for nothing. Put the saved money into an earlier Refinery
   or an extra Harvester, and let a real Watchtower come from the `DEFENSE`
   budget once the economy is up. Use a `PRODUCTION` earmark timed to the
   War Factory. Compare against `GDIStandard` head-to-head.
2. **Economy knobs** — `EconomyBuilderMinFarmsOwned` is already 1 for GDI;
   raise the harvester cap gate (`HarvesterCapHeuristic MaxHarvesters`) in an
   investment budget so it keeps building harvesters past stock's 5–6;
   `Expansion_MaxTiberiumRemaining` high enough that the first expansion is
   triggered by time/money, not depletion.
3. **Unit preferences** — an always-on `GDICommanderUnitPreferences` state:
   Pitbull and Predator up, Slingshot suppressed unless air is seen (no
   ground attack), Hammerhead moderate, Zone Trooper up once the Armory
   exists, Juggernaut for siege states only.
4. **Harass states** — a mid-game `SimpleAttack` on `EconomyKillHeuristic`
   with a small fast team (`CreateUnits` Pitbull ×3–4), duty-cycled with
   `IntervalHeuristic`; an air state on `SafestToAirPowerPlantHeuristic`
   with Orcas.
5. **Defence** — keep `ReactiveDefense`; small `DEFENSE` share early
   (Watchtower at the choke), not 0% like the 2016 mod, because harvester
   harassment is exactly what humans will do to us.
6. **Tech ladder** — `TechByTimeBudget` gated to ~4:00 for Command Post +
   Airfield + AP Ammo / Composite Armor; `TechByMoneyBudget` as the overflow
   sink.
7. **Escalating attacks** — keep the 2016 idea of overrun waves (16 → 24 →
   32) but target with `ProductionKillHeuristic` / `PowerKillHeuristic`
   instead of `ClosestStructureHeuristic`.

Validation: Commander vs stock Hard, several maps, both starting positions,
scored on win rate and time-to-win. A human win against it proves nothing;
the automated series is the measure.
