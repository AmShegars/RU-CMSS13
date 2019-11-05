/*
 * Cryogenic refrigeration unit. Basically a despawner.
 * Stealing a lot of concepts/code from sleepers due to massive laziness.
 * The despawn tick will only fire if it's been more than time_till_despawned ticks
 * since time_entered, which is world.time when the occupant moves in.
 * ~ Zuhayr
 */

//Used for logging people entering cryosleep and important items they are carrying.
var/global/list/frozen_crew = list()
var/global/list/frozen_items = list("Alpha"=list(),"Bravo"=list(),"Charlie"=list(),"Delta"=list(),"MP"=list(),"REQ"=list(),"Eng"=list(),"Med"=list())

//Main cryopod console.

/obj/structure/machinery/computer/cryopod
	name = "hypersleep bay console"
	desc = "A large console controlling the ship's hypersleep bay. Most of the options are disabled and locked, although it allows recovery of items from long-term hypersleeping crew."
	icon = 'icons/obj/structures/machinery/computer.dmi'
	icon_state = "cellconsole"
	circuit = "/obj/item/circuitboard/computer/cryopodcontrol"
	exproof = TRUE
	unslashable = TRUE
	unacidable = TRUE
	var/cryotype = "REQ"
	var/mode = null

/obj/structure/machinery/computer/cryopod/medical
	cryotype = "Med"

/obj/structure/machinery/computer/cryopod/brig
	cryotype = "MP"

/obj/structure/machinery/computer/cryopod/eng
	cryotype = "Eng"

/obj/structure/machinery/computer/cryopod/alpha
	cryotype = "Alpha"

/obj/structure/machinery/computer/cryopod/bravo
	cryotype = "Bravo"

/obj/structure/machinery/computer/cryopod/charlie
	cryotype = "Charlie"

/obj/structure/machinery/computer/cryopod/delta
	cryotype = "Delta"

/obj/structure/machinery/computer/cryopod/attack_ai()
	src.attack_hand()

/obj/structure/machinery/computer/cryopod/attack_hand(mob/user = usr)
	if(stat & (NOPOWER|BROKEN))
		return

	user.set_interaction(src)
	src.add_fingerprint(usr)

	var/dat

	if(!(ticker))
		return

	dat += "<hr/><br/><b>Cryogenic Oversight Control for [cryotype]</b><br/>"
	dat += "<i>Welcome, [user.real_name].</i><br/><br/><hr/>"
	dat += "<a href='?src=\ref[src];log=1'>View storage log</a>.<br>"
	dat += "<a href='?src=\ref[src];view=1'>View objects</a>.<br>"
	dat += "<a href='?src=\ref[src];item=1'>Recover object</a>.<br>"
	dat += "<a href='?src=\ref[src];allitems=1'>Recover all objects</a>.<br>"

	user << browse(dat, "window=cryopod_console")
	onclose(user, "cryopod_console")

/obj/structure/machinery/computer/cryopod/Topic(href, href_list)

	//if(..())
	//	return

	var/mob/user = usr
	var/list/frozen_items_for_type = frozen_items[cryotype]

	src.add_fingerprint(user)

	if(href_list["log"])

		var/dat = "<b>Recently stored crewmembers</b><br/><hr/><br/>"
		for(var/person in frozen_crew)
			dat += "[person]<br/>"
		dat += "<hr/>"

		user << browse(dat, "window=cryolog")

	if(href_list["view"])

		var/dat = "<b>Recently stored objects</b><br/><hr/><br/>"
		for(var/obj/item/I in frozen_items_for_type)
			dat += "[I.name]<br/>"
		dat += "<hr/>"

		user << browse(dat, "window=cryoitems")

	else if(href_list["item"])

		if(frozen_items_for_type.len == 0)
			to_chat(user, SPAN_WARNING("There is nothing to recover from storage."))
			return

		var/obj/item/I = input(usr, "Please choose which object to retrieve.", "Object recovery",null) as null|anything in frozen_items_for_type
		if(!I)
			return

		if(!(I in frozen_items_for_type))
			to_chat(user, SPAN_WARNING("[I] is no longer in storage."))
			return

		visible_message(SPAN_NOTICE("[src] beeps happily as it disgorges [I]."))

		I.loc = get_turf(src)
		frozen_items_for_type -= I

	else if(href_list["allitems"])

		if(frozen_items_for_type.len == 0)
			to_chat(user, SPAN_WARNING("There is nothing to recover from storage."))
			return

		visible_message(SPAN_NOTICE("[src] beeps happily as it disgorges the desired objects."))

		for(var/obj/item/I in frozen_items_for_type)
			I.loc = get_turf(src)
			frozen_items_for_type -= I

	src.updateUsrDialog()
	return


//Decorative structures to go alongside cryopods.
/obj/structure/cryofeed

	name = "hypersleep chamber feed"
	desc = "A bewildering tangle of machinery and pipes linking the hypersleep chambers to the hypersleep bay.."
	icon = 'icons/obj/structures/machinery/cryogenics.dmi'
	icon_state = "cryo_rear"
	anchored = 1
	density = 1

	var/orient_right = null //Flips the sprite.

/obj/structure/cryofeed/right
	orient_right = 1
	icon_state = "cryo_rear-r"

/obj/structure/cryofeed/New()

	if(orient_right)
		icon_state = "cryo_rear-r"
	else
		icon_state = "cryo_rear"
	..()

//Cryopods themselves.
/obj/structure/machinery/cryopod
	name = "hypersleep chamber"
	desc = "A large automated capsule with LED displays intended to put anyone inside into 'hypersleep', a form of non-cryogenic statis used on most ships, linked to a long-term hypersleep bay on a lower level."
	icon = 'icons/obj/structures/machinery/cryogenics.dmi'
	icon_state = "body_scanner_0"
	density = 1
	anchored = 1

	var/mob/living/occupant = null //Person waiting to be despawned.
	var/orient_right = null // Flips the sprite.
	var/time_till_despawn = MINUTES_10 //10 minutes-ish safe period before being despawned.
	var/time_entered = 0 //Used to keep track of the safe period.
	var/obj/item/device/radio/intercom/announce //Intercom for cryo announcements

/obj/structure/machinery/cryopod/right
	orient_right = 1
	icon_state = "body_scanner_0-r"

/obj/structure/machinery/cryopod/New()

	announce = new /obj/item/device/radio/intercom(src)

	if(orient_right)
		icon_state = "body_scanner_0-r"
	else
		icon_state = "body_scanner_0"
	..()

//Lifted from Unity stasis.dm and refactored. ~Zuhayr
/obj/structure/machinery/cryopod/process()
	if(occupant)
		//Allow a ten minute gap between entering the pod and actually despawning.
		if(world.time - time_entered < time_till_despawn)
			return

		if(!occupant.client && occupant.stat < DEAD) //Occupant is living and has no client.

			//Drop all items into the pod.
			for(var/obj/item/W in occupant)
				occupant.drop_inv_item_to_loc(W, src)

			//Delete all items not on the preservation list.

			var/list/items = contents.Copy()
			items -= occupant //Don't delete the occupant
			items -= announce //or the autosay radio.

			var/list/dept_console = frozen_items["REQ"]
			if(ishuman(occupant))
				var/mob/living/carbon/human/H = occupant
				switch(H.job)
					if("Military Police","Chief MP")
						dept_console = frozen_items["MP"]
					if("Doctor","Researcher","Chief Medical Officer")
						dept_console = frozen_items["Med"]
					if("Maintenance Tech","Chief Engineer")
						dept_console = frozen_items["Eng"]

			var/list/deleteempty = list(/obj/item/storage/backpack/marine/satchel)

			var/list/deleteall = list(/obj/item/clothing/mask/cigarette, \
			/obj/item/clothing/glasses/sunglasses, \
			/obj/item/clothing/glasses/mgoggles, \
			/obj/item/clothing/head/beret/cm/red, \
			/obj/item/clothing/gloves/black, \
			/obj/item/weapon/baton, \
			/obj/item/weapon/gun/energy/taser, \
			/obj/item/clothing/glasses/sunglasses/sechud, \
			/obj/item/device/radio/headset/almayer, \
			/obj/item/card/id, \
			/obj/item/clothing/under/marine, \
			/obj/item/clothing/shoes/marine, \
			/obj/item/clothing/head/cmcap)

			var/list/strippeditems = list()

			item_loop:
				for(var/obj/item/W in items)
					if((W.flags_inventory & CANTSTRIP) || (W.flags_item & NODROP)) //We don't keep donor items and undroppable/unremovable items
						if(istype(W, /obj/item/clothing/suit/storage))
							var/obj/item/clothing/suit/storage/SS = W
							for(var/obj/item/I in SS.pockets) //But we keep stuff inside them
								SS.pockets.remove_from_storage(I, loc)
								strippeditems += I
								I.loc = null
						if(istype(W, /obj/item/storage))
							var/obj/item/storage/S = W
							for(var/obj/item/I in S)
								S.remove_from_storage(I, loc)
								strippeditems += I
								I.loc = null
						qdel(W)
						continue


					//special items that store stuff in a nonstandard way, we properly remove those items

					if(istype(W, /obj/item/clothing/suit/storage))
						var/obj/item/clothing/suit/storage/SS = W
						for(var/obj/item/I in SS.pockets)
							SS.pockets.remove_from_storage(I, loc)
							strippeditems += I
							I.loc = null

					if(istype(W, /obj/item/clothing/under))
						var/obj/item/clothing/under/UN = W
						for(var/obj/item/I in UN.accessories)
							UN.remove_accessory(occupant, I)
							strippeditems += I
							I.loc = null

					if(istype(W, /obj/item/clothing/shoes/marine))
						var/obj/item/clothing/shoes/marine/MS = W
						if(MS.stored_item)
							strippeditems += MS.stored_item
							MS.stored_item.loc = null
							MS.stored_item = null



					for(var/TT in deleteempty)
						if(istype(W, TT))
							if(length(W.contents) == 0)
								qdel(W) // delete all the empty satchels
								continue item_loop
							break // not empty, don't delete

					for(var/DA in deleteall)
						if(istype(W, DA))
							qdel(W)
							continue item_loop



					dept_console += W
					W.loc = null

			stripped_items:
				for(var/obj/item/A in strippeditems)
					for(var/DAA in deleteall)
						if(istype(A, DAA))
							qdel(A)
							continue stripped_items

					dept_console += A
					A.loc = null


			//Update any existing objectives involving this mob.
			for(var/datum/objective/O in all_objectives)
				//We don't want revs to get objectives that aren't for heads of staff. Letting
				//them win or lose based on cryo is silly so we remove the objective.
				if(istype(O, /datum/objective/mutiny) && O.target == occupant.mind)
					qdel(O)
				else if(O.target && istype(O.target,/datum/mind))
					if(O.target == occupant.mind)
						if(O.owner && O.owner.current)
							to_chat(O.owner.current, SPAN_DANGER("You get the feeling your target is no longer within your reach. Time for Plan [pick(list("A","B","C","D","X","Y","Z"))]."))
						O.target = null
						spawn(1) //This should ideally fire after the occupant is deleted.
							if(!O) return
							O.find_target()
							if(!(O.target))
								all_objectives -= O
								O.owner.objectives -= O
								qdel(O)

			if(ishuman(occupant))
				var/mob/living/carbon/human/H = occupant
				if(H.mind && H.assigned_squad)
					var/datum/squad/S = H.assigned_squad
					switch(H.mind.assigned_role)
						if("Squad Engineer")
							S.num_engineers--
						if("Squad Medic")
							S.num_medics--
						if("Squad Specialist")
							S.num_specialists--
							//we make the set this specialist took if any available again
							if(H.mind.cm_skills)
								var/set_name
								switch(H.mind.cm_skills.get_skill_level(SKILL_SPEC_WEAPONS))
									if(SKILL_SPEC_ROCKET)
										set_name = "Demolitionist Set"
									if(SKILL_SPEC_GRENADIER)
										set_name = "Heavy Grenadier Set"
									if(SKILL_SPEC_PYRO)
										set_name = "Pyro Set"
									if(SKILL_SPEC_SCOUT)
										set_name = "Scout Set"
									if(SKILL_SPEC_SNIPER)
										set_name = "Sniper Set"

								if(set_name && !available_specialist_sets.Find(set_name))
									available_specialist_sets += set_name
						if("Squad Smartgunner")
							S.num_smartgun--
						if("Squad Leader")
							S.num_leaders--
					S.count--

			ticker.mode.latejoin_tally-- //Cryoing someone out removes someone from the Marines, blocking further larva spawns until accounted for

			//Handle job slot/tater cleanup.
			if(occupant.mind)
				RoleAuthority.free_role(RoleAuthority.roles_for_mode[occupant.mind.assigned_role])

				if(occupant.mind.objectives.len)
					qdel(occupant.mind.objectives)
					occupant.mind.objectives = null
					occupant.mind.special_role = null

			//Delete them from datacore.
			if(PDA_Manifest.len)
				PDA_Manifest.Cut()
			for(var/datum/data/record/R in data_core.medical)
				if((R.fields["name"] == occupant.real_name))
					data_core.medical -= R
					qdel(R)
			for(var/datum/data/record/T in data_core.security)
				if((T.fields["name"] == occupant.real_name))
					data_core.security -= T
					qdel(T)
			for(var/datum/data/record/G in data_core.general)
				if((G.fields["name"] == occupant.real_name))
					data_core.general -= G
					qdel(G)

			if(orient_right)
				icon_state = "body_scanner_0-r"
			else
				icon_state = "body_scanner_0"

			occupant.track_death_calculations()

			occupant.ghostize(0) //We want to make sure they are not kicked to lobby.
			//TODO: Check objectives/mode, update new targets if this mob is the target, spawn new antags?

			//Make an announcement and log the person entering storage.
			frozen_crew += "[occupant.real_name]"

			announce.autosay("[occupant.real_name] has entered long-term hypersleep storage. Belongings moved to hypersleep inventory.", "Hypersleep Storage System")
			visible_message(SPAN_NOTICE("[src] hums and hisses as it moves [occupant.real_name] into hypersleep storage."))

			//Delete the mob.

			qdel(occupant)
			occupant = null
			stop_processing()


/obj/structure/machinery/cryopod/attackby(obj/item/W, mob/living/user)

	if(istype(W, /obj/item/grab))
		if(isXeno(user)) return
		var/obj/item/grab/G = W
		if(occupant)
			to_chat(user, SPAN_WARNING("[src] is occupied."))
			return

		if(!isliving(G.grabbed_thing))
			return

		var/willing = null //We don't want to allow people to be forced into despawning.
		var/mob/living/M = G.grabbed_thing

		if(M.stat == DEAD) //This mob is dead
			to_chat(user, SPAN_WARNING("[src] immediately rejects [M]. \He passed away!"))
			return

		if(isXeno(M))
			to_chat(user, SPAN_WARNING("There is no way [src] will accept [M]!"))
			return

		if(M.client)
			if(alert(M,"Would you like to enter cryosleep?", , "Yes", "No") == "Yes")
				if(!M || !G || !G.grabbed_thing) return
				willing = 1
		else
			willing = 1

		if(willing)

			visible_message(SPAN_NOTICE("[user] starts putting [M] into [src]."),
			SPAN_NOTICE("You start putting [M] into [src]."))

			if(!do_after(user, 20, INTERRUPT_ALL, BUSY_ICON_GENERIC)) return
			if(!M || !G || !G.grabbed_thing) return
			if(occupant)
				to_chat(user, SPAN_WARNING("[src] is occupied."))
				return
			M.forceMove(src)
			if(orient_right)
				icon_state = "body_scanner_1-r"
			else
				icon_state = "body_scanner_1"

			to_chat(M, SPAN_NOTICE("You feel cool air surround you. You go numb as your senses turn inward."))
			to_chat(M, "<span class='boldnotice'>If you ghost, log out or close your client now, your character will shortly be permanently removed from the round.</span>")
			occupant = M
			start_processing()
			time_entered = world.time

			//Book keeping!
			var/turf/location = get_turf(src)
			log_admin("[key_name_admin(M)] has entered a stasis pod. (<A HREF='?_src_=admin_holder;adminplayerobservecoodjump=1;X=[location.x];Y=[location.y];Z=[location.z]'>JMP</a>)")
			message_admins(SPAN_NOTICE("[key_name_admin(M)] has entered a stasis pod."))

			//Despawning occurs when process() is called with an occupant without a client.
			add_fingerprint(M)

/obj/structure/machinery/cryopod/verb/eject()

	set name = "Eject Pod"
	set category = "Object"
	set src in oview(1)
	if(usr.stat != 0)
		return

	if(occupant != usr)
		to_chat(usr, SPAN_WARNING("You can't drag people out of hypersleep!"))
		return

	if(orient_right)
		icon_state = "body_scanner_0-r"
	else
		icon_state = "body_scanner_0"

	//Eject any items that aren't meant to be in the pod.
	var/list/items = src.contents
	if(occupant) items -= occupant
	if(announce) items -= announce

	for(var/obj/item/W in items)
		W.loc = get_turf(src)

	go_out()
	add_fingerprint(usr)
	return

/obj/structure/machinery/cryopod/verb/move_inside()
	set name = "Enter Pod"
	set category = "Object"
	set src in oview(1)

	if(usr.stat != 0 || !(ishuman(usr)))
		return

	if(occupant)
		to_chat(usr, SPAN_WARNING("[src] is occupied."))
		return

	if(isXeno(usr))
		to_chat(usr, SPAN_WARNING("There is no way [src] will accept you!"))
		return

	usr.visible_message(SPAN_NOTICE("[usr] starts climbing into [src]."),
	SPAN_NOTICE("You start climbing into [src]."))

	if(do_after(usr, 20, INTERRUPT_NO_NEEDHAND, BUSY_ICON_GENERIC))

		if(!usr || !usr.client)
			return

		if(occupant)
			to_chat(usr, SPAN_WARNING("[src] is occupied."))
			return

		usr.forceMove(src)
		occupant = usr

		if(orient_right)
			icon_state = "body_scanner_1-r"
		else
			icon_state = "body_scanner_1"

		to_chat(usr, SPAN_NOTICE("You feel cool air surround you. You go numb as your senses turn inward."))
		to_chat(usr, "<span class='boldnotice'>If you ghost, log out or close your client now, your character will shortly be permanently removed from the round.</span>")
		time_entered = world.time
		start_processing()

		add_fingerprint(usr)

	return

/obj/structure/machinery/cryopod/proc/go_out()

	if(!occupant)
		return

	occupant.forceMove(get_turf(src))
	occupant = null
	stop_processing()

	if(orient_right)
		icon_state = "body_scanner_0-r"
	else
		icon_state = "body_scanner_0"
