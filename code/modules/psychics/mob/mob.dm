/mob/living
	var/datum/psi_complexus/psi

/mob/living/Login()
	. = ..()
	if(psi)
		psi.update()

/mob/living/Destroy()
	if(psi) qdel(psi)
	. = ..()

/mob/living/proc/set_psi_rank(var/faculty, var/rank, var/take_larger, var/defer_update, var/temporary)
	if(!psi)
		psi = new(src)
	if(!HAS_ASPECT(src, ASPECT_PSI_ROOT))
		ADD_ASPECT(src, ASPECT_PSI_ROOT)
	var/current_rank = psi.get_rank(faculty)
	if(current_rank != rank && (!take_larger || current_rank < rank))
		psi.set_rank(faculty, rank, defer_update, temporary)
