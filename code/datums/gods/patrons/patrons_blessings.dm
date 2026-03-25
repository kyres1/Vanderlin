/// Admin proc to apply or remove blessings from a character
/// Supports timed expiration, auto-removal on sleep, and dynamic flavor text injection
/datum/admins/proc/admin_bless(mob/living/carbon/human/M in GLOB.mob_list)
	set name = "Bless"
	set desc = "Bless or lift a blessing from a character"
	set category = "GameMaster.Gods"

	if(!check_rights())
		return FALSE

	var/category = input("Select Blessing Category") as null|anything in list("Divine", "Food", "Special", "Mending")
	if(!category)
		return FALSE

	var/blessing_path
	switch(category)
		if("Divine")
			blessing_path = input("Choose Divine Blessing") as null|anything in list( \
				/datum/status_effect/buff/noc, \
				/datum/status_effect/buff/ravox, \
				/datum/status_effect/buff/beastsense, \
				/datum/status_effect/buff/trollshape, \
				/datum/status_effect/buff/divine_beauty, \
				/datum/status_effect/buff/call_to_arms, \
				/datum/status_effect/buff/craft_buff)
		if("Food")
			blessing_path = input("Choose Food Blessing") as null|anything in list( \
				/datum/status_effect/buff/foodbuff, \
				/datum/status_effect/buff/clean_plus)
		if("Special")
			blessing_path = input("Choose Special Blessing") as null|anything in list( \
				/datum/status_effect/buff/featherfall, \
				/datum/status_effect/buff/darkvision, \
				/datum/status_effect/buff/haste, \
				/datum/status_effect/buff/calm, \
				/datum/status_effect/buff/barbrage)
		if("Mending")
			var/mending_amount = input("Choose Lifeblood Amount") as null|anything in list(5, 10, 15, 20, 25, 30)
			if(!mending_amount)
				return FALSE

			if(!M || !M.reagents)
				to_chat(usr, span_warning("[M] has no reagent container."))
				return FALSE

			M.reagents.add_reagent(/datum/reagent/medicine/stronghealth, mending_amount)
			var/patron_name = (M.patron && istype(M.patron)) ? M.patron.name : "a divine presence"
			to_chat(M, span_nicegreen("You feel your body renewing. [patron_name] has renewed your body with temporary divinity."))
			to_chat(usr, span_notice("You mended [M] with [mending_amount] units of Lifeblood."))
			log_admin("[key_name(usr)] mended [key_name(M)] with [mending_amount] units of Lifeblood.")
			return TRUE

	if(!blessing_path)
		return FALSE

	var/duration_choice = input("Select Duration for the Blessing:") as null|anything in list( \
		"1 Minute", "5 Minutes", "10 Minutes", "20 Minutes", \
		"30 Minutes", "60 Minutes", "Until Sleep", "Infinite")
	if(!duration_choice)
		return FALSE

	var/until_sleep = FALSE
	var/duration = -1
	switch(duration_choice)
		if("1 Minute") duration = 1 MINUTES
		if("5 Minutes") duration = 5 MINUTES
		if("10 Minutes") duration = 10 MINUTES
		if("20 Minutes") duration = 20 MINUTES
		if("30 Minutes") duration = 30 MINUTES
		if("60 Minutes") duration = 60 MINUTES
		if("Until Sleep") until_sleep = TRUE
		if("Infinite") duration = -1

	/// Apply Blessing
	if(M.apply_status_effect(blessing_path))
		message_admins(span_notice("Admin [key_name_admin(usr)] blessed [key_name_admin(M)] with [blessing_path]! Duration: [duration_choice]."))
		log_admin("[key_name(usr)] blessed [key_name(M)] with [blessing_path] for [duration_choice].")

		M.playsound_local(get_turf(M), 'sound/magic/bless.ogg', 100, FALSE)

		var/flavor_text = get_patron_blessing_text(M, blessing_path)
		if(flavor_text)
			to_chat(M, span_nicegreen("[flavor_text]"))

		/// Set actual expiration if needed (manual override for duration_modification types)
		if(duration > 0)
			M.start_blessing_duration_timer(blessing_path, duration)

		if(until_sleep)
			M.start_blessing_sleep_monitor(blessing_path)

		var/alert_desc = flavor_text ? span_nicegreen("[flavor_text]") : span_nicegreen("A divine force blesses you!")
		M.modify_blessing_alert_desc(blessing_path, alert_desc)

		return TRUE

	/// Toggle Off: Remove if present
	else if(M.remove_status_effect(blessing_path))
		message_admins(span_notice("Admin [key_name_admin(usr)] lifted blessing [blessing_path] from [key_name_admin(M)]!"))
		log_admin("[key_name(usr)] lifted blessing [key_name(M)] from [blessing_path].")
		return TRUE

	return FALSE


/// Starts a timer to auto-remove the blessing after duration expires
/mob/living/proc/start_blessing_duration_timer(blessing_path, duration)
	spawn(duration)
		if(has_status_effect(blessing_path))
			remove_status_effect(blessing_path)
			to_chat(src, span_warning("Your blessing fades with time..."))

/// Monitors if the mob falls asleep, removing the blessing if so
/mob/living/proc/start_blessing_sleep_monitor(blessing_path)
	spawn while(has_status_effect(blessing_path))
		if(IsSleeping())
			remove_status_effect(blessing_path)
			to_chat(src, span_warning("Your blessing fades as you fall asleep..."))
			return
		sleep(10)  /// Adjust check frequency as needed

/// Dynamically modifies the alert description for the active blessing
/// Can be used to customize Trollshape or any other active buff's description
/mob/living/proc/modify_blessing_alert_desc(blessing_path, new_desc)
	if(!blessing_path || !new_desc)
		return FALSE

	var/datum/status_effect/B = get_status_effect(blessing_path)
	if(!B || !B.alert_type)
		to_chat(src, span_warning("No active buff or invalid blessing path found to modify."))
		return FALSE

	for(var/atom/movable/screen/alert/A in client.screen)
		if(istype(A, B.alert_type))
			A.desc = new_desc
			//to_chat(src, span_notice("Blessing visual updated: [new_desc]"))
			return TRUE

	to_chat(src, span_warning("Could not find active alert instance for the blessing."))
	return FALSE

/// Returns the active status effect datum for the given type if it exists on the mob
/mob/living/proc/get_status_effect(path)
	if(!status_effects)
		return null
	for(var/datum/status_effect/B in status_effects)
		if(istype(B, path))
			return B
	return null

/// Returns the immersive flavor text based on both the target's patron and the specific blessing applied
/// Falls back to generic patron text or a default generic divine message
/// Returns the immersive flavor text based on both the target's patron and the specific blessing applied
/// Fully extended for Mjallidhorn, Visires, Hertannea, Gani, Pomette, Archdevil, Goler Kanh, Deceivers, Valdala, Akan, Erdl, Mordsol, Iliope, One Envy
/proc/get_patron_blessing_text(mob/living/carbon/human/M, blessing_path)
	var/patron_type = M.patron?.type
	if(!patron_type)
		return "A divine force surges through you, wrapping your soul in unseen power."

	/// Specific god -> specific blessing mapping
	var/static/list/blessing_flavor = list(
		/// Mjallidhorn – The Sunken God
		/datum/patron/divine/abyssor = list(
			/datum/status_effect/buff/beastsense = "Mjallidhorn whispers: \"The sea calls yer senses forth. Smell tha salt, taste tha fear.\"",
			/datum/status_effect/buff/trollshape = "Mjallidhorn groans: \"The abyss grants form... and hungers fer more.\"",
			/datum/status_effect/buff/divine_beauty = "Mjallidhorn rumbles: \"Even beauty drowns. But fer now, ye rise.\"",
			/datum/status_effect/buff/call_to_arms = "Mjallidhorn intones: \"The currents surge. Ya follow, or ya sink like a fockin' hog.\"",
			/datum/status_effect/buff/craft_buff = "Mjallidhorn echoes: \"Stone crumbles, but tha deep remembers yer craft.\"",
			/datum/status_effect/buff/foodbuff = "Mjallidhorn bubbles: \"Eat... but know tha sea waits to feast in turn.\"",
			/datum/status_effect/buff/clean_plus = "Mjallidhorn sighs: \"Saltwater cleanses shite from tha deck. Have a good wash.\"",
			/datum/status_effect/buff/featherfall = "Mjallidhorn murmurs: \"Float like a driftin' log.\"",
			/datum/status_effect/buff/darkvision = "Mjallidhorn growls: \"See through thickest of storms, lil'un.\"",
			/datum/status_effect/buff/haste = "Mjallidhorn growls: \"Flee if ya must... the sea is patient.\"",
			/datum/status_effect/buff/calm = "Mjallidhorn whispers: \"Still yerself. Think of shiftin' waves.\"",
			/datum/status_effect/buff/barbrage = "Mjallidhorn bellows: \"Like the fockin' storm tide, break 'em'! Break tha bastards! Makin' mah blood boil!\""
		),

		/// (Repeat this block, tailored for each god)
		/// Visires - The Sun Queen
		/datum/patron/divine/astrata = list(
			/datum/status_effect/buff/beastsense = "Visires commandeth: \"LET THY SIGHT BE CLEARED. THE LIGHT REVEALETH ALL.\"",
			/datum/status_effect/buff/trollshape = "Visires proclaimeth: \"BECOME THE HAMMER OF MINE WILL. STRIKE WITH PURPOSE.\"",
			/datum/status_effect/buff/divine_beauty = "Visires speaketh: \"RADIATE THY DUTY. LET NONE AVERT THEIR GAZE.\"",
			/datum/status_effect/buff/call_to_arms = "Visires belloweth: \"RISE, O RIGHTEOUS ONE. MARCH TO GLORY IN MINE NAME.\"",
			/datum/status_effect/buff/craft_buff = "Visires declareth: \"LET THINE HANDS BUILD THAT WHICH SHALL ENDURE.\"",
			/datum/status_effect/buff/foodbuff = "Visires blesseth: \"FEAST AND GROW STRONG BENEATH MINE EVER-WATCHFUL GAZE.\"",
			/datum/status_effect/buff/clean_plus = "Visires proclaims: \"THE LIGHT CLEANSETH ALL. DIRT SHALL NOT ENDURE.\"",
			/datum/status_effect/buff/featherfall = "Visires commandeth: \"ASCEND, FOR THOU ART WORTHY OF HEIGHT.\"",
			/datum/status_effect/buff/darkvision = "Visires scoffeth: \"SHADOWS ARE FOR THE FAINT. THOU NEEDST THEM NOT.\"",
			/datum/status_effect/buff/haste = "Visires ordereth: \"SWIFT BE THY FEET. DUTY BROOKETH NO DELAY.\"",
			/datum/status_effect/buff/calm = "Visires whispereth: \"BE STILL. THE SUN KEEPETH THEE SAFE.\"",
			/datum/status_effect/buff/barbrage = "Visires declareth: \"LET THY RIGHTEOUS FURY BURN AS MINE SUN DOES.\""
		),

		/// Hertannea - The Tiefling Queen
		/datum/patron/inhumen/baotha = list(
			/datum/status_effect/buff/beastsense = "Hertannea shrieks: \"See it! Smell it! Rip it apart! Or hug it! Both are valid!\"",
			/datum/status_effect/buff/trollshape = "Hertannea howls: \"Perfect. You’re gonna cause SUCH a scene!\"",
			/datum/status_effect/buff/divine_beauty = "Hertannea swoons: \"Beauty fit for a queen. I'd know.\"",
			/datum/status_effect/buff/call_to_arms = "Hertannea cackles: \"Ready to finally have some FUN?\"",
			/datum/status_effect/buff/craft_buff = "Hertannea snorts: \"Glue it wrong? Regardless of if it works, it’s ART!\"",
			/datum/status_effect/buff/foodbuff = "Hertannea hoots: \"Eat it, snort it! What could go wrong?\"",
			/datum/status_effect/buff/clean_plus = "Hertannea coughs: \"CLEAN? Hah! Let’s see how long it lasts, little neat freak. Have some fuuun!\"",
			/datum/status_effect/buff/featherfall = "Hertannea sings: \"Don't wanna live in fear and loathing; I wanna feel like I am floating.\"",
			/datum/status_effect/buff/darkvision = "Hertannea giggles: \"Oooo, secrets! Don’t blink or you’ll miss the eyes!\"",
			/datum/status_effect/buff/haste = "Hertannea screams: \"Dance like nobody cares! They don't! But I do. You're beautiful, darling. Beautiful.\"",
			/datum/status_effect/buff/calm = "Hertannea reassures: \"Sink into the serenity of mindlessness. I'm here for you, when no-one else is.\"",
			/datum/status_effect/buff/barbrage = "Hertannea squeals: \"BREAK SOMETHING BEAUTIFUL! Be someone beautiful. It’s therapeutic!\""
		),

		/// Gani - The Treefather
		/datum/patron/divine/dendor = list(
			/datum/status_effect/buff/beastsense = "Gani growls: \"Beasts... hunting? Yes, of course.\"",
			/datum/status_effect/buff/trollshape = "Gani mutters: \"Ah. I do recall making one of these, right?\"",
			/datum/status_effect/buff/divine_beauty = "Gani sighs: \"Bloom... Blooming and pollen.\"",
			/datum/status_effect/buff/call_to_arms = "Gani grumbles: \"Huh? Fighting..? Defend your forest.\"",
			/datum/status_effect/buff/craft_buff = "Gani states: \"Making something..? Don't hurt the trees, hm?\"",
			/datum/status_effect/buff/foodbuff = "Gani grunts: \"Eat. Eating good.\"",
			/datum/status_effect/buff/clean_plus = "Gani rasps: \"You wipe the rot... but it returns.\"",
			/datum/status_effect/buff/featherfall = "Gani chuckles: \"Fallin' leaves. Yah! You're like that. Heh.\"",
			/datum/status_effect/buff/darkvision = "Gani growls: \"See the dark roots..\"",
			/datum/status_effect/buff/haste = "Gani grumbles: \"Run fast. The wolves do.\"",
			/datum/status_effect/buff/calm = "Gani breathes: \"Wind flows. Calming?\"",
			/datum/status_effect/buff/barbrage = "Gani growls: \"GRRR! It's dancing time!\""
		),

		/// Pomette - The Heart of Angros
		/datum/patron/divine/eora = list(
			/datum/status_effect/buff/beastsense = "Pomette whispers: \"Even the beasts know love's call.\"",
			/datum/status_effect/buff/trollshape = "Pomette coos: \"Strong arms, tender heart.\"",
			/datum/status_effect/buff/divine_beauty = "Pomette smiles: \"You shine, beloved. All gaze upon you with wonder.\"",
			/datum/status_effect/buff/call_to_arms = "Pomette urges: \"Fight for love. For them.\"",
			/datum/status_effect/buff/craft_buff = "Pomette hums: \"Hands that build with love make wonders eternal.\"",
			/datum/status_effect/buff/foodbuff = "Pomette sings: \"Eat well, my sweet. Love fuels you.\"",
			/datum/status_effect/buff/clean_plus = "Pomette beams: \"I wash away your hurts, my dear.\"",
			/datum/status_effect/buff/featherfall = "Pomette hums: \"Softly now. I hold you.\"",
			/datum/status_effect/buff/darkvision = "Pomette comforts: \"See even where light fears to go.\"",
			/datum/status_effect/buff/haste = "Pomette nudges: \"Hurry, beloved. They wait for you.\"",
			/datum/status_effect/buff/calm = "Pomette soothes: \"Hush... Breathe... You are safe.\"",
			/datum/status_effect/buff/barbrage = "Pomette whispers: \"Love rages too. Protect what’s yours.\""
		),

		/// Archdevil - The Warborn Beast
		/datum/patron/inhumen/graggar = list(
			/datum/status_effect/buff/beastsense = "Archdevil growls: \"Sniff it. Smell the fear, thu fool.\"",
			/datum/status_effect/buff/trollshape = "Archdevil roars: \"Meat swells. Thu strong. Thu crush now.\"",
			/datum/status_effect/buff/divine_beauty = "Archdevil spits: \"Pah! Pretty? WASTE! Git bloody, thu fole!\"",
			/datum/status_effect/buff/call_to_arms = "Archdevil bellows: \"Raise swerd. Kill 'em fast. Or die, weakling!\"",
			/datum/status_effect/buff/craft_buff = "Archdevil smirks: \"Build? HA! Smash it till 'tis strong!\"",
			/datum/status_effect/buff/foodbuff = "Archdevil snorts: \"Meat good. Git strong.\"",
			/datum/status_effect/buff/clean_plus = "Archdevil spits: \"Clean? Bah. Mud good fer ya.\"",
			/datum/status_effect/buff/featherfall = "Archdevil snorts: \"Pah! Drop faster next time.\"",
			/datum/status_effect/buff/darkvision = "Archdevil huffs: \"See 'em hidin'. Then kill 'em.\"",
			/datum/status_effect/buff/haste = "Archdevil yells: \"Fast now! Get killin'!\"",
			/datum/status_effect/buff/calm = "Archdevil grumbles: \"Pff. Calm’s fer weaklings.\"",
			/datum/status_effect/buff/barbrage = "Archdevil roars: \"RAAAGH! Smash 'em flat!\""
		),

		/// Goler Kanh - The Iron Lord
		/datum/patron/divine/malum = list(
			/datum/status_effect/buff/beastsense = "Goler Kanh grunts: \"Even beasts know CRAFT. So should you.\"",
			/datum/status_effect/buff/trollshape = "Goler Kanh states: \"Strong arms make stronger tools.\"",
			/datum/status_effect/buff/divine_beauty = "Goler Kanh hammers: \"Beauty fades. STEEL remains.\"",
			/datum/status_effect/buff/call_to_arms = "Goler Kanh intones: \"Hammer strikes. Blood flows. This is labor's price.\"",
			/datum/status_effect/buff/craft_buff = "Goler Kanh orders: \"Work HARDER. Or break.\"",
			/datum/status_effect/buff/foodbuff = "Goler Kanh grunts: \"Eat. FUEL the forge within.\"",
			/datum/status_effect/buff/clean_plus = "Goler Kanh nods: \"Clean steel, good steel.\"",
			/datum/status_effect/buff/featherfall = "Goler Kanh mutters: \"Floatin’s for feathers... not IRON.\"",
			/datum/status_effect/buff/darkvision = "Goler Kanh growls: \"See what lurks. Strike it down.\"",
			/datum/status_effect/buff/haste = "Goler Kanh commands: \"Faster. The FORGE waits not.\"",
			/datum/status_effect/buff/calm = "Goler Kanh states: \"Temper your rage. FORGE it right.\"",
			/datum/status_effect/buff/barbrage = "Goler Kanh snarls: \"Unleash it. Strike like the hammer.\""
		),

		/// Deceivers - The Bandit God
		/datum/patron/inhumen/matthios = list(
			/datum/status_effect/buff/beastsense = "Deceivers laughs: \"Sniff it out, lad. Something worth stealing.\"",
			/datum/status_effect/buff/trollshape = "Deceivers grins: \"Ugly sells well in some towns, friend.\"",
			/datum/status_effect/buff/divine_beauty = "Deceivers smirks: \"Pretty coin, pretty face... both stolen easy.\"",
			/datum/status_effect/buff/call_to_arms = "Deceivers shouts: \"Fight dirty. Win rich.\"",
			/datum/status_effect/buff/craft_buff = "Deceivers shrugs: \"Build fast. Sell faster.\"",
			/datum/status_effect/buff/foodbuff = "Deceivers grins: \"Eat now... pay later.\"",
			/datum/status_effect/buff/clean_plus = "Deceivers cackles: \"Cleaned up nice... for a mark.\"",
			/datum/status_effect/buff/featherfall = "Deceivers chuckles: \"Fall soft... means you live to steal again.\"",
			/datum/status_effect/buff/darkvision = "Deceivers winks: \"See the dark? Hide better.\"",
			/datum/status_effect/buff/haste = "Deceivers shouts: \"Quick hands win riches.\"",
			/datum/status_effect/buff/calm = "Deceivers smirks: \"Calm? Nah, means they don’t see you comin'.\"",
			/datum/status_effect/buff/barbrage = "Deceivers yells: \"Break stuff. Blame someone else!\""
		),

		/// Valdala - The Undermaiden
		/datum/patron/divine/necra = list(
			/datum/status_effect/buff/beastsense = "Valdala murmurs: \"The grave knows your scent... and waits.\"",
			/datum/status_effect/buff/trollshape = "Valdala hums: \"Mass returns to earth. Let the soil remember you.\"",
			/datum/status_effect/buff/divine_beauty = "Valdala whispers: \"Even beauty rots. But for now... wear it.\"",
			/datum/status_effect/buff/call_to_arms = "Valdala states: \"Raise thy blade. All paths end the same.\"",
			/datum/status_effect/buff/craft_buff = "Valdala sighs: \"All things break. Make them, even so.\"",
			/datum/status_effect/buff/foodbuff = "Valdala croons: \"Feast whilst thou breathe. The hunger ends soon.\"",
			/datum/status_effect/buff/clean_plus = "Valdala sighs: \"Thou mayest wash flesh... but not its fate.\"",
			/datum/status_effect/buff/featherfall = "Valdala hums: \"Fall gently. The earth shall catch thee.\"",
			/datum/status_effect/buff/darkvision = "Valdala whispers: \"The dark is not empty. It welcomes.\"",
			/datum/status_effect/buff/haste = "Valdala murmurs: \"Quickly now. Time thins beneath thy feet.\"",
			/datum/status_effect/buff/calm = "Valdala soothes: \"Rest... the silence shall come for all.\"",
			/datum/status_effect/buff/barbrage = "Valdala intones: \"Rage, if thy must. The dead are silent, but not still.\""
		),

		/// Akan - The Moon Prince
		/datum/patron/divine/noc = list(
			/datum/status_effect/buff/beastsense = "Akan pondereth: \"The nite sees what the day fears.\"",
			/datum/status_effect/buff/trollshape = "Akan museth: \"Moonlight swells thy shape...\"",
			/datum/status_effect/buff/divine_beauty = "Akan murmureth: \"A fabulous dress fixes anyone. For now, have this.\"",
			/datum/status_effect/buff/call_to_arms = "Akan fadeth: \"There lies enemies of discovery. Remove them.\"",
			/datum/status_effect/buff/craft_buff = "Akan breatheth: \"Build in secret. None must know.\"",
			/datum/status_effect/buff/foodbuff = "Akan museth: \"A shrewd mind requires healthy appetite.\"",
			/datum/status_effect/buff/clean_plus = "Akan museth: \"Moonlight cleans better than the sun ever may.\"",
			/datum/status_effect/buff/featherfall = "Akan whispereth: \"Float, like silver strands through the wind.\"",
			/datum/status_effect/buff/darkvision = "Akan offereth: \"See through the nite.\"",
			/datum/status_effect/buff/haste = "Akan murmureth: \"Move as quickly as the pages turn.\"",
			/datum/status_effect/buff/calm = "Akan sootheth: \"Calm thyself... think of gotes leaping over the moon.\"",
			/datum/status_effect/buff/barbrage = "Akan commandeth: \"Feel the power of strengthened magick flow through thyself.\""
		),

		/// Erdl - The Mistake
		/datum/patron/divine/pestra = list(
			/datum/status_effect/buff/beastsense = "Erdl bemuses: \"Sniff it. Identify its substance— not that cycles of rot would harm you.\"",
			/datum/status_effect/buff/trollshape = "Erdl wheezes: \"Thick skin, bad breath. You’re a fascinating specimen.\"",
			/datum/status_effect/buff/divine_beauty = "Erdl muses: \"Unblemished... Curious. Beauty often masks the most virulent flaws.\"",
			/datum/status_effect/buff/call_to_arms = "Erdl howls: \"Some bones must be broken before one may mend them.\"",
			/datum/status_effect/buff/craft_buff = "Erdl giggles: \"Change is divine. One compound into another— chaos with purpose.\"",
			/datum/status_effect/buff/foodbuff = "Erdl comments: \"Be nourished. Spoilage is just misunderstood fermentation.\"",
			/datum/status_effect/buff/clean_plus = "Erdl scoffs: \"Cleanliness? Temporary at best. Let’s see how long it lasts.\"",
			/datum/status_effect/buff/featherfall = "Erdl hiccups: \"You sink through water but fall through air. What if we reversed this?\"",
			/datum/status_effect/buff/darkvision = "Erdl lectures: \"Germs are not limited by darkness.\"",
			/datum/status_effect/buff/haste = "Erdl snaps: \"Faster now! Spores don’t wait to bloom.\"",
			/datum/status_effect/buff/calm = "Erdl whispers: \"Stillness... Let the fever sleep awhile.\"",
			/datum/status_effect/buff/barbrage = "Erdl shrieks: \"Destruction is yet another form of change.\""
		),

		/// Mordsol - Justice Incarnate
		/datum/patron/divine/ravox = list(
			/datum/status_effect/buff/beastsense = "Mordsol growls: \"Smell your enemy. Hunt them down with purpose.\"",
			/datum/status_effect/buff/trollshape = "Mordsol commands: \"Let might serve justice. Let strength carry duty.\"",
			/datum/status_effect/buff/divine_beauty = "Mordsol declares: \"Wear your glory well, warrior. Let honor shine brighter.\"",
			/datum/status_effect/buff/call_to_arms = "Mordsol bellows: \"To war! You've got this, kid.\"",
			/datum/status_effect/buff/craft_buff = "Mordsol nods: \"Forge victory with your hands. Let each blow ring true.\"",
			/datum/status_effect/buff/foodbuff = "Mordsol grunts: \"Eat. Even the strong must endure the march.\"",
			/datum/status_effect/buff/clean_plus = "Mordsol commands: \"Clean your blade. We should not revel in blood we spill.\"",
			/datum/status_effect/buff/featherfall = "Mordsol comments: \"Even the bold must fall with grace.\"",
			/datum/status_effect/buff/darkvision = "Mordsol growls: \"See the coward. Bring them to justice.\"",
			/datum/status_effect/buff/haste = "Mordsol barks: \"Swift feet carry righteous blades.\"",
			/datum/status_effect/buff/calm = "Mordsol grunts: \"Still your heart. The battle shall come.\"",
			/datum/status_effect/buff/barbrage = "Mordsol roars: \"BE FILLED WITH RIGHTEOUS ANGER!\""
		),

		/// Iliope - The Trickster
		/datum/patron/divine/xylix = list(
			/datum/status_effect/buff/beastsense = "Iliope laughs: \"Sniff sniff! What's behind that tree? Chaos, I hope!\"",
			/datum/status_effect/buff/trollshape = "Iliope grins: \"Big, dumb, and hilarious. Perfect.\"",
			/datum/status_effect/buff/divine_beauty = "Iliope cackles: \"Shiny! Pretty! Now trip over it!\"",
			/datum/status_effect/buff/call_to_arms = "Iliope shouts: \"Time for a fun fight. Maybe you'll win. Maybe not!\"",
			/datum/status_effect/buff/craft_buff = "Iliope winks: \"Stack it wrong. Bet it still works!\"",
			/datum/status_effect/buff/foodbuff = "Iliope giggles: \"Eat that. Could be poison!\"",
			/datum/status_effect/buff/clean_plus = "Iliope chuckles: \"Clean now. Mess later.\"",
			/datum/status_effect/buff/featherfall = "Iliope howls: \"Whee! Hope ya bounce!\"",
			/datum/status_effect/buff/darkvision = "Iliope snickers: \"Ooo... spooky. Boo!\"",
			/datum/status_effect/buff/haste = "Iliope screams: \"FAST! Trip 'em!\"",
			/datum/status_effect/buff/calm = "Iliope hums: \"Calm... until it ain’t.\"",
			/datum/status_effect/buff/barbrage = "Iliope roars: \"Break it! Then break it twice!\""
		),

		/// One Envy - The Ascended Goddess
		/datum/patron/inhumen/zizo = list(
			/datum/status_effect/buff/beastsense = "One Envy hisses: \"They crawl. They beg. They are prey, inferior. Hunt them.\"",
			/datum/status_effect/buff/trollshape = "One Envy croons: \"This form? Power. Strength. Craft your flesh. This is my gift.\"",
			/datum/status_effect/buff/divine_beauty = "One Envy sneers: \"They shall kneel before this visage. And they shall weep.\"",
			/datum/status_effect/buff/call_to_arms = "One Envy commands: \"Fight. Break them. Show the strength and cunning of your queen.\"",
			/datum/status_effect/buff/craft_buff = "One Envy states: \"Strong. Flexible Show the craft is worthy. Weave flesh like linen.\"",
			/datum/status_effect/buff/foodbuff = "One Envy smirks: \"Eat. Power grows.\"",
			/datum/status_effect/buff/clean_plus = "One Envy sneers: \"Clean. Now you are worthy of gaze.\"",
			/datum/status_effect/buff/featherfall = "One Envy hisses: \"Float above them. They are beneath us.\"",
			/datum/status_effect/buff/darkvision = "One Envy purrs: \"See what they hide. See all.\"",
			/datum/status_effect/buff/haste = "One Envy commands: \"Move. Do not stumble. Do not fail me.\"",
			/datum/status_effect/buff/calm = "One Envy whispers: \"Calm now. Wait for your opportunity to strike.\"",
			/datum/status_effect/buff/barbrage = "One Envy roars: \"Rend them. Show this strength!\""
		)
	)

	/// Return specific blessing line if available
	if(blessing_flavor[patron_type] && blessing_flavor[patron_type][blessing_path])
		return blessing_flavor[patron_type][blessing_path]

	/// Generic fallback
	return "A divine force surges through you, wrapping your soul in unseen power."
