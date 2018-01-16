
/obj/structure/table/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if(air_group || (height==0)) return 1
	if(istype(mover,/obj/item/projectile))
		return (check_cover(mover,target))
	if (flipped == 1)
		if (get_dir(loc, target) == dir)
			return !density
		else
			return 1
	if(istype(mover) && mover.checkpass(PASSTABLE))
		return 1
	if(locate(/obj/structure/table) in get_turf(mover))
		return 1
	return 0

//checks if projectile 'P' from turf 'from' can hit whatever is behind the table. Returns 1 if it can, 0 if bullet stops.
/obj/structure/table/proc/check_cover(obj/item/projectile/P, turf/from)
	var/turf/cover
	if(flipped)
		cover = get_turf(src)
	else
		cover = get_step(loc, get_dir(from, loc))
	if(!cover)
		return 1
	if (get_dist(P.starting, loc) <= 1) //Tables won't help you if people are THIS close
		return 1

	var/chance = 20
	if(ismob(P.original) && get_turf(P.original) == cover)
		var/mob/M = P.original
		if (M.lying)
			chance += 20				//Lying down lets you catch less bullets
	if(flipped)
		if(get_dir(loc, from) == dir)	//Flipped tables catch mroe bullets
			chance += 30
		else
			return 1					//But only from one side

	if(prob(chance))
		return 0 //blocked
	return 1

/obj/structure/table/bullet_act(obj/item/projectile/P)
	if(!(P.damage_type == BRUTE || P.damage_type == BURN))
		return 0

	if(take_damage(P.damage/2))
		//prevent tables with 1 health left from stopping bullets outright
		return PROJECTILE_CONTINUE //the projectile destroyed the table, so it gets to keep going

	visible_message("<span class='warning'>\The [P] hits [src]!</span>")
	return 0

/obj/structure/table/CheckExit(var/atom/movable/O, target as turf)
	if(istype(O) && O.checkpass(PASSTABLE))
		return 1
	if (flipped==1)
		if (get_dir(loc, target) == dir)
			return !density
		else
			return 1
	return 1


/obj/structure/table/MouseDrop_T(obj/O as obj, var/mob/user)

	if ((!( istype(O, /obj/item) ) || user.get_active_hand() != O))
		return ..()
	if(isrobot(user))
		return
	user.drop_item()
	if (O.loc != src.loc)
		step(O, get_dir(O, src))
	return


/obj/structure/table/attackby(obj/item/W, mob/user, var/click_params)
	if (!W) return

	// Handle harm intent grabbing/tabling.
	if(istype(W, /obj/item/grab) && get_dist(src,user)<2)
		var/obj/item/grab/G = W
		if (G.affecting_mob)
			var/obj/occupied = turf_is_crowded()
			if(occupied)
				user << "<span class='danger'>There's \a [occupied] in the way.</span>"
				return
			if (G.state < GRAB_AGGRESSIVE)
				user << "<span class='danger'>You need a better grip to do that!</span>"
			else
				if(user.a_intent == I_HURT)
					visible_message("<span class='danger'>\The [G.assailant] slams \the [G.affecting_mob]'s face into \the [src]!</span>")
					var/list/L = take_damage(rand(1,5))
					var/blocked = G.affecting_mob.run_armor_check(BP_HEAD, "melee")
					if (prob(30 * blocked_mult(blocked)))
						G.affecting_mob.Weaken(5)
					G.affecting_mob.apply_damage(8, BRUTE, BP_HEAD, blocked)
					// Shards. Extra damage, plus potentially the fact YOU LITERALLY HAVE A PIECE OF GLASS/METAL/WHATEVER IN YOUR FACE
					for(var/obj/item/material/shard/S in L)
						if(S.sharp && prob(50))
							G.affecting_mob.visible_message("<span class='danger'>\The [S] slices into \the [G.affecting_mob]'s face!</span>",
					                  "<span class='danger'>\The [S] slices into your face!</span>")
							G.affecting_mob.standard_weapon_hit_effects(S, G.assailant, S.force*2, blocked, BP_HEAD) //standard weapon hit effects include damage and embedding
					playsound(loc, material ? material.tableslam_noise : 'sound/weapons/tablehit1.ogg', 50, 1)
				else
					G.affecting_mob.forceMove(src.loc)
					G.affecting_mob.Weaken(5)
					visible_message("<span class='danger'>[G.assailant] heaves \the [G.affecting_mob] onto \the [src].</span>")
				qdel(W)
			return

	// Handle dismantling or placing things on the table from here on.
	if(isrobot(user))
		return

	if(W.loc != user) // This should stop mounted modules ending up outside the module.
		return

	if(istype(W, /obj/item/melee/energy/blade) || istype(W,/obj/item/psychic_power/psiblade/master/grand/paramount))
		var/datum/effect/system/spark_spread/spark_system = new /datum/effect/system/spark_spread()
		spark_system.set_up(5, 0, src.loc)
		spark_system.start()
		playsound(src.loc, 'sound/weapons/blade1.ogg', 50, 1)
		playsound(src.loc, "sparks", 50, 1)
		user.visible_message("<span class='danger'>\The [src] was sliced apart by [user]!</span>")
		break_to_parts()
		return

	if(can_plate && !material)
		user << "<span class='warning'>There's nothing to put \the [W] on! Try adding plating to \the [src] first.</span>"
		return

	// Placing stuff on tables
	if(user.drop_from_inventory(W, src.loc))
		auto_align(W, click_params)

	return

/*
Automatic alignment of items to an invisible grid, defined by CELLS and CELLSIZE, defined in code/__defines/misc.dm.
Since the grid will be shifted to own a cell that is perfectly centered on the turf, we end up with two 'cell halves'
on edges of each row/column.
Each item defines a center_of_mass, which is the pixel of a sprite where its projected center of mass toward a turf
surface can be assumed. For a piece of paper, this will be in its center. For a bottle, it will be (near) the bottom
of the sprite.
auto_align() will then place the sprite so the defined center_of_mass is at the bottom left corner of the grid cell
closest to where the cursor has clicked on.
Note: This proc can be overwritten to allow for different types of auto-alignment.
*/
/obj/item/var/center_of_mass = "x=16;y=16" //can be null for no exact placement behaviour
/obj/structure/table/proc/auto_align(obj/item/W, click_params)
	if (!W.center_of_mass) // Clothing, material stacks, generally items with large sprites where exact placement would be unhandy.
		W.pixel_x = rand(-W.randpixel, W.randpixel)
		W.pixel_y = rand(-W.randpixel, W.randpixel)
		W.pixel_z = 0
		return

	if (!click_params)
		return

	var/list/click_data = params2list(click_params)
	if (!click_data["icon-x"] || !click_data["icon-y"])
		return

	// Calculation to apply new pixelshift.
	var/mouse_x = text2num(click_data["icon-x"])-1 // Ranging from 0 to 31
	var/mouse_y = text2num(click_data["icon-y"])-1

	var/cell_x = Clamp(round(mouse_x/CELLSIZE), 0, CELLS-1) // Ranging from 0 to CELLS-1
	var/cell_y = Clamp(round(mouse_y/CELLSIZE), 0, CELLS-1)

	var/list/center = cached_key_number_decode(W.center_of_mass)

	W.pixel_x = (CELLSIZE * (cell_x + 0.5)) - center["x"]
	W.pixel_y = (CELLSIZE * (cell_y + 0.5)) - center["y"]
	W.pixel_z = 0

/obj/structure/table/rack/auto_align(obj/item/W, click_params)
	if(W && !W.center_of_mass)
		..(W)

	var/i = -1
	for (var/obj/item/I in get_turf(src))
		if (I.anchored || !I.center_of_mass)
			continue
		i++
		I.pixel_x = max(3-i*3, -3) + 1 // There's a sprite layering bug for 0/0 pixelshift, so we avoid it.
		I.pixel_y = max(4-i*4, -4) + 1
		I.pixel_z = 0

/obj/structure/table/attack_tk() // no telehulk sorry
	return
