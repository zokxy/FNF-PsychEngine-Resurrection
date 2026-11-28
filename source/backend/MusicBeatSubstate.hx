package backend;

import flixel.FlxSubState;
#if debug
import backend.ui.PsychUIInputText;
#end

class MusicBeatSubstate extends FlxSubState
{
	public function new()
	{
		super();
	}

	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	public var scripts:StateScriptManager;
	public var allowStateScripts:Null<Bool> = null;
	var _scriptsPostCalled:Bool = false;
	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return Controls.instance;

	function getScriptName():String
	{
		var clsName:String = Type.getClassName(Type.getClass(this));
		return clsName.substr(clsName.lastIndexOf('.') + 1);
	}

	function getScriptExtraVars():Map<String, Dynamic>
		return null;

	function shouldLoadStateScripts():Bool
	{
		if (allowStateScripts != null) return allowStateScripts;
		if (Std.isOfType(this, CustomFadeTransition)) return false;
		var clsName:String = Type.getClassName(Type.getClass(this));
		if (clsName.startsWith('states.editors.')) return false;
		return true;
	}

	function ensureScriptsPost():Void
	{
		if (_scriptsPostCalled || scripts == null) return;
		_scriptsPostCalled = true;
		scripts.call('onCreatePost');
	}

	override function create()
	{
		super.create();
		if (shouldLoadStateScripts())
		{
			scripts = new StateScriptManager(this, getScriptName(), true, getScriptExtraVars());
			scripts.load();
			scripts.call('onCreate');
		}
	}

	override function draw()
	{
		ensureScriptsPost();
		super.draw();
	}

	override function update(elapsed:Float)
	{
		var oldStep:Int = curStep;

		#if debug
		if (PsychUIInputText.focusOn == null && FlxG.keys.justPressed.F5)
		{
			if (FlxG.keys.pressed.SHIFT)
			{
				MusicBeatState.resetState();
				return;
			}
			if (scripts != null) scripts.requestReload();
		}
		#end

		if (scripts != null)
		{
			ensureScriptsPost();
			scripts.flushReload();
			if (scripts.call('onUpdate', [elapsed]) == StateScript.Function_Stop)
				return;
		}

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();

		super.update(elapsed);

		if (scripts != null)
		{
			scripts.call('onUpdatePost', [elapsed]);
			scripts.flushReload();
		}
	}

	public function stepHit():Void
	{
		if (scripts != null && scripts.call('onStepHit', [curStep]) == StateScript.Function_Stop)
			return;

		if (curStep % 4 == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		if (scripts != null) scripts.call('onBeatHit', [curBeat]);
	}

	public function sectionHit():Void
	{
		if (scripts != null) scripts.call('onSectionHit', [curSection]);
	}

	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;
				
				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	
	override function destroy()
	{
		if (scripts != null)
		{
			scripts.destroy(false);
			scripts = null;
		}
		super.destroy();
	}
	
	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}
}
