package backend;

import flixel.FlxState;
import backend.PsychCamera;
#if debug
import backend.ui.PsychUIInputText;
#end

class MusicBeatState extends FlxState
{
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	public var scripts:StateScriptManager;
	public var allowStateScripts:Null<Bool> = null;
	var _scriptsPostCalled:Bool = false;

	public var controls(get, never):Controls;
	private function get_controls()
	{
		return Controls.instance;
	}

	var _psychCameraInitialized:Bool = false;

	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static function getVariables()
		return getState().variables;

	override function create()
	{
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		#if MODS_ALLOWED Mods.updatedOnState = false; #end

		if (!_psychCameraInitialized) initPsychCamera();

		super.create();
		initStateScripts();
		FlxG.signals.postStateSwitch.addOnce(callStateScriptsPost);

		if (!skip)
			openSubState(new CustomFadeTransition(0.5, true));
		FlxTransitionableState.skipNextTransOut = false;
		timePassedOnState = 0;
	}

	function shouldLoadStateScripts():Bool
	{
		if (allowStateScripts != null) return allowStateScripts;
		var clsName:String = Type.getClassName(Type.getClass(this));
		if (clsName == 'states.LoadingState' || clsName.startsWith('states.editors.'))
			return false;
		return true;
	}

	function getScriptName():String
	{
		var clsName:String = Type.getClassName(Type.getClass(this));
		return clsName.substr(clsName.lastIndexOf('.') + 1);
	}

	function getScriptExtraVars():Map<String, Dynamic>
		return null;

	function initStateScripts():Void
	{
		if (scripts != null || !shouldLoadStateScripts()) return;
		scripts = new StateScriptManager(this, getScriptName(), false, getScriptExtraVars());
		scripts.load();
		scripts.call('onCreate');
	}

	function callStateScriptsPost():Void
	{
		if (_scriptsPostCalled || scripts == null) return;
		_scriptsPostCalled = true;
		scripts.call('onCreatePost');
	}

	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		return camera;
	}

	public static var timePassedOnState:Float = 0;
	override function update(elapsed:Float)
	{
		var oldStep:Int = curStep;

		#if debug
		if (subState == null && PsychUIInputText.focusOn == null && FlxG.keys.justPressed.F5)
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
			if (!_scriptsPostCalled) callStateScriptsPost();
			scripts.flushReload();
			if (scripts.call('onUpdate', [elapsed]) == StateScript.Function_Stop)
				return;
		}

		timePassedOnState += elapsed;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep)
		{
			if (curStep > 0)
				stepHit();

			if (PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		if (FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;

		stagesFunc(function(stage:BaseStage) {
			stage.update(elapsed);
		});

		super.update(elapsed);
		if (scripts != null)
		{
			scripts.call('onUpdatePost', [elapsed]);
			scripts.flushReload();
		}
	}

	private function updateSection():Void
	{
		if (stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while (curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	private function rollbackSection():Void
	{
		if (curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if (stepsToDo > curStep) break;
				curSection++;
			}
		}

		if (curSection > lastSection) sectionHit();
	}

	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep / 4;
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.data.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(nextState:FlxState = null)
	{
		if (nextState == null) nextState = FlxG.state;
		if (nextState == FlxG.state)
		{
			resetState();
			return;
		}

		if (FlxTransitionableState.skipNextTransIn) FlxG.switchState(nextState);
		else startTransition(nextState);
		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function resetState()
	{
		if (FlxTransitionableState.skipNextTransIn) FlxG.resetState();
		else startTransition();
		FlxTransitionableState.skipNextTransIn = false;
	}

	public static function startTransition(nextState:FlxState = null)
	{
		if (nextState == null)
			nextState = FlxG.state;

		FlxG.state.openSubState(new CustomFadeTransition(0.5, false));
		if (nextState == FlxG.state)
			CustomFadeTransition.finishCallback = function() FlxG.resetState();
		else
			CustomFadeTransition.finishCallback = function() FlxG.switchState(nextState);
	}

	public static function getState():MusicBeatState
	{
		return cast (FlxG.state, MusicBeatState);
	}

	public function stepHit():Void
	{
		if (scripts != null && scripts.call('onStepHit', [curStep]) == StateScript.Function_Stop)
			return;

		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

	public var stages:Array<BaseStage> = [];
	public function beatHit():Void
	{
		if (scripts != null && scripts.call('onBeatHit', [curBeat]) == StateScript.Function_Stop)
			return;

		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	public function sectionHit():Void
	{
		if (scripts != null && scripts.call('onSectionHit', [curSection]) == StateScript.Function_Stop)
			return;

		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if (stage != null && stage.exists && stage.active)
				func(stage);
	}

	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if (PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}

	override function openSubState(SubState:flixel.FlxSubState)
	{
		if (scripts != null && !Std.isOfType(SubState, CustomFadeTransition))
			if (scripts.call('onOpenSubState', [SubState]) == StateScript.Function_Stop)
				return;
		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		var wasTransition:Bool = Std.isOfType(subState, CustomFadeTransition);
		super.closeSubState();
		if (scripts != null && !wasTransition)
			scripts.call('onCloseSubState');
	}

	override function destroy()
	{
		FlxG.signals.postStateSwitch.remove(callStateScriptsPost);
		if (scripts != null)
		{
			scripts.destroy(false);
			scripts = null;
		}
		super.destroy();
		if (MemoryManager.gcPausedInGameplay)
			MemoryManager.exitGameplay(true);
	}
}