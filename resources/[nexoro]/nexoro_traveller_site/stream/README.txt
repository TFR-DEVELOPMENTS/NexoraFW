Put the MLO files here (exported from CodeWalker or Sollumz):
  nexoro_traveller_site.ytyp   the archetype definitions
  nexoro_traveller_site.ymap   the placed walls, gate and props
Then uncomment the data_file line in fxmanifest.lua.

The gate is a prop placed in the map. Its model name and position go in nexoro_encampments/config.lua
(Gates: model, openHeading, closedHeading). Gate control already works: nexoro_encampments opens and closes it.
