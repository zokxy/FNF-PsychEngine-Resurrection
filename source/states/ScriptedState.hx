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

	override function create()
	{
		initPsychCamera();
		super.create();
	}

	public static function open(scriptName:String, ?args:Array<Dynamic>):Void
	{
		MusicBeatState.switchState(new ScriptedState(scriptName, args));
	}
}