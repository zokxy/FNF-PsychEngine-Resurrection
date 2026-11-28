package states;

import backend.MusicBeatState;

class ScriptedState extends MusicBeatState
{
	public var scriptName:String;
	public var scriptArgs:Array<Dynamic>;

	public function new(scriptName:String, ?args:Array<Dynamic>)
	{
		this.scriptName = scriptName;
		this.scriptArgs = args != null ? args : [];
		super();
	}

	override function getScriptName():String
		return scriptName;

	override function getScriptExtraVars():Map<String, Dynamic>
		return ['scriptArgs' => scriptArgs];

	var _missingScript:Bool = false;

	override function create()
	{
		super.create();

		if (scripts == null || scripts.scripts.length == 0)
		{
			_missingScript = true;
			var errTxt = new FlxText(0, 0, FlxG.width - 80,
				'ScriptedState "' + getScriptName() + '" not found!\nPress ESC or BACK to return to Main Menu.', 24);
			errTxt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.RED, CENTER);
			errTxt.screenCenter();
			add(errTxt);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (_missingScript && (controls.BACK || FlxG.keys.justPressed.ESCAPE))
			MusicBeatState.switchState(new MainMenuState());
	}

	public static function open(scriptName:String, ?args:Array<Dynamic>):Void
	{
		MusicBeatState.switchState(new ScriptedState(scriptName, args));
	}
}