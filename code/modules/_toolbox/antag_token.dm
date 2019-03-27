GLOBAL_VAR_INIT(antagtokenpath,"data/other_saves/antagtokens.sav")

/datum/game_mode
	var/list/available_antag_tokens = list("traitor","changeling")

client/verb/check_antag_token()
	set name = "Antagonist Tokens"
	set category = "OOC"
	var/tokens = get_antag_token_count()
	if(!SSticker || !SSticker.mode || !SSticker.mode.available_antag_tokens || !SSticker.mode.available_antag_tokens.len)
		return
	var/list/choices = SSticker.mode.available_antag_tokens
	if(!istype(mob,/mob/living/carbon/human) || !mob.mind)
		if(!tokens)
			alert(src,"You have [tokens] antagonist tokens","Antagonist Tokens","Ok")
		else
			alert(src,"You have [tokens] antagonist tokens but you can not use one at this time.","Antagonist Tokens","Ok")
		return
	if(!isnum(tokens))
		return
	if(tokens < 1)
		alert(src,"You have 0 antagonist tokens.","Antagonist Tokens","Ok")
		return
	else
		var/antagchoice = alert(src,"You have [tokens] antagonist tokens. Do you wish to use one now?","Antagonist Tokens","Yes","No")
		if(antagchoice != "Yes")
			return
		if(choices.len > 1)
			antagchoice = input(src,"What antagonist from this list do you wish to be?","Antagonist Tokens",null) as null|anything in choices
		else
			antagchoice = choices[1]
		if(!(antagchoice in SSticker.mode.available_antag_tokens))
			return
		var/success = use_antag_token(antagchoice)
		if(success)
			to_chat(src, "<B>You have used an antagonist token.</B>")
			message_admins("[ckey] has used an antag token to be come a [antagchoice].")
			log_game("[ckey] has used an antag token to be come a [antagchoice].")

/client/proc/get_antag_token_count()
	if(!ckey)
		return 0
	var/path = GLOB.antagtokenpath
	var/savefile/S
	if(!S)
		S = new /savefile(path)
	if(!S)
		return 0
	var/tokens = 0
	S["[ckey]"] >> tokens
	if(isnum(tokens) && tokens > 0)
		return tokens
	else
		return 0

/client/proc/use_antag_token(var/antagtype = null)
	if(!ckey || !antagtype || !istext(antagtype)||!mob.mind)
		to_chat(src, "<B>You can't use an antagonist token right now.</B>")
		return 0
	if(!(mob.mind in GLOB.Original_Minds))
		to_chat(src, "<B>You must be a part of the original crew to use an antagonist token.</B>")
		return 0
	var/timesincestart = GLOB.Original_Minds[mob.mind]
	if(world.time > timesincestart+3000)
		to_chat(src, "<B>It is to late to use an antagonist token, You must use it with in the first 5 minutes of joining the station.</B>")
		return 0
	var/path = GLOB.antagtokenpath
	var/savefile/S
	if(!S)
		S = new /savefile(path)
	if(!S)
		to_chat(src, "<B>You can't use an antagonist token right now.</B>")
		return 0
	var/tokens = 0
	S["[ckey]"] >> tokens
	if(isnum(tokens) && tokens >= 1)
		if(mob.mind)
			if(mob.mind.special_role)
				to_chat(src, "<B>You are already an antagonist.</B>")
				return 0
			if(mob.mind.assigned_role)
				var/datum/job/J = SSjob.GetJob("[mob.mind.assigned_role]")
				if((CONFIG_GET(flag/protect_roles_from_antagonist) && (mob.mind.assigned_role in GLOB.memorized_restricted_jobs))||(J && J.antagonist_immune))
					to_chat(src, "<B>A [mob.mind.assigned_role] cannot be an antagonist.</B>")
					return 0
		var/success = 0
		switch(antagtype)
			if("traitor")
				if(istype(mob,/mob/living/carbon/human))
					mob.mind.add_antag_datum(/datum/antagonist/traitor)
					success = 1
			if("changeling")
				if(istype(mob,/mob/living/carbon/human))
					mob.mind.make_Changling()
					success = 1
			if("cult")
				if(istype(mob,/mob/living/carbon/human))
					if(istype(SSticker.mode,/datum/game_mode/cult))
						var/datum/game_mode/cult/cultmode = SSticker.mode
						cultmode.add_cultist(mob.mind, 0, equip=TRUE)
						success = 1
						if(cultmode.main_cult)
							var/datum/antagonist/cult/C = mob.mind.has_antag_datum(/datum/antagonist/cult,TRUE)
							if(C && C.cult_team)
								cultmode.main_cult = C.cult_team
			if("revs")
				if(istype(SSticker.mode,/datum/game_mode/revolution))
					var/datum/game_mode/revolution/revmode = SSticker.mode
					if(revmode.revolution)
						var/datum/antagonist/rev/head/new_head = new()
						new_head.give_flash = TRUE
						new_head.give_hud = TRUE
						new_head.remove_clumsy = TRUE
						mob.mind.add_antag_datum(new_head,revmode.revolution)
						success = 1
						revmode.revolution.update_objectives()
						revmode.revolution.update_heads()
		if(success)
			tokens--
			tokens = max(tokens,0)
			S["[ckey]"] << tokens
			return 1
	to_chat(src, "<B>You can't use an antagonist token right now.</B>")
	return 0

/datum/admins/proc/manage_antag_tokens()
	set name = "Manage Antag Tokens"
	set category = "Admin"
	var/list/themenu = list(
	"Check a ckey's antag token count" = 1,
	"Give antag token to ckey" = 2,
	"Remove antag token from ckey" = 3,
	"Set a ckey's antag tokens" = 4)
	var/choice = input(usr,"Choose an option","Manage Antag Tokens","Check a ckey's antag token count") as null|anything in themenu
	if(!(choice in themenu))
		return
	var/getckey = alert(usr,"Is the ckey currently online?","Manage Antag Tokens","Online","Offline")
	var/chosenckey
	if(getckey == "Online")
		var/list/onlineclients = GLOB.clients
		var/client/C = input(usr,"Choose a client","Manage Antag Tokens",null) as null|anything in onlineclients
		if(C.ckey)
			chosenckey = C.ckey
	else if(getckey == "Offline")
		chosenckey = input(usr,"Enter a ckey (Note: Ckeys must be all lowercase and not include any punctuation)","Manage Antag Tokens",null) as text
	if(!chosenckey)
		return
	var/path = GLOB.antagtokenpath
	var/savefile/S
	if(!S)
		S = new /savefile(path)
	if(!S)
		return
	var/tokens = 0
	S["[chosenckey]"] >> tokens
	if(!isnum(tokens) || tokens < 1)
		tokens = 0
	switch(themenu[choice])
		if(1)
			to_chat(usr,"<B>Player \"[chosenckey]\" has [tokens] antag tokens.<B>")
		if(2)
			to_chat(usr, "<B>You give one antag token to [chosenckey].")
			message_admins("[usr.ckey] gives one antag token to [chosenckey].")
			log_admin("[usr.ckey] gives one antag token to [chosenckey].")
			tokens++
			S["[chosenckey]"] << tokens
		if(3)
			to_chat(usr, "<B>You remove one antag token from [chosenckey].")
			message_admins("[usr.ckey] removes one antag token from [chosenckey].")
			log_admin("[usr.ckey] removes one antag token from [chosenckey].")
			tokens = max(tokens-1,0)
			S["[chosenckey]"] << tokens
		if(4)
			var/newtokencount = input(usr,"Enter a new value that will replace [chosenckey]'s antag token count.","Manage Antag Tokens",tokens) as num
			tokens = max(newtokencount,0)
			S["[chosenckey]"] << tokens
			message_admins("[usr.ckey] has set [chosenckey]'s antag tokens to [newtokencount]")
			log_admin("[usr.ckey] removes one antag token from [chosenckey].")

/datum/game_mode/revolution
	available_antag_tokens = list("revs")

/datum/game_mode/cult
	available_antag_tokens = list("cult")