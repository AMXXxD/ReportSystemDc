#include < amxmodx >
#include < grip >

#define ANTIFLOOD	300		//Ile czasu trzeba czekac zeby zglosic jeszcze raz
#define REP_IMMUN	ADMIN_RCON		//Flaga jaka ma nie byc brana pod uwage w menu

new const WEBHOOK[] =	"WPISZ TU SWOJEGO WEBHOOKA";

new const cmds[][] = {
	"say /report", 	"say_team /report",
	"say /zglos", "say_team /zglos"
};

new const reasons[][] = {
	"Wyzywa",
	"Obraza",
	"Przeklina",
	"Mowi brzydkie slowa"
};

new const PREFIX[] =	"^3[^4Report System^3]";

new const SHABLON_REPORT[] =	"@everyone^n{hostname} ({ip})^nОт: {rname} ({rauth})^nНа: {vname} ({vauth}) ({vip})^nПричина: {reason}";	//То что, будет написано в дискорд канал

new gTarget[33], gReason[33][192], rMenu;
#if defined ANTIFLOOD
new Trie: AntiF, AntiFlood[33];
#endif

new gHostname[64], gIp[22];

public plugin_init(){
	register_plugin("Report System DC", "0.2", "Amxxxd unikalny plugin 2023");
	
	for(new i; i < sizeof cmds; i ++)
		register_clcmd(cmds[i], "gotoMenu");
	
	create_reasons();
	
	get_cvar_string("hostname", gHostname, charsmax(gHostname));
	get_user_ip(0, gIp, charsmax(gIp));
	
	#if defined ANTIFLOOD
	AntiF = TrieCreate();
	#endif
}

#if defined ANTIFLOOD
public plugin_end()
	TrieDestroy(AntiF);
#endif

public create_reasons(){
	rMenu = menu_create("\wWybierz powod", "handler_reason");
	
	for(new i; i < sizeof reasons; i ++)
		menu_additem(rMenu, reasons[i]);
	
	menu_setprop(rMenu, MPROP_NEXTNAME, "Dalej");
	menu_setprop(rMenu, MPROP_BACKNAME, "Wroc");
	menu_setprop(rMenu, MPROP_EXITNAME, "Wyjdz");
}

public client_putinserver(id){
	clear(id);
	
	#if defined ANTIFLOOD	
	new steam[35];	
	get_user_authid(id, steam, charsmax(steam));
	if(!TrieGetCell(AntiF, steam, AntiFlood[id]))
		AntiFlood[id] = 0;
	#endif
}

#if defined ANTIFLOOD
public client_disconnected(id){
	if(AntiFlood[id] > get_systime()){
		new steam[35];	
		get_user_authid(id, steam, charsmax(steam));
		TrieSetCell(AntiF, steam, AntiFlood[id]);
	}
}
#endif

public clear(id){
	gTarget[id] = 0;
	gReason[id][0] = '^0';
}

public gotoMenu(id){
	clear(id);
	
	new menu = menu_create("\wWybierz gracza", "handler_players");
	
	new pl[32], cnt;
	get_players(pl, cnt, "ch");
	
	for(new i, player; i < cnt; i ++){
		player = pl[i];
		
		#if !defined REP_IMMUN
		if(player == id)	
			continue;
		#else
		if(player == id || get_user_flags(player) & REP_IMMUN)	
			continue;
		#endif
		
		menu_additem(menu, fmt("%n", player), fmt("%d", player));
	}
	
	if(!menu_items(menu)){
		client_print_color(id, 0, "%s Na serwerze nie ma graczy", PREFIX);
		menu_destroy(menu);
		return;
	}
	
	menu_setprop(menu, MPROP_NEXTNAME, "Dalej");
	menu_setprop(menu, MPROP_BACKNAME, "Wroc");
	menu_setprop(menu, MPROP_EXITNAME, "Wyjdz");
	
	menu_display(id, menu);
}

public handler_players(id, menu, item){
	if(item == MENU_EXIT){
		menu_destroy(menu);
		return;
	}
	
	#if defined ANTIFLOOD
	new systime;
	if(AntiFlood[id] > (systime = get_systime())){
		client_print_color(id, 0, "%s Zgloszenie gracza bedzie mozliwe za^4 %d sekund.", PREFIX, AntiFlood[id] - systime);
		menu_destroy(menu);
		return;
	}
	#endif
	
	new access, name[32], info[10], clbck;
	menu_item_getinfo(menu, item, access, info, charsmax(info), name, charsmax(name), clbck);
	menu_destroy(menu);
	
	new pl = str_to_num(info);
	if(!check_target(id, pl)){
		gotoMenu(id);
		return;
	}
	
	gTarget[id] = pl;
	menu_display(id, rMenu);
}

public handler_reason(id, menu, item){
	if(item == MENU_EXIT)
		return;
	
	copy(gReason[id], charsmax(gReason[]), reasons[item]);
	send_report(id);
}

public send_report(id){	
	if(!is_user_connected(id) || !check_target(id, gTarget[id]))
		return;
	
	new text[1024], steam[35], ip[17], psteam[35], pip[17];
	get_user_authid(id, steam, charsmax(steam));
	get_user_authid(gTarget[id], psteam, charsmax(psteam));
	get_user_ip(id, ip, charsmax(ip), 1);
	get_user_ip(gTarget[id], pip, charsmax(pip), 1);
	
	format(text, charsmax(text), "content=%s", SHABLON_REPORT);
	
	replace_string(text, charsmax(text), "{rname}", fmt("%n", id));
	replace_string(text, charsmax(text), "{rauth}", steam);
	replace_string(text, charsmax(text), "{rip}", ip);	
	replace_string(text, charsmax(text), "{vname}", fmt("%n", gTarget[id]));
	replace_string(text, charsmax(text), "{vauth}", psteam);
	replace_string(text, charsmax(text), "{vip}", pip);
	replace_string(text, charsmax(text), "{reason}", gReason[id]);
	replace_string(text, charsmax(text), "{hostname}", gHostname);
	replace_string(text, charsmax(text), "{ip}", gIp);
	
	GoRequest(id, WEBHOOK, "Handler_SendReason", GripRequestTypePost, text);
	
	clear(id);
	#if defined ANTIFLOOD
	AntiFlood[id] = get_systime() + ANTIFLOOD;
	#endif
}

public Handler_SendReason(const id){
	if(!is_user_connected(id))
		return;
	
	if(!HandlerGetErr()){
		client_print_color(id, 0, "%s Wystapil blad, skontaktuj sie z ^4administracja", PREFIX);
		#if defined ANTIFLOOD
		AntiFlood[id] = 0;
		#endif
		return;
	}
	
	client_print_color(id, 0, "%s Zgloszenie zostalo^4 pomyslnie wyslane!", PREFIX);
}

public check_target(id, pl){
	if(!is_user_connected(pl)){
		client_print_color(id, 0, "%s Gracz wyszedl z^4 serwera!", PREFIX);
		clear(id);
		return false;
	}
	return true;
}

public GoRequest(const id, const site[], const handler[], const GripRequestType:type, data[]){		
	new GripRequestOptions:options = grip_create_default_options();
	grip_options_add_header(options, "Content-Type", "application/x-www-form-urlencoded");
	
	new GripBody: body = grip_body_from_string(data);
	grip_request(site, body, type, handler, options, id);	
	
	grip_destroy_body(body);	
	grip_destroy_options(options);
}

public bool: HandlerGetErr(){
	if(grip_get_response_state() == GripResponseStateError){
		log_amx("ResponseState is Error");
		return false;
	}
	
	new GripHTTPStatus:err;
	if((err = grip_get_response_status_code()) != GripHTTPStatusNoContent){
		log_amx("ResponseStatusCode is %d", err);
		return false;
	}
	
	return true;
}