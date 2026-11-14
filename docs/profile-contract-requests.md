# Site profile: contract change requests

From the rotation engine (`FieldShift.Rotation`) to the profile service owner.
The engine does not work around these; it reads the fields as they are today and documents the limits
in `FieldShift.Rotation/Profile/SiteProfile.cs`.

1. **pH method.** Rename `soil.ph` to `phH2O` or add `phMethod`.
   The current `phClass` of "Lekko kwaśna" for 5.75 is off by one class: Polish reaction classes are defined on pH
   measured in KCl, and on a water basis 5.1 to 6.0 corresponds to "kwaśny".
2. **Organic matter class.** "Średnia" for 15.3 g/kg of organic carbon looks like humus thresholds applied to carbon.
   Humus is carbon times 1.724, so 26 g/kg, which is "wysoka" on the usual scale.
3. **Administrative unit.** Add `location.teryt` (gmina code) and voivodeship, optionally the cadastral parcel id.
   Regional tables are keyed on these. GUGiK's ULDK service resolves a point or parcel id.
4. **Naming.** `climate.minTempC` and `maxTempC` should be `recordMinTempC` and `recordMaxTempC`
   (they are 25-year record extremes, not typical values).
5. **Season definition.** `seasonPrecipitationMm` covers April to September while `growingSeasonMonths` runs to October.
   Pick one.
6. **Later, from daily series:** last spring and first autumn frost dates with probabilities, average annual minimum
   temperature, SoilGrids uncertainty bounds for pH, sand and clay.

## Fields the engine deliberately does not read

| Field | Why |
|---|---|
| `climate.minTempC`, `maxTempC` and everything derived from them (`frostRiskMonths`, `heatRiskMonths`, `lastSpringFrostMonth`, `firstAutumnFrostMonth`) | Record extremes, not typical values. |
| `soil.nitrogenGkg` | Total nitrogen, not plant-available nitrogen. |
| `soil.cecCmolKg` | 21.8 for a soil that is 77% sand is not plausible enough to build on. |
| every `*Class` string | The engine computes its own classes so there is one implementation. |
