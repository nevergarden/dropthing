package;

import core.DropData;
import core.ClientMessage;
import core.Room;
#if js

import core.RoomData;
import core.ServerMessage;
import core.JoinData;
import haxe.Json;
import hxd.res.Embed;
import hxd.res.FontBuilder;
import h2d.Font;
import h2d.Text;
import js.html.MessageEvent;
import js.html.WebSocket;
import h2d.Object;
import h2d.Interactive;
import h3d.Vector;
import h2d.Bitmap;
import h2d.Tile;

class Client extends hxd.App {
	var server : String = "ws://localhost:8000";
	var socket : WebSocket;
	var playerID : Int;
	var room : Room;

	var mainMenu : Object;
	var waitScene : Object;
	var gameScene : Object;
	var gameInfoText : Text;

	var waitingText : Text;

	var atlas : Tile;
	var font20 : Font;
	var board : Tile;
	var piece : Tile;
	var boardObj : Object;
	var piecesObj : Object;
	var gameOver : Bool = false;

	var m : Array<Int> = new Array<Int>();

	static final COLOR_RED:Vector =new Vector(229/255, 53/255, 44/255, 1);
	static final Color_ORANGE:Vector = new Vector(229/255, 123/255, 42/255, 1);
	static final Color_YELLOW:Vector = new Vector(229/255, 194/255, 42/255, 1);
	static final Color_GREEN:Vector = new Vector(148/255, 229/255, 42/255, 1);
	static final Color_TIEL:Vector = new Vector(42/255, 229/255, 201/255, 1);
	static final Color_BLUE:Vector = new Vector(42/255, 138/255, 229/255, 1);
	static final COLOR_PURPLE:Vector = new Vector(70/255, 43/255, 78/255, 1);

	function loadAtlas() {
		atlas = hxd.Res.boardandpiece.toTile();
		board = atlas.sub(0, 0, 22, 98);
		piece = atlas.sub(22,31, 16,16);
		var fontBuildOpt : FontBuildOptions = {
			antiAliasing: false
		};
		font20 = FontBuilder.getFont("R_res_evilempire_ttf", 24, fontBuildOpt);
	}

	override function init() : Void {
		engine.backgroundColor = 0xff393b45;
		s2d.scaleMode = ScaleMode.LetterBox(175,148);
		loadAtlas();

		createMainMenu();
		createWaitScene();
		s2d.addChild(mainMenu);
	}
	/*
		 __  __           _             __  __                        
		|  \/  |         (_)           |  \/  |                       
		| \  / |   __ _   _   _ __     | \  / |   ___   _ __    _   _ 
		| |\/| |  / _` | | | | '_ \    | |\/| |  / _ \ | '_ \  | | | |
		| |  | | | (_| | | | | | | |   | |  | | |  __/ | | | | | |_| |
		|_|  |_|  \__,_| |_| |_| |_|   |_|  |_|  \___| |_| |_|  \__,_|
	*/

	function createMainMenu() {
		mainMenu = new Object();
		var titleTile = atlas.sub(42, 34, 100, 20);
		var title = new Bitmap(titleTile, mainMenu);
		title.x = 40; title.y = 19;
		var joinButtonTile = atlas.sub(23, 58, 117, 40);
		var joinButton = new Bitmap(joinButtonTile, mainMenu);
		joinButton.color = new Vector(15/255, 164/255, 103/255, 1);
		joinButton.x = 31; joinButton.y = 51;

		var text : Text = new Text(font20, joinButton);
		text.text = "Join";
		text.x = 59 - (text.textWidth/2);
		text.y = 20 - (text.textHeight/2);

		var buttonInteractive : Interactive = new Interactive(117, 40, joinButton);
		buttonInteractive.onOver = function(e:hxd.Event) {
			joinButton.color = new Vector(30/255, 179/255, 118/255, 1);
		};

		buttonInteractive.onOut = function(e:hxd.Event) {
			joinButton.color = new Vector(15/255, 164/255, 103/255, 1);
		};
		
		buttonInteractive.onClick = function(e:hxd.Event) {
			joinMatch();
		}
	}

	/*
		__          __          _   _        _____                              
		\ \        / /         (_) | |      / ____|                             
		 \ \  /\  / /    __ _   _  | |_    | (___     ___    ___   _ __     ___ 
		  \ \/  \/ /    / _` | | | | __|    \___ \   / __|  / _ \ | '_ \   / _ \
		   \  /\  /    | (_| | | | | |_     ____) | | (__  |  __/ | | | | |  __/
			\/  \/      \__,_| |_|  \__|   |_____/   \___|  \___| |_| |_|  \___|																
    */

	function createWaitScene() {
		waitScene = new Object();
		waitingText = new Text(font20, waitScene);
	}

	function joinMatch() {
		s2d.removeChild(mainMenu);
		s2d.addChild(waitScene);
		waitingText.text = "Connecting To Server...";
		recalculateWaitingTextPos();
		connect();
	}

	function serverMessage(event:MessageEvent) {
		var data : ServerMessage = Json.parse(event.data);
		var type : ServerMessageType = data.type;
		var t : ServerMessageType = Connected;
		switch (type) {
			case Connected:
				waitForOpponent(data);
			case RoomReady:
				setRoomData(data);
			case RoomUpdate:
				updateRoom(data);
			case _:
				socket.close();
		}
	}

	function waitForOpponent(data : ServerMessage) {
		var joinData : JoinData = data.data;
		playerID = joinData.id;
		waitingText.text = "Waiting For Opponent...";
		recalculateWaitingTextPos();
	}

	function setRoomData(data :ServerMessage) {
		var roomData : RoomData = data.data;
		room = Room.fromRoomData(roomData);
		drawField(roomData.rowsCount, roomData.columnCount);

		if(room.roomData.roomState == RoomState.Ready) {
			s2d.removeChild(waitScene);
			s2d.addChild(gameScene);
		}
	}

	function updateRoom(data : ServerMessage ) : Void {
		var roomData : RoomData = data.data;
		room.roomData = roomData;
		updateField();
	}

	function reset() {
		s2d.removeChildren();
		s2d.addChild(mainMenu);	
	}

	function connect() {
		socket = new WebSocket(server);
		socket.addEventListener("message", serverMessage);
		socket.addEventListener("close", reset);
		socket.addEventListener("error", reset);
	}

	function recalculateWaitingTextPos() {
		waitingText.x = 89 - (waitingText.textWidth/2);
		waitingText.y = 70 - (waitingText.textHeight/2);
	}

	/*
   _____                        _                 _      
  / ____|                      | |               (_)     
 | |  __  __ _ _ __ ___   ___  | |     ___   __ _ _  ___ 
 | | |_ |/ _` | '_ ` _ \ / _ \ | |    / _ \ / _` | |/ __|
 | |__| | (_| | | | | | |  __/ | |___| (_) | (_| | | (__ 
  \_____|\__,_|_| |_| |_|\___| |______\___/ \__, |_|\___|
                                             __/ |       
                                            |___/        
	*/

	/**
		Generates a new board from model.
	**/
	function drawField(rowCount:Int, columnCount:Int) : Void {
		gameScene = new Object();
		piecesObj = new Object();
		gameInfoText = new Text(font20 , gameScene);
		gameInfoText.x = 89 - (gameInfoText.textWidth/2);
		gameInfoText.y = 10 - (gameInfoText.textHeight/2);
		gameScene.addChild(piecesObj);
		var x : Int = 11;
		var y : Int = 46;

		piecesObj.x = x;
		piecesObj.y = y;

		for (i in 0...columnCount) {
			var b = new Bitmap(board,gameScene);
			b.color = new Vector(225/255, 109/255, 54/255, 1);
			b.x = x;
			b.y = y;
			x+=22;
		}

		var interactive = new Interactive(22*columnCount, 98, gameScene);
		interactive.x = 11;
		interactive.y = 46;
		interactive.onClick = drop;
	}

	function drop(e:hxd.Event) {
		var column : Int = Math.floor(e.relX/22);
		var dropData : DropData = {
			column: column
		};
		var message : ClientMessage = {
			room: this.room.roomID,
			playerId: this.playerID,
			type: Drop,
			data: dropData
		};
		this.socket.send(Json.stringify(message));
	}

	function updateField() {
		if(gameOver)
			return;

		if(room.roomData.roomState == Player1Turn)
			gameInfoText.text = "Player 1 Turn";
		else if(room.roomData.roomState == Player2Turn)
			gameInfoText.text = "Player 2 Turn";

		if(room.roomData.winner != 0) {
			gameInfoText.text = 'Winner is Player ${room.roomData.winner}';
			gameOver = true;
		}
		gameInfoText.x = 89 - (gameInfoText.textWidth/2);
		gameInfoText.y = 10 - (gameInfoText.textHeight/2);
		piecesObj.removeChildren();
		for(i in 0...room.roomData.rowsCount) {
			for(j in 0...room.roomData.columnCount) {
				var player = room.get(j, i);
				if(player != 0) {
					var bmp = new Bitmap(piece, piecesObj);
					bmp.x = (j*22)+3;
					bmp.y = ((room.roomData.rowsCount-i-1)*19)+3;
					if(player == 1) {
						bmp.color = COLOR_RED;
					} else {
						bmp.color = Color_BLUE;
					}
				}
			}
		}
	}

	override function update(_) : Void {}

	static function main() {
		Embed.embedFont("res/evilempire.ttf");
		hxd.Res.initEmbed();
		new Client();
	}
}

#end