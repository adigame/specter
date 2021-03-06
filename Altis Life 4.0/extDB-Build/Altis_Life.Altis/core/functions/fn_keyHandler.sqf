#include <macro.h>
/*
	File: fn_keyHandler.sqf
	Author: Bryan "Tonic" Boardwine
	
	Description:
	Main key handler for event 'keyDown'
*/
private ["_handled","_shift","_alt","_code","_ctrl","_alt","_ctrlKey","_veh","_locked","_interactionKey","_mapKey","_interruptionKeys"/*,"_blinkerRechts","_blinkerLinks","_blinkerWarn"*/];
_ctrl = SEL(_this,0);
_code = SEL(_this,1);
_shift = SEL(_this,2);
_ctrlKey = SEL(_this,3);
_alt = SEL(_this,4);
_speed = speed cursorTarget;
_handled = false;

_interactionKey = if((EQUAL(count (actionKeys "User10"),0))) then {219} else {(actionKeys "User10") select 0};
_mapKey = SEL(actionKeys "ShowMap",0);
//hint str _code;
_interruptionKeys = [17,30,31,32]; //A,S,W,D

//Vault handling...
if((_code in (actionKeys "GetOver") || _code in (actionKeys "salute")) && {(player GVAR ["restrained",false])}) exitWith {
	true;
};

if(life_action_inUse) exitWith {
	if(!life_interrupted && _code in _interruptionKeys) then {life_interrupted = true;};
	_handled;
};

//Hotfix for Interaction key not being able to be bound on some operation systems.
if(!(EQUAL(count (actionKeys "User10"),0)) && {(inputAction "User10" > 0)}) exitWith {
	//Interaction key (default is Left Windows, can be mapped via Controls -> Custom -> User Action 10)
	if(!life_action_inUse) then {
		[] spawn {
			private "_handle";
			_handle = [] spawn life_fnc_actionKeyHandler;
			waitUntil {scriptDone _handle};
			life_action_inUse = false;
		};
	};
	true;
};

switch (_code) do {
	//Space key for Jumping
	case 57: {
		if(isNil "jumpActionTime") then {jumpActionTime = 0;};
		if(_shift && {!(EQUAL(animationState player,"AovrPercMrunSrasWrflDf"))} && {isTouchingGround player} && {EQUAL(stance player,"STAND")} && {speed player > 2} && {!life_is_arrested} && {SEL((velocity player),2) < 2.5} && {time - jumpActionTime > 1.5}) then {
			jumpActionTime = time; //Update the time.
			[player,true] spawn life_fnc_jumpFnc; //Local execution
			[[player,false],"life_fnc_jumpFnc",nil,FALSE] call life_fnc_MP; //Global execution 
			_handled = true;
		};
	};
	
	//Map Key
	case _mapKey: {
		switch (playerSide) do {
			case west: {if(!visibleMap) then {[] spawn life_fnc_copMarkers;}};
			case independent: {if(!visibleMap) then {[] spawn life_fnc_medicMarkers;}};
		};
	};
	
	//Holster / recall weapon.
	case 35: {
		if(_shift && !_ctrlKey && !(EQUAL(currentWeapon player,""))) then {
			life_curWep_h = currentWeapon player;
			player action ["SwitchWeapon", player, player, 100];
			player switchCamera cameraView;
		};
		
		if(!_shift && _ctrlKey && !isNil "life_curWep_h" && {!(EQUAL(life_curWep_h,""))}) then {
			if(life_curWep_h in [RIFLE,LAUNCHER,PISTOL]) then {
				player selectWeapon life_curWep_h;
			};
		};
	};
	
	//Interaction key (default is Left Windows, can be mapped via Controls -> Custom -> User Action 10)
	case _interactionKey: {
		if(!life_action_inUse) then {
			[] spawn  {
				private "_handle";
				_handle = [] spawn life_fnc_actionKeyHandler;
				waitUntil {scriptDone _handle};
				life_action_inUse = false;
			};
		};
	};
	
	//Restraining (Shift + R)
	case 19: {
		if(_shift) then {_handled = true;};
		if(_shift && playerSide == west && {!isNull cursorTarget} && {cursorTarget isKindOf "Man"} && {(isPlayer cursorTarget)} && {(side cursorTarget in [civilian,independent])} && {alive cursorTarget} && {cursorTarget distance player < 3.5} && {!(cursorTarget GVAR "Escorting")} && {!(cursorTarget GVAR "restrained")} && {speed cursorTarget < 1}) then {
			[] call life_fnc_restrainAction;
		};
	};
	
	//Knock out, this is experimental and yeah...
	case 34: {
		if(_shift) then {_handled = true;};
		if(_shift && playerSide == civilian && {!isNull cursorTarget} && {cursorTarget isKindOf "Man"} && {isPlayer cursorTarget} && {alive cursorTarget} && {cursorTarget distance player < 4} && {speed cursorTarget < 1}) then {
			if(!(EQUAL(animationState cursorTarget,"Incapacitated")) && {(EQUAL(currentWeapon player,RIFLE))} OR {EQUAL(currentWeapon player,PISTOL)} && {!(EQUAL(currentWeapon player,""))} && {!life_knockout} && {!(player GVAR ["restrained",false])} && {!life_istazed}) then {
				[cursorTarget] spawn life_fnc_knockoutAction;
			};
		};
	};

	//T Key (Trunk)
	case 20: {
		if(!_alt && !_ctrlKey && !life_is_processing) then {
			if(vehicle player != player && alive vehicle player) then {
				if((vehicle player) in life_vehicles) then {
					[vehicle player] call life_fnc_openInventory;
				};
			} else {
				private "_list";
				_list = ["landVehicle","Air","Ship","House_F"];
				if(KINDOF_ARRAY(cursorTarget,_list) && {player distance cursorTarget < 7} && {vehicle player == player} && {alive cursorTarget}) then {
					if(cursorTarget in life_vehicles OR {!(cursorTarget GVAR ["locked",true])} && !life_is_processing) then {
						[cursorTarget] call life_fnc_openInventory;
					};
				};
			};
		};
	};
	//L Key?
	case 38: {
		//If cop run checks for turning lights on.
		if(_shift && playerSide in [west,independent]) then {
			if(vehicle player != player && (typeOf vehicle player) in ["C_Offroad_01_F","B_MRAP_01_F","C_SUV_01_F"]) then {
				if(!isNil {vehicle player GVAR "lights"}) then {
					if(playerSide == west) then {
						[vehicle player] call life_fnc_sirenLights;
					} else {
						[vehicle player] call life_fnc_medicSirenLights;
					};
					_handled = true;
				};
			};
		};
		
		if(!_alt && !_ctrlKey) then { [] call life_fnc_radar; };
	};
	
	//Y Player Menu
	case 21: {
		if(!_alt && !_ctrlKey && !dialog && !life_is_processing) then {
			[] call life_fnc_p_openMenu;
		};
	};
	
	//F Key Siren - Shift + F Yelp
	case 33: {
		if(_shift) then
            {
                if(playerSide in [west,independent] && vehicle player != player && !life_medicSiren2_active && ((driver vehicle player) == player)) then
                {
                    [] spawn
                    {
                        life_medicSiren2_active = true;
                        sleep 1.2;
                        life_medicSiren2_active = false;
                    };
                    _veh = vehicle player;
                    if(isNil {_veh GVAR "medicSiren2"}) then {_veh SVAR["medicSiren2",false,true];};
                    if((_veh GVAR "medicsiren2")) then
                    {
                        titleText ["Yelp Off","PLAIN"];
                        _veh SVAR["medicSiren2",false,true];
                    } else {
                        titleText ["Yelp On","PLAIN"];
                        _veh SVAR["medicSiren2",true,true];
						if(playerside == west) then {						
                        [[_veh],"life_fnc_copsiren2",nil,true] call life_fnc_MP;
					} else {
						[[_veh],"life_fnc_medicSiren2",nil,true] call life_fnc_MP;
                    };
                };
            };
		};
		if(!_shift) then {
		if(playerSide in [west,independent] && {vehicle player != player} && {!life_siren_active} && {((driver vehicle player) == player)}) then {
			[] spawn {
				life_siren_active = true;
				sleep 4.7;
				life_siren_active = false;
			};
			
			_veh = vehicle player;
			if(isNil {_veh GVAR "siren"}) then {_veh SVAR ["siren",false,true];};
			if((_veh GVAR "siren")) then {
				titleText [localize "STR_MISC_SirensOFF","PLAIN"];
				_veh SVAR ["siren",false,true];
			} else {
				titleText [localize "STR_MISC_SirensON","PLAIN"];
				_veh SVAR ["siren",true,true];
				if(playerSide == west) then {
					[[_veh],"life_fnc_copSiren",nil,true] call life_fnc_MP;
				} else {
					[[_veh],"life_fnc_medicSiren",nil,true] call life_fnc_MP;
				};		
			};
		};
	};
};
	
	
	//Shift+P = Faded Sound
	case 25: {
		if(_shift) then {
			[] call life_fnc_fadeSound;
			_handled = true;
		};
	};
	
	//U Key
	case 22: {
		if(!_alt && !_ctrlKey) then {
			if(vehicle player == player) then {
				_veh = cursorTarget;
			} else {
				_veh = vehicle player;
			};
			
			if(_veh isKindOf "House_F" && {playerSide == civilian}) then {
				if(_veh in life_vehicles && player distance _veh < 8) then {
					_door = [_veh] call life_fnc_nearestDoor;
					if(EQUAL(_door,0)) exitWith {hint localize "STR_House_Door_NotNear"};
					_locked = _veh GVAR [format["bis_disabled_Door_%1",_door],0];
					
					if(EQUAL(_locked,0)) then {
						_veh SVAR [format["bis_disabled_Door_%1",_door],1,true];
						_veh animate [format["door_%1_rot",_door],0];
						systemChat localize "STR_House_Door_Lock";
					} else {
						_veh SVAR [format["bis_disabled_Door_%1",_door],0,true];
						_veh animate [format["door_%1_rot",_door],1];
						systemChat localize "STR_House_Door_Unlock";
					};
				};
			} else {
				_locked = locked _veh;
				if(_veh in life_vehicles && player distance _veh < 8) then {
					if(EQUAL(_locked,2)) then {
						if(local _veh) then {
							_veh lock 0;
						} else {
							[[_veh,0],"life_fnc_lockVehicle",_veh,false] call life_fnc_MP;
						};
						systemChat localize "STR_MISC_VehUnlock";
						[[_veh],"life_fnc_UnlockCarSound",nil,true] spawn life_fnc_MP;
					} else {
						if(local _veh) then {
							_veh lock 2;
						} else {
							[[_veh,2],"life_fnc_lockVehicle",_veh,false] call life_fnc_MP;
						};	
						systemChat localize "STR_MISC_VehLock";
						[[_veh],"life_fnc_LockCarSound",nil,true] spawn life_fnc_MP;
					};
				};
			};
		};
	};
	
	//indicators

	
	case 16: {
		if(alive vehicle player && vehicle player != player && ((driver vehicle player) == player) ) then {
			//[_veh,"left"] call life_fnc_BlinkerInit;	
			[[vehicle player,"left"],"life_fnc_BlinkerInit",true,false]  call life_fnc_mp;							
		};			
	};		
	
	case 18: { // E Right
		if(alive vehicle player && vehicle player != player && ((driver vehicle player) == player) ) then{
		//	[_veh,"right"] call life_fnc_BlinkerInit;			
			[[vehicle player,"right"],"life_fnc_BlinkerInit",true,false]  call life_fnc_mp;			
		};
	};	
	
	case 15: { // Tab Warning
		if(alive vehicle player && vehicle player != player && ((driver vehicle player) == player) ) then{
			[[vehicle player,"warning"],"life_fnc_BlinkerInit",true,false]  call life_fnc_mp;			
		};
	};
	
	//O Police Gate Opener
	
	 case 24:
	{
		if (!_shift && !_alt && !_ctrlKey && (playerSide == west) && (vehicle player != player)) then {
			[] call life_fnc_copOpener;
		};
	};
};




_handled;