//domotan_south map areas
/area/outdoors/woods/heavenscoast
	name = "County of Heavenscoast"
	icon_state = "woods"
	droning_index = DRONING_JUNGLE_DAY
	droning_index_night = DRONING_JUNGLE_NIGHT
	ambient_index = AMBIENCE_BIRDS
	ambient_index_night = AMBIENCE_FOREST
	background_track = 'sound/music/area/forest.ogg'
	background_track_dusk = 'sound/music/area/septimus.ogg'
	background_track_night = 'sound/music/area/forestnight.ogg'
	soundenv = 15
	ambush_times = list("night")
	ambush_types = list(
				/turf/open/floor/grass)
	ambush_mobs = list(
				/mob/living/simple_animal/hostile/retaliate/wolf = 60,
				/mob/living/carbon/human/species/goblin/npc/ambush = 45)
	first_time_text = "Heavenscoast"
	custom_area_sound = 'sound/misc/stings/RosewoodSting.ogg'
	converted_type = /area/indoors/shelter/woods

/area/outdoors/woods/crossroads
	name = "County of Crossroads"
	icon_state = "woods"
	droning_index = DRONING_JUNGLE_DAY
	droning_index_night = DRONING_JUNGLE_NIGHT
	ambient_index = AMBIENCE_BIRDS
	ambient_index_night = AMBIENCE_FOREST
	background_track = 'sound/music/area/forest.ogg'
	background_track_dusk = 'sound/music/area/septimus.ogg'
	background_track_night = 'sound/music/area/forestnight.ogg'
	soundenv = 15
	ambush_times = list("night")
	ambush_types = list(
				/turf/open/floor/grass)
	ambush_mobs = list(
				/mob/living/simple_animal/hostile/retaliate/wolf = 60,
				/mob/living/carbon/human/species/goblin/npc/ambush = 45)
	first_time_text = "Crossroads"
	custom_area_sound = 'sound/misc/stings/generic.ogg'

/area/outdoors/woods/seculton
	name = "Seculton Gate"
	icon_state = "woods"
	droning_index = DRONING_JUNGLE_DAY
	droning_index_night = DRONING_JUNGLE_NIGHT
	ambient_index = AMBIENCE_BIRDS
	ambient_index_night = AMBIENCE_FOREST
	background_track = 'sound/music/area/forest.ogg'
	background_track_dusk = 'sound/music/area/septimus.ogg'
	background_track_night = 'sound/music/area/forestnight.ogg'
	soundenv = 15
	ambush_times = list("night")
	ambush_types = list(
				/turf/open/floor/grass)
	ambush_mobs = list(
				/mob/living/simple_animal/hostile/retaliate/spider = 60,
				/mob/living/carbon/human/species/goblin/npc/ambush/sea = 45)
	first_time_text = "Seculton Gate"
	custom_area_sound = 'sound/misc/stings/BogSting.ogg'

/area/outdoors/woods/whisperen
	name = "Wey Whisperen"
	icon_state = "woods"
	droning_index = DRONING_LAKE
	droning_index_night = DRONING_LAKE
	ambient_index = AMBIENCE_MYSTICAL
	ambient_index_night = AMBIENCE_FOREST
	background_track = 'sound/music/area/forest.ogg'
	background_track_dusk = 'sound/music/area/septimus.ogg'
	background_track_night = 'sound/music/area/forestnight.ogg'
	soundenv = 15
	ambush_times = list("night")
	ambush_types = list(
				/turf/open/floor/grass)
	ambush_mobs = null
	first_time_text = "Wey Whisperen Hamlet"
	custom_area_sound = 'sound/misc/stings/RosewoodSting.ogg'
